param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence, [Parameter(Mandatory)][string]$FixtureBin)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$limits = Get-Content "$PSScriptRoot/limits.json" -Raw | ConvertFrom-Json
$sessionCount = [int]$limits.sessionCount
$Exe = (Resolve-Path $Exe).Path
$FixtureBin = (Resolve-Path $FixtureBin).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -Path "$root/tools/verify-chat-delivery/desktop.cs"
Add-Type -Path "$root/tools/verify-chat-delivery/job.cs"
$profile = Join-Path $env:RUNNER_TEMP ('resource-guard-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"
$env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
$env:MP_VERIFY_STATE = "$profile/state"
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$root/tools/verify-chat-delivery/boundary.py").Path
$env:PATH = "$FixtureBin;$env:PATH"
$env:MULTIPROMPT_NO_LOGIN = '1'; $env:ZIGSHELL_DEBUG = '1'; $env:IGSH_246 = '0'; $env:PYTHONUTF8 = '1'
$settings = "$profile/roaming/ZigShell"; $log = "$settings/debug.log"
$job = $null; $app = $null; $result = @{ workload=$limits.workload; sessionCount=$sessionCount; readySessions=0; cleaned=$false; appAlive=$false; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash }
function Read-Log {
    if (-not (Test-Path $log)) { return '' }
    $s = [IO.File]::Open($log, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $r = [IO.StreamReader]::new($s)
    try { $r.ReadToEnd() } finally { $r.Dispose() }
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $app -and $app.HasExited) { throw "App exited during $Name" }
        if (& $Check) { return }
        Start-Sleep -Milliseconds 100
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Session {
    try { return (Get-Content "$settings/session.json" -Raw | ConvertFrom-Json) } catch { return $null }
}
try {
    & $env:MP_VERIFY_PYTHON "$PSScriptRoot/fixture.py" $profile "$FixtureBin/ssh.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Fixture failed' }
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = [IntPtr]::Zero
    Wait-For 'owned main window' { $script:main = [ChatDeliveryDesktop]::Window($app.Id); $script:main -ne [IntPtr]::Zero }
    Wait-For "$sessionCount restored chat tabs" {
        $s = Session
        $null -ne $s -and (Read-Log) -match 'launch step=browser' -and @($s.tabs).Count -eq $sessionCount -and @($s.tabs | Where-Object { -not $_.cv }).Count -eq 0
    }
    $seen = @{}
    for ($i = 0; $i -lt $sessionCount; $i++) {
        Wait-For 'owned foreground composer' {
            $composer = [ChatDeliveryDesktop]::Composer($main)
            $composer -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
        }
        $previous = (Session).active_tab
        $offset = (Read-Log).Length
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
        $target = ($previous + 1) % $sessionCount
        Wait-For 'tab selected' { (Session).active_tab -eq $target }
        $id = (Session).tabs[$target].shell_id
        Wait-For "chat $id loaded" { (Read-Log).Substring($offset) -match ('\[switch\] chat content shown shell=' + $id + ' blocks=[1-9]') }
        $seen["$id"] = $true
    }
    $result.readySessions = $seen.Count
    if ($seen.Count -ne $sessionCount) { throw 'Not all distinct chats loaded' }
    $result.loadedShellIds = @($seen.Keys)
    Start-Sleep -Seconds 15
    $before = $job.ReadAccounting(); $timer = [Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Seconds 10
    $after = $job.ReadAccounting(); $timer.Stop()
    if ($app.HasExited -or [ChatDeliveryDesktop]::Window($app.Id) -eq [IntPtr]::Zero) { throw 'App or main window exited' }
    $s = Session
    if ($null -eq $s -or @($s.tabs).Count -ne $sessionCount -or @($s.tabs | Where-Object { -not $_.cv }).Count -ne 0) { throw 'Chat tabs dropped' }
    $result.idleCpuPercent = (($after.UserTime + $after.KernelTime - $before.UserTime - $before.KernelTime) / 10000.0) / $timer.Elapsed.TotalMilliseconds * 100 / [Environment]::ProcessorCount
    $result.idleWallMs = $timer.Elapsed.TotalMilliseconds
    $result.jobBefore = $before; $result.jobAfter = $after
    $raw = @()
    foreach ($p in [Diagnostics.Process]::GetProcesses()) {
        try {
            if ($job.Contains($p)) { $raw += @{ id=$p.Id; name=$p.ProcessName; workingSetBytes=$p.WorkingSet64 } }
        } catch {
        } finally { $p.Dispose() }
    }
    $accounting = $job.ReadAccounting()
    if (@($raw | Where-Object { $_.id -eq $app.Id }).Count -ne 1) { throw 'App absent from job snapshot' }
    if ($raw.Count -ne $accounting.ActiveProcesses) { throw "Incomplete process snapshot: $($raw.Count) vs $($accounting.ActiveProcesses)" }
    $result.rawProcesses = $raw; $result.jobActiveProcesses = $accounting.ActiveProcesses
    $result.processes = $raw.Count
    $result.syntheticSshProcesses = @($raw | Where-Object { $_.name -ieq 'ssh' }).Count
    $cim = @(Get-CimInstance Win32_Process)
    $sshIds = @($raw | Where-Object { $_.name -ieq 'ssh' } | ForEach-Object { $_.id })
    $sshDetails = @($cim | Where-Object { $_.ProcessId -in $sshIds })
    if ($sshDetails.Count -ne $sshIds.Count -or @($sshDetails | Where-Object { -not $_.CommandLine }).Count -ne 0) { throw 'Missing synthetic SSH command lines' }
    if (@($sshDetails | Where-Object { $_.ExecutablePath -ine "$FixtureBin\ssh.exe" }).Count -ne 0) { throw 'SSH process is not the synthetic fixture' }
    $result.syntheticSshReaders = @($sshDetails | Where-Object { $_.CommandLine -match '--serve|--watch' }).Count
    $result.sshCommandLines = @($sshDetails | Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine)
    $result.jobConsoleProcesses = @($raw | Where-Object { $_.name -in @('conhost','OpenConsole') }).Count
    $result.workingSetBytes = [long](($raw | Measure-Object -Property workingSetBytes -Sum).Sum)
    $ids = @($raw | ForEach-Object { $_.id })
    $result.associatedExternalConsoles = @($cim | Where-Object { $_.Name -in @('conhost.exe','OpenConsole.exe') -and $_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids } | Select-Object ProcessId,ParentProcessId,Name)
    $result.appAlive = $true
} finally {
    if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$Evidence/session.json" }
    if (Test-Path $log) { Copy-Item $log "$Evidence/debug.log" }
    if ($null -ne $job) {
        try { $stopped = $job.Stop(); $result.cleaned = $stopped.ActiveProcesses -eq 0 } finally { $job.Dispose() }
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content "$Evidence/measurement.json" -Encoding UTF8
    if (Test-Path $profile) { Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue }
}
