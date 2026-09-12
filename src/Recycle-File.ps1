# Copyright (c) 2026 Stephen Langer. MIT license.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$UriBase64, [switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    $value = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($UriBase64))
    if ($value -cnotmatch '^file:///[A-Za-z]:/') { throw 'Only local drive file URIs are supported.' }
    $uri = [Uri]$value
    if (-not $uri.IsFile -or $uri.IsUnc -or $uri.Query -or $uri.Fragment) { throw 'Unsupported file URI.' }
    $path = $uri.LocalPath
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer) { throw 'Folders cannot be recycled by this extension.' }
    # Reject redirected paths, including junctions in ancestor directories.
    $cursor = $item
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not supported.' }
        if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory } else { $cursor = $cursor.Parent }
    }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($path))
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'Only fixed local drives are supported.' }
    if ($path.Substring(2).Contains(':')) { throw 'Alternate data streams are not supported.' }
    if ($ValidateOnly) { Write-Output 'VALID'; exit 0 }
    Add-Type -Path (Join-Path $PSScriptRoot 'RecycleBin.cs')
    # VLC stop is asynchronous. Wait briefly for its handle to be released.
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        try {
            $handle = [IO.File]::Open($path, 'Open', 'Read', 'None')
            $handle.Dispose()
            break
        } catch [IO.IOException] {
            if ($attempt -eq 11) { throw }
            Start-Sleep -Milliseconds 100
        }
    }
    [VlcDeleter.RecycleBin]::Recycle($path)
    if (Test-Path -LiteralPath $path) { throw 'Windows did not recycle the file.' }
    Write-Output 'RECYCLED'
    exit 0
} catch {
    Write-Output ('ERROR: ' + $_.Exception.Message)
    exit 1
}
