#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Watch configured git repos and sync via git-sync.ps1 -n -s -ForceLocal after a throttle.

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
$DefaultThrottleSeconds = 60
$MaxLogBytes = 5MB

# Shared with FileSystemWatcher event runspaces
$Shared = [hashtable]::Synchronized(@{
        Pending     = [hashtable]::Synchronized(@{})  # path -> last event [datetime]
        Throttles   = [hashtable]::Synchronized(@{})  # path -> seconds
        DirtyAgain  = [hashtable]::Synchronized(@{})  # path -> bool
        ConfigReload = $false
        Stop        = $false
    })

$Watchers = @{}
$ConfigWatcher = $null

function Write-WatcherLog {
    param([string]$Message)
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
            $list += [pscustomobject]@{
                Path            = Get-NormalizedPath $r.path
                ThrottleSeconds = $throttle
            }
        }
        return $list
    }
    catch {
        Write-WatcherLog "Failed to read config: $($_.Exception.Message)"
        return @()
    }
}

function Test-IsGitNoisePath {
    param(
        [string]$FullPath,
        [string]$RepoRoot
    )
    if ([string]::IsNullOrWhiteSpace($FullPath)) { return $true }
    $norm = $FullPath
    try { $norm = [System.IO.Path]::GetFullPath($FullPath) } catch { }
    $gitDir = Join-Path $RepoRoot '.git'
    if ($norm.StartsWith($gitDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $name = Split-Path $norm -Leaf
    if ($name -match '(^~\$|\.swp$|\.swo$|\.tmp$|\.TMP$|~$)') {
        return $true
    }
    return $false
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

    $Shared.Pending.Clear()
    $Shared.Throttles.Clear()
    $Shared.DirtyAgain.Clear()
}

function Invoke-RepoSync {
    param([string]$RepoPath)

    $key = Get-NormalizedPath $RepoPath
    Write-WatcherLog "Sync start: $key"

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
}

function Register-RepoWatcher {
    param(
        [string]$RepoPath,
        [int]$ThrottleSeconds
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
        Path     = $key
        Shared   = $Shared
    }

    $handler = {
        $repo = $Event.MessageData.Path
        $shared = $Event.MessageData.Shared
        $full = $EventArgs.FullPath
        $gitDir = Join-Path $repo '.git'
        if ($full -and $full.StartsWith($gitDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
        $shared.Pending[$repo] = Get-Date
    }

    Register-ObjectEvent -InputObject $fsw -EventName Changed -SourceIdentifier "gap-fsw-changed-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Created -SourceIdentifier "gap-fsw-created-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Deleted -SourceIdentifier "gap-fsw-deleted-$key" -Action $handler -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Renamed -SourceIdentifier "gap-fsw-renamed-$key" -Action $handler -MessageData $msg | Out-Null

    $Watchers[$key] = $fsw
    $Shared.Throttles[$key] = $ThrottleSeconds
    Write-WatcherLog "Watching $key (throttle ${ThrottleSeconds}s)"
}

function Import-WatchConfig {
    Stop-RepoWatchers

    $repos = Read-RepoConfig
    Write-WatcherLog "Loaded $($repos.Count) repo(s) from $ConfigPath"
    foreach ($r in $repos) {
        Register-RepoWatcher -RepoPath $r.Path -ThrottleSeconds $r.ThrottleSeconds
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

# --- main ---
if (-not (Test-Path $GitSyncPath)) {
    Write-Error "git-sync.ps1 not found at $GitSyncPath"
    exit 1
}

if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}

$PID | Set-Content -Path $PidPath -Encoding ASCII
Write-WatcherLog "Watcher starting (pid $PID)"
Write-WatcherLog "git-sync: $GitSyncPath"

Register-ConfigWatcher
Import-WatchConfig

$syncing = @{}
$configReloadAt = $null

try {
    while (-not $Shared.Stop) {
        Start-Sleep -Milliseconds 500

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
        $due = @()
        foreach ($key in @($Shared.Pending.Keys)) {
            $last = $Shared.Pending[$key]
            if (-not $last) { continue }
            $throttle = $DefaultThrottleSeconds
            if ($Shared.Throttles.ContainsKey($key)) {
                $throttle = [int]$Shared.Throttles[$key]
            }
            if (($now - [datetime]$last).TotalSeconds -ge $throttle) {
                $due += $key
            }
        }

        foreach ($key in $due) {
            if ($syncing[$key]) {
                $Shared.DirtyAgain[$key] = $true
                continue
            }
            $Shared.Pending.Remove($key)
            $syncing[$key] = $true
            try {
                Invoke-RepoSync -RepoPath $key
            }
            finally {
                $syncing[$key] = $false
                if ($Shared.DirtyAgain[$key]) {
                    $Shared.DirtyAgain[$key] = $false
                    $Shared.Pending[$key] = Get-Date
                    Write-WatcherLog "Changes during sync; re-queued $key"
                }
            }
        }

        # Drain PS event queue
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
}
