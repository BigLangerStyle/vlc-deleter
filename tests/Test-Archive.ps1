param([string]$FixtureParent = (Join-Path $PSScriptRoot 'tmp'))
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $FixtureParent ('archive-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$helper = Join-Path $PSScriptRoot '../src/Archive-File.ps1'
function Invoke-Archive([string]$Path, [bool]$Validate = $false) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(([Uri]$Path).AbsoluteUri))
    $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $helper, '-UriBase64', $encoded)
    if ($Validate) { $arguments += '-ValidateOnly' } else { $arguments += '-Archive' }
    $output = & powershell.exe @arguments
    return @{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$name = '.favorite [1] & %PATH% $() ' + [char]0x00e9 + [char]::ConvertFromUtf32(0x1f3ac) + '.mp4'
$file = Join-Path $testRoot $name
$archiveDirectory = Join-Path $testRoot '.archive'
$destination = Join-Path $archiveDirectory $name
[IO.File]::WriteAllText($file, 'Disposable archive test fixture')
$subtitle = Join-Path $testRoot 'subtitle.srt'
[IO.File]::WriteAllText($subtitle, 'Subtitle stays beside the original file')
$hash = (Get-FileHash -LiteralPath $file).Hash
$result = Invoke-Archive $file $true
Assert ($result.Output -eq 'VALID') ('Validation failed: ' + $result.Output)
Assert (-not (Test-Path -LiteralPath $archiveDirectory)) 'Validation created an archive folder.'
Assert ((Get-FileHash -LiteralPath $file).Hash -eq $hash) 'Validation changed the source.'
# A regular file named .archive must not be replaced with a directory.
[IO.File]::WriteAllText($archiveDirectory, 'Blocker')
$result = Invoke-Archive $file
Assert ($result.Code -ne 0) 'Accepted a file as the archive directory.'
Assert ([IO.File]::ReadAllText($archiveDirectory) -eq 'Blocker') 'Changed the blocker.'
[IO.File]::Move($archiveDirectory, (Join-Path $testRoot 'blocker-copy.txt'))
$handle = [IO.File]::Open($file, 'Open', 'Read', 'None')
try {
    $result = Invoke-Archive $file
    Assert ($result.Code -ne 0) 'Archived a locked file.'
    Assert (Test-Path -LiteralPath $file) 'Locked source disappeared.'
} finally { $handle.Dispose() }
# Test both validation and the move against an existing destination.
[IO.Directory]::CreateDirectory($archiveDirectory) | Out-Null
[IO.File]::WriteAllText($destination, 'Existing archive entry')
foreach ($validate in @($true, $false)) {
    $result = Invoke-Archive $file $validate
    Assert ($result.Code -ne 0) 'Accepted a filename collision.'
    Assert ([IO.File]::ReadAllText($destination) -eq 'Existing archive entry') 'Overwrote the destination.'
    Assert ((Get-FileHash -LiteralPath $file).Hash -eq $hash) 'Changed the source.'
}
[IO.File]::Move($destination, (Join-Path $testRoot 'collision-copy.txt'))
$result = Invoke-Archive $file
Assert ($result.Output -eq 'ARCHIVED') ('Archiving failed: ' + $result.Output)
Assert (-not (Test-Path -LiteralPath $file)) 'Original filename still exists.'
Assert ((Get-FileHash -LiteralPath $destination).Hash -eq $hash) 'Archived contents changed.'
Assert ([IO.File]::ReadAllText($subtitle) -eq 'Subtitle stays beside the original file') 'Subtitle changed.'
$result = Invoke-Archive $destination
Assert ($result.Output -eq 'ALREADY') 'Did not recognize an archived video.'
Assert (-not (Test-Path -LiteralPath (Join-Path $archiveDirectory '.archive'))) 'Created a nested archive.'
$nestedDirectory = Join-Path $archiveDirectory 'subfolder'
[IO.Directory]::CreateDirectory($nestedDirectory) | Out-Null
$nestedFile = Join-Path $nestedDirectory 'nested.mp4'
[IO.File]::WriteAllText($nestedFile, 'Already inside an archive')
$result = Invoke-Archive $nestedFile
Assert ($result.Output -eq 'ALREADY') 'Did not recognize an archive ancestor.'
foreach ($invalid in @($testRoot, (Join-Path $testRoot 'missing.mp4'))) {
    $result = Invoke-Archive $invalid
    Assert ($result.Code -ne 0) 'Accepted an invalid source.'
}
Write-Output 'PASS: archive move, unchanged contents and favorite name, Unicode, collisions, locked file, existing archive, subtitles, invalid targets.'
