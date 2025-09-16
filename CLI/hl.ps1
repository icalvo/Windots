param($path)

$name=[IO.Path]::GetFileName($path)
$resolved=Resolve-Path $path

New-Item -Type HardLink -Path $name -Target $resolved