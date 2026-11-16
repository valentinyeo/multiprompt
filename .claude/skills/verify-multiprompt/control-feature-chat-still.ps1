Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/chat-still/observer.cs')
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$case = @{ name = 'chat-still'; status = 'failed'; detail = 'Chat stillness observation did not complete' }
$result.checks += $case
$observations = @{}
$streamJob = $null
$writer = $null
try {
    Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 5 } 'five long-chat sessions restored'
    Wait-Until { (Get-Content $log -Raw) -match '\[chat-still\] row message=' } 'initial native chat geometry'
    Focus-Palette 'tab order' 6217
    Press @(0x28) 'Down: Tab Order Manual'
    Press @(0x0D) 'Enter: keep the long-chat switch target in manual order'
    Wait-Until {
        $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
        if (-not (Test-Path $path)) { return $false }
        $saved = Get-Content $path -Raw | ConvertFrom-Json
        $saved.PSObject.Properties['sort_auto'] -and -not $saved.sort_auto
    } 'manual tab order saved'
    Snapshot 'before'
    $state = Read-Session
    $target = $state.tabs[1]
    $offset = (Get-Item $log).Length
    $idle = New-Object ChatStillObserver
    $idle.Start($process.Id, $script:window, $log, $offset, [string]$target.shell_id, $false)
    Press @(0x11, 0x32) 'Ctrl+2: switch to a long chat without scrolling'
    $observations.idle = $idle.Finish()
    Save-Json $observations.idle 'chat-still-idle.json'
    Snapshot 'action'
    $stream = New-Object ChatStillObserver
    $stream.Start($process.Id, $script:window, $log, (Get-Item $log).Length, [string]$target.shell_id, $true)
    $streamJob = New-Object VerifyJob
    $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/chat-still/stream.py')).Path
    $receipt = Join-Path $Evidence 'chat-still-stream-receipt.json'
    $arguments = '"' + $scriptPath + '" "' + $remoteState + '" "' + $target.tmux_session + '" "' + $receipt + '"'
    Record 'Observe a streaming reply without any scroll input'
    $writer = $streamJob.Start($env:MP_VERIFY_PYTHON, $scratch, (Join-Path $Evidence 'stream.stdout.log'), (Join-Path $Evidence 'stream.stderr.log'), $arguments, $true)
    $observations.streaming = $stream.Finish()
    Save-Json $observations.streaming 'chat-still-streaming.json'
    if (-not $writer.WaitForExit(10000) -or $writer.ExitCode -ne 0) { throw 'Streaming boundary did not complete' }
    $chunks = (Get-Content $receipt -Raw | ConvertFrom-Json).chunks
    if ($chunks.Count -ne 30 -or ($chunks[-1].time_ns - $chunks[0].time_ns) -lt 2000000000) { throw 'Streaming boundary did not run for two seconds' }
    foreach ($phase in @('idle', 'streaming')) {
        if ($observations[$phase].status -ne 'passed') { throw ($phase + ': ' + $observations[$phase].error) }
    }
    $samples = @($observations.streaming.samples)
    $overlap = @($chunks | Where-Object { ($_.time_ns / 1000000) -ge $samples[0].utc_ms -and ($_.time_ns / 1000000) -le $samples[-1].utc_ms })
    if ($overlap.Count -lt 10) { throw 'Streaming and per-frame observation did not overlap' }
    Snapshot 'after'
    if ($observations.streaming.distinct_content_heights -lt 2) { throw 'Streaming did not change the laid-out reply height' }
    if ($observations.streaming.paints -lt 2) { throw 'No streaming redraws reached the real transcript' }
    $case.status = 'passed'
    $case.detail = 'The newest initially visible message retained its exact screen rectangle on every sampled frame, idle and streaming'
} catch {
    $case.detail = $_.Exception.Message
    throw
} finally {
    Save-Json $observations 'chat-still.json'
    if ($null -ne $streamJob) {
        $stopped = $streamJob.Stop()
        Save-Json @{ activeAfterStop = $stopped.ActiveProcesses } 'chat-still-stream-cleanup.json'
        $streamJob.Dispose()
        if ($null -ne $writer) { $writer.Dispose() }
        if ($stopped.ActiveProcesses -ne 0) { throw 'Streaming boundary left owned processes running' }
    }
    if (Test-Path $log) { Copy-Item $log (Join-Path $Evidence 'chat-still-debug.log') }
}
