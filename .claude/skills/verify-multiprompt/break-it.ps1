param(
    [Parameter(Mandatory)][string]$Feature,
    [Parameter(Mandatory)][string]$Journey,
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
    [switch]$ExpectRegression
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Break-it requires the existing GitHub Windows job' }
$baseline = Get-Content "$Evidence/result.json" -Raw | ConvertFrom-Json
if ($baseline.status -ne 'passed') { throw 'Break-it requires the ordinary head repro to pass first' }
if ($ExpectRegression -and $env:VERIFY_APP_REVISION -ne '5ce536b45569e8cb4394e8e967067f19bf3d49d0') { throw 'Historical proof requires the pinned past fix' }
$root = Join-Path $Evidence 'break-it'
New-Item -ItemType Directory -Path $root | Out-Null
$names = @(& node -e "console.log(require('./tools/pr-verifier.cjs').breakItVariations(process.argv[1]).join('\n'))" $Feature)
if ($LASTEXITCODE -ne 0) { throw 'Break-it plan unavailable' }
$report = @{ feature=$Feature; status='passed'; variations=@() }
foreach ($name in $names) {
    $folder = Join-Path $root $name
    New-Item -ItemType Directory -Path $folder | Out-Null
    $item = @{name=$name; status='blocked'; error=''; actions=0; cleanup='pending'; failureKind='infrastructure'}
    $video = $null
    try {
        $start = [Diagnostics.ProcessStartInfo]::new('ffmpeg', "-y -f gdigrab -framerate 8 -i desktop -an -c:v libx264 -preset ultrafast -pix_fmt yuv420p `"$folder/journey.mp4`"")
        $start.UseShellExecute = $false
        $start.RedirectStandardInput = $true
        $start.CreateNoWindow = $true
        $video = [Diagnostics.Process]::Start($start)
        $env:MP_BREAK_IT_VARIATION = $name
        & powershell -NoProfile -File "$PSScriptRoot/control.ps1" -Feature $Journey -Exe $Exe -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $folder
        $exit = $LASTEXITCODE
        $outcome = Get-Content "$folder/result.json" -Raw | ConvertFrom-Json
        if (Test-Path "$folder/break-it-input.json") {
            $receipt = Get-Content "$folder/break-it-input.json" -Raw | ConvertFrom-Json
            $item.actions = @($receipt.inputs).Count
        }
        $clean = $false
        if (Test-Path "$folder/cleanup.json") {
            $cleanup = Get-Content "$folder/cleanup.json" -Raw | ConvertFrom-Json
            $clean = $cleanup.remaining_owned_processes -eq 0 -and $cleanup.scratch_removed
        } elseif (Test-Path "$folder/process-tree.json") {
            $tree = Get-Content "$folder/process-tree.json" -Raw | ConvertFrom-Json
            $clean = $outcome.scratchRemoved -and $tree.activeAfterStop -eq 0
        }
        if ($clean) { $item.cleanup = 'complete' }
        if (-not $clean -or $item.actions -eq 0) { throw 'Break-it infrastructure: input or cleanup receipt missing' }
        $item.status = $outcome.status
        $item.failureKind = if ($outcome.PSObject.Properties['failureKind']) { $outcome.failureKind } else { '' }
        $item.error = if ($outcome.PSObject.Properties['error']) { $outcome.error } elseif ($outcome.PSObject.Properties['cases']) { (@($outcome.cases | Where-Object { -not $_.passed } | ForEach-Object { $_.detail }) -join '; ') } else { '' }
        if ($item.error -match 'Break-it infrastructure:') { $item.failureKind = 'infrastructure' }
        if ($exit -ne 0 -and $item.status -eq 'passed') { throw 'Break-it infrastructure: driver exit disagrees with result' }
    } catch {
        $item.status = 'blocked'
        $item.failureKind = 'infrastructure'
        $item.error = $_.Exception.Message
    } finally {
        Remove-Item Env:MP_BREAK_IT_VARIATION -ErrorAction SilentlyContinue
        try {
            if ($null -eq $video) { throw 'Recorder did not start' }
            if (-not $video.HasExited) { $video.StandardInput.WriteLine('q'); $video.StandardInput.Close() }
            if (-not $video.WaitForExit(15000)) { $video.Kill(); $video.WaitForExit(); throw 'Recorder did not stop' }
            if ($video.ExitCode -ne 0) { throw 'Recorder failed' }
            $probe = & ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of json "$folder/journey.mp4"
            if ($LASTEXITCODE -ne 0 -or @((($probe -join "`n") | ConvertFrom-Json).streams).Count -ne 1) { throw 'Video is unreadable' }
            $probe | Set-Content -Encoding UTF8 "$folder/video.json"
        } catch { $item.status='blocked'; $item.failureKind='infrastructure'; $item.error=$_.Exception.Message }
        finally { if ($null -ne $video) { $video.Dispose() } }
        $report.variations += $item
        if ($item.status -ne 'passed') { $report.status = 'failed' }
        $report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 "$root/result.json"
    }
}
if ($ExpectRegression) {
    $product = @($report.variations | Where-Object { $_.status -eq 'failed' -and $_.failureKind -ne 'infrastructure' -and $_.actions -gt 0 -and $_.cleanup -eq 'complete' -and $_.error -notmatch 'timed? ?out|timeout|Break-it infrastructure:' })
    if ($product.Count -eq 0) { throw 'Historical break-it proof found no product regression after a passing repro' }
    Write-Output 'HISTORICAL_BREAK_IT_REJECTED_WITH_VIDEO'
} elseif ($report.status -ne 'passed') { throw 'Break-it did not pass; retain every variation video and receipt' }
