$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$work = Join-Path $env:RUNNER_TEMP 'account-photo-fixture'
$statePath = Join-Path $work 'processes.json'
New-Item -ItemType Directory -Force 'cleanup-evidence' | Out-Null
$receipt = [ordered]@{ status = 'failed'; owned_survivors = $null; verified_roots = 0; directory_removed = $false }
$failure = $null
try {
    if (!(Test-Path $statePath)) {
        if (Test-Path (Join-Path $work 'service.out')) { throw 'Fixture process ownership was not recorded' }
        $receipt.status = 'not_started'
        $receipt.owned_survivors = 0
    } else {
        $roots = @(Get-Content $statePath -Raw | ConvertFrom-Json)
        if ($roots.Count -lt 1 -or $roots.Count -gt 2) { throw 'Invalid fixture process state' }
        $known = [Collections.Generic.List[object]]::new()
        $verified = [Collections.Generic.List[object]]::new()
        try { $all = @(Get-CimInstance Win32_Process) } catch { $all = @(); $failure = 'Could not inspect fixture descendants' }
        foreach ($root in $roots) {
            try {
                $process = Get-Process -Id ([int]$root.pid) -ErrorAction SilentlyContinue
                if (!$process) { $failure = 'An owned root exited before cleanup'; continue }
                if ($process.StartTime.ToUniversalTime().Ticks -ne [long]$root.started -or $process.Path -ine [string]$root.path) { $failure = 'Fixture root identity mismatch'; continue }
                $verified.Add($root)
                $receipt.verified_roots++
                $queue = [Collections.Generic.Queue[int]]::new()
                $queue.Enqueue([int]$root.pid)
                while ($queue.Count -gt 0) {
                    $processId = $queue.Dequeue()
                    $item = Get-Process -Id $processId -ErrorAction SilentlyContinue
                    if ($item) {
                        try { $known.Add([ordered]@{ pid = $item.Id; started = $item.StartTime.ToUniversalTime().Ticks; path = $item.Path }) }
                        catch { $failure = 'Could not verify a fixture descendant' }
                    }
                    foreach ($child in @($all | Where-Object { $_.ParentProcessId -eq $processId })) { $queue.Enqueue([int]$child.ProcessId) }
                }
            } catch { $failure = 'Could not verify a fixture root' }
        }
        foreach ($root in $verified) {
            $process = Get-Process -Id ([int]$root.pid) -ErrorAction SilentlyContinue
            if ($process -and $process.StartTime.ToUniversalTime().Ticks -eq [long]$root.started -and $process.Path -ieq [string]$root.path) {
                & taskkill.exe /PID ([string]$root.pid) /T /F | Out-Null
            } else { $failure = 'Fixture root changed before termination' }
        }
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            $survivors = @($known | Where-Object {
                $item = Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue
                $item -and $item.StartTime.ToUniversalTime().Ticks -eq [long]$_.started -and $item.Path -ieq [string]$_.path
            })
            if ($survivors.Count -eq 0) { break }
            Start-Sleep -Milliseconds 250
        } while ($timer.Elapsed.TotalSeconds -lt 15)
        $receipt.owned_survivors = $survivors.Count
        if ($survivors.Count -ne 0) { $failure = 'Owned fixture processes survived cleanup' }
        if (!$failure -and $roots.Count -eq 2 -and $receipt.verified_roots -eq 2) { $receipt.status = 'passed' }
        elseif (!$failure) { $failure = 'Fixture startup did not finish' }
    }
} catch { $failure = $_.Exception.Message }
finally {
    try { if (Test-Path $work) { Remove-Item -Recurse -Force $work -ErrorAction Stop } }
    catch { $failure = 'Could not remove fixture directory' }
    $receipt.directory_removed = !(Test-Path $work)
    if (!$receipt.directory_removed) { $failure = 'Fixture directory remains' }
    if ($failure) { $receipt.status = 'failed' }
    [IO.File]::WriteAllText((Join-Path $PWD 'cleanup-evidence/fixture-cleanup.json'), ($receipt | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
}
if ($failure) { throw $failure }
