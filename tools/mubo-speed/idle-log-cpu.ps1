param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [Parameter(Mandatory=$true)][string]$Tag,
    [ValidateSet('bare', 'chat', 'live')][string]$Scenario = 'bare',
    [string]$SshPath = '',
    [int]$IdleSeconds = 660,
    [int]$SettleSeconds = 40
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Idle measurement runs only on GitHub Windows' }
$exePath = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$evidencePath = (Resolve-Path $Evidence).Path
$root = Join-Path $env:RUNNER_TEMP ('idle-measure-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $root 'roaming'
$env:LOCALAPPDATA = Join-Path $root 'local'
$env:USERPROFILE = Join-Path $root 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '1'
New-Item -ItemType Directory -Force $root, $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
if ($Scenario -eq 'live') {
    if (-not $SshPath) { throw 'The live scenario needs -SshPath pointing at the boundary launcher' }
    $env:MP_VERIFY_STATE = Join-Path $root 'state'
    $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
    $env:MP_VERIFY_BOUNDARY = (Resolve-Path 'tools/verify-chat-delivery/boundary.py').Path
    $env:PYTHONUTF8 = '1'
}
Add-Type -Path tools/verify-chat-delivery/job.cs
Add-Type -Path tools/verify-chat-delivery/desktop.cs
Add-Type -AssemblyName System.Drawing
$settings = Join-Path $env:APPDATA 'ZigShell'
$logPath = Join-Path $settings 'debug.log'
$eventName = 'Local\MultipromptIdle-' + [guid]::NewGuid().ToString('N')
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $eventName)
$job = [VerifyJob]::new()
$process = $null
function Read-LogText {
    if (-not (Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Measure-Log {
    $total = 0L
    foreach ($file in @(Get-ChildItem $settings -Filter 'debug.log*' -ErrorAction SilentlyContinue)) { $total += $file.Length }
    return $total
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120, [int]$PollMs = 100) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $process -and $process.HasExited) { throw "App exited during $Name" }
        $value = & $Check
        if ($value) { return $value }
        Start-Sleep -Milliseconds $PollMs
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Get-TagHistogram([string]$Text) {
    $counts = @{}
    foreach ($line in ($Text -split "`n")) {
        $parts = $line.Trim() -split ' '
        if ($parts.Count -lt 3) { continue }
        $tagName = ($parts[1] -split '=')[0]
        if (-not $tagName) { continue }
        if (-not $counts.ContainsKey($tagName)) { $counts[$tagName] = 0 }
        $counts[$tagName]++
    }
    $rows = @()
    foreach ($pair in @($counts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10)) {
        $rows += [ordered]@{ tag = $pair.Key; lines = $pair.Value }
    }
    return $rows
}
$result = [ordered]@{
    probe = 'idle-log-cpu'
    tag = $Tag
    scenario = $Scenario
    status = 'failed'
    idleSeconds = $IdleSeconds
    windowSeconds = $null
    logBytesBefore = $null
    logBytesAfter = $null
    logBytesDelta = $null
    logLinesDelta = $null
    logBytesPerMinute = $null
    logMbPerHour = $null
    cpuMs = $null
    cpuMsPerMinute = $null
    cpuPercentOfOneCore = $null
    machineCores = [Environment]::ProcessorCount
    rotatedLogs = @()
    series = @()
    topLogTags = @()
    chatView = $null
    chatTabs = $null
    transcriptReads = $null
    statusSnapshots = $null
    chatPaintLines = $null
    windowStatusSnapshots = $null
    windowChatPaintLines = $null
    sha256 = $null
    exeVersion = $null
    error = $null
}
try {
    $result.sha256 = (Get-FileHash $exePath -Algorithm SHA256).Hash
    $bytes = [IO.File]::ReadAllBytes($exePath)
    $result.exeVersion = [regex]::Match([Text.Encoding]::ASCII.GetString($bytes), 'MPVERSION=([0-9][0-9.]*);').Groups[1].Value
    $bytes = $null
    if (-not $result.exeVersion) { throw 'Executable version marker missing' }
    New-Item -ItemType Directory -Force $settings | Out-Null
    if ($Scenario -eq 'live') {
        & python "$PSScriptRoot/live-chat-fixture.py" $root (Resolve-Path $SshPath).Path
        if ($LASTEXITCODE -ne 0) { throw 'Live chat fixture failed' }
    }
    $process = $job.Start($exePath, $root, "$evidencePath/stdout.log", "$evidencePath/stderr.log", "--single-window --no-window-restore --update-ready $eventName")
    if (-not $ready.WaitOne(45000)) { throw 'Released app did not become ready' }
    $main = [IntPtr]::Zero
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        if ($process.HasExited) { throw "Released app exited with $($process.ExitCode)" }
        $main = [ChatDeliveryDesktop]::Window([uint32]$process.Id)
        if ($main -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($main -eq [IntPtr]::Zero) { throw 'Released app did not show its main window' }
    [void](Wait-For 'session snapshot' { Test-Path (Join-Path $settings 'session.json') })
    [void](Wait-For 'app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$process.Id, $main) } 30 200)
    if ($Scenario -eq 'chat') {
        $null = [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
        [void](Wait-For 'chat view composer' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero } 60 250)
        $result.chatView = 'composer present after a real Alt+C'
    }
    if ($Scenario -eq 'live') {
        $sessionFile = Join-Path $settings 'session.json'
        $restored = Wait-For 'three restored live chats' {
            try {
                $saved = Get-Content $sessionFile -Raw | ConvertFrom-Json
                if (@($saved.tabs).Count -ne 3) { return $false }
                if (@($saved.tabs | Where-Object { -not $_.cv }).Count -ne 0) { return $false }
                $saved
            } catch { return $false }
        } 120 500
        $result.chatTabs = @($restored.tabs).Count
        [void](Wait-For 'live chat composer' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero } 60 250)
        [void](Wait-For 'transcript read for a live chat' { (Read-LogText) -match '\[chat\] transcript (load|push) shell=' } 90 250)
        $result.chatView = 'three live chats restored into the chat view'
    }
    Write-Host "Settling for $SettleSeconds s before the idle window"
    Start-Sleep -Seconds $SettleSeconds
    $process.Refresh()
    $beforeLog = Measure-Log
    $beforeText = Read-LogText
    $beforeCpu = $process.TotalProcessorTime.TotalMilliseconds
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $result.series += [ordered]@{ atSeconds = 0; logBytes = $beforeLog; cpuMs = [Math]::Round($beforeCpu, 2) }
    $elapsed = 0
    while ($elapsed -lt $IdleSeconds) {
        Start-Sleep -Seconds 30
        $elapsed = [int][Math]::Round($timer.Elapsed.TotalSeconds)
        if ($process.HasExited) { throw "App exited after $elapsed s of idling" }
        $process.Refresh()
        $result.series += [ordered]@{ atSeconds = $elapsed; logBytes = (Measure-Log); cpuMs = [Math]::Round($process.TotalProcessorTime.TotalMilliseconds, 2) }
        Write-Host ("idle {0}s: log {1} bytes, cpu {2} ms" -f $elapsed, (Measure-Log), [Math]::Round($process.TotalProcessorTime.TotalMilliseconds, 2))
    }
    $wallMs = $timer.Elapsed.TotalMilliseconds
    $process.Refresh()
    $afterLog = Measure-Log
    $afterText = Read-LogText
    $afterCpu = $process.TotalProcessorTime.TotalMilliseconds
    $window = if ($afterText.Length -ge $beforeText.Length) { $afterText.Substring($beforeText.Length) } else { '' }
    $result.transcriptReads = [regex]::Matches($afterText, '\[chat\] transcript (load|push) shell=').Count
    $result.statusSnapshots = [regex]::Matches($afterText, 'chat-status-snapshot: sid=').Count
    $result.chatPaintLines = [regex]::Matches($afterText, '\[chat-live\] (page|draw)|PERF\[chat\]: ').Count
    $result.windowStatusSnapshots = [regex]::Matches($window, 'chat-status-snapshot: sid=').Count
    $result.windowChatPaintLines = [regex]::Matches($window, '\[chat-live\] (page|draw)|PERF\[chat\]: ').Count
    $bytesDelta = $afterLog - $beforeLog
    $cpuDelta = $afterCpu - $beforeCpu
    $minutes = $wallMs / 60000
    $result.windowSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 1)
    $result.logBytesBefore = $beforeLog
    $result.logBytesAfter = $afterLog
    $result.logBytesDelta = $bytesDelta
    $result.logLinesDelta = if ($window) { ($window -split "`n").Count - 1 } else { 0 }
    $result.logBytesPerMinute = [Math]::Round($bytesDelta / $minutes, 1)
    $result.logMbPerHour = [Math]::Round($bytesDelta / $minutes * 60 / 1MB, 3)
    $result.cpuMs = [Math]::Round($cpuDelta, 2)
    $result.cpuMsPerMinute = [Math]::Round($cpuDelta / $minutes, 1)
    $result.cpuPercentOfOneCore = [Math]::Round($cpuDelta / $wallMs * 100, 3)
    $result.rotatedLogs = @(Get-ChildItem $settings -Filter 'debug.log*' | Where-Object { $_.Name -ne 'debug.log' } | ForEach-Object { $_.Name })
    $result.topLogTags = Get-TagHistogram $window
    $result.status = if (-not $process.HasExited -and $result.logMbPerHour -ne $null) { 'measured' } else { 'invalid' }
    if ($Scenario -eq 'live' -and ($result.chatTabs -ne 3 -or $result.transcriptReads -lt 1)) {
        $result.status = 'invalid'
        if (-not $result.error) { $result.error = "live chats never read a transcript (tabs=$($result.chatTabs), reads=$($result.transcriptReads), snapshots=$($result.statusSnapshots))" }
    }
} catch {
    $result.error = $_.Exception.Message
    Write-Host $_.ScriptStackTrace
} finally {
    if ($null -ne $job) { try { [void]$job.Stop() } catch { Write-Host "job stop failed: $($_.Exception.Message)" }; $job.Dispose() }
    $ready.Dispose()
    if ($null -ne $process) { $process.Dispose() }
    if (Test-Path $logPath) {
        $size = (Get-Item $logPath).Length
        if ($size -lt 40MB) { Copy-Item $logPath "$evidencePath/debug.log" } else { Write-Host "debug.log is $size bytes; keeping the series and skipping the copy" }
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$evidencePath/idle.json"
}
exit ($(if ($result.status -eq 'measured') { 0 } else { 1 }))
