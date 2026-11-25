param(
    [Parameter(Mandatory=$true, Position=0)][ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Feature,
    [Parameter(Position=1)][ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Journey,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use verify.yml on GitHub Windows' }
$map = Join-Path $PSScriptRoot "features/$Feature.md"
$text = Get-Content -LiteralPath $map -Raw
if ($text -match '(?m)^Journeys: (.+)\r?$') {
    $journeys = $Matches[1].Trim() -split ', '
    if (-not $Journey) { $Journey = $journeys[0] }
    if ($Journey -notin $journeys) { throw "Journey $Journey is not mapped under $Feature" }
} else {
    if ($Journey -and $Journey -ne $Feature) { throw 'Legacy maps accept only their own journey' }
    $Journey = $Feature
}
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
if (Test-Path "$Evidence/journey.json") { throw 'Use a fresh evidence folder for each journey' }
$record = [ordered]@{ feature=$Feature; journey=$Journey; revision=(git rev-parse HEAD).Trim(); status='failed'; error=$null }
$video = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new('ffmpeg', "-y -f gdigrab -framerate 6 -i desktop -an -vf scale=960:-2 -c:v libx264 -preset ultrafast -crf 28 -movflags +faststart -pix_fmt yuv420p `"$Evidence/journey.mp4`"")
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.CreateNoWindow = $true
    $video = [Diagnostics.Process]::Start($start)
    & powershell -NoProfile -File "$PSScriptRoot/control.ps1" -Feature $Journey -Exe $Exe -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
    if ($LASTEXITCODE -ne 0) { throw "Journey exited $LASTEXITCODE; inspect result.json" }
    $result = Get-Content "$Evidence/result.json" -Raw | ConvertFrom-Json
    if ($result.status -ne 'passed') { throw 'Journey did not pass' }
    if ($result.PSObject.Properties['scratchRemoved'] -and $result.scratchRemoved -eq $false) { throw 'Owned cleanup failed' }
    if ((Test-Path "$Evidence/process-tree.json") -and ((Get-Content "$Evidence/process-tree.json" -Raw | ConvertFrom-Json).activeAfterStop -ne 0)) { throw 'Owned cleanup failed' }
    $record.status = 'passed'
} catch {
    $record.error = $_.Exception.Message
} finally {
    if ($null -ne $video) {
        try {
            if (-not $video.HasExited) { $video.StandardInput.WriteLine('q'); $video.StandardInput.Close() }
            if (-not $video.WaitForExit(15000)) { $video.Kill(); $video.WaitForExit(); throw 'Recorder did not stop' }
            if ($video.ExitCode -ne 0 -or -not (Test-Path "$Evidence/journey.mp4") -or (Get-Item "$Evidence/journey.mp4").Length -eq 0) { throw 'Recorder failed' }
            $probe = & ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of json "$Evidence/journey.mp4"
            if ($LASTEXITCODE -ne 0 -or @((($probe -join "`n") | ConvertFrom-Json).streams).Count -ne 1) { throw 'Video is not readable' }
            $probe | Set-Content -Encoding UTF8 "$Evidence/video.json"
        } catch {
            $record.status = 'failed'
            if (-not $record.error) { $record.error = $_.Exception.Message } else { $record.videoError = $_.Exception.Message }
        }
        finally { $video.Dispose() }
    }
    $record | ConvertTo-Json | Set-Content -Encoding UTF8 "$Evidence/journey.json"
}
if ($record.status -ne 'passed') { throw $record.error }
Write-Output "VERIFIED $Feature/$Journey; evidence retained at $Evidence"
