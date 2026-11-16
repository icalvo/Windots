#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Watch configured git repos and sync via git-sync.ps1 -n -s -ForceLocal.

Throttle (leading-edge): sync immediately on local change, then at most once per
throttleSeconds; if more changes arrive during the window, sync again when it opens.

Also polls remotes with git fetch every fetchSeconds; if not in sync, runs git-sync.
Routine fetch/state messages are quiet unless a difference is found (or -Verbose).

Machine-local config: %LOCALAPPDATA%\git-auto-push\repos.json
Log file:            %LOCALAPPDATA%\git-auto-push\watcher.log
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$StateDir = Join-Path $env:LOCALAPPDATA 'git-auto-push'
$ConfigPath = Join-Path $StateDir 'repos.json'
$LogPath = Join-Path $StateDir 'watcher.log'
$PidPath = Join-Path $StateDir 'watcher.pid'
$GitSyncPath = Join-Path $PSScriptRoot 'git-sync.ps1'
$DefaultThrottleSeconds = 10
$DefaultFetchSeconds = 20
$MaxLogBytes = 5MB

# Shared with FileSystemWatcher event runspaces
$Shared = [hashtable]::Synchronized(@{
        Dirty        = [hashtable]::Synchronized(@{})  # path -> $true when local FS activity
        Throttles    = [hashtable]::Synchronized(@{})  # path -> seconds
        FetchSeconds = [hashtable]::Synchronized(@{})  # path -> seconds
        ConfigReload = $false
        Stop         = $false
    })

$Watchers = @{}
$ConfigWatcher = $null
$LastSync = @{}   # path -> datetime
$LastFetch = @{}  # path -> datetime
$Syncing = @{}

function Write-WatcherLog {
    param(
        [string]$Message,
        [switch]$VerboseOnly
    )
    if ($VerboseOnly -and $VerbosePreference -ne 'Continue') {
        return
    }
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try {
        if (-not (Test-Path $StateDir)) {
            New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
        }
        if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt $MaxLogBytes)) {
            $rotated = "$LogPath.1"
            if (Test-Path $rotated) { Remove-Item $rotated -Force -ErrorAction SilentlyContinue }
            Move-Item $LogPath $rotated -Force
        }
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    }
    catch { }
    Write-Host $line
}

function Get-NormalizedPath {
    param([string]$Path)
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    }
    catch {
        return $Path
    }
}

function Read-RepoConfig {
    if (-not (Test-Path $ConfigPath)) {
        return @()
    }
    try {
        $raw = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @()
        }
        $obj = $raw | ConvertFrom-Json
        $list = @()
        foreach ($r in @($obj.repos)) {
            if (-not $r.path) { continue }
            $throttle = $DefaultThrottleSeconds
            if ($null -ne $r.throttleSeconds -and "$($r.throttleSeconds)" -ne '') {
                $throttle = [int]$r.throttleSeconds
            }
            if ($throttle -lt 1) { $throttle = 1 }

            $fetch = $DefaultFetchSeconds
            if ($null -ne $r.fetchSeconds -and "$($r.fetchSeconds)" -ne '') {
                $fetch = [int]$r.fetchSeconds
            }
            if ($fetch -lt 1) { $fetch = 1 }

            $list += [pscustomobject]@{
                Path            = Get-NormalizedPath $r.path
                ThrottleSeconds = $throttle
                FetchSeconds    = $fetch
            }
        }
        return $list
    }
    catch {
        Write-WatcherLog "Failed to read config: $($_.Exception.Message)"
        return @()
    }
}

function Stop-RepoWatchers {
    foreach ($key in @($Watchers.Keys)) {
        try {
            $w = $Watchers[$key]
            if ($w) {
                $w.EnableRaisingEvents = $false
                $w.Dispose()
            }
        }
        catch { }
    }
    $Watchers.Clear()

    Get-EventSubscriber -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -like 'gap-fsw-*' } |
        ForEach-Object {
            Unregister-ObjectEvent -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
        }

    $Shared.Dirty.Clear()
    $Shared.Throttles.Clear()
    $Shared.FetchSeconds.Clear()
}

function Get-UpstreamSyncState {
    param([string]$RepoPath)

    Push-Location $RepoPath
    try {
        $branchRef = & git symbolic-ref -q HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branchRef)) {
            return 'noBranch'
        }
        $branch = $branchRef -replace '^refs/heads/', ''

        $remote = & git config --get "branch.$branch.pushRemote" 2>$null
        if ([string]::IsNullOrWhiteSpace($remote)) {
            $remote = & git config --get remote.pushDefault 2>$null
        }
        if ([string]::IsNullOrWhiteSpace($remote)) {
            $remote = & git config --get "branch.$branch.remote" 2>$null
        }
        if ([string]::IsNullOrWhiteSpace($remote)) {
            return 'noRemote'
        }

        $count = & git rev-list --count --left-right "$remote/$branch...HEAD" 2>$null
        if ($LASTEXITCODE -ne 0) {
            return 'noUpstream'
        }
        switch -Regex ($count.Trim()) {
            '^0\s+0$' { return 'equal' }
            '^0\s+\d+$' { return 'ahead' }
            '^\d+\s+0$' { return 'behind' }
            default { return 'diverged' }
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-RepoSync {
    param(
        [string]$RepoPath,
        [string]$Reason = 'local'
    )

    $key = Get-NormalizedPath $RepoPath
    Write-WatcherLog "Sync start ($Reason): $key"

    try {
        if (-not (Test-Path $key)) {
            Write-WatcherLog "Sync skip: path missing $key"
            return
        }
        Push-Location $key
        try {
            $output = & pwsh -NoProfile -File $GitSyncPath -n -s -ForceLocal 2>&1
            $code = $LASTEXITCODE
            foreach ($line in @($output)) {
                Write-WatcherLog "  [$key] $line"
            }
            Write-WatcherLog "Sync end: $key (exit $code)"
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-WatcherLog "Sync error: $key :: $($_.Exception.Message)"
    }
    finally {
        $LastSync[$key] = Get-Date
    }
}

function Invoke-RepoFetchCheck {
    param([string]$RepoPath)

    $key = Get-NormalizedPath $RepoPath
    if (-not (Test-Path $key)) {
        return
    }

    Write-WatcherLog "Fetch: $key" -VerboseOnly
    Push-Location $key
    try {
        $fetchOut = & git fetch --all --prune 2>&1
        $fetchCode = $LASTEXITCODE
        foreach ($line in @($fetchOut)) {
            if ("$line".Trim()) {
                Write-WatcherLog "  [$key] fetch: $line" -VerboseOnly
            }
        }
        if ($fetchCode -ne 0) {
            Write-WatcherLog "Fetch failed: $key (exit $fetchCode)"
            return
        }
    }
    finally {
        Pop-Location
    }

    $state = Get-UpstreamSyncState -RepoPath $key
    $outOfSync = $state -ne 'equal' -and $state -ne 'noBranch' -and $state -ne 'noRemote' -and $state -ne 'noUpstream'
    if ($outOfSync) {
        Write-WatcherLog "Fetch state: $key -> $state"
        # Remote and/or local differ — full sync (respects ForceLocal)
        $Shared.Dirty[$key] = $true
    }
    else {
        Write-WatcherLog "Fetch state: $key -> $state" -VerboseOnly
    }
}

function Register-RepoWatcher {
    param(
        [string]$RepoPath,
        [int]$ThrottleSeconds,
        [int]$FetchSeconds
    )

    $key = Get-NormalizedPath $RepoPath
    if (-not (Test-Path $key)) {
        Write-WatcherLog "Skip missing path: $key"
        return
    }

    $gitCheck = & git -C $key rev-parse --is-inside-work-tree 2>$null
    if ($gitCheck -ne 'true') {
        Write-WatcherLog "Skip non-git path: $key"
        return
    }

    $fsw = New-Object System.IO.FileSystemWatcher $key
    $fsw.IncludeSubdirectories = $true
    $fsw.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
    $fsw.EnableRaisingEvents = $true

    $msg = [pscustomobject]@{
        Path   = $key
        Shared = $Shared
    }

    $handler = {
        $repo = $Event.MessageData.Path
        $shared = $Event.MessageData.Shared
        $full = $EventArgs.FullPath
        $gitDir = Join-Path $repo '.git'
        if ($full -and $full.StartsWith($gitDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
        $shared.Dirty[$repo] = $true
    }

    Register-ObjectEvent -InputObject $fsw -EventName Changed -SourceIdentifier "gap-fsw-changed-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Created -SourceIdentifier "gap-fsw-created-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Deleted -SourceIdentifier "gap-fsw-deleted-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Renamed -SourceIdentifier "gap-fsw-renamed-$key" -Action $handler -MessageData $msg | Out-Null

    $Watchers[$key] = $fsw
    $Shared.Throttles[$key] = $ThrottleSeconds
    $Shared.FetchSeconds[$key] = $FetchSeconds
    if (-not $LastSync.ContainsKey($key)) {
        $LastSync[$key] = [datetime]::MinValue
    }
    if (-not $LastFetch.ContainsKey($key)) {
        # First fetch runs on the next poll cycle
        $LastFetch[$key] = [datetime]::MinValue
    }
    Write-WatcherLog "Watching $key (throttle ${ThrottleSeconds}s, fetch ${FetchSeconds}s)"
}

function Import-WatchConfig {
    Stop-RepoWatchers

    $repos = Read-RepoConfig
    Write-WatcherLog "Loaded $($repos.Count) repo(s) from $ConfigPath"
    foreach ($r in $repos) {
        Register-RepoWatcher -RepoPath $r.Path -ThrottleSeconds $r.ThrottleSeconds -FetchSeconds $r.FetchSeconds
    }
}

function Register-ConfigWatcher {
    if ($ConfigWatcher) {
        try {
            $ConfigWatcher.EnableRaisingEvents = $false
            $ConfigWatcher.Dispose()
        }
        catch { }
        Get-EventSubscriber -ErrorAction SilentlyContinue |
            Where-Object { $_.SourceIdentifier -like 'gap-config-*' } |
            ForEach-Object {
                Unregister-ObjectEvent -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
            }
    }

    if (-not (Test-Path $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }
    if (-not (Test-Path $ConfigPath)) {
        '{"repos":[]}' | Set-Content -Path $ConfigPath -Encoding UTF8
    }

    $dir = Split-Path $ConfigPath -Parent
    $name = Split-Path $ConfigPath -Leaf
    $cw = New-Object System.IO.FileSystemWatcher $dir, $name
    $cw.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, Size, FileName'
    $cw.EnableRaisingEvents = $true
    $script:ConfigWatcher = $cw

    $msg = [pscustomobject]@{ Shared = $Shared }
    $cfgHandler = {
        $Event.MessageData.Shared.ConfigReload = $true
    }
    Register-ObjectEvent -InputObject $cw -EventName Changed -SourceIdentifier 'gap-config-changed' -Action $cfgHandler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $cw -EventName Created -SourceIdentifier 'gap-config-created' -Action $cfgHandler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $cw -EventName Renamed -SourceIdentifier 'gap-config-renamed' -Action $cfgHandler -MessageData $msg | Out-Null
}

function Test-ThrottleOpen {
    param(
        [string]$Key,
        [datetime]$Now
    )
    $throttle = $DefaultThrottleSeconds
    if ($Shared.Throttles.ContainsKey($Key)) {
        $throttle = [int]$Shared.Throttles[$Key]
    }
    $last = [datetime]::MinValue
    if ($LastSync.ContainsKey($Key)) {
        $last = [datetime]$LastSync[$Key]
    }
    return (($Now - $last).TotalSeconds -ge $throttle)
}

# --- main ---
if (-not (Test-Path $GitSyncPath)) {
    Write-Error "git-sync.ps1 not found at $GitSyncPath"
    exit 1
}

if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}

# Single instance across Scheduled Task + Startup races
$createdNew = $false
$instanceMutex = New-Object System.Threading.Mutex($true, 'Local\GitAutoPushWatcher', [ref]$createdNew)
if (-not $createdNew) {
    Write-WatcherLog "Another watcher already running; exiting"
    if ($instanceMutex) { $instanceMutex.Dispose() }
    exit 0
}

$PID | Set-Content -Path $PidPath -Encoding ASCII
Write-WatcherLog "Watcher starting (pid $PID)"
Write-WatcherLog "git-sync: $GitSyncPath"

Register-ConfigWatcher
Import-WatchConfig

$configReloadAt = $null

try {
    while (-not $Shared.Stop) {
        Start-Sleep -Milliseconds 250

        if ($Shared.ConfigReload) {
            $Shared.ConfigReload = $false
            $configReloadAt = Get-Date
        }
        if ($configReloadAt -and ((Get-Date) - $configReloadAt).TotalMilliseconds -ge 400) {
            $configReloadAt = $null
            Write-WatcherLog "Config changed; reloading"
            try {
                Import-WatchConfig
            }
            catch {
                Write-WatcherLog "Config reload failed: $($_.Exception.Message)"
            }
        }

        $now = Get-Date

        # Periodic remote fetch
        foreach ($key in @($Shared.FetchSeconds.Keys)) {
            if ($Syncing[$key]) { continue }
            $fetchEvery = [int]$Shared.FetchSeconds[$key]
            if ($fetchEvery -lt 1) { $fetchEvery = $DefaultFetchSeconds }
            $lastF = [datetime]::MinValue
            if ($LastFetch.ContainsKey($key)) { $lastF = [datetime]$LastFetch[$key] }
            if (($now - $lastF).TotalSeconds -ge $fetchEvery) {
                $LastFetch[$key] = $now
                try {
                    Invoke-RepoFetchCheck -RepoPath $key
                }
                catch {
                    Write-WatcherLog "Fetch check error: $key :: $($_.Exception.Message)"
                }
            }
        }

        # Leading-edge throttle: sync immediately if window open; otherwise keep Dirty until it opens
        foreach ($key in @($Shared.Dirty.Keys)) {
            if (-not $Shared.Dirty[$key]) {
                $Shared.Dirty.Remove($key)
                continue
            }
            if ($Syncing[$key]) { continue }
            if (-not (Test-ThrottleOpen -Key $key -Now $now)) { continue }

            $Shared.Dirty.Remove($key)
            $Syncing[$key] = $true
            try {
                Invoke-RepoSync -RepoPath $key -Reason 'throttle'
            }
            finally {
                $Syncing[$key] = $false
                # If more FS events arrived during sync, Dirty was set again — next loop handles it
            }
        }

        while ($evt = Get-Event -ErrorAction SilentlyContinue) {
            Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Write-WatcherLog "Watcher stopping (pid $PID)"
    Stop-RepoWatchers
    Get-EventSubscriber -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -like 'gap-*' } |
        ForEach-Object {
            Unregister-ObjectEvent -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
        }
    if ($ConfigWatcher) { $ConfigWatcher.Dispose() }
    if ((Test-Path $PidPath) -and ((Get-Content $PidPath -ErrorAction SilentlyContinue) -eq "$PID")) {
        Remove-Item $PidPath -Force -ErrorAction SilentlyContinue
    }
    if ($instanceMutex) {
        try { $instanceMutex.ReleaseMutex() } catch { }
        $instanceMutex.Dispose()
    }
}
