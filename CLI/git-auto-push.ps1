#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Manage machine-local git auto-push watcher (repos list outside WinDots).

.EXAMPLE
  .\git-auto-push.ps1 install
  .\git-auto-push.ps1 add C:\Repos\my-repo -ThrottleSeconds 10 -FetchSeconds 20
  .\git-auto-push.ps1 log -Follow
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'uninstall', 'start', 'stop', 'status', 'add', 'remove', 'list', 'log', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Path,

    [int]$ThrottleSeconds = 10,

    [int]$FetchSeconds = 20,

    [Alias('f')]
    [switch]$Follow,

    [int]$Lines = 100
)

$ErrorActionPreference = 'Stop'

$script:StateDir = Join-Path $env:LOCALAPPDATA 'git-auto-push'
$script:ConfigPath = Join-Path $script:StateDir 'repos.json'
$script:LogPath = Join-Path $script:StateDir 'watcher.log'
$script:PidPath = Join-Path $script:StateDir 'watcher.pid'
$script:WatchScript = Join-Path $PSScriptRoot 'git-auto-push-watch.ps1'
$script:TaskName = 'GitAutoPush'
$script:StartupLink = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\GitAutoPush.cmd'
$script:DefaultThrottleSeconds = 10
$script:DefaultFetchSeconds = 20

function Show-Usage {
    @"
usage: git-auto-push.ps1 <command> [args]

Commands:
  install                              Create LocalAppData config + logon start; start watcher
  uninstall                            Stop watcher and remove logon start
  start                                Start the watcher now
  stop                                 Stop the running watcher
  status                               Show task + process + config summary
  add <path> [-ThrottleSeconds N] [-FetchSeconds N]
                                       Add/update a repo (defaults: throttle 10s, fetch 20s)
  remove <path>                        Remove a repo from the list
  list                                 List configured repos
  log [-Lines N] [-Follow]             Show watcher.log (default last 100 lines; -f to tail)

Throttle: sync immediately on local change, at most once per throttleSeconds.
Fetch:    periodic git fetch; if remote differs, run sync (default every fetchSeconds).

Config (machine-local, not in WinDots):
  $script:ConfigPath

Example repos.json:
  {
    "repos": [
      { "path": "C:\\Repos\\my-repo", "throttleSeconds": 10, "fetchSeconds": 20 },
      { "path": "C:\\Repos\\other" }
    ]
  }
"@
}

function ConvertTo-RepoEntry {
    param($Entry)
    $p = "$($Entry.path)"
    $th = $script:DefaultThrottleSeconds
    if ($null -ne $Entry.throttleSeconds -and "$($Entry.throttleSeconds)" -ne '') {
        $th = [int]$Entry.throttleSeconds
    }
    $fs = $script:DefaultFetchSeconds
    if ($null -ne $Entry.fetchSeconds -and "$($Entry.fetchSeconds)" -ne '') {
        $fs = [int]$Entry.fetchSeconds
    }
    return [pscustomobject]@{
        path            = $p
        throttleSeconds = $th
        fetchSeconds    = $fs
    }
}

function Ensure-StateDir {
    if (-not (Test-Path $script:StateDir)) {
        New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
    }
}

function Ensure-ConfigFile {
    Ensure-StateDir
    if (-not (Test-Path $script:ConfigPath)) {
        '{"repos":[]}' | Set-Content -Path $script:ConfigPath -Encoding UTF8
        Write-Host "Created $script:ConfigPath"
    }
}

function Get-NormalizedPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path).TrimEnd('\', '/')
}

function Read-Config {
    Ensure-ConfigFile
    $raw = Get-Content -Path $script:ConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{ repos = @() }
    }
    $obj = $raw | ConvertFrom-Json
    if (-not $obj.repos) {
        $obj | Add-Member -NotePropertyName repos -NotePropertyValue @() -Force
    }
    # Normalize to array
    $obj.repos = @($obj.repos)
    return $obj
}

function Save-Config {
    param($Config)
    Ensure-StateDir
    $json = $Config | ConvertTo-Json -Depth 5
    Set-Content -Path $script:ConfigPath -Value $json -Encoding UTF8
}

function Get-WatcherProcess {
    if (-not (Test-Path $script:PidPath)) {
        return $null
    }
    $pidText = (Get-Content $script:PidPath -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $pidText) { return $null }
    $procId = 0
    if (-not [int]::TryParse("$pidText", [ref]$procId)) { return $null }
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) { return $null }
    # Ensure it looks like our watcher (pwsh hosting the script)
    return $p
}

function Stop-WatcherProcess {
    $p = Get-WatcherProcess
    if ($p) {
        Write-Host "Stopping watcher pid $($p.Id)..."
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    if (Test-Path $script:PidPath) {
        Remove-Item $script:PidPath -Force -ErrorAction SilentlyContinue
    }
}

function Start-WatcherProcess {
    if (-not (Test-Path $script:WatchScript)) {
        throw "Watch script not found: $script:WatchScript"
    }
    $existing = Get-WatcherProcess
    if ($existing) {
        Write-Host "Watcher already running (pid $($existing.Id))"
        return
    }
    Ensure-ConfigFile
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $proc = Start-Process -FilePath $pwsh -ArgumentList @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-File', $script:WatchScript
    ) -PassThru -WindowStyle Hidden
    # pid file is written by the watcher; wait briefly
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        $p = Get-WatcherProcess
        if ($p) {
            Write-Host "Watcher started (pid $($p.Id))"
            return
        }
        Start-Sleep -Milliseconds 200
    }
    Write-Host "Watcher process launched (pid $($proc.Id)); pid file not seen yet."
}

function Install-LogonStart {
    if (-not (Test-Path $script:WatchScript)) {
        throw "Watch script not found: $script:WatchScript"
    }
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $arg = "-NoProfile -WindowStyle Hidden -File `"$($script:WatchScript)`""

    $taskOk = $false
    try {
        $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arg
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

        Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        Write-Host "Registered Scheduled Task '$script:TaskName' (At log on)."
        $taskOk = $true
    }
    catch {
        Write-Host "Scheduled Task registration failed ($($_.Exception.Message)); using Startup folder instead."
    }

    # Always also (or only) write a Startup cmd so logon start works without elevation
    $cmd = @"
@echo off
start "" "$pwsh" -NoProfile -WindowStyle Hidden -File "$($script:WatchScript)"
"@
    Set-Content -Path $script:StartupLink -Value $cmd -Encoding ASCII
    Write-Host "Installed logon starter: $script:StartupLink"
    return $taskOk
}

function Uninstall-LogonStart {
    Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed Scheduled Task '$script:TaskName' (if it existed)."
    if (Test-Path $script:StartupLink) {
        Remove-Item $script:StartupLink -Force
        Write-Host "Removed $script:StartupLink"
    }
}

switch ($Command) {
    'help' {
        Show-Usage
    }
    'install' {
        Ensure-ConfigFile
        Install-LogonStart | Out-Null
        Start-WatcherProcess
        Write-Host "Config: $script:ConfigPath"
        Write-Host "Use: git-auto-push.ps1 add <path> [-ThrottleSeconds N]"
    }
    'uninstall' {
        Stop-WatcherProcess
        Uninstall-LogonStart
    }
    'start' {
        Ensure-ConfigFile
        Start-WatcherProcess
    }
    'stop' {
        Stop-WatcherProcess
        Write-Host "Watcher stopped."
    }
    'status' {
        Ensure-ConfigFile
        $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
        if ($task) {
            $info = Get-ScheduledTaskInfo -TaskName $script:TaskName
            Write-Host "Task: $script:TaskName ($($task.State)), last result $($info.LastTaskResult)"
        }
        else {
            Write-Host "Task: not installed"
        }
        if (Test-Path $script:StartupLink) {
            Write-Host "Startup: $script:StartupLink"
        }
        else {
            Write-Host "Startup: not installed"
        }
        $p = Get-WatcherProcess
        if ($p) {
            Write-Host "Watcher: running (pid $($p.Id))"
        }
        else {
            Write-Host "Watcher: not running"
        }
        Write-Host "Config: $script:ConfigPath"
        $cfg = Read-Config
        Write-Host "Repos: $($cfg.repos.Count)"
        foreach ($r in $cfg.repos) {
            $e = ConvertTo-RepoEntry $r
            Write-Host "  - $($e.path)  (throttle $($e.throttleSeconds)s, fetch $($e.fetchSeconds)s)"
        }
    }
    'add' {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "add requires a path. Example: git-auto-push.ps1 add C:\Repos\my-repo"
        }
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Path does not exist: $Path"
        }
        $full = Get-NormalizedPath $Path
        $inside = & git -C $full rev-parse --is-inside-work-tree 2>$null
        if ($inside -ne 'true') {
            throw "Not a git work tree: $full"
        }
        if ($ThrottleSeconds -lt 1) { $ThrottleSeconds = 1 }
        if ($FetchSeconds -lt 1) { $FetchSeconds = 1 }

        $cfg = Read-Config
        $list = @()
        $found = $false
        foreach ($e in $cfg.repos) {
            if (-not $e.path) { continue }
            $p = [System.IO.Path]::GetFullPath($e.path).TrimEnd('\', '/')
            if ($p -eq $full) {
                $list += [pscustomobject]@{
                    path            = $full
                    throttleSeconds = $ThrottleSeconds
                    fetchSeconds    = $FetchSeconds
                }
                $found = $true
            }
            else {
                $list += ConvertTo-RepoEntry $e
            }
        }
        if (-not $found) {
            $list += [pscustomobject]@{
                path            = $full
                throttleSeconds = $ThrottleSeconds
                fetchSeconds    = $FetchSeconds
            }
            Write-Host "Added $full (throttle ${ThrottleSeconds}s, fetch ${FetchSeconds}s)"
        }
        else {
            Write-Host "Updated $full (throttle ${ThrottleSeconds}s, fetch ${FetchSeconds}s)"
        }
        Save-Config ([pscustomobject]@{ repos = $list })
    }
    'remove' {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "remove requires a path"
        }
        $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        $cfg = Read-Config
        $kept = @()
        $removed = $false
        foreach ($e in $cfg.repos) {
            $p = [System.IO.Path]::GetFullPath($e.path).TrimEnd('\', '/')
            if ($p -eq $full) {
                $removed = $true
                continue
            }
            $kept += ConvertTo-RepoEntry $e
        }
        if (-not $removed) {
            Write-Host "Not found: $full"
            return
        }
        Save-Config ([pscustomobject]@{ repos = $kept })
        Write-Host "Removed $full"
    }
    'list' {
        $cfg = Read-Config
        if ($cfg.repos.Count -eq 0) {
            Write-Host "(no repos configured)"
            Write-Host "Config: $script:ConfigPath"
            return
        }
        foreach ($r in $cfg.repos) {
            $e = ConvertTo-RepoEntry $r
            Write-Host "$($e.path)  throttle=$($e.throttleSeconds)s  fetch=$($e.fetchSeconds)s"
        }
    }
    'log' {
        if (-not (Test-Path $script:LogPath)) {
            Write-Host "No log yet at $script:LogPath"
            return
        }
        if ($Follow) {
            Get-Content -Path $script:LogPath -Tail $Lines -Wait
        }
        else {
            Get-Content -Path $script:LogPath -Tail $Lines
        }
    }
}
