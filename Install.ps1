[CmdletBinding()]
param([string]$VlcDataDirectory = (Join-Path $env:APPDATA 'vlc'))
$ErrorActionPreference = 'Stop'
$extensions = Join-Path $VlcDataDirectory 'lua/extensions'
$helper = Join-Path $extensions 'vlc-deleter'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src/vlc-deleter.lua') -Destination $extensions -Force
foreach ($name in @('Delete-File.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "src/$name") -Destination $helper -Force
}
foreach ($obsolete in @('Recycle-File.ps1', 'RecycleBin.cs')) {
    $obsoletePath = Join-Path $helper $obsolete
    if (Test-Path -LiteralPath $obsoletePath) { Remove-Item -LiteralPath $obsoletePath -Force }
}
Write-Output "Installed to $extensions. Restart VLC, then choose View > Delete current video."
