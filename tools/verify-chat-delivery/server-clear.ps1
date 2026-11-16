[void](Wait-For 'initial history loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$hostDir = "$profile/home/.local/state/multiprompt/agent-host"
$statePath = Wait-For 'running production host agent' {
    $files = @(Get-ChildItem "$hostDir/*.state.json" -ErrorAction SilentlyContinue)
    if ($files.Count -ne 1) { return $null }
    $value = Read-Shared $files[0].FullName | ConvertFrom-Json
    if ($value.agent_pid -gt 0 -and (Read-Shared "$state/model-argv.jsonl")) { $files[0].FullName }
} 60
function Clear-Copy([string]$Stage, [string]$Required) {
    [void](Wait-For 'owned app foreground for transcript copy' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer) })
    [Windows.Forms.Clipboard]::Clear()
    $copied = Wait-For "rendered transcript contains $Required" {
        [ChatSwitchObserver]::CopyTranscript($app.Id, $main)
        try {
            $text = [Windows.Forms.Clipboard]::GetText()
            if ($text.Contains($Required)) { $text }
        } catch [Runtime.InteropServices.ExternalException] { $null }
    } 30
    [IO.File]::WriteAllText("$caseDir/$Stage-history.txt", $copied)
    Press @(0x1B) 'Escape: clear transcript selection'
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
Clear-Copy 'before' 'The fake session is ready.'
$before = Read-Shared $statePath | ConvertFrom-Json
Copy-Item $statePath "$caseDir/before-state.json"
Shot 'clear-before'
Type-Composer '/clear'
[void](Wait-For 'bare clear in the real composer' { [ChatDeliveryDesktop]::Text($composer) -ceq '/clear' })
Press @(0x1B) 'Escape: dismiss slash completion without changing the command' $true
Press @(0x0D) 'Enter: clear the server chat' $true
[void](Wait-For 'clear starts a new production agent context' {
    $next = Read-Shared $statePath | ConvertFrom-Json
    $next.PSObject.Properties['context_session'] -and $next.context_session -and $next.agent_pid -gt 0 -and $next.agent_pid -ne $before.agent_pid -and $next.native_session -ceq $next.context_session
} 60)
Copy-Item $statePath "$caseDir/after-state.json"
[void](Wait-For 'clear send has completed without a failed outbox entry' { (Read-Shared "$settings/debug.log") -match '\[chat\] send legacy reply=ok' })
Clear-Copy 'after-clear' 'The fake session is ready.'
Shot 'clear-after'
Type-Composer 'A new question after clearing.'
Press @(0x0D) 'Enter: send after clearing' $true
Clear-Copy 'after-reply' 'Synthetic fixture response.'
Shot 'clear-reply'
Copy-Item "$state/model-argv.jsonl" "$caseDir/agent-argv.jsonl"
$hostLog = @(Get-ChildItem "$hostDir/*.events.log")
if ($hostLog.Count -ne 1) { throw 'Expected exactly one isolated production host log' }
Copy-Item $hostLog[0].FullName "$caseDir/host-events.jsonl"
if (Test-Path "$settings/chat-outbox.json") { Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox.json" } else { Save @{queues=@()} "$caseDir/outbox.json" }
$observation.newContext = $true
Doctor $true
