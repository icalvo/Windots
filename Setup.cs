// ██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ████████╗███████╗
// ██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
// ██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║   ██║   ███████╗
// ██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║   ██║   ╚════██║
// ╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝   ██║   ███████║
//  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
// Setup.cs - single-file C# port of Setup.ps1
// Run with:  dotnet run Setup.cs            (from an elevated terminal)
//      or:   dotnet run Setup.cs -- --dry-run   (preview, no changes, no elevation needed)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#:property TargetFramework=net10.0-windows
#:property BuiltInComInteropSupport=true
#:package WindowsShortcutFactory@1.2.0

using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Security.Principal;
using System.Text;
using WindowsShortcutFactory;

bool dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);

string scriptRoot = GetScriptRoot();
string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

// Linked Files (Destination => Source). Sources are relative to this script.
(string Destination, string Source)[] symlinks =
[
    (GetPowerShellProfile(),                                                                            @".\Profile.ps1"),
    (Path.Combine(home, "AutoHotKey"),                                                                  @".\AutoHotKey"),
    (Path.Combine(home, @"AppData\Local\nvim"),                                                         @".\nvim"),
    (Path.Combine(home, @"AppData\Local\k9s"),                                                          @".\k9s"),
    (Path.Combine(home, @"AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"), @".\windowsterminal\settings.json"),
    (Path.Combine(home, @"AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\InactivePane.hlsl"), @".\windowsterminal\InactivePane.hlsl"),
    (Path.Combine(home, ".gitconfig"),                                                                  @".\.gitconfig"),
    (Path.Combine(home, @"AppData\Local\lazygit"),                                                      @".\lazygit"),
    (Path.Combine(home, @"AppData\Roaming\neovide"),                                                    @".\neovide"),
    (Path.Combine(programFiles, @"WezTerm\wezterm_modules"),                                            @".\wezterm"),
    (Path.Combine(home, ".ideavimrc"),                                                                  @".\.ideavimrc"),
    (Path.Combine(home, @"AppData\Roaming\yazi\config"),                                                @".\yazi"),
    (Path.Combine(home, @".cursor\hooks.json"),                                                         @".\cursor\hooks.json"),
    (Path.Combine(home, @".cursor\hooks"),                                                              @".\cursor\hooks"),
    (Path.Combine(home, @".cursor\skills"),                                                             @".\cursor\skills"),
    (Path.Combine(home, @".cursor\user-rules"),                                                         @".\cursor\user-rules"),
    (Path.Combine(home, @"AppData\Roaming\Cursor\User\keybindings.json"),                               @".\cursor\keybindings.json"),
];

// Winget dependencies
string[] wingetDeps =
[
    "7zip.7zip",
    "agilebits.1password.cli",
    "appest.ticktick",
    "autohotkey.autohotkey",
    "chocolatey.chocolatey",
    "eza-community.eza",
    "ezwinports.make",
    "git.git",
    "github.cli",
    "kitware.cmake",
    "mbuilov.sed",
    "microsoft.dotnet.sdk.10",
    "microsoft.dotnet.sdk.11",
    "microsoft.dotnet.sdk.preview",
    "microsoft.powershell",
    "openjs.nodejs.lts",
    "sst.opencode",
    "task.task",
    "jandedobbeleer.ohmyposh",
];

// Chocolatey dependencies
string[] chocoDeps =
[
    "bat",
    "caffeine",
    "fd",
    "fzf",
    "gawk",
    "haskell-language-server",
    "jq",
    "lazygit",
    "mingw",
    "nerd-fonts-jetbrainsmono",
    "neovim",
    "nircmd",
    "ripgrep",
    "sqlite",
    "wezterm",
    "windirstat",
    "zig",
    "zoxide",
    "yt-dlp",
];

// PowerShell Gallery modules (installed via pwsh - no BCL/NuGet equivalent exists)
string[] psModules =
[
    "posh-git",
    "CompletionPredictor",
    "PSScriptAnalyzer",
    "ps-arch-wsl",
    "ps-color-scripts",
];

// dotnet global tools
string[] dotnetTools =
[
    "dotnet-suggest",
];

// Set working directory
Directory.SetCurrentDirectory(scriptRoot);

if (dryRun)
    Console.WriteLine(">> DRY RUN - no changes will be made\n");

if (!dryRun && !IsAdministrator())
{
    Console.Error.WriteLine("This script must be run from an elevated (Administrator) terminal.");
    return 1;
}

// Install missing winget dependencies
Console.WriteLine("Installing missing dependencies...");
string installedWinget = dryRun ? "" : RunCapture("winget", "list");
foreach (var dep in wingetDeps)
{
    if (installedWinget.Contains(dep, StringComparison.OrdinalIgnoreCase))
        continue;
    if (dryRun)
        Console.WriteLine($"  [winget] would install {dep}");
    else
        RunStream("winget", $"install --id {dep}");
}

// Path refresh so freshly-installed tools (choco, bat, ...) are resolvable
RefreshPath();

// Install missing chocolatey dependencies
var installedChoco = (dryRun ? "" : RunCapture("choco", "list --local --limit-output --id-only"))
    .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
foreach (var dep in chocoDeps)
{
    if (installedChoco.Contains(dep, StringComparer.OrdinalIgnoreCase))
        continue;
    if (dryRun)
        Console.WriteLine($"  [choco] would install {dep}");
    else
        RunStream("choco", $"install {dep} -y");
}

// Install PowerShell modules
foreach (var module in psModules)
{
    if (dryRun)
    {
        Console.WriteLine($"  [pwsh] would ensure module {module}");
        continue;
    }
    RunStream("pwsh", $"-NoProfile -Command \"if (-not (Get-Module -ListAvailable -Name {module})) {{ Install-Module -Name {module} -Force -AcceptLicense -Scope CurrentUser }}\"");
}

// Install dotnet tools
foreach (var tool in dotnetTools)
{
    if (dryRun)
        Console.WriteLine($"  [dotnet] would install tool {tool}");
    else
        RunStream("dotnet", $"tool install {tool} -g");
}

// Delete OOTB Nvim shortcuts (including QT)
string nvimShortcuts = Path.Combine(home, @"AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Neovim");
if (Directory.Exists(nvimShortcuts))
{
    if (dryRun)
        Console.WriteLine($"  would remove {nvimShortcuts}");
    else
        DeletePath(nvimShortcuts);
}

// Persist environment variables
string weztermConfig = Path.Combine(scriptRoot, @"wezterm\wezterm.lua");
if (dryRun)
    Console.WriteLine($"  would set user env WEZTERM_CONFIG_FILE={weztermConfig}");
else
    Environment.SetEnvironmentVariable("WEZTERM_CONFIG_FILE", weztermConfig, EnvironmentVariableTarget.User);

// Create symbolic links
Console.WriteLine("Creating Symbolic Links...");
foreach (var (destination, source) in symlinks)
{
    string target = Path.GetFullPath(source, scriptRoot);
    if (dryRun)
    {
        Console.WriteLine($"  {destination}  ->  {target}");
        continue;
    }
    CreateSymlink(destination, target);
}

// Install bat themes
if (dryRun)
{
    Console.WriteLine("  would run: bat cache --clear && bat cache --build");
}
else
{
    RunStream("bat", "cache --clear");
    RunStream("bat", "cache --build");
}

// Create the AutoHotkey startup shortcut
CreateStartupShortcut();

Console.WriteLine(dryRun ? "\nDry run complete." : "\nSetup complete.");
return 0;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Helpers
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Resolves the directory of this source file at compile time.
static string GetScriptRoot([CallerFilePath] string path = "") => Path.GetDirectoryName(path)!;

static bool IsAdministrator()
{
    using var identity = WindowsIdentity.GetCurrent();
    return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
}

// Equivalent of $PROFILE.CurrentUserAllHosts; asks pwsh so OneDrive-redirected Documents resolve correctly.
static string GetPowerShellProfile()
{
    string fromPwsh = RunCapture("pwsh", "-NoProfile -Command \"$PROFILE.CurrentUserAllHosts\"").Trim();
    if (!string.IsNullOrWhiteSpace(fromPwsh))
        return fromPwsh;

    string documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
    return Path.Combine(documents, "PowerShell", "profile.ps1");
}

static void RefreshPath()
{
    string machine = Environment.GetEnvironmentVariable("Path", EnvironmentVariableTarget.Machine) ?? "";
    string user = Environment.GetEnvironmentVariable("Path", EnvironmentVariableTarget.User) ?? "";
    Environment.SetEnvironmentVariable("Path", $"{machine};{user}");
}

// Creates symlinks via pwsh so Controlled Folder Access (common on managed laptops)
// sees PowerShell rather than the ephemeral Setup.exe under %TEMP%\dotnet\runfile.
static void CreateSymlink(string destination, string target)
{
    string? parent = Path.GetDirectoryName(destination);
    string script =
        """
        $ErrorActionPreference = 'Stop'
        $dest = '{0}'
        $target = '{1}'
        $parent = '{2}'
        if ($parent) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        if (Test-Path -LiteralPath $dest) {
            $item = Get-Item -LiteralPath $dest -Force
            $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($item.PSIsContainer -and -not $isReparse) {
                Remove-Item -LiteralPath $dest -Force -Recurse
            } else {
                Remove-Item -LiteralPath $dest -Force
            }
        }
        New-Item -ItemType SymbolicLink -Path $dest -Target $target | Out-Null
        """
        .Replace("{0}", EscapeForPwshSingleQuoted(destination))
        .Replace("{1}", EscapeForPwshSingleQuoted(target))
        .Replace("{2}", EscapeForPwshSingleQuoted(parent ?? ""));

    string encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
    var (exitCode, stderr) = RunCaptureExit("pwsh", $"-NoProfile -EncodedCommand {encoded}");
    if (exitCode != 0)
    {
        string detail = string.IsNullOrWhiteSpace(stderr) ? $"exit code {exitCode}" : stderr.Trim();
        Console.Error.WriteLine($"  ! Failed to link {destination} -> {target}: {detail}");
    }
}

static string EscapeForPwshSingleQuoted(string value) => value.Replace("'", "''");

// Best-effort removal of a file, directory, or reparse point (mirrors Remove-Item -SilentlyContinue).
static void DeletePath(string path)
{
    try
    {
        if (Directory.Exists(path))
        {
            bool isReparse = (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0;
            Directory.Delete(path, recursive: !isReparse);
        }
        else if (File.Exists(path))
        {
            File.Delete(path);
        }
    }
    catch
    {
        // ignore - matches -ErrorAction SilentlyContinue
    }
}

void CreateStartupShortcut()
{
    string targetPath = Path.Combine(home, @"AutoHotKey\Ignacio.ahk");
    string linkFile = Path.Combine(home, @"AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Ignacio.lnk");

    if (File.Exists(linkFile))
        return;

    if (dryRun)
    {
        Console.WriteLine($"  would create startup shortcut {linkFile} -> {targetPath}");
        return;
    }

    try
    {
        using var shortcut = new WindowsShortcut
        {
            Path = targetPath,
            WorkingDirectory = Path.Combine(home, "AutoHotKey"),
        };
        shortcut.Save(linkFile);
        Process.Start(new ProcessStartInfo(linkFile) { UseShellExecute = true });
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  ! Failed to create startup shortcut: {ex.Message}");
    }
}

// Runs a command, streaming its output to the console; returns the exit code.
static int RunStream(string fileName, string arguments)
{
    try
    {
        using var process = Process.Start(new ProcessStartInfo(fileName, arguments) { UseShellExecute = false });
        if (process is null)
            return -1;
        process.WaitForExit();
        return process.ExitCode;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  ! Failed to run '{fileName} {arguments}': {ex.Message}");
        return -1;
    }
}

// Runs a command and returns its captured standard output.
static string RunCapture(string fileName, string arguments)
{
    try
    {
        using var process = Process.Start(new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        });
        if (process is null)
            return "";
        string output = process.StandardOutput.ReadToEnd();
        process.WaitForExit();
        return output;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  ! Failed to run '{fileName} {arguments}': {ex.Message}");
        return "";
    }
}

// Runs a command and returns exit code + stderr (stdout discarded).
static (int ExitCode, string Stderr) RunCaptureExit(string fileName, string arguments)
{
    try
    {
        using var process = Process.Start(new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        });
        if (process is null)
            return (-1, "failed to start process");
        Task<string> stdoutTask = process.StandardOutput.ReadToEndAsync();
        Task<string> stderrTask = process.StandardError.ReadToEndAsync();
        process.WaitForExit();
        _ = stdoutTask.GetAwaiter().GetResult();
        string stderr = stderrTask.GetAwaiter().GetResult();
        return (process.ExitCode, stderr);
    }
    catch (Exception ex)
    {
        return (-1, ex.Message);
    }
}
