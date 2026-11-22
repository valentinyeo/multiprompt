param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$BeforeRoot,
    [Parameter(Mandatory)][string]$Output,
    [ValidateRange(1,20)][int]$Runs = 20
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
$BeforeRoot = (Resolve-Path $BeforeRoot).Path
$afterRoot = (Resolve-Path "$PSScriptRoot/..").Path
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
$rows = [Collections.Generic.List[object]]::new()
$processor = Get-CimInstance Win32_Processor
$provenance = @{
    release=$ExpectedVersion; sha256=$ExpectedHash; before=(git -C $BeforeRoot rev-parse HEAD).Trim(); after=(git -C $afterRoot rev-parse HEAD).Trim()
    machine=$env:COMPUTERNAME; cpu=@($processor | ForEach-Object { $_.Name }); cores=[Environment]::ProcessorCount
    run_url="https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"; requested_runs=$Runs
    metric='inputGapMs is injected key spacing; verifiedClosedMs includes input and verification overhead; neither proves an application speedup'
}
function Save($Value, [string]$Name) { [IO.File]::WriteAllText("$Output/$Name", ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
Save $provenance 'provenance.json'
for ($i = 0; $i -lt $Runs; $i++) {
    $phases = if ($i % 2 -eq 0) { @('before', 'after') } else { @('after', 'before') }
    foreach ($phase in $phases) {
        $root = if ($phase -eq 'before') { $BeforeRoot } else { $afterRoot }
        $directory = "$Output/$phase-$i"
        New-Item -ItemType Directory -Force $directory | Out-Null
        $load = @(Get-CimInstance Win32_Processor | ForEach-Object { $_.LoadPercentage })
        $started = [DateTime]::UtcNow.ToString('o')
        $arguments = @('-NoProfile', '-File', ('"' + $root + '/.claude/skills/verify-multiprompt/control.ps1"'), '-Feature', 'browser-pane-stuck', '-Exe', ('"' + $Exe + '"'), '-ExpectedVersion', $ExpectedVersion, '-ExpectedHash', $ExpectedHash, '-Evidence', ('"' + $directory + '"'))
        $child = Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList $arguments -WorkingDirectory $root -RedirectStandardOutput "$directory/stdout.log" -RedirectStandardError "$directory/stderr.log" -Wait -PassThru
        $exit = $child.ExitCode
        $child.Dispose()
        $result = if (Test-Path "$directory/result.json") { Get-Content "$directory/result.json" -Raw | ConvertFrom-Json } else { $null }
        $pairs = if (Test-Path "$directory/immediate-toggle.json") { @(Get-Content "$directory/immediate-toggle.json" -Raw | ConvertFrom-Json) } else { @() }
        $tree = if (Test-Path "$directory/process-tree.json") { Get-Content "$directory/process-tree.json" -Raw | ConvertFrom-Json } else { $null }
        $samples = @($pairs | ForEach-Object {
            $gap = if ($phase -eq 'before') { $_.gapMs } else { $_.inputGapMs }
            $verified = if ($phase -eq 'after') { $_.verifiedClosedMs } else { $null }
            @{page=$_.page; pair=$_.pair; inputGapMs=$gap; verifiedClosedMs=$verified; closed=$_.closed; states=@($_.states)}
        })
        $errorText = if ($null -ne $result -and $result.PSObject.Properties['error']) { $result.error } else { $null }
        $passed = $exit -eq 0 -and $null -ne $result -and $result.status -eq 'passed' -and $null -ne $tree -and $tree.activeAfterStop -eq 0
        $rows.Add(@{phase=$phase; iteration=$i; started=$started; machine=$env:COMPUTERNAME; hostLoadPercent=$load; exit=$exit; passed=$passed; error=$errorText; samples=$samples})
        Save @($rows.ToArray()) 'runs.json'
        $state = "$directory/data/roaming/ZigShell"
        if (Test-Path $state) {
            New-Item -ItemType Directory -Force "$directory/app-state" | Out-Null
            Get-ChildItem $state -File | Where-Object { $_.Extension -in @('.json', '.log', '.txt') } | Copy-Item -Destination "$directory/app-state"
        }
        if (Test-Path "$directory/data") { Remove-Item "$directory/data" -Recurse -Force }
        if ($i -ne 0 -and $i -ne $Runs - 1) { Get-ChildItem $directory -Filter '*.mp4' -Recurse | Remove-Item -Force }
        if ($null -eq $tree -or $tree.activeAfterStop -ne 0) { throw 'Native journey did not prove process cleanup' }
        if (Test-Path "$directory/toggle-helper-process-tree.json") {
            $helpers = @(Get-Content "$directory/toggle-helper-process-tree.json" -Raw | ConvertFrom-Json)
            if (@($helpers | Where-Object { $_.activeAfterStop -ne 0 }).Count -ne 0) { throw 'Native journey left an owned helper process' }
        }
    }
}
$after = @($rows | Where-Object { $_.phase -eq 'after' })
foreach ($run in $after) {
    if (-not $run.passed -or $run.samples.Count -ne 40) { throw 'Normal-spacing journey did not complete all physical-input cases' }
    foreach ($page in @('blank', 'slow')) {
        $samples = @($run.samples | Where-Object { $_.page -eq $page })
        if ($samples.Count -ne 20 -or @($samples.pair | Sort-Object -Unique).Count -ne 20) { throw 'Missing or duplicate native pair samples' }
    }
    foreach ($sample in $run.samples) {
        if (-not $sample.closed -or $sample.states.Count -ne 2 -or $sample.states[0] -notmatch 'enabled= 1$' -or $sample.states[1] -notmatch 'enabled= 0$') { throw 'Physical input did not open then close' }
        if ($sample.inputGapMs -lt 0 -or $sample.inputGapMs -ge 200) { throw 'Normal key spacing missed the requested 200ms target' }
        if ($sample.verifiedClosedMs -lt $sample.inputGapMs) { throw 'Verification time excludes the physical input' }
    }
}
$before = @($rows | Where-Object { $_.phase -eq 'before' })
Save @{passed=$true; before_runs=$before.Count; after_runs=$after.Count; before_errors=@($before | Where-Object { -not $_.passed }).Count; after_errors=@($after | Where-Object { -not $_.passed }).Count; app_speedup_claimed=$false} 'summary.json'
Write-Output 'NATIVE_NORMAL_SPACING_PROVEN'
