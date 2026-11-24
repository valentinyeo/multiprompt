param([Parameter(Mandatory)][string[]]$Tags)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Release download runs only inside GitHub Actions' }
foreach ($tag in $Tags) {
    $tag = $tag.Trim()
    if ($tag -notmatch '^v\d+\.\d+\.\d+$') { throw "Expected a release tag, got $tag" }
    New-Item -ItemType Directory -Force "bin/$tag" | Out-Null
    gh release download $tag --repo $env:GITHUB_REPOSITORY --dir "bin/$tag" --pattern multiprompt-x64.exe --pattern SHA256SUMS.txt
    if ($LASTEXITCODE -ne 0) { throw "Release download failed: $tag" }
    $expected = (Select-String -Path "bin/$tag/SHA256SUMS.txt" -Pattern 'multiprompt-x64\.exe' | Select-Object -First 1).Line.Split(' ')[0]
    $actual = (Get-FileHash "bin/$tag/multiprompt-x64.exe" -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $expected -or $expected.ToLowerInvariant() -ne $actual) { throw "Release checksum mismatch for ${tag}: $expected vs $actual" }
    Write-Host "downloaded $tag sha256 $actual"
}
