# Copyright (c) 2026 Stephen Langer. MIT license.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$UriBase64, [switch]$ValidateOnly, [switch]$Archive)
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
    $alreadyArchived = $false
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Open the file from its original location, without symbolic links or junctions.' }
        if ($cursor -is [IO.DirectoryInfo] -and $cursor.Name -ieq '.archive') { $alreadyArchived = $true }
        if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory } else { $cursor = $cursor.Parent }
    }
    if ($path.Substring(2).Contains(':')) { throw 'Alternate data streams are not supported.' }
    if ($alreadyArchived) { Write-Output 'ALREADY'; exit 0 }
    $archiveDirectory = Join-Path $item.DirectoryName '.archive'
    $destination = Join-Path $archiveDirectory $item.Name
    function Assert-ArchiveDirectory {
        if (Test-Path -LiteralPath $archiveDirectory) {
            $folder = Get-Item -LiteralPath $archiveDirectory -Force
            if (-not $folder.PSIsContainer) { throw 'A file named .archive is in the way. Nothing was moved.' }
            if ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The .archive folder points to another location. Nothing was moved.' }
        }
    }
    Assert-ArchiveDirectory
    if (Test-Path -LiteralPath $destination) { throw 'This .archive folder already has a file with the same name. Nothing was moved.' }
    if ($ValidateOnly) { Write-Output 'VALID'; exit 0 }
    if (-not $Archive) { throw 'Specify -ValidateOnly or -Archive.' }
    # Validation does not create a folder. Only the requested move does.
    [IO.Directory]::CreateDirectory($archiveDirectory) | Out-Null
    Assert-ArchiveDirectory
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        try {
            Assert-ArchiveDirectory
            # Exact sibling paths; File.Move refuses to overwrite a collision.
            [IO.File]::Move($path, $destination)
            Write-Output 'ARCHIVED'
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
