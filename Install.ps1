[CmdletBinding()]
param([string]$VlcDataDirectory = (Join-Path $env:APPDATA 'vlc'))
$ErrorActionPreference = 'Stop'
$extensions = Join-Path $VlcDataDirectory 'lua/extensions'
$helper = Join-Path $extensions 'vlc-deleter'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src/vlc-deleter.lua') -Destination $extensions -Force
foreach ($name in @('Recycle-File.ps1', 'RecycleBin.cs')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "src/$name") -Destination $helper -Force
}
Write-Output "Installed to $extensions. Restart VLC, then choose View > Recycle current video."
