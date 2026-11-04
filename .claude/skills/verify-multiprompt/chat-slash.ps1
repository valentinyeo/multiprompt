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
function Wait-SlashMode([string]$Mode) {
    Wait-Until {
        $file = Join-Path $remoteState 'slash-mode.json'
        if (-not (Test-Path $file)) { return $false }
        try { (Get-Content $file -Raw | ConvertFrom-Json).mode -ceq $Mode } catch { $false }
    } ('host acknowledged mode ' + $Mode)
    Wait-ChatFocus 'Edit' ('slash-mode-' + $Mode)
    Wait-Until { [VerifyNative]::EditText($script:slashComposer) -ceq '' } 'acknowledged mode clears the slash draft'
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
    Snapshot ('slash-' + $command.Substring(1) + '-notice')
}
Press @(0x11, 0x41) 'Ctrl+A: clear the unsupported command'
Press @(0x08) 'Backspace: clear without sending'
$offset = (Read-SharedText $script:slashLog).Length
Palette 'accept edits'
Wait-SlashPalette 12002 $offset
Snapshot 'slash-permissions-palette'
Press @(0x0D) 'Enter: choose Accept edits from Ctrl+K'
Wait-SlashMode 'acceptEdits'
Snapshot 'slash-permissions-edits-applied'
$controls = @(Get-Content (Join-Path $remoteState 'slash-control.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
if ($controls.Count -ne 3 -or ($controls.request.mode -join ',') -cne 'plan,manual,acceptEdits') { throw 'Mode choices did not reach the host exactly once and in order' }
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
Snapshot 'slash-after'
Snapshot 'after'
$result.checks += @{ name = 'live-chat-slash'; commands = @('/plan', '/permissions', '/model', '/resume', '/rewind'); modes = @('plan', 'manual', 'acceptEdits'); controls = $controls.Count; target = 'live-slash'; screenshots = $true; ordinarySends = 0 }
