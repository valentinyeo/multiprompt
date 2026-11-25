$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '../../../tools/probe-native-version.ps1')

$pinned = $env:FFMPEG_VERSION
$sourceSha = "$($env:FFMPEG_SHA256)".ToLowerInvariant()
$limit = 5
$target = $env:FFMPEG_TARGET
$archive = "https://github.com/GyanD/codexffmpeg/releases/download/$pinned/ffmpeg-$pinned-essentials_build.zip"
$reports = "version n?$([regex]::Escape($pinned))\b"
$evidence = Join-Path $env:RUNNER_TEMP 'ffmpeg-evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null

function Use-Ffmpeg([string]$directory) {
  $exe = Join-Path $directory 'ffmpeg.exe'
  if (-not (Test-Path $exe)) { throw "FFmpeg $pinned is missing from $directory" }
  $probe = Invoke-NativeVersionProbe -FilePath $exe -Arguments '-version' -Evidence $evidence
  if ($probe.ExitCode -ne 0) { throw "FFmpeg $pinned from $directory exited $($probe.ExitCode): $($probe.ErrorText)" }
  if (-not $probe.Line) { throw "FFmpeg $pinned from $directory printed no version line: $($probe.ErrorText)" }
  if ($probe.Line -notmatch $reports) { throw "FFmpeg from $directory reports '$($probe.Line)' instead of $pinned" }
  Add-Content -Path $env:GITHUB_PATH -Value $directory
  Write-Host "FFmpeg ready: $($probe.Line)"
}

if ($env:FFMPEG_CACHE_HIT -eq 'true' -and (Test-Path (Join-Path $target 'ffmpeg.exe'))) {
  $cached = Invoke-NativeVersionProbe -FilePath (Join-Path $target 'ffmpeg.exe') -Arguments '-version' -Evidence $evidence
  if ($cached.ExitCode -eq 0 -and $cached.Line -match $reports) {
    Write-Host "FFmpeg $pinned restored from cache"
    Use-Ffmpeg $target
    exit 0
  }
  Write-Host "FFmpeg $pinned restored from cache but does not run; installing a fresh copy"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $target
}
$existing = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($existing) {
  $installed = Invoke-NativeVersionProbe -FilePath $existing.Source -Arguments '-version' -Evidence $evidence
  if ($installed.ExitCode -eq 0 -and $installed.Line -match $reports) {
    Write-Host "FFmpeg $pinned already available at $($existing.Source)"
    exit 0
  }
}
$failure = ''
for ($attempt = 1; $attempt -le $limit; $attempt++) {
  Write-Host "FFmpeg $pinned download attempt $attempt of $limit from $archive"
  try {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $target
    Remove-Item -Force -ErrorAction SilentlyContinue "$target.zip"
    Invoke-WebRequest -Uri $archive -OutFile "$target.zip" -UseBasicParsing
    $actual = (Get-FileHash -Path "$target.zip" -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $sourceSha) { throw "FFmpeg $pinned archive hash $actual does not match the pinned $sourceSha" }
    Expand-Archive -Path "$target.zip" -DestinationPath "$target.extract" -Force
    $bin = Get-ChildItem -Path "$target.extract" -Recurse -Filter ffmpeg.exe | Select-Object -First 1
    if (-not $bin) { throw "FFmpeg $pinned archive carries no ffmpeg.exe" }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Copy-Item -Path (Join-Path $bin.Directory.FullName '*') -Destination $target -Recurse -Force
    Use-Ffmpeg $target
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$target.zip", "$target.extract"
    exit 0
  } catch {
    $failure = $_.Exception.Message
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$target.zip", "$target.extract"
    if ($attempt -lt $limit) {
      $delay = [int][Math]::Min(60, 5 * [Math]::Pow(2, $attempt - 1))
      Write-Host "FFmpeg $pinned download attempt $attempt failed: $failure; retrying in $($delay)s"
      Start-Sleep -Seconds $delay
    }
  }
}
Write-Host "FFmpeg $pinned download failed: $failure"
throw "FFmpeg $pinned install failed after $limit attempts"
