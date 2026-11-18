$ErrorActionPreference = 'Stop'

$existing = @(Get-Command ffmpeg.exe, ffprobe.exe -ErrorAction SilentlyContinue)
if ($existing.Count -eq 2) {
    foreach ($tool in $existing) {
        & $tool.Source -version
        if ($LASTEXITCODE -ne 0) { throw 'Existing video tool failed its version check' }
    }
    return
}

if ($env:OS -ne 'Windows_NT' -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or -not $env:RUNNER_TEMP -or -not $env:GITHUB_PATH) { throw 'Video setup requires a Windows x64 runner' }
$dist = 'ffmpeg-n8.1.3-35-gf1acb0a266-win64-gpl-8.1'
$sha = '5e50099d2ad086f193889452e98bce6f5ece36e852b2390769707c3afa39659b'
$root = Join-Path $env:RUNNER_TEMP 'video-tools-8.1.3'
$archive = Join-Path $root 'ffmpeg.zip'
New-Item -ItemType Directory -Force -Path $root | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/FFmpeg-Builds/FFmpeg-Builds/releases/download/autobuild-2026-11-17-12-40/$dist.zip" -OutFile $archive
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $sha) { throw 'FFmpeg archive checksum mismatch' }
Expand-Archive -LiteralPath $archive -DestinationPath $root -Force
$bin = Join-Path $root "$dist/bin"
foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
    & (Join-Path $bin $name) -version
    if ($LASTEXITCODE -ne 0) { throw 'Downloaded video tool failed its version check' }
}
Add-Content -LiteralPath $env:GITHUB_PATH -Value $bin -Encoding utf8
