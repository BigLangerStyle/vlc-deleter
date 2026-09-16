# Copyright (c) 2026 Stephen Langer. MIT license.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$UriBase64, [switch]$ValidateOnly, [switch]$Favorite)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    $value = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($UriBase64))
    if ($value -cnotmatch '^file:///[A-Za-z]:/') { throw 'The file needs to be on a drive with a letter, such as C: or S:.' }
    $uri = [Uri]$value
    if (-not $uri.IsFile -or $uri.IsUnc -or $uri.Query -or $uri.Fragment) { throw 'Cannot use this file address.' }
    $path = $uri.LocalPath
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer) { throw 'Open a video file, not a folder.' }
    $cursor = $item
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Open the file from its original location, without symbolic links or junctions.' }
        if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory } else { $cursor = $cursor.Parent }
    }
    if ($path.Substring(2).Contains(':')) { throw 'Alternate data streams are not supported.' }
    if ($item.Name.StartsWith('.')) { Write-Output 'ALREADY'; exit 0 }
    $destination = Join-Path $item.DirectoryName ('.' + $item.Name)
    if (Test-Path -LiteralPath $destination) { throw 'A file with the favorite name already exists. Nothing was renamed.' }
    if ($ValidateOnly) { Write-Output 'VALID'; exit 0 }
    if (-not $Favorite) { throw 'Specify -ValidateOnly or -Favorite.' }
    # Windows may still be closing VLC's handle after playback stops.
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        try {
            # File.Move never overwrites the destination, including a collision
            # created after the validation step. Both paths stay in one folder.
            [IO.File]::Move($path, $destination)
            Write-Output 'FAVORITED'
            exit 0
        } catch [IO.IOException] {
            if ($attempt -eq 11 -or (Test-Path -LiteralPath $destination)) { throw }
            Start-Sleep -Milliseconds 100
        }
    }
} catch {
    Write-Output ('ERROR: ' + $_.Exception.Message)
    exit 1
}
