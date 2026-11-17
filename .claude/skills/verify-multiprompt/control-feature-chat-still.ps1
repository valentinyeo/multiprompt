Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/chat-still/observer.cs') -ReferencedAssemblies System,System.Core,System.Drawing
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$case = @{ name = 'chat-still'; status = 'failed'; detail = 'Chat stillness observation did not complete' }
$result.checks += $case
try {
    Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 5 } 'five long-chat sessions restored'
    Wait-Until { ((Get-Content $log -Raw) -join '') -match '\[chat-still\] row message=' } 'initial native chat geometry'
    Invoke-JourneyCommand 'Tab order: auto'
    Wait-Until {
        $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
        if (-not (Test-Path $path)) { return $false }
        $saved = Get-Content $path -Raw | ConvertFrom-Json
        $saved.PSObject.Properties['sort_auto'] -and -not $saved.sort_auto
    } 'manual tab order saved'
    Snapshot 'before'
    $target = (Read-Session).tabs[1]
    $observer = New-Object ChatStillObserver
    $observer.Start($process.Id, $script:window, $log, (Get-Item $log).Length, [string]$target.shell_id, $remoteState, $Evidence)
    Press @(0x11, 0x32) 'Ctrl+2: switch to a long chat; observe idle, live streaming and reconciliation without scrolling'
    $observation = $observer.Finish()
    Save-Json $observation 'chat-still.json'
    foreach ($phase in @('idle', 'streaming')) {
        Save-Json @{ message = $observation.message; baseline = $observation.baseline; samples = @($observation.samples | Where-Object { $_.phase -eq $phase }); status = $observation.status; error = $observation.error } "chat-still-$phase.json"
    }
    Snapshot 'action'
    if ($observation.status -ne 'passed') { throw $observation.error }
    Wait-Until { Test-Path (Join-Path $remoteState 'still-stream-receipt.json') } 'production streaming boundary completed' 10
    $receipt = Get-Content (Join-Path $remoteState 'still-stream-receipt.json') -Raw | ConvertFrom-Json
    $chunks = $receipt.chunks
    if ($chunks.Count -ne 30 -or ($chunks[-1].time_ns - $chunks[0].time_ns) -lt 2000000000) { throw 'Streaming boundary did not run for two seconds' }
    $samples = @($observation.samples | Where-Object { $_.phase -eq 'streaming' })
    $overlap = @($chunks | Where-Object { ($_.time_ns / 1000000) -ge $samples[0].utc_ms -and ($_.time_ns / 1000000) -le $samples[-1].utc_ms })
    if ($overlap.Count -lt 10 -or ($samples[-1].utc_ms - $receipt.canonical_time_ns / 1000000) -lt 1000) { throw 'Streaming and reconciliation did not overlap frame observation' }
    $pushes = @(Get-Content (Join-Path $remoteState 'chat-still-host.jsonl') | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.stage -eq 'pushed' -and $_.ms -ge $samples[0].utc_ms -and $_.ms -le $samples[-1].utc_ms } | ForEach-Object { $_.events } | Where-Object { $_.event.kind -eq 'text.delta' })
    if ($pushes.Count -lt 10) { throw 'The real live subscription did not push ten streaming chunks during observation' }
    if ($observation.streaming_paints -lt 2 -or $observation.distinct_streaming_heights -lt 2) { throw 'Streaming did not reach native layout and paint' }
    Snapshot 'after'
    $case.status = 'passed'
    $case.detail = 'The same newest initially visible message retained its exact screen rectangle on every sampled frame, idle, live streaming and after the canonical history write'
} catch {
    $case.detail = $_.Exception.Message
    throw
} finally {
    if (Test-Path $log) { Copy-Item $log (Join-Path $Evidence 'chat-still-debug.log') }
    foreach ($name in @('chat-still-host.jsonl', 'still-stream-receipt.json')) {
        $path = Join-Path $remoteState $name
        if (Test-Path $path) { Copy-Item $path (Join-Path $Evidence $name) }
    }
}
