$releaseGatePolicy = Get-Content (Join-Path $PSScriptRoot 'release-gates.json') -Raw | ConvertFrom-Json

function Assert-ReleaseTiming([string]$Name, [double]$Value, [string]$Context) {
    $property = $releaseGatePolicy.checks.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Unclassified timing check: $Name" }
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value) -or $Value -lt 0) { throw "Invalid timing sample: $Name = $Value" }
    $gate = $property.Value
    if ($gate.kind -notin @('stability', 'speed')) { throw "Invalid release gate kind: $Name" }
    $missed = $Value -gt $gate.limit
    $status = if (-not $missed) { 'passed' } elseif ($gate.kind -eq 'speed') { 'warning' } else { 'failed' }
    $large = $gate.kind -eq 'speed' -and $Value -gt $gate.largeRegression
    $sample = [ordered]@{ name = $Name; kind = $gate.kind; value = $Value; limit = $gate.limit; unit = 'ms'; status = $status; largeRegression = $large; context = $Context; revision = $(if ($env:VERIFY_REVISION) { $env:VERIFY_REVISION } else { $env:GITHUB_SHA }); run = $env:GITHUB_RUN_ID; time = [DateTime]::UtcNow.ToString('o') }
    New-Item -ItemType Directory -Force $Evidence | Out-Null
    $sample | ConvertTo-Json -Compress | Add-Content -Encoding UTF8 (Join-Path $Evidence 'speed-trend.jsonl')
    $line = "$Name : $Value ms (target $($gate.limit) ms), $status; $Context"
    if ($env:GITHUB_STEP_SUMMARY) { "- $line" | Add-Content -Encoding UTF8 $env:GITHUB_STEP_SUMMARY }
    if ($status -eq 'warning') { Write-Warning $line }
    if ($status -eq 'failed') { throw $line }
    if ($gate.kind -eq 'speed' -and $Value -gt $releaseGatePolicy.checks.'ui-hang'.limit) { Assert-ReleaseTiming 'ui-hang' $Value "$Name; $Context" }
}
