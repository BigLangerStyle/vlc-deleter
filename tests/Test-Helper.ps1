param([string]$FixtureParent = (Join-Path $PSScriptRoot 'tmp'))
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $FixtureParent ('helper-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$helper = Join-Path $PSScriptRoot '../src/Delete-File.ps1'
function Invoke-Helper([string]$Uri, [bool]$Validate = $false) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Uri))
    $arguments = @('-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $helper, '-UriBase64', $encoded)
    if ($Validate) { $arguments += '-ValidateOnly' } else { $arguments += '-Delete' }
    $output = & powershell.exe @arguments
    return @{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$specialName = 'clip [1] & %PATH% $() ' + [char]0x00e9 + [char]::ConvertFromUtf32(0x1f3ac) + '.avi'
$file = Join-Path $testRoot $specialName
[IO.File]::WriteAllText($file, 'Disposable VLC Deleter test fixture')
$uri = ([Uri]$file).AbsoluteUri
$result = Invoke-Helper $uri $true
Assert ($result.Code -eq 0 -and $result.Output -eq 'VALID') ('Unicode validation failed: ' + $result.Output)
Assert (Test-Path -LiteralPath $file) 'Validation modified the file.'
foreach ($invalid in @('https://example.com/movie.mp4', 'file://server/share/movie.mp4', ([Uri]$testRoot).AbsoluteUri, ([Uri](Join-Path $testRoot 'missing.avi')).AbsoluteUri)) {
    $result = Invoke-Helper $invalid $true
    Assert ($result.Code -ne 0) ('Accepted invalid target: ' + $invalid)
}
$handle = [IO.File]::Open($file, 'Open', 'Read', 'None')
try {
    $validation = Invoke-Helper $uri $true
    Assert ($validation.Code -eq 0) ('Read-only validation rejected a locked file: ' + $validation.Output)
    Assert (Test-Path -LiteralPath $file) 'Validation removed the locked file.'
    $result = Invoke-Helper $uri
    Assert ($result.Code -ne 0) 'Deleted a locked file.'
    Assert (Test-Path -LiteralPath $file) 'Locked file disappeared.'
} finally { $handle.Dispose() }
$result = Invoke-Helper $uri
Assert ($result.Code -eq 0 -and $result.Output -eq 'DELETED') ('Deletion failed: ' + $result.Output)
Assert (-not (Test-Path -LiteralPath $file)) 'Deleted file still exists at source.'
Write-Output 'PASS: Unicode and shell characters, invalid targets, validation preserves playback file, locked file, permanent deletion.'
