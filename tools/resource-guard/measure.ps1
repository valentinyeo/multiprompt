param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence, [Parameter(Mandatory)][string]$FixtureBin)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/snapshot.ps1"
. "$PSScriptRoot/session.ps1"
. "$PSScriptRoot/stage.ps1"
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
    $result.staging = New-GuardStage $Exe $profile $root
    & $env:MP_VERIFY_PYTHON "$PSScriptRoot/fixture.py" $profile "$FixtureBin/ssh.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Fixture failed' }
    $job = [VerifyJob]::new()
    $app = $job.Start($result.staging.exe.stagedPath, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = [IntPtr]::Zero
    Wait-For 'owned main window' { $script:main = [ChatDeliveryDesktop]::Window($app.Id); $script:main -ne [IntPtr]::Zero }
    Wait-For "$sessionCount restored chat tabs" {
        $script:sessionIds = Get-GuardSessionIds (Session) $sessionCount
        $null -ne $script:sessionIds -and (Read-Log) -match 'launch step=browser'
    }
    $seen = @{}
    for ($i = 0; $i -lt $sessionCount; $i++) {
        Wait-For 'owned foreground composer' {
            $composer = [ChatDeliveryDesktop]::Composer($main)
            $composer -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
        }
        $offset = (Read-Log).Length
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
        Wait-For 'switched chat painted' {
            $text = Read-Log
            $script:paintedId = if ($text.Length -ge $offset) { Get-GuardPaintedId ($text.Substring($offset)) $sessionIds } else { $null }
            $null -ne $script:paintedId
        }
        if ($seen.ContainsKey($paintedId)) { throw "Chat $paintedId visited twice" }
        $seen[$paintedId] = $true
    }
    $result.readySessions = $seen.Count
    if ($seen.Count -ne $sessionCount) { throw 'Not all distinct chats loaded' }
    $result.loadedShellIds = @($seen.Keys)
    Start-Sleep -Seconds 15
    $before = $job.ReadAccounting(); $timer = [Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Seconds 10
    $after = $job.ReadAccounting(); $timer.Stop()
    $result.idleSnapshots = @()
    for ($sample = 1; $sample -le 4; $sample++) {
        $result.idleSnapshots += Get-StableJobSnapshot -Job $job -AppId $app.Id
    }
    if ($app.HasExited -or [ChatDeliveryDesktop]::Window($app.Id) -eq [IntPtr]::Zero) { throw 'App or main window exited' }
    $finalIds = Get-GuardSessionIds (Session) $sessionCount
    if ($null -eq $finalIds -or @($sessionIds.Keys | Where-Object { -not $finalIds.ContainsKey($_) }).Count -ne 0) { throw 'Chat tabs dropped or changed' }
    $result.idleCpuPercent = (($after.UserTime + $after.KernelTime - $before.UserTime - $before.KernelTime) / 10000.0) / $timer.Elapsed.TotalMilliseconds * 100 / [Environment]::ProcessorCount
    $result.idleWallMs = $timer.Elapsed.TotalMilliseconds
    $result.jobBefore = $before; $result.jobAfter = $after
    $snapshot = Get-StableJobSnapshot -Job $job -AppId $app.Id
    $raw = $snapshot.processes; $accounting = $snapshot.accounting
    $result.rawProcesses = $raw; $result.jobActiveProcesses = $accounting.ActiveProcesses
    $result.processes = $raw.Count
    $result.syntheticSshProcesses = @($raw | Where-Object { $_.name -ieq 'ssh' }).Count
    $cim = @(Get-CimInstance Win32_Process)
    $sshDetails = @($raw | Where-Object { $_.name -ieq 'ssh' })
    if (@($sshDetails | Where-Object { $_.ExecutablePath -ine "$FixtureBin\ssh.exe" }).Count -ne 0) { throw 'SSH process is not the synthetic fixture' }
    $result.syntheticSshReaders = @($sshDetails | Where-Object { $_.CommandLine -match '--serve|--watch' }).Count
    $result.sshCommandLines = @($sshDetails | ForEach-Object { @{ ProcessId=$_.id; ParentProcessId=$_.parentProcessId; ExecutablePath=$_.executablePath; CommandLine=$_.commandLine } })
    $result.jobConsoleProcesses = @($raw | Where-Object { $_.name -in @('conhost','OpenConsole') }).Count
    $result.workingSetBytes = [long](($raw | Measure-Object -Property workingSetBytes -Sum).Sum)
    $ids = @($raw | ForEach-Object { $_.id })
    $result.associatedExternalConsoles = @($cim | Where-Object { $_.Name -in @('conhost.exe','OpenConsole.exe') -and $_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids } | Select-Object ProcessId,ParentProcessId,Name)
    if (Test-Path "$profile/tools/usage-telemetry/config.local.json") { throw 'Unexpected local telemetry config' }
    foreach ($name in @('config', 'helper')) {
        if ((Get-FileHash -LiteralPath $result.staging[$name].stagedPath -Algorithm SHA256).Hash -ne $result.staging[$name].inputSha256) { throw "Telemetry $name changed during measurement" }
    }
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
