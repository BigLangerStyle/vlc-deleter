param([string]$FixtureParent = (Join-Path $PSScriptRoot 'tmp'))
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $FixtureParent ('favorite-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$helper = Join-Path $PSScriptRoot '../src/Favorite-File.ps1'
function Invoke-Favorite([string]$Path, [bool]$Validate = $false) {
    $uri = ([Uri]$Path).AbsoluteUri
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($uri))
    $arguments = @('-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $helper, '-UriBase64', $encoded)
    if ($Validate) { $arguments += '-ValidateOnly' } else { $arguments += '-Favorite' }
    $output = & powershell.exe @arguments
    return @{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$name = 'clip [1] & %PATH% $() ' + [char]0x00e9 + [char]::ConvertFromUtf32(0x1f3ac) + '.mp4'
$file = Join-Path $testRoot $name
$favorite = Join-Path $testRoot ('.' + $name)
[IO.File]::WriteAllText($file, 'Disposable favorite test fixture')
$originalHash = (Get-FileHash -LiteralPath $file).Hash
$result = Invoke-Favorite $file $true
Assert ($result.Output -eq 'VALID') ('Validation failed: ' + $result.Output)
Assert ((Test-Path -LiteralPath $file) -and -not (Test-Path -LiteralPath $favorite)) 'Validation changed the filename.'
[IO.File]::WriteAllText($favorite, 'Existing destination must not be overwritten')
foreach ($validate in @($true, $false)) {
    $result = Invoke-Favorite $file $validate
    Assert ($result.Code -ne 0) 'Accepted a filename collision.'
    Assert ([IO.File]::ReadAllText($favorite) -eq 'Existing destination must not be overwritten') 'Destination content changed.'
    Assert ((Get-FileHash -LiteralPath $file).Hash -eq $originalHash) 'Source content changed.'
}
[IO.File]::Move($favorite, (Join-Path $testRoot 'collision-copy.txt'))
$handle = [IO.File]::Open($file, 'Open', 'Read', 'None')
try {
    $result = Invoke-Favorite $file
    Assert ($result.Code -ne 0) 'Renamed a locked file.'
    Assert (Test-Path -LiteralPath $file) 'Locked file disappeared.'
} finally { $handle.Dispose() }
$result = Invoke-Favorite $file
Assert ($result.Output -eq 'FAVORITED') ('Rename failed: ' + $result.Output)
Assert (-not (Test-Path -LiteralPath $file)) 'Old filename still exists.'
Assert ((Get-FileHash -LiteralPath $favorite).Hash -eq $originalHash) 'Renamed file content changed.'
$result = Invoke-Favorite $favorite
Assert ($result.Output -eq 'ALREADY') 'Favoriting twice did not return ALREADY.'
Assert (-not (Test-Path -LiteralPath (Join-Path $testRoot ('..' + $name)))) 'Added a second period.'
$result = Invoke-Favorite $testRoot
Assert ($result.Code -ne 0) 'Accepted a folder.'
$result = Invoke-Favorite (Join-Path $testRoot 'missing.mp4')
Assert ($result.Code -ne 0) 'Accepted a missing file.'
Write-Output 'PASS: favorite rename, unchanged contents, Unicode, collision protection, locked file, repeated favorite, invalid targets.'
