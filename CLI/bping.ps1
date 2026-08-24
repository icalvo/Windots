[CmdletBinding()]
param (
    # Target address
    [Parameter(Mandatory=$true)]
    [string]
    $Target,

    # Cadence in milliseconds (default 500). Each cycle logs or beeps within
    # about this long; if a ping already took this long, the next starts immediately.
    [ValidateRange(0, [int]::MaxValue)]
    [int]
    $IntervalMs = 500
)

$failedPings = 0
$freq = Get-Random -Minimum 300 -Maximum 800
# ping -w / WaitForExit need a positive timeout; 0 means "as fast as possible"
$waitMs = [Math]::Max(1, $IntervalMs)

while ($true) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $line = $null
    $success = $false

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ping.exe"
    $psi.Arguments = "-n 1 -w $waitMs `"$Target`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()

    if (-not $p.WaitForExit($waitMs)) {
        # DNS or stack hung past the interval — kill and keep the cadence
        try { $p.Kill() } catch { }
        try { [void]$p.WaitForExit(1000) } catch { }
        $line = "Request timed out (no response within ${waitMs}ms)."
    }
    else {
        $output = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
        $line = (
            $output -split "`r?`n" |
            Where-Object {
                $_ -match '^(Reply from|Request timed out|Destination host unreachable|General failure|Ping request could not find host)'
            } |
            Select-Object -First 1
        )
        if (-not $line) {
            $line = "No response within ${waitMs}ms."
        }
        $success = $line.StartsWith("Reply from")
    }

    if (-not $p.HasExited) {
        try { $p.Kill() } catch { }
    }
    $p.Dispose()

    if ($success) {
        $failedPings = 0
    }
    else {
        $failedPings = $failedPings + 1
        if ($failedPings -gt 3) {
            [Console]::Beep($freq, 200)
        }
    }
    (Get-Date -f "HH:mm:ss") + " " + $line

    $remaining = $IntervalMs - $sw.ElapsedMilliseconds
    if ($remaining -gt 0) {
        Start-Sleep -Milliseconds $remaining
    }
}
