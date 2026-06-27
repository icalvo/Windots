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
#:package TaskScheduler@2.12.2
#:package WindowsShortcutFactory@1.2.0

using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Security.Principal;
using Microsoft.Win32.TaskScheduler;
using WindowsShortcutFactory;

bool dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);

string scriptRoot = GetScriptRoot();
string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

// Linked Files (Destination => Source). Sources are relative to this script.
var symlinks = new (string Destination, string Source)[]
{
    (GetPowerShellProfile(),                                                                            @".\Profile.ps1"),
    (Path.Combine(home, "AutoHotKey"),                                                                  @".\AutoHotKey"),
    (Path.Combine(home, @"AppData\Local\nvim"),                                                         @".\nvim"),
    (Path.Combine(home, @"AppData\Local\k9s"),                                                          @".\k9s"),
    (Path.Combine(home, @"AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"), @".\windowsterminal\settings.json"),
    (Path.Combine(home, @"AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\InactivePane.hlsl"), @".\windowsterminal\InactivePane.hlsl"),
    (Path.Combine(home, ".gitconfig"),                                                                  @".\.gitconfig"),
    (Path.Combine(home, @"AppData\Local\lazygit"),                                                      @".\lazygit"),
    (Path.Combine(home, @"AppData\Roaming\neovide"),                                                    @".\neovide"),
    (Path.Combine(home, @"AppData\Roaming\AltSnap\AltSnap.ini"),                                        @".\altsnap\AltSnap.ini"),
    (Path.Combine(programFiles, @"WezTerm\wezterm_modules"),                                            @".\wezterm"),
    (Path.Combine(home, ".ideavimrc"),                                                                  @".\.ideavimrc"),
};

// Winget dependencies
string[] wingetDeps =
{
    "autohotkey.autohotkey",
    "chocolatey.chocolatey",
    "eza-community.eza",
    "ezwinports.make",
    "git.git",
    "github.cli",
    "kitware.cmake",
    "mbuilov.sed",
    "microsoft.powershell",
    "openjs.nodejs.lts",
    "sst.opencode",
    "task.task",
    "JanDeDobbeleer.OhMyPosh",
};

// Chocolatey dependencies
string[] chocoDeps =
{
    "altsnap",
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
};

// PowerShell Gallery modules (installed via pwsh - no BCL/NuGet equivalent exists)
string[] psModules =
{
    "posh-git",
    "CompletionPredictor",
    "PSScriptAnalyzer",
    "ps-arch-wsl",
    "ps-color-scripts",
};

// dotnet global tools
string[] dotnetTools =
{
    "dotnet-suggest",
};

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

// Register the AltSnap scheduled task (replaces altsnap/createTask.ps1)
RegisterAltSnapTask();

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

static void CreateSymlink(string destination, string target)
{
    DeletePath(destination);

    string? parent = Path.GetDirectoryName(destination);
    if (!string.IsNullOrEmpty(parent))
        Directory.CreateDirectory(parent);

    try
    {
        if (Directory.Exists(target))
            Directory.CreateSymbolicLink(destination, target);
        else
            File.CreateSymbolicLink(destination, target);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  ! Failed to link {destination} -> {target}: {ex.Message}");
    }
}

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

void RegisterAltSnapTask()
{
    string altSnapExe = Path.Combine(home, @"AppData\Roaming\AltSnap\AltSnap.exe");

    if (dryRun)
    {
        Console.WriteLine($"  would register scheduled task 'AltSnap' -> {altSnapExe}");
        return;
    }

    try
    {
        using var taskService = new TaskService();
        TaskDefinition definition = taskService.NewTask();
        definition.RegistrationInfo.Description = "Start AltSnap on logon";
        definition.Principal.GroupId = @"BUILTIN\Users";
        definition.Principal.RunLevel = TaskRunLevel.Highest;
        definition.Triggers.Add(new LogonTrigger { Delay = TimeSpan.FromSeconds(10) });
        definition.Actions.Add(new ExecAction(altSnapExe));
        definition.Settings.MultipleInstances = TaskInstancesPolicy.IgnoreNew;
        definition.Settings.ExecutionTimeLimit = TimeSpan.Zero;

        taskService.RootFolder.RegisterTaskDefinition("AltSnap", definition);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  ! Failed to register AltSnap task: {ex.Message}");
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
