$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$launcher = (Resolve-Path "$root/fixture-bin/ssh.exe").Path
Add-Type -Path "$root/tools/verify-chat-delivery/job.cs"
$state = Join-Path $env:RUNNER_TEMP ('launcher-lifetime-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $state | Out-Null
$env:MP_LIFETIME_STATE = $state
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/launcher-lifetime-boundary.py").Path
$job = $null
try {
    $job = [VerifyJob]::new()
    $launcherProcess = $job.Start($launcher, $state, "$state/out.log", "$state/err.log", 'tree')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (-not ((Test-Path "$state/child") -and (Test-Path "$state/grandchild"))) {
        if ($launcherProcess.HasExited) { throw "Launcher exited early: $($launcherProcess.ExitCode)" }
        if ($timer.Elapsed.TotalSeconds -ge 20) { throw 'Python tree did not start' }
        Start-Sleep -Milliseconds 100
    }
    $child = Get-Process -Id ([int](Get-Content "$state/child" -Raw))
    $grandchild = Get-Process -Id ([int](Get-Content "$state/grandchild" -Raw))
    $null = $child.Handle; $null = $grandchild.Handle
    if (-not $job.Contains($child) -or -not $job.Contains($grandchild)) { throw 'Python tree escaped the outer job' }
    $childInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($child.Id)"
    $grandchildInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($grandchild.Id)"
    if ($childInfo.ParentProcessId -ne $launcherProcess.Id -or $grandchildInfo.ParentProcessId -ne $child.Id) { throw 'Unexpected Python tree' }
    $launcherProcess.Kill()
    if (-not $launcherProcess.WaitForExit(10000)) { throw 'Launcher did not exit' }
    $childStopped = $child.WaitForExit(10000)
    $grandchildStopped = $grandchild.WaitForExit(10000)
    if (-not $childStopped -or -not $grandchildStopped) { throw 'Python descendants survived launcher termination' }
    $job.Dispose(); $job = $null
    $job = [VerifyJob]::new()
    $launcherProcess = $job.Start($launcher, $state, "$state/exit-out.log", "$state/exit-err.log", 'exit')
    if (-not $launcherProcess.WaitForExit(10000)) { throw 'Normal launcher exit timed out' }
    if ($launcherProcess.ExitCode -ne 37) { throw "Exit code was $($launcherProcess.ExitCode), expected 37" }
    Write-Host 'Launcher termination stopped both Python descendants; normal exit preserved code 37.'
} finally {
    if ($null -ne $job) { $job.Dispose() }
    Remove-Item -Recurse -Force $state -ErrorAction SilentlyContinue
}
