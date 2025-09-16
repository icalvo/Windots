# ██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ████████╗███████╗
# ██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
# ██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║   ██║   ███████╗
# ██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║   ██║   ╚════██║
# ╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝   ██║   ███████║
#  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
# Setup.ps1 - Scott McKendry
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#Requires -RunAsAdministrator
#Requires -Version 7

# Linked Files (Destination => Source)
$symlinks = @{
    $PROFILE.CurrentUserAllHosts                                                                    = ".\Profile.ps1"
    "$HOME\AutoHotKey"                                                                              = ".\AutoHotKey"
    "$HOME\AppData\Local\nvim"                                                                      = ".\nvim"
    "$HOME\AppData\Local\k9s"                                                                       = ".\k9s"
    "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = ".\windowsterminal\settings.json"
    "$HOME\.gitconfig"                                                                              = ".\.gitconfig"
    "$HOME\AppData\Roaming\lazygit"                                                                 = ".\lazygit"
    "$HOME\AppData\Roaming\neovide"                                                                 = ".\neovide"
    "$HOME\AppData\Roaming\AltSnap\AltSnap.ini"                                                     = ".\altsnap\AltSnap.ini"
    "$ENV:PROGRAMFILES\WezTerm\wezterm_modules"                                                     = ".\wezterm\"
}

# Winget & choco dependencies
$wingetDeps = @(
    "autohotkey.autohotkey"
    "chocolatey.chocolatey"
    "eza-community.eza"
    "ezwinports.make"
    "git.git"
    "github.cli"
    "kitware.cmake"
    "mbuilov.sed"
    "microsoft.powershell"
    "neovim.neovim"
    "openjs.nodejs"
    "sst.opencode"
    "task.task"
    "JanDeDobbeleer.OhMyPosh"
)
$chocoDeps = @(
    "altsnap"
    "bat"
    "caffeine"
    "fd"
    "fzf"
    "gawk"
    "lazygit"
    "mingw"
    "nerd-fonts-jetbrainsmono"
    "nircmd"
    "ripgrep"
    "sqlite"
    "wezterm"
    "windirstat"
    "zig"
    "zoxide"
)

# PS Modules
$psModules = @(
    "posh-git"
    "CompletionPredictor"
    "PSScriptAnalyzer"
    "ps-arch-wsl"
    "ps-color-scripts"
)
$dotnetTools = @(
    "dotnet-suggest"
)
# Set working directory
Set-Location $PSScriptRoot
[Environment]::CurrentDirectory = $PSScriptRoot

Write-Host "Installing missing dependencies..."
$installedWingetDeps = winget list | Out-String
foreach ($wingetDep in $wingetDeps) {
    if ($installedWingetDeps -notmatch $wingetDep) {
        winget install --id $wingetDep
    }
}

# Path Refresh
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$installedChocoDeps = (choco list --local --limit-output --id-only).Split("`n")
foreach ($chocoDep in $chocoDeps) {
    if ($installedChocoDeps -notcontains $chocoDep) {
        choco install $chocoDep -y
    }
}

# Install PS Modules
foreach ($psModule in $psModules) {
    if (!(Get-Module -ListAvailable -Name $psModule)) {
        Install-Module -Name $psModule -Force -AcceptLicense -Scope CurrentUser
    }
}

# Install dotnet tools
foreach ($dotnetTool in $dotnetTools) {
    dotnet tool install $dotnetTool -g
}

# Delete OOTB Nvim Shortcuts (including QT)
if (Test-Path "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Neovim\") {
    Remove-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Neovim\" -Recurse -Force
}

# Persist Environment Variables
[System.Environment]::SetEnvironmentVariable('WEZTERM_CONFIG_FILE', "$PSScriptRoot\wezterm\wezterm.lua", [System.EnvironmentVariableTarget]::User)

# Create Symbolic Links
Write-Host "Creating Symbolic Links..."
foreach ($symlink in $symlinks.GetEnumerator()) {
    Get-Item -Path $symlink.Key -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $symlink.Key -Target (Resolve-Path $symlink.Value) -Force | Out-Null
}

# $currentGitEmail = (git config --global user.email)
# $currentGitName = (git config --global user.name)
# git config --global --unset user.email | Out-Null
# git config --global --unset user.name | Out-Null
# git config --global user.email $currentGitEmail | Out-Null
# git config --global user.name $currentGitName | Out-Null

# Install bat themes
bat cache --clear
bat cache --build

.\altsnap\createTask.ps1 | Out-Null

# Create Startup links
$strTargetPath = "$HOME\AutoHotKey\Ignacio.ahk"
$strLinkFile = "$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Ignacio.lnk"
if (-not (Test-Path $strLinkFile)) {
    Remove-Item -Force -ErrorAction SilentlyContinue $strLinkFile
    $shell = New-Object -ComObject WScript.Shell
    $Shortcut = $shell.CreateShortcut($strLinkFile)
    $Shortcut.TargetPath = $strTargetPath
    $Shortcut.WorkingDirectory = "$HOME\AutoHotKey\"
    # Set the window style (3=Maximized 7=Minimized 4=Normal)
    $shortcut.WindowStyle = 4
    $Shortcut.Save()
    Invoke-Item $strLinkFile
}
