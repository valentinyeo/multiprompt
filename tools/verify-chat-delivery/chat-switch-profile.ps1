function Invoke-ChatSwitchProfile([int]$TargetProcessId, [scriptblock]$Switch, [string]$Directory, $Route) {
    if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Switch profiling runs only on GitHub Windows' }
    $recorder = (Get-Command wpr.exe -ErrorAction Stop).Source
    $target = Get-Process -Id $TargetProcessId -ErrorAction Stop
    New-Item -ItemType Directory -Force $Directory | Out-Null
    $trace = Join-Path $Directory 'cpu.etl'
    $image = Join-Path $Directory 'multiprompt.exe'
    Copy-Item -LiteralPath $target.Path -Destination $image
    $symbols = [IO.Path]::ChangeExtension($target.Path, '.pdb')
    if (Test-Path -LiteralPath $symbols) { Copy-Item -LiteralPath $symbols -Destination (Join-Path $Directory 'multiprompt.pdb') }
    if ((Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target.Path -Algorithm SHA256).Hash) { throw 'Profile executable identity mismatch' }
    if (Test-Path -LiteralPath $trace) { throw 'Profile trace must be a new owned artifact' }
    $observation = [ordered]@{ target_pid = $TargetProcessId; process_started_utc = $target.StartTime.ToUniversalTime().ToString('o'); separate_from_acceptance = $true; route = $Route; recorder = 'Windows WPR CPU'; trace_scope = 'system-wide kernel samples; analyze only target_pid and the recorded switch interval'; analyzed = $false; status = 'not-started' }
    $started = $false
    $status = & $recorder -status 2>&1 | Out-String
    $status | Out-File -Encoding UTF8 (Join-Path $Directory 'recorder-before.log')
    if ($status -notmatch '(?i)not (currently )?recording|recording is not in progress|no (active )?recording') { throw 'Cannot prove WPR is idle; existing recordings stay untouched' }
    try {
        & $recorder -start CPU -filemode 2>&1 | Out-File -Encoding UTF8 (Join-Path $Directory 'recorder-start.log')
        if ($LASTEXITCODE -ne 0) { throw 'WPR did not start; no existing recording will be stopped or cancelled' }
        $started = $true
        $observation.status = 'recording'
        $observation.switch_started_utc = [DateTime]::UtcNow.ToString('o')
        $observation.switch = & $Switch
        $observation.switch_finished_utc = [DateTime]::UtcNow.ToString('o')
    } catch {
        $observation.error = $_.Exception.Message
        throw
    } finally {
        try {
            if ($started) {
                & $recorder -stop $trace 'IGSH-1040 separate generated-chat switch' 2>&1 | Out-File -Encoding UTF8 (Join-Path $Directory 'recorder-stop.log')
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $trace)) { throw 'Owned WPR recording did not produce its trace' }
                $observation.status = 'recorded-unanalysed'
                $observation.trace = 'cpu.etl'
                $observation.trace_sha256 = (Get-FileHash -LiteralPath $trace -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        } finally {
            [IO.File]::WriteAllText((Join-Path $Directory 'profile-request.json'), ($observation | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
        }
    }
}
