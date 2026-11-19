param (
    [Parameter(Mandatory = $true)]
    $url
)

$outputTemplate = "%(title)s-%(id)s.%(ext)s"

$infoJson = yt-dlp -J --no-download --no-warnings $url
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$info = $infoJson | ConvertFrom-Json
$formats = @($info.formats | Where-Object { $_.protocol -ne 'mhtml' })
if ($formats.Count -eq 0 -and $info.format_id) {
    $formats = @($info)
}

$formatArgs = @()
if ($formats.Count -gt 1) {
    Write-Host ("{0,-10} {1,-5} {2,-12} {3,-8} {4}" -f 'ID', 'EXT', 'RESOLUTION', 'SIZE', 'NOTE')
    Write-Host ('-' * 72)
    foreach ($f in $formats) {
        $res = if ($f.resolution) { $f.resolution }
            elseif ($f.height) { "$($f.width)x$($f.height)" }
            elseif ($f.vcodec -eq 'none') { 'audio only' }
            else { '-' }
        $size = if ($f.filesize) { '{0:N1} MiB' -f ($f.filesize / 1MB) }
            elseif ($f.filesize_approx) { '~{0:N1} MiB' -f ($f.filesize_approx / 1MB) }
            else { '' }
        $note = $(if ($f.format_note) { $f.format_note } else { '' })
        Write-Host ("{0,-10} {1,-5} {2,-12} {3,-8} {4}" -f $f.format_id, $f.ext, $res, $size, $note)
    }

    $validIds = @($formats | ForEach-Object { $_.format_id })
    $combined = $formats | Where-Object { $_.vcodec -ne 'none' -and $_.acodec -ne 'none' } | Select-Object -Last 1
    $videoOnly = $formats | Where-Object { $_.vcodec -ne 'none' -and $_.acodec -eq 'none' } | Select-Object -Last 1
    $audioOnly = $formats | Where-Object { $_.acodec -ne 'none' -and $_.vcodec -eq 'none' } | Select-Object -Last 1

    $examples = @()
    if ($combined) { $examples += $combined.format_id }
    elseif ($validIds.Count -gt 0) { $examples += $validIds[-1] }
    if ($videoOnly -and $audioOnly) {
        $examples += "$($videoOnly.format_id)+$($audioOnly.format_id)"
    }
    $exampleText = $examples -join ', '

    while ($true) {
        $choice = Read-Host "`nSelect format ID (e.g. $exampleText, or Enter = best)"
        if ([string]::IsNullOrWhiteSpace($choice)) { break }

        $parts = @($choice -split '\+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $invalid = @($parts | Where-Object { $_ -notin $validIds })
        if ($invalid.Count -gt 0) {
            Write-Host "Unknown format(s): $($invalid -join ', '). Choose an ID from the table."
            continue
        }

        $formatArgs = @('-f', ($parts -join '+'))
        break
    }
}

yt-dlp @formatArgs $url -o $outputTemplate
