[void](Wait-For 'initial history loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$hostDir = "$profile/home/.local/state/multiprompt/agent-host"
$statePath = Wait-For 'running production host agent' {
    $files = @(Get-ChildItem "$hostDir/*.state.json" -ErrorAction SilentlyContinue)
    if ($files.Count -ne 1) { return $null }
    $value = Read-Shared $files[0].FullName | ConvertFrom-Json
    if ($value.PSObject.Properties['agent_pid'] -and $value.agent_pid -gt 0 -and (Read-Shared "$state/model-argv.jsonl")) { $files[0].FullName }
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
. "$PSScriptRoot/header-ocr.ps1"
$headers = @{}
Clear-Copy 'before' 'The fake session is ready.'
$before = Read-Shared $statePath | ConvertFrom-Json
Copy-Item $statePath "$caseDir/before-state.json"
Shot 'clear-before'
try {
    $oldArgs = @((Read-Shared "$state/model-argv.jsonl") -split "`n" | Where-Object { $_.Trim() }).Count
    Type-Composer '/clear extra'
    Press @(0x1B) 'Escape: dismiss completion before the argument refusal' $true
    Press @(0x0D) 'Enter: refuse clear with arguments' $true
    $headers.arguments = Wait-For 'visible plain argument refusal' { $text = Read-Header 'clear-arguments'; if ($text -match 'without arguments') { $text } } 15
    $argumentState = Read-Shared $statePath | ConvertFrom-Json
    $argsAfter = @((Read-Shared "$state/model-argv.jsonl") -split "`n" | Where-Object { $_.Trim() }).Count
    Save @{draft=[ChatDeliveryDesktop]::Text($composer); contextUnchanged=($argumentState.native_session -ceq $before.native_session); agentUnchanged=($argumentState.agent_pid -eq $before.agent_pid); beforeArgs=$oldArgs; afterArgs=$argsAfter} "$caseDir/arguments.json"
} catch {
    $observation.argumentsError = $_.ToString()
} finally {
    Clear-Composer
    Save $headers "$caseDir/headers.json"
}
try {
    [IO.File]::WriteAllText("$state/restart-probe", '')
    $headers.stopped = Wait-For 'cached shell inventory exposes the real restart action' { $text = Read-Header 'restart-stopped'; if ($text -match 'AI stopped') { $text } } 60
    $word = @(Get-Content "$caseDir/restart-stopped-words.json" -Raw | ConvertFrom-Json | Where-Object { $_.text -match '^stopped' })
    if ($word.Count -ne 1) { throw 'The visible stopped badge has no unique click target' }
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    $x = [int](300 + $word[0].x + $word[0].width / 2 - $origin.X)
    $y = [int]($word[0].y + $word[0].height / 2 - $origin.Y)
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Doctor $true
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='click Restart AI badge'; x=$x; y=$y})
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, $x, $y)
    [void](Wait-For 'production restart request reaches the SSH boundary' { Test-Path "$state/restart-requested" })
    $headers.requestedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $headers.pending = Wait-For 'Restarting the AI is visibly painted before the refusal' { $text = Read-Header 'restart-pending'; if ($text -match 'Restarting the AI') { $text } } 15
    [IO.File]::WriteAllText("$state/restart-release", '')
    $headers.releasedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $headers.refused = Wait-For 'plain refusal reason is visibly painted' { $text = Read-Header 'restart-refused'; if ($text -match 'still running') { $text } } 15
    $headers.settled = Wait-For 'refusal notice expires without leaving the restarting badge' {
        $text = Read-Header 'restart-settled'
        if ($text -match 'Verify agent' -and $text -notmatch 'still running|Restarting|AI stopped|not restarted') { $text }
    } 15
    $headers.settledMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Save $headers "$caseDir/headers.json"
    Copy-Item "$state/restart-reply.jsonl" "$caseDir/restart-reply.jsonl"
} catch {
    $observation.restartError = $_.ToString()
} finally {
    [IO.File]::WriteAllText("$state/restart-release", '')
    Remove-Item "$state/restart-probe" -ErrorAction SilentlyContinue
    Press @(0x1B) 'Escape: close any remaining restart overlay'
    Save $headers "$caseDir/headers.json"
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
Type-Composer '/clear'
[void](Wait-For 'bare clear in the real composer' { [ChatDeliveryDesktop]::Text($composer) -ceq '/clear' })
Press @(0x1B) 'Escape: dismiss slash completion without changing the command' $true
Press @(0x0D) 'Enter: clear the server chat' $true
[void](Wait-For 'clear starts a new production agent context' {
    $next = Read-Shared $statePath | ConvertFrom-Json
    $next.PSObject.Properties['context_session'] -and $next.PSObject.Properties['agent_pid'] -and $next.PSObject.Properties['native_session'] -and $next.context_session -and $next.agent_pid -gt 0 -and $next.agent_pid -ne $before.agent_pid -and $next.native_session -ceq $next.context_session
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
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
Doctor $true
