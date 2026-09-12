# Copyright (c) 2026 Stephen Langer. MIT license.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$UriBase64, [switch]$ValidateOnly, [switch]$Delete)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    $value = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($UriBase64))
    if ($value -cnotmatch '^file:///[A-Za-z]:/') { throw 'The file needs to be on a drive with a letter, such as C: or S:.' }
    $uri = [Uri]$value
    if (-not $uri.IsFile -or $uri.IsUnc -or $uri.Query -or $uri.Fragment) { throw 'VLC Deleter cannot use this file address.' }
    $path = $uri.LocalPath
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer) { throw 'This is a folder. VLC Deleter only deletes files.' }
    # Reject redirected paths, including junctions in ancestor directories.
    $cursor = $item
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'This path goes through a symbolic link or another redirected location. Open the file from its original location.' }
        if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory } else { $cursor = $cursor.Parent }
    }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($path))
    if ($drive.DriveType -notin @([IO.DriveType]::Fixed, [IO.DriveType]::Removable, [IO.DriveType]::Network)) {
        throw ($drive.Name + ' is an unsupported ' + $drive.DriveType + ' drive.')
    }
    if ($path.Substring(2).Contains(':')) { throw 'Alternate data streams are not supported.' }
    if ($ValidateOnly) {
        Write-Output 'VALID'
        exit 0
    }
    if (-not $Delete) { throw 'Specify -ValidateOnly or -Delete.' }
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
    [IO.File]::Delete($path)
    if (Test-Path -LiteralPath $path) { throw 'Windows did not delete the file.' }
    Write-Output 'DELETED'
    exit 0
} catch {
    Write-Output ('ERROR: ' + $_.Exception.Message)
    exit 1
}
