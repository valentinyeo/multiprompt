param([string]$Root = "$env:RUNNER_TEMP/legacy-update-proof")
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Run only on GitHub Windows' }
. "$PSScriptRoot/fixtures/HYCI-253/legacy-asset-check.ps1"
$headers = @{ 'User-Agent' = 'multibot-legacy-update-proof'; Accept = 'application/vnd.github+json' }
$baseline = Invoke-RestMethod 'https://api.github.com/repos/valentinyeo/multiprompt/releases/tags/v0.28.1660' -Headers $headers
$next = Invoke-RestMethod 'https://api.github.com/repos/valentinyeo/multiprompt/releases/latest' -Headers $headers
if ((Get-ReleaseVersion $next.tag_name) -le (Get-ReleaseVersion $baseline.tag_name)) { throw 'Expected a newer signed release' }
foreach ($folder in @('baseline', 'next')) { New-Item -ItemType Directory -Force (Join-Path $Root $folder) | Out-Null }
foreach ($name in @('multiprompt-x64.exe', 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig')) {
    $asset = Get-ReleaseAsset $baseline $name
    Invoke-WebRequest $asset.browser_download_url -Headers $headers -UseBasicParsing -OutFile (Join-Path $Root "baseline/$name")
}
foreach ($name in @('SHA256SUMS.txt', 'SHA256SUMS.txt.sig')) {
    $asset = Get-ReleaseAsset $next $name
    Invoke-WebRequest $asset.browser_download_url -Headers $headers -UseBasicParsing -OutFile (Join-Path $Root "next/$name")
}
@'
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { signedFiles } from './tools/legacy-update-feed.mjs';
const root = process.argv[2];
const rawKey = Buffer.from(fs.readFileSync('src/release_signing_public_key.txt', 'utf8').trim(), 'base64');
for (const folder of ['baseline', 'next']) {
  const read = name => fs.readFileSync(path.join(root, folder, name));
  const files = signedFiles(read('SHA256SUMS.txt'), read('SHA256SUMS.txt.sig'), rawKey);
  if (folder === 'baseline' && createHash('sha256').update(read('multiprompt-x64.exe')).digest('hex') !== files.get('multiprompt-x64.exe')) throw new Error('Old verifier checksum mismatch');
}
console.log('Signed manifests and old executable verified before execution');
'@ | node --input-type=module - $Root
if ($LASTEXITCODE -ne 0) { throw 'Signature bootstrap verification failed' }
$verifier = (Resolve-Path (Join-Path $Root 'baseline/multiprompt-x64.exe')).Path
$sums = Join-Path $Root 'next/SHA256SUMS.txt'
$signature = Join-Path $Root 'next/SHA256SUMS.txt.sig'
function Verify-Next([bool]$Expected) {
    $process = Start-Process -FilePath $verifier -ArgumentList "--verify-release-manifest `"$sums`" `"$signature`"" -PassThru
    if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Old verifier timed out' }
    if (($process.ExitCode -eq 0) -ne $Expected) { throw 'Old verifier returned an unexpected result' }
}
$names = @('multiprompt-x64.exe', 'multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe', 'multiprompt-extension.zip', 'release-notes.json', 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig')
foreach ($name in $names) { $null = Get-ReleaseAsset $next $name }
Verify-Next $true
Write-Host 'BEFORE: old updater accepts original feed and next signed manifest'
$renamed = $next | ConvertTo-Json -Depth 20 | ConvertFrom-Json
foreach ($asset in $renamed.assets) { $asset.browser_download_url = $asset.browser_download_url.Replace('/multiprompt/', '/multibot/') }
$refused = $false
try { $null = Get-ReleaseAsset $renamed 'multiprompt-x64.exe' } catch { $refused = $true }
if (-not $refused) { throw 'Control failed: literal rename should break old clients' }
Write-Host 'CONTROL: literal repository rename rejected by unchanged old updater'
foreach ($asset in $renamed.assets) { $asset.browser_download_url = $asset.browser_download_url.Replace('/multibot/', '/multiprompt/') }
foreach ($name in $names) { $null = Get-ReleaseAsset $renamed $name }
Verify-Next $true
Write-Host 'AFTER: old updater accepts permanent legacy feed and unchanged signed manifest'
[IO.File]::AppendAllText($sums, 'tampered')
Verify-Next $false
Write-Host 'SECURITY: old executable rejects tampered manifest'
@{ baseline = $baseline.tag_name; next = $next.tag_name; actualRename = $false; before = 'PASS'; literalRenameControl = 'REFUSED'; permanentLegacyOrigin = 'PASS'; tamperedManifest = 'REFUSED' } | ConvertTo-Json | Set-Content (Join-Path $Root 'proof.json')
Write-Host 'LEGACY_CLIENT_PROOF_OK'
