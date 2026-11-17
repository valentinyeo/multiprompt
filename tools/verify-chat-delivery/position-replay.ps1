$case = @{ name='chat-position-replay'; status='failed'; detail='Replay did not complete' }
$result.checks += $case
$phases = [Collections.Generic.List[object]]::new()
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
function Read-ReplayLog {
    $file = [IO.File]::Open($log, 'Open', 'Read', [IO.FileShare]::ReadWrite)
    try { $reader = [IO.StreamReader]::new($file); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $file.Dispose() }
}
function Observe-Replay([string]$Name, [string]$Policy, [scriptblock]$Action, [int]$Tab) {
    Doctor
    $phase = @{ name=$Name; policy=$Policy; start=[VerifyNative]::GetTickCount64(); shell=0; end=0 }
    $phases.Add($phase)
    Save-Json $phases.ToArray() 'position-phases.json'
    & $Action
    $phase.shell = (Read-Session).tabs[$Tab].shell_id
    $until = [VerifyNative]::GetTickCount64() + 3000
    Wait-Until { [VerifyNative]::GetTickCount64() -ge $until } "record every paint for $Name" 10
    $phase.end = [VerifyNative]::GetTickCount64()
    Save-Json $phases.ToArray() 'position-phases.json'
    Snapshot $Name
}
function Set-ReplayProvider([int]$Tab) {
    $document = Get-Content (Join-Path $remoteState 'state.json') -Raw | ConvertFrom-Json
    $name = $document.sessions[$Tab]
    $sid = $document.sids.PSObject.Properties[$name].Value
    $transcript = Join-Path $scratch "profile/.claude/projects/C--verify-work$Tab/$sid.jsonl"
    $document | Add-Member -Force NoteProperty sid $sid
    $document | Add-Member -Force NoteProperty transcript $transcript
    [IO.File]::WriteAllText((Join-Path $remoteState 'state.json'), ($document | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    return @{ sid=$sid; transcript=$transcript }
}
function Add-ReplayAnswer([int]$Tab, [string]$Text) {
    $provider = Set-ReplayProvider $Tab
    $row = @{ type='assistant'; timestamp=[DateTime]::UtcNow.ToString('o'); sessionId=$provider.sid; uuid=[guid]::NewGuid().ToString(); isSidechain=$false; message=@{ role='assistant'; id=('msg_' + [guid]::NewGuid().ToString('N')); model='claude-opus-5-5'; content=@(@{ type='text'; text=$Text }) } }
    [IO.File]::AppendAllText($provider.transcript, (($row | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
}
try {
    Wait-Until { $state=Read-Session; $null -ne $state -and @($state.tabs).Count -eq 5 -and @($state.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq 5 } 'five restored session transports'
    Invoke-JourneyCommand 'Tab order: auto' -Confirm { Press @(0x0D) 'Keep saved session order' }
    for ($tab=0; $tab -lt 5; $tab++) {
        $target = $tab
        Observe-Replay "open-$tab" 'stable' {
            Press @(0x11, (0x31 + $target)) "Select session $target"
            Wait-Until { (Read-Session).active_tab -eq $target } 'selected session'
            Press @(0x12, 0x43) 'Open Chat View'
            Wait-Until { $tabState=(Read-Session).tabs[$target]; $tabState.PSObject.Properties['cv'] -and $tabState.cv } 'Chat View saved for selected session'
            $sid = (Read-Session).tabs[$target].shell_id
            Wait-Until { (Read-ReplayLog) -match ('\[switch\] chat content shown shell=' + $sid + ' blocks=[1-9]') } 'actual session history painted' 60
        } $tab
    }
    Snapshot 'before'
    foreach ($tab in @(0, 1, 4, 2, 0, 3, 1, 4, 0, 2, 4, 1)) {
        $target = $tab
        Add-ReplayAnswer $tab ("New answer while another session is open. " * 12)
        Observe-Replay "switch-$($phases.Count)-$tab" 'stable' {
            Press @(0x11, (0x31 + $target)) "Switch to session $target"
            Wait-Until { (Read-Session).active_tab -eq $target } 'selected replay target'
        } $tab
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'desktop.cs')
    $composer = [ChatDeliveryDesktop]::Composer($script:window)
    if ($composer -eq [IntPtr]::Zero) { throw 'No owned visible composer' }
    Observe-Replay 'scroll-to-history' 'user-scroll' {
        Press @(0x21) 'Page Up into old history'
        Press @(0x21) 'Page Up farther into old history'
    } 1
    $latestFrame = @(Get-Content (Join-Path $env:MULTIPROMPT_FRAME_PROBE 'frames.tsv') | Where-Object { $_.StartsWith("frame`t") })[-1] -split "`t"
    if ($latestFrame[14] -ne '1') { throw 'Reader must actually be scrolled above the newest messages' }
    Observe-Replay 'receive-while-reading' 'stable' {
        Add-ReplayAnswer 1 ("A streamed answer arrives below the reader. " * 80)
    } 1
    Observe-Replay 'send-while-reading' 'send' {
        [void](Set-ReplayProvider 1)
        Press @(0x12, 0x51) 'Focus composer without changing the reader position'
        Type-Text 'position replay send while reading'
        if ([VerifyNative]::EditText($composer) -ne 'position replay send while reading') { throw 'Reader-send draft mismatch' }
        Press @(0x0D) 'Send while reading'
        Wait-Until { [VerifyNative]::EditText($composer) -eq '' } 'reader-send composer cleared'
    } 1
    Observe-Replay 'jump-to-newest' 'user-scroll' {
        Press @(0x23) 'End to newest messages'
    } 1
    Observe-Replay 'send-at-bottom' 'send' {
        Press @(0x12, 0x51) 'Focus composer'
        Type-Text 'position replay send at bottom'
        if ([VerifyNative]::EditText($composer) -ne 'position replay send at bottom') { throw 'Bottom-send draft mismatch' }
        Press @(0x0D) 'Send at bottom'
        Wait-Until { [VerifyNative]::EditText($composer) -eq '' } 'bottom-send composer cleared'
    } 1
    Observe-Replay 'receive-at-bottom' 'follow-bottom' {
        Add-ReplayAnswer 1 ("A received answer extends the bottom. " * 30)
    } 1
    Invoke-JourneyCommand 'Chat View: Select all text'
    Press @(0x11, 0x43) 'Copy the actual rendered conversation'
    $copied = [Windows.Forms.Clipboard]::GetText()
    foreach ($receipt in @('position replay send while reading', 'position replay send at bottom', 'A streamed answer arrives below the reader.', 'A received answer extends the bottom.')) {
        if (-not $copied.Contains($receipt)) { throw "Rendered transcript is missing receipt: $receipt" }
    }
    [IO.File]::WriteAllText((Join-Path $Evidence 'position-transcript.txt'), $copied)
    Press @(0x1B) 'Clear copied selection'
    Snapshot 'action'
    Snapshot 'after'
    & node (Join-Path $PSScriptRoot 'position-replay.cjs') $env:MULTIPROMPT_FRAME_PROBE (Join-Path $Evidence 'position-phases.json') (Join-Path $Evidence 'position-replay.json')
    if ($LASTEXITCODE -ne 0) { throw 'Chat moved after its first painted frame; inspect position-replay.json and paints' }
    $case.status='passed'
    $case.detail='Every successful paint retained through opens, switches, reader arrivals and sends'
} catch {
    $case.detail=$_.Exception.Message
    throw
} finally {
    Save-Json $phases.ToArray() 'position-phases.json'
}
