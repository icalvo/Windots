[CmdletBinding()]
param (
    # Target address
    [Parameter(Mandatory=$true)]
    [string]
    $Target
)

$failedPings = 0;
$freq = Get-Random -Minimum 300 -Maximum 800;
ping $Target -t `
| ForEach-Object {
    if ($_.StartsWith("Reply from")) {
        $failedPings = 0
    }
    else {
        $failedPings = $failedPings + 1;
        if ($failedPings -gt 3) {
            [Console]::Beep($freq, 200)
        }
    };
    (get-date -f "HH:mm:ss") + " " + $_
}