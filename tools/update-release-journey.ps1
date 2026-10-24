param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/update-release.test.ps1" -Verifier $Exe -Evidence $Evidence
if (-not $?) { throw 'Signed local release journey failed' }
$proof = Get-Content (Join-Path $Evidence 'safe-updates.json') -Raw | ConvertFrom-Json
foreach ($required in @('update card shows aggregated plain notes', 'release notes checksum verified', 'first signed local release swap', 'second consecutive update', 'immediate-exit rollback', 'locked backup update succeeds')) {
    if ($required -notin $proof.checks) { throw "Missing signed local release proof: $required" }
}
if (-not (Test-Path (Join-Path $Evidence 'update-card-notes.png'))) { throw 'Missing update card screenshot' }
if ($proof.success -ne $true) { throw 'Signed local release journey did not finish' }
Write-Output 'VERIFIED safe-updates: signed local release, second consecutive update, immediate-exit rollback'
