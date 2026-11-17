$result.seedBoundary = 'Two isolated saved remote tabs and one transcript round seeded before launch. SSH, host ownership and agent transport are stand-ins. Windows uses the reader polling fallback instead of Linux filesystem notifications. No real agent, credentials or shared session.'
$result.slashBoundary = @{
    app = 'Real Windows app, keyboard input, autocomplete, palette, send routing and asynchronous mode requests'
    reader = 'App-supplied reader, real host_reply and host_handle_request validation and host_set_mode'
    agent = 'Isolated host ownership and Claude stdin transport stand-ins; no real Claude, SSH server or paid calls'
}
Press @(0x11, 0x32) 'Ctrl+2: select the isolated live chat'
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.tabs[$saved.active_tab].tmux_session -ceq 'live-slash' -and $saved.tabs[$saved.active_tab].cv
} 'live slash chat selected and visible'
Wait-ChatFocus 'Edit' 'slash-composer'
$script:slashComposer = [IntPtr][System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle
if ([VerifyNative]::Class($script:slashComposer) -cne 'Edit' -or [VerifyNative]::GetAncestor($script:slashComposer, 2) -ne $script:window) { throw 'Slash composer is not owned by the verified app' }
$script:slashLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
function Send-Slash([string]$Command) {
    Press @(0x11, 0x41) 'Ctrl+A: replace the previous unsent command'
    Press @(0x08) 'Backspace: clear the composer'
    Type-Text $Command
    Wait-Until { [VerifyNative]::EditText($script:slashComposer) -ceq $Command } ('typed ' + $Command)
    Press @(0x1B) 'Escape: dismiss completion without changing the typed command'
    Snapshot ('slash-' + $Command.Substring(1) + '-typed')
    Press @(0x0D) ('Enter: run ' + $Command + ' in live chat')
}
function Wait-SlashPalette([int]$Target, [int]$Offset) {
    Wait-Until {
        $text = Read-SharedText $script:slashLog
        if ($text.Length -le $Offset) { return $false }
        $text.Substring($Offset) -match ('\[palette\] ready chars=\d+ count=\d+ target=' + $Target + '(?:\s|$)')
    } 'live chat mode picker painted'
}
$script:slashExpectedControls = 0
$script:slashInputs = @()
function Wait-SlashMode([string]$Mode, [string]$Draft = '', [string]$Entry = 'slash') {
    $script:slashExpectedControls++
    Wait-Until {
        $file = Join-Path $remoteState 'slash-mode.json'
        if (-not (Test-Path $file)) { return $false }
        try {
            $controls = @(Get-Content (Join-Path $remoteState 'slash-control.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
            $replies = @(Get-Content (Join-Path $remoteState 'slash-replies.jsonl') | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.op -ceq 'set_permission_mode' })
            (Get-Content $file -Raw | ConvertFrom-Json).mode -ceq $Mode -and $controls.Count -eq $script:slashExpectedControls -and $replies.Count -eq $script:slashExpectedControls -and @($replies | Where-Object { $_.reply.status -cne 'ok' }).Count -eq 0
        } catch { $false }
    } ('host acknowledged mode ' + $Mode)
    Wait-ChatFocus 'Edit' ('slash-mode-' + $Mode)
    Wait-Until { [VerifyNative]::EditText($script:slashComposer) -ceq $Draft } 'mode acknowledgement preserves exactly the expected draft'
    $screenshot = 'mode-' + $Entry + '-' + $Mode + '-received'
    Snapshot $screenshot
    $script:slashInputs += @{ entry=$Entry; mode=$Mode; draft=[VerifyNative]::EditText($script:slashComposer); receipt=$script:slashExpectedControls; screenshot=($screenshot + '.png') }
    Save-Json @($script:slashInputs) 'mode-inputs.json'
}
$offset = (Read-SharedText $script:slashLog).Length
Send-Slash '/plan'
Wait-SlashPalette 12000 $offset
Snapshot 'slash-plan-picker'
Snapshot 'action'
Press @(0x0D) 'Enter: choose Plan mode'
Wait-SlashMode 'plan'
Snapshot 'slash-plan-applied'
$offset = (Read-SharedText $script:slashLog).Length
Send-Slash '/permissions'
Wait-SlashPalette 12000 $offset
Snapshot 'slash-permissions-picker'
Press @(0x28) 'Down: select Ask mode'
Snapshot 'slash-permissions-ask'
Press @(0x0D) 'Enter: choose Ask mode'
Wait-SlashMode 'manual'
Snapshot 'slash-permissions-applied'
foreach ($command in @('/model', '/resume', '/rewind')) {
    Send-Slash $command
    Wait-Until { [VerifyNative]::EditText($script:slashComposer) -ceq $command } ('unsupported command remains editable ' + $command)
    $noticeName = 'slash-' + $command.Substring(1) + '-notice'
    Snapshot $noticeName
    $noticeImage = [Drawing.Bitmap]::new((Join-Path $Evidence ($noticeName + '.png')))
    try {
        $noticeInk = 0
        for ($y = 20; $y -lt 60; $y++) {
            for ($x = 320; $x -lt [Math]::Min(850, $noticeImage.Width); $x++) {
                $color = $noticeImage.GetPixel($x, $y)
                if ($color.R -gt 150 -and $color.G -gt 80 -and $color.B -lt 150 -and $color.R -gt $color.G) { $noticeInk++ }
            }
        }
        if ($noticeInk -lt 10) { throw ('Command notice is not visibly painted: ' + $command) }
    } finally { $noticeImage.Dispose() }
}
Press @(0x11, 0x41) 'Ctrl+A: clear the unsupported command'
Press @(0x08) 'Backspace: clear without sending'
foreach ($choice in @(@{mode='acceptEdits'; down=2}, @{mode='bypassPermissions'; down=3})) {
    $offset = (Read-SharedText $script:slashLog).Length
    Send-Slash '/permissions'
    Wait-SlashPalette 12000 $offset
    for ($step = 0; $step -lt $choice.down; $step++) { Press @(0x28) 'Down: choose the next permission mode' }
    Snapshot ('slash-' + $choice.mode + '-picker')
    Press @(0x0D) 'Enter: apply the chosen slash mode'
    Wait-SlashMode $choice.mode
}
Type-Text 'Keep this mode draft'
foreach ($choice in @(
    @{mode='plan'; command='Chat permission mode: Plan'},
    @{mode='manual'; command='Chat permission mode: Ask'},
    @{mode='acceptEdits'; command='Chat permission mode: Accept edits'},
    @{mode='bypassPermissions'; command='Chat permission mode: Bypass'}
)) {
    Invoke-JourneyCommand $choice.command -SelectOnly
    Snapshot ('mode-palette-' + $choice.mode)
    Press @(0x0D) 'Enter: apply the selected palette permission mode'
    Wait-SlashMode $choice.mode 'Keep this mode draft' 'palette'
    Snapshot ('mode-palette-' + $choice.mode + '-applied')
}
foreach ($choice in @(@{mode='plan'; up=2}, @{mode='manual'; up=4}, @{mode='acceptEdits'; up=3}, @{mode='bypassPermissions'; up=1})) {
    $offset = (Read-SharedText $script:slashLog).Length
    Invoke-JourneyCommand 'Chat View: Plus Menu'
    Wait-Until { [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptPlusMenu', $null) -ne [IntPtr]::Zero -and (Read-SharedText $script:slashLog).Substring($offset) -match '\[chat\] plus menu mode_ask rect=' } 'owned Plus menu has permission choices'
    for ($step = 0; $step -lt $choice.up; $step++) { Press @(0x26) 'Up: choose a permission row from the bottom of Plus' }
    Snapshot ('mode-plus-' + $choice.mode)
    Press @(0x0D) 'Enter: choose the Plus permission mode'
    Wait-SlashMode $choice.mode 'Keep this mode draft' 'plus'
    Snapshot ('mode-plus-' + $choice.mode + '-applied')
}
Invoke-JourneyCommand 'Chat View: Plus Menu'
Snapshot 'mode-plus-cancel'
Press @(0x1B) 'Escape: dismiss Plus without changing permission or draft'
Wait-ChatFocus 'Edit' 'mode-plus-cancelled'
if ([VerifyNative]::EditText($script:slashComposer) -cne 'Keep this mode draft') { throw 'Cancelling Plus changed the unsent draft' }
$controls = @(Get-Content (Join-Path $remoteState 'slash-control.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
if ($controls.Count -ne 12 -or ($controls.request.mode -join ',') -cne 'plan,manual,acceptEdits,bypassPermissions,plan,manual,acceptEdits,bypassPermissions,plan,manual,acceptEdits,bypassPermissions') { throw 'Mode choices did not reach the host exactly once and in order' }
foreach ($control in $controls) {
    if ($control.sid -cne $remoteSids['live-slash'] -or $control.request.subtype -cne 'set_permission_mode') { throw 'Mode control targeted another chat or operation' }
}
Copy-Item (Join-Path $remoteState 'slash-control.jsonl') (Join-Path $Evidence 'slash-control.jsonl')
Copy-Item (Join-Path $remoteState 'slash-replies.jsonl') (Join-Path $Evidence 'slash-replies.jsonl')
Copy-Item (Join-Path $remoteState 'slash-mode.json') (Join-Path $Evidence 'slash-mode.json')
$outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
if (Test-Path $outboxPath) {
    $outboxText = Read-SharedText $outboxPath
    if ($outboxText -match '/(plan|permissions|model|resume|rewind)') { throw 'A local slash command leaked into the message outbox' }
}
& node (Join-Path $PSScriptRoot 'chat-control-coverage.test.cjs') --mode-evidence $Evidence
if ($LASTEXITCODE -ne 0) { throw 'Live mode route receipts do not cover the declared input matrix' }
Snapshot 'slash-after'
Snapshot 'after'
$result.checks += @{ name = 'live-chat-slash'; commands = @('/plan', '/permissions', '/model', '/resume', '/rewind'); modes = @('plan', 'manual', 'acceptEdits', 'bypassPermissions'); routes = @('slash', 'palette', 'plus'); controls = $controls.Count; target = 'live-slash'; screenshots = $true; ordinarySends = 0 }
