param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
zig build "-Drelease=true" "-Dversion=9.99.999" --prefix "$env:RUNNER_TEMP/native-update"
if ($LASTEXITCODE -ne 0) { throw 'Could not build newer native update fixture' }
& "$PSScriptRoot/update-release.test.ps1" -Verifier $Exe -Evidence $Evidence -NativeUpdate "$env:RUNNER_TEMP/native-update/bin/multiprompt.exe"
if (-not $?) { throw 'Signed local release journey failed' }
$proof = Get-Content (Join-Path $Evidence 'safe-updates.json') -Raw | ConvertFrom-Json
foreach ($required in @('restart card reopens newer native app with session restored', 'update card shows aggregated plain notes', 'update card opens the full list on click', 'release notes checksum verified', 'first signed local release swap', 'second consecutive update', 'immediate-exit rollback', 'locked backup update succeeds')) {
    if ($required -notin $proof.checks) { throw "Missing signed local release proof: $required" }
}
if (-not (Test-Path (Join-Path $Evidence 'update-card-notes.png'))) { throw 'Missing update card screenshot' }
if (-not (Test-Path (Join-Path $Evidence 'update-card-expanded.png'))) { throw 'Missing expanded update card screenshot' }
if ($proof.success -ne $true) { throw 'Signed local release journey did not finish' }
Write-Output 'VERIFIED safe-updates: signed local release, second consecutive update, immediate-exit rollback'
