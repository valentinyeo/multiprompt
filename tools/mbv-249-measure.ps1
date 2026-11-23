param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence, [Parameter(Mandatory)][string]$Revision, [int]$Rounds = 450, [int]$WindowSeconds = 200, [int]$WarmupSeconds = 45)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Measurement runs only on GitHub Windows' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
Add-Type -Path "$PSScriptRoot/mbv-249-probe.cs"
$work = Join-Path $env:RUNNER_TEMP ('mbv249-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = "$work/roaming"
$env:LOCALAPPDATA = "$work/local"
$env:USERPROFILE = "$work/home"
$env:HOME = "$work/home"
$env:MP_VERIFY_STATE = "$work/state"
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/verify-chat-delivery/boundary.py").Path
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:PYTHONUTF8 = '1'
$settings = "$work/roaming/ZigShell"
$log = "$settings/debug.log"
$job = $null
$app = $null
$appender = $null
$result = [ordered]@{ revision = $Revision; rounds = $Rounds; windowSeconds = $WindowSeconds; warmupSeconds = $WarmupSeconds; blocks = @{}; error = $null }
function Read-Log {
    if (-not (Test-Path $log)) { return '' }
    $stream = [IO.File]::Open($log, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120, [int]$PollMs = 100) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $app -and $app.HasExited) { throw "App exited during $Name" }
        $value = & $Check
        if ($value) { return $value }
        Start-Sleep -Milliseconds $PollMs
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Session {
    Wait-For 'readable session snapshot' {
        try {
            $snapshot = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            if ($null -ne $snapshot -and $null -ne $snapshot.PSObject.Properties['tabs'] -and $null -ne $snapshot.PSObject.Properties['active_tab']) { return $snapshot }
        } catch { return $false }
    }
}
function Focus-App {
    Wait-For 'owned window foreground' {
        $composer = [ChatDeliveryDesktop]::Composer($main)
        $composer -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    } | Out-Null
}
try {
    & python "$PSScriptRoot/mbv-249-fixture.py" $work "$(Split-Path $Exe)/ssh.exe" $Rounds
    if ($LASTEXITCODE -ne 0) { throw 'Fixture failed' }
    $result.sha256 = (Get-FileHash $Exe -Algorithm SHA256).Hash
    $result.cpuCores = [Environment]::ProcessorCount
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $work, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'session snapshot written' { Test-Path "$settings/session.json" })
    [void](Wait-For 'ten restored Chat View sessions' {
        $s = Session
        (Read-Log) -match 'launch step=browser' -and @($s.tabs).Count -eq 10 -and @($s.tabs | Where-Object { -not $_.cv }).Count -eq 0
    })
    for ($i = 0; $i -lt 10; $i++) {
        Focus-App
        $offset = (Read-Log).Length
        $previous = (Session).active_tab
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
        $target = ($previous + 1) % 10
        [void](Wait-For 'different target selected' { (Session).active_tab -eq $target })
        $targetShellId = (Session).tabs[$target].shell_id
        $shown = Wait-For 'target painted' {
            Focus-App
            $m = [regex]::Match((Read-Log).Substring($offset), ('\[switch\] chat content shown shell=' + $targetShellId + ' blocks=([1-9]\d*)'))
            if ($m.Success) { $m.Groups[1].Value }
        }
        $result.blocks["tab$target"] = [int]$shown
        Start-Sleep -Milliseconds 500
    }
    $result.finalTab = (Session).active_tab
    Focus-App
    $appender = Start-Process -FilePath python -ArgumentList @("$PSScriptRoot/mbv-249-append.py", $work) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds $WarmupSeconds
    $portMatch = [regex]::Match((Read-Log), 'tunnel-inbound listening port=(\d+)')
    $port = if ($portMatch.Success) { [int]$portMatch.Groups[1].Value } else { 0 }
    $result.bridgePort = $port
    Focus-App
    $startMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $logOffset = (Read-Log).Length
    $app.Refresh()
    $cpuBefore = $app.TotalProcessorTime.TotalMilliseconds
    [Mbv249Probe]::Start($main, $port, 'verify-agent-1')
    $window = [Diagnostics.Stopwatch]::StartNew()
    while ($window.Elapsed.TotalSeconds -lt $WindowSeconds) {
        if ($app.HasExited) { throw 'App exited during the measurement window' }
        Start-Sleep -Seconds 10
        try { Focus-App } catch { $result.error = "refocus: $($_.Exception.Message)" }
    }
    $endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [Mbv249Probe]::Stop()
    $app.Refresh()
    $result.appCpuMs = $app.TotalProcessorTime.TotalMilliseconds - $cpuBefore
    $result.windowMs = $endMs - $startMs
    New-Item -ItemType File -Force "$work/state/append.stop" | Out-Null
    $pings = @([Mbv249Probe]::Pings.ToArray())
    $elapsed = @($pings | ForEach-Object { $_[1] })
    $result.pingSamples = $elapsed.Count
    $result.stallsOver200 = @($elapsed | Where-Object { $_ -gt 200 }).Count
    $result.stallsOver1000 = @($elapsed | Where-Object { $_ -gt 1000 }).Count
    $result.stallPeakMs = if ($elapsed.Count) { ($elapsed | Measure-Object -Maximum).Maximum } else { $null }
    $result.stallTimeouts = @($pings | Where-Object { $_[2] -eq 1 }).Count
    $result.stallsMs = @($elapsed | Where-Object { $_ -gt 200 } | Sort-Object -Descending | Select-Object -First 30)
    $slice = (Read-Log).Substring($logOffset)
    $reconcile = @([regex]::Matches($slice, 'PERF\[chat\]: reconcile ms=(\d+) size=(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
    $result.reconcileLoggedLines = $reconcile.Count
    $result.reconcileOver200 = @($reconcile | Where-Object { $_ -gt 200 }).Count
    $result.reconcileMaxMs = if ($reconcile.Count) { ($reconcile | Measure-Object -Maximum).Maximum } else { $null }
    $parse = @([regex]::Matches($slice, 'PERF\[chat\]: parse ms=(\d+) size=(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
    $result.parseLoggedLines = $parse.Count
    $result.keptSyncedNotices = [regex]::Matches($slice, 'kept synced tabs missing locally').Count
    $rows = @()
    if (Test-Path "$work/state/invocations.jsonl") {
        foreach ($line in [IO.File]::ReadAllLines("$work/state/invocations.jsonl")) {
            try { $rows += ($line | ConvertFrom-Json) } catch { }
        }
    }
    $inWindow = @($rows | Where-Object { $_.ms -ge $startMs -and $_.ms -le $endMs })
    $requests = @($inWindow | Where-Object { $_.kind -eq 'channel-request' -and $_.data -match '"settlement":true' })
    $background = @($requests | Where-Object { $_.data -notmatch 'a1b2c3d4-1068-4000-8000-000000000000' })
    $foreground = @($requests | Where-Object { $_.data -match 'a1b2c3d4-1068-4000-8000-000000000000' })
    $result.historyQueriesBackground = $background.Count
    $result.historyQueriesActive = $foreground.Count
    $result.historyQueriesBackgroundPerHour = [math]::Round($background.Count * 3600000.0 / [math]::Max(1, ($endMs - $startMs)), 0)
    $result.channelRequestsAll = @($inWindow | Where-Object { $_.kind -eq 'channel-request' }).Count
    $result.readerInvocations = @($inWindow | Where-Object { $_.kind -eq 'reader' }).Count
    $bridge = @([Mbv249Probe]::Bridge.ToArray())
    $result.bridge = @($bridge | ForEach-Object { [ordered]@{ verb = $_[0]; atMs = [double]$_[1]; ms = [double]$_[2]; reply = $_[3] } })
    $statusMs = @($bridge | Where-Object { $_[0] -eq 'status' } | ForEach-Object { [double]$_[2] })
    $result.statusCalls = $statusMs.Count
    $result.statusMaxMs = if ($statusMs.Count) { ($statusMs | Measure-Object -Maximum).Maximum } else { $null }
    $result.statusOver5000 = @($statusMs | Where-Object { $_ -gt 5000 }).Count
    $result.statusReplied = @($bridge | Where-Object { $_[0] -eq 'status' -and $_[3] -like '*"ok":true*' }).Count
    $whoMs = @($bridge | Where-Object { $_[0] -eq 'who' } | ForEach-Object { [double]$_[2] })
    $result.whoCalls = $whoMs.Count
    $result.whoEmpty = @($bridge | Where-Object { $_[0] -eq 'who' -and [string]::IsNullOrEmpty($_[3]) }).Count
    $result.whoMaxMs = if ($whoMs.Count) { ($whoMs | Measure-Object -Maximum).Maximum } else { $null }
} catch {
    $result.error = $_.Exception.Message
    Write-Host "Measurement error: $($result.error)"
} finally {
    try { [Mbv249Probe]::Stop() } catch { }
    New-Item -ItemType File -Force "$work/state/append.stop" -ErrorAction SilentlyContinue | Out-Null
    if ($null -ne $appender -and -not $appender.HasExited) { [void]$appender.WaitForExit(10000); if (-not $appender.HasExited) { $appender.Kill() } }
    try {
        $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/screen.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
    } catch { }
    $result | ConvertTo-Json -Depth 6 | Set-Content "$Evidence/samples.json"
    if ($null -ne $job) { [void]$job.Stop(); $job.Dispose() }
    if (Test-Path $log) { Copy-Item $log "$Evidence/debug.log" }
    if (Test-Path "$work/state/invocations.jsonl") { Copy-Item "$work/state/invocations.jsonl" "$Evidence/invocations.jsonl" }
    if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$Evidence/session.json" }
}
exit 0
