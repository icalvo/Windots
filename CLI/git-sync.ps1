#!/usr/bin/env pwsh
#
# git-sync.ps1
#
# synchronize tracking repositories (PowerShell port)
#
# 2025 PowerShell port of original bash script by Simon Thum and contributors
# Original Licensed as: CC0
#
# This script intends to sync via git near-automatically
# in "tracking" repositories where a nice history is not
# crucial, but having one at all is.
#
# Unlike the myriad of scripts to do just that already available,
# it follows the KISS principle: It is small, requires nothing but
# git and PowerShell, but does not even try to shield you from git.
#
# Mode sync (default)
#
# Sync will likely get from you from a dull normal git repo with trivial
# changes to an updated dull normal git repo equal to origin. No more,
# no less. The intent is to do everything that's needed to sync
# automatically, and resort to manual intervention as soon
# as something non-trivial occurs. It is designed to be safe
# in that it will likely refuse to do anything not known to
# be safe.
#
# Mode check
#
# Check only performs the basic checks to make sure the repository
# is in an orderly state to continue syncing, i.e. committing
# changes, pull etc. without losing any data. When check returns
# 0, sync can start immediately. This does not, however, indicate
# that syncing is at all likely to succeed.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("sync", "check")]
    [string]$Mode = "sync",
    
    [Alias('h')]
    [switch]$Help,
    
    [Alias('n')]
    [switch]$SyncNewFiles,
    
    [Alias('s')]
    [switch]$SyncAnyway
)

# Default commit message substituted into autocommit commands
$script:DEFAULT_AUTOCOMMIT_MSG = "changes from $env:COMPUTERNAME on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

function Show-Usage {
    Write-Host @"
usage: git-sync.ps1 [-h] [-n] [-s] [MODE]

Synchronize the current branch to a remote backup
MODE may be either "sync" (the default) or "check", to verify that the branch is ready to sync

OPTIONS:
   -h      Show this message
   -n      Commit new files even if branch.`$branch_name.syncNewFiles isn't set
   -s      Sync the branch even if branch.`$branch_name.sync isn't set
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

# Utility functions

function Write-LogMessage {
    param([string]$Message)
    Write-Host "git-sync: $Message"
}

# Get the git directory
function Get-GitDir {
    try {
        $isInWorkTree = git rev-parse --is-inside-work-tree $PWD 2>$null
        if ($isInWorkTree -eq "true") {
            return git rev-parse --git-dir $PWD 2>$null
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-SyncNewFilesFlag {
    param([string]$BranchName)
    
    if ($SyncNewFiles) {
        return $true
    }

    $syncNewFlag = git config --get --bool "branch.$BranchName.syncNewFiles" 2>$null
    if ([string]::IsNullOrEmpty($syncNewFlag)) {
        $syncNewFlag = git config --get --bool "git-sync.syncNewFiles" 2>$null
    }
    if ([string]::IsNullOrEmpty($syncNewFlag)) {
        $syncNewFlag = "false"
    }

    return $syncNewFlag -eq "true"
}

function Get-SyncFlag {
    param([string]$BranchName)
    
    if ($SyncAnyway) {
        return $true
    }

    $syncFlag = git config --get --bool "branch.$BranchName.sync" 2>$null
    if ([string]::IsNullOrEmpty($syncFlag)) {
        $syncFlag = git config --get --bool "git-sync.syncEnabled" 2>$null
    }
    if ([string]::IsNullOrEmpty($syncFlag)) {
        $syncFlag = "false"
    }

    return $syncFlag -eq "true"
}

# Compose the add step command
function Get-GitAddCommand {
    param([string]$BranchName)
    
    if (Get-SyncNewFilesFlag -BranchName $BranchName) {
        return "git add -A"
    }
    else {
        return "git add -u"
    }
}

# Compose the commit step command
function Get-GitCommitCommand {
    param([string]$BranchName)
    
    $skipHooks = git config --get --bool "branch.$BranchName.syncSkipHooks" 2>$null
    if ([string]::IsNullOrEmpty($skipHooks)) {
        $skipHooks = git config --get --bool "git-sync.syncSkipHooks" 2>$null
    }
    if ([string]::IsNullOrEmpty($skipHooks)) {
        $skipHooks = "false"
    }

    if ($skipHooks -eq "true") {
        return 'git commit --no-verify -m "%message"'
    }
    else {
        return 'git commit -m "%message"'
    }
}

# Get repository state
function Get-GitRepoState {
    $gitDir = Get-GitDir
    if (-not $gitDir) {
        return "NOGIT"
    }

    $state = ""

    if (Test-Path "$gitDir/rebase-merge/interactive") {
        $state += "REBASE-i"
    }
    elseif (Test-Path "$gitDir/rebase-merge") {
        $state += "REBASE-m"
    }
    else {
        if (Test-Path "$gitDir/rebase-apply") {
            $state += "AM/REBASE"
        }
        elseif (Test-Path "$gitDir/MERGE_HEAD") {
            $state += "MERGING"
        }
        elseif (Test-Path "$gitDir/CHERRY_PICK_HEAD") {
            $state += "CHERRY-PICKING"
        }
        elseif (Test-Path "$gitDir/BISECT_LOG") {
            $state += "BISECTING"
        }
    }

    try {
        $isInsideGitDir = git rev-parse --is-inside-git-dir 2>$null
        if ($isInsideGitDir -eq "true") {
            $isBareRepo = git rev-parse --is-bare-repository 2>$null
            if ($isBareRepo -eq "true") {
                $state += "|BARE"
            }
            else {
                $state += "|GIT_DIR"
            }
        }
        elseif ((& git rev-parse --is-inside-work-tree 2>&1 | Out-String -ErrorAction SilentlyContinue).Trim() -eq "true") {
            & git diff --no-ext-diff --quiet --exit-code 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $state += "|DIRTY"
            }
        }
    }
    catch {
        # Ignore errors
    }

    return $state
}

# Check if we only have untouched, modified or (if configured) new files
function Test-InitialFileState {
    param([string]$BranchName)
    
    $porcelainOutput = git status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    if (Get-SyncNewFilesFlag -BranchName $BranchName) {
        # Allow for new files - check for non-new/modified files
        $problematicFiles = $porcelainOutput | Where-Object { 
            $_ -match '^[^ \?][^M\?] *' 
        }
        if ($problematicFiles) {
            return "NonNewOrModified"
        }
    }
    else {
        # Bail on new files - only allow modified files
        $problematicFiles = $porcelainOutput | Where-Object { 
            $_ -match '^[^ ][^M] *' 
        }
        if ($problematicFiles) {
            return "NotOnlyModified"
        }
    }

    return $null
}

# Look for local changes
function Test-LocalChanges {
    $porcelainOutput = git status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $changes = $porcelainOutput | Where-Object { 
        $_ -match '^(\?\?|[MARC] |[ MARC][MD])*' 
    }
    
    if ($changes) {
        return "LocalChanges"
    }
    
    return $null
}

# Determine sync state of repository
function Get-SyncState {
    param(
        [string]$RemoteName,
        [string]$BranchName
    )
    
    try {
        $countOutput = git rev-list --count --left-right "$RemoteName/$BranchName...HEAD" 2>$null
        if ($LASTEXITCODE -ne 0) {
            return "noUpstream"
        }

        switch ($countOutput) {
            { $_ -match "^0\s+0$" } { return "equal" }
            { $_ -match "^0\s+\d+$" } { return "ahead" }
            { $_ -match "^\d+\s+0$" } { return "behind" }
            default { return "diverged" }
        }
    }
    catch {
        return "noUpstream"
    }
}

# Exit, issue warning if not in sync
function Exit-AssumingSync {
    param(
        [string]$RemoteName,
        [string]$BranchName
    )
    
    $syncState = Get-SyncState -RemoteName $RemoteName -BranchName $BranchName
    if ($syncState -eq "equal") {
        Write-LogMessage "In sync, all fine."
        exit 0
    }
    else {
        Write-LogMessage "Synchronization FAILED! You should definitely check your repository carefully!"
        Write-LogMessage "(Possibly a transient network problem? Please try again in that case.)"
        exit 3
    }
}

#
#        Here git-sync actually starts
#

# First some sanity checks
$repoState = Get-GitRepoState

if ([string]::IsNullOrEmpty($repoState) -or $repoState -eq "|DIRTY") {
    $gitDir = Get-GitDir
    Write-LogMessage "Preparing. Repo in $gitDir"
}
elseif ($repoState -eq "NOGIT") {
    Write-LogMessage "No git repository detected. Exiting."
    exit 128  # matches git's error code
}
else {
    Write-LogMessage "Git repo state considered unsafe for sync: $repoState"
    exit 2
}

# Determine the current branch
try {
    $branchRef = git symbolic-ref -q HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($branchRef)) {
        Write-LogMessage "Syncing is only possible on a branch."
        git status
        exit 2
    }
    
    $branchName = $branchRef -replace "^refs/heads/", ""
}
catch {
    Write-LogMessage "Syncing is only possible on a branch."
    git status
    exit 2
}

# Determine the remote to operate on
$remoteName = git config --get "branch.$branchName.pushRemote" 2>$null
if ([string]::IsNullOrEmpty($remoteName)) {
    $remoteName = git config --get "remote.pushDefault" 2>$null
}
if ([string]::IsNullOrEmpty($remoteName)) {
    $remoteName = git config --get "branch.$branchName.remote" 2>$null
}

if ([string]::IsNullOrEmpty($remoteName)) {
    Write-LogMessage "the current branch does not have a configured remote."
    Write-Host ""
    Write-LogMessage "Please use"
    Write-Host ""
    Write-LogMessage "  git branch --set-upstream-to=[remote_name]/$branchName"
    Write-Host ""
    Write-LogMessage "replacing [remote_name] with the name of your remote, i.e. - origin"
    Write-LogMessage "to set the remote tracking branch for git-sync to work"
    exit 2
}

# Check if current branch is configured for sync
if (-not (Get-SyncFlag -BranchName $branchName)) {
    Write-Host ""
    Write-LogMessage "Please use"
    Write-Host ""
    Write-LogMessage "  git config --bool branch.$branchName.sync true"
    Write-Host ""
    Write-LogMessage "to enlist branch $branchName for synchronization."
    Write-LogMessage "Branch $branchName has to have a same-named remote branch"
    Write-LogMessage "for git-sync to work."
    Write-Host ""
    Write-LogMessage "(If you don't know what this means, you should change that"
    Write-LogMessage "before relying on this script. You have been warned.)"
    Write-Host ""
    exit 1
}

Write-LogMessage "Mode $Mode"
Write-LogMessage "Using $remoteName/$branchName"

# Check for intentionally unhandled file states
$fileStateIssue = Test-InitialFileState -BranchName $branchName
if ($fileStateIssue) {
    Write-LogMessage "There are changed files you should probably handle manually."
    git status
    exit 1
}

# If in check mode, this is all we need to know
if ($Mode -eq "check") {
    Write-LogMessage "check OK; sync may start."
    exit 0
}

# Check if we have to commit local changes, if yes, do so
$localChanges = Test-LocalChanges
if ($localChanges) {
    $configAutocommitCmd = git config --get "branch.$branchName.autocommitscript" 2>$null
    
    # Discern the three ways to auto-commit
    if (-not [string]::IsNullOrEmpty($configAutocommitCmd)) {
        $autocommitCmd = $configAutocommitCmd
    }
    else {
        $gitAddCmd = Get-GitAddCommand -BranchName $branchName
        $gitCommitCmd = Get-GitCommitCommand -BranchName $branchName
        $autocommitCmd = "$gitAddCmd; $gitCommitCmd;"
    }

    $commitMsg = git config --get "branch.$branchName.syncCommitMsg" 2>$null
    if ([string]::IsNullOrEmpty($commitMsg)) {
        $commitMsg = $script:DEFAULT_AUTOCOMMIT_MSG
    }
    
    $autocommitCmd = $autocommitCmd -replace "%message", $commitMsg

    Write-LogMessage "Committing local changes using $autocommitCmd"
    
    # Execute the autocommit command
    try {
        Invoke-Expression $autocommitCmd
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "Auto-commit command failed with exit code $LASTEXITCODE"
            exit 1
        }
    }
    catch {
        Write-LogMessage "Auto-commit command failed: $($_.Exception.Message)"
        exit 1
    }

    # After autocommit, we should be clean
    $repoState = Get-GitRepoState
    if (-not [string]::IsNullOrEmpty($repoState) -and $repoState -ne "|DIRTY") {
        Write-LogMessage "Auto-commit left uncommitted changes. Please add or remove them as desired and retry."
        exit 1
    }
}

# Fetch remote to get to the current sync state
Write-LogMessage "Fetching from $remoteName/$branchName"
git fetch $remoteName $branchName
if ($LASTEXITCODE -ne 0) {
    Write-LogMessage "git fetch $remoteName returned non-zero. Likely a network problem; exiting."
    exit 3
}

$syncState = Get-SyncState -RemoteName $remoteName -BranchName $branchName

switch ($syncState) {
    "noUpstream" {
        Write-LogMessage "Strange state, you're on your own. Good luck."
        exit 2
    }
    "equal" {
        Exit-AssumingSync -RemoteName $remoteName -BranchName $branchName
    }
    "ahead" {
        Write-LogMessage "Pushing changes..."
        git push $remoteName "$branchName`:$branchName"
        if ($LASTEXITCODE -eq 0) {
            Exit-AssumingSync -RemoteName $remoteName -BranchName $branchName
        }
        else {
            Write-LogMessage "git push returned non-zero. Likely a connection failure."
            exit 3
        }
    }
    "behind" {
        Write-LogMessage "We are behind, fast-forwarding..."
        git merge --ff --ff-only "$remoteName/$branchName"
        if ($LASTEXITCODE -eq 0) {
            Exit-AssumingSync -RemoteName $remoteName -BranchName $branchName
        }
        else {
            Write-LogMessage "git merge --ff --ff-only returned non-zero ($LASTEXITCODE). Exiting."
            exit 2
        }
    }
    "diverged" {
        Write-LogMessage "We have diverged. Trying to rebase..."
        git rebase "$remoteName/$branchName"
        
        $repoStateAfterRebase = Get-GitRepoState
        $syncStateAfterRebase = Get-SyncState -RemoteName $remoteName -BranchName $branchName
        
        if ($LASTEXITCODE -eq 0 -and [string]::IsNullOrEmpty($repoStateAfterRebase) -and $syncStateAfterRebase -eq "ahead") {
            Write-LogMessage "Rebasing went fine, pushing..."
            git push $remoteName "$branchName`:$branchName"
            Exit-AssumingSync -RemoteName $remoteName -BranchName $branchName
        }
        else {
            Write-LogMessage "Rebasing failed, likely there are conflicting changes. Resolve them and finish the rebase before repeating git-sync."
            exit 1
        }
    }
}
