param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/update-release.test.ps1" -Verifier $Exe -Evidence $Evidence
if ($LASTEXITCODE -ne 0) { throw 'Signed local release journey failed' }
$proof = Get-Content (Join-Path $Evidence 'safe-updates.json') -Raw | ConvertFrom-Json
foreach ($required in @('first signed local release swap', 'second consecutive update', 'immediate-exit rollback', 'locked backup update succeeds')) {
    if ($required -notin $proof.checks) { throw "Missing signed local release proof: $required" }
}
if ($proof.success -ne $true) { throw 'Signed local release journey did not finish' }
Write-Output 'VERIFIED safe-updates: signed local release, second consecutive update, immediate-exit rollback'
