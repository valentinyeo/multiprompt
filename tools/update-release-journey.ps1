param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$proofNames = @('ticket-title staged notes retain title and ticket link', 'restart card reopens newer native app with session restored', 'signed staged notes retain expected data', 'release notes checksum verified', 'first signed local release swap', 'second consecutive update', 'immediate-exit rollback', 'update with old bridge helper running succeeds', 'update leaves no usage helper process')
zig test src/update_notes.zig
if ($LASTEXITCODE -ne 0) { throw 'Release note aggregation and filtering failed' }
zig build "-Drelease=true" "-Dversion=9.99.999" --prefix "$env:RUNNER_TEMP/native-update"
if ($LASTEXITCODE -ne 0) { throw 'Could not build newer native update fixture' }
& "$PSScriptRoot/update-release.test.ps1" -Verifier $Exe -Evidence $Evidence -NativeUpdate "$env:RUNNER_TEMP/native-update/bin/multiprompt.exe"
if (-not $?) { throw 'Signed local release journey failed' }
$proof = Get-Content (Join-Path $Evidence 'safe-updates.json') -Raw | ConvertFrom-Json
foreach ($required in $proofNames) {
    if ($required -notin @($proof.checks)) { throw "Missing signed local release proof: $required" }
}
if (-not (Test-Path (Join-Path $Evidence 'update-card-notes.png'))) { throw 'Missing update card screenshot' }
if ($proof.success -ne $true) { throw 'Signed local release journey did not finish' }
$version = if ($env:VERIFY_VERSION) { $env:VERIFY_VERSION } else { '' }
$sha256 = if ($env:VERIFY_SHA256) { $env:VERIFY_SHA256 } else { (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() }
@{ feature = 'safe-updates'; version = $version; sha256 = $sha256; status = 'passed'; checks = $proof.checks; cleanup = $proof.cleanup } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'result.json')
Write-Output 'VERIFIED safe-updates: signed local release, second consecutive update, immediate-exit rollback'
