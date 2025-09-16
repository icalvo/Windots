param($pwsh)

$cmd = [System.IO.Path]::ChangeExtension($pwsh, ".cmd")
$pwshname = [System.IO.Path]::GetFileName($pwsh)
Write-Output "@echo off" > $cmd
Write-Output "pswh -file %~dp0$pwshname %*" >> $cmd
