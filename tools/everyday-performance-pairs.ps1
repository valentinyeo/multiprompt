param([Parameter(Mandatory)][string]$BaseExe, [Parameter(Mandatory)][string]$HeadExe, [Parameter(Mandatory)][string]$BaseRevision, [Parameter(Mandatory)][string]$HeadRevision, [Parameter(Mandatory)][string]$Evidence, [int]$Count = 100, [int]$Trials = 5)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Measurement requires GitHub-hosted Windows' }
if ($Trials -lt 5) { throw 'At least five alternating trials per side are required' }
$executables = @{ base=(Resolve-Path $BaseExe).Path; head=(Resolve-Path $HeadExe).Path }
$revisions = @{ base=$BaseRevision; head=$HeadRevision }
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$order = [Collections.Generic.List[object]]::new()
for ($trial = 1; $trial -le $Trials; $trial++) {
    foreach ($side in @('base', 'head')) {
        $directory = "$Evidence/pairs/$trial-$side"
        $started = [DateTime]::UtcNow.ToString('o')
        & "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/everyday-performance.ps1" -Exe $executables[$side] -Evidence $directory -Revision $revisions[$side] -Count $Count -Trials 1
        if ($LASTEXITCODE -ne 0) { throw "Trial $trial $side failed; keep all evidence and reject the comparison" }
        $sideDirectory = "$Evidence/$side"
        New-Item -ItemType Directory -Force $sideDirectory | Out-Null
        Move-Item "$directory/trial-1" "$sideDirectory/trial-$trial"
        $machine = Get-Content "$directory/machine.json" -Raw | ConvertFrom-Json
        $machine.trials = $Trials
        $machine | ConvertTo-Json -Depth 8 | Set-Content "$sideDirectory/machine.json"
        Copy-Item "$(Split-Path $executables[$side])/measurement-build.json" "$sideDirectory/build.json" -Force
        $order.Add(@{ trial=$trial; side=$side; revision=$revisions[$side]; sha256=$machine.exeSha256; startedUtc=$started; finishedUtc=[DateTime]::UtcNow.ToString('o') })
        $order.ToArray() | ConvertTo-Json -Depth 4 | Set-Content "$Evidence/order.json"
    }
}
& python "$PSScriptRoot/everyday-performance-report.py" "$Evidence/base"
if ($LASTEXITCODE -ne 0) { throw 'Base evidence validation failed' }
& python "$PSScriptRoot/everyday-performance-report.py" "$Evidence/head"
if ($LASTEXITCODE -ne 0) { throw 'Head evidence validation failed' }
