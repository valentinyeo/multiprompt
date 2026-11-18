param([string]$Destination = (Join-Path $env:RUNNER_TEMP 'verify-recorder-7.1.1'))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Destination | Out-Null
$archive = Join-Path $Destination 'ffmpeg.zip'
Invoke-WebRequest -Uri 'https://github.com/GyanD/codexffmpeg/releases/download/7.1.1/ffmpeg-7.1.1-essentials_build.zip' -OutFile $archive
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ine '04861d3339c5ebe38b56c19a15cf2c0cc97f5de4fa8910e4d47e5e6404e4a2d4') { throw 'FFmpeg archive checksum mismatch' }
Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
$bin = Join-Path $Destination 'ffmpeg-7.1.1-essentials_build/bin'
foreach ($tool in @('ffmpeg', 'ffprobe')) {
    & (Join-Path $bin "$tool.exe") -version
    if ($LASTEXITCODE -ne 0) { throw "$tool validation failed" }
}
$bin | Out-File -LiteralPath $env:GITHUB_PATH -Encoding utf8 -Append
