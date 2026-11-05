Add-Type -AssemblyName System.Windows.Forms
$hostedLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
$condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
$element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
if ($null -eq $element -or $element.Current.IsOffscreen -or $element.Current.ProcessId -ne $process.Id) { throw 'Hosted transcript is not visible in the owned app' }
$hostedTranscript = [IntPtr]$element.Current.NativeWindowHandle
if ([VerifyNative]::GetAncestor($hostedTranscript, 2) -ne $script:window) { throw 'Hosted transcript owner mismatch' }
function Read-HostedRows([string]$Name) {
    $file = Join-Path $remoteState ($Name + '.jsonl')
    if (Test-Path $file) { return @(Get-Content $file | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }) }
    return @()
}
function Read-HostedChoices {
    $text = Read-SharedText $hostedLog
    if ($text.Length -le $script:hostedOffset) { return $null }
    $found = [regex]::Matches($text.Substring($script:hostedOffset), 'CHAT_CHOICES prompt=(\d) live=(\d) chosen=(-?\d+) n=(\d+)((?: c\d+=-?\d+,-?\d+,-?\d+,-?\d+)*)')
    if ($found.Count -eq 0) { return $null }
    $last = $found[$found.Count - 1]
    $cards = @([regex]::Matches($last.Groups[5].Value, 'c(\d+)=(-?\d+),(-?\d+),(-?\d+),(-?\d+)') | ForEach-Object { @{ index = [int]$_.Groups[1].Value; left = [int]$_.Groups[2].Value; top = [int]$_.Groups[3].Value; right = [int]$_.Groups[4].Value; bottom = [int]$_.Groups[5].Value } })
    return @{ count = [int]$last.Groups[4].Value; live = [int]$last.Groups[2].Value; cards = $cards }
}
function Start-HostedRequest([string]$Id, [string]$Tool, $InputValue) {
    $script:hostedOffset = (Read-SharedText $hostedLog).Length
    $event = @{ type = 'control_request'; request_id = $Id; request = @{ subtype = 'can_use_tool'; tool_name = $Tool; tool_use_id = ('tool-' + $Id); input = $InputValue; title = ('Hosted ' + $Id); requires_user_interaction = $true } }
    $temporary = Join-Path $remoteState 'hosted-request.tmp'
    [IO.File]::WriteAllText($temporary, (ConvertTo-Json -InputObject $event -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Move-Item -Force $temporary (Join-Path $remoteState 'hosted-request.json')
    Wait-Until { @(Read-HostedRows 'hosted-events' | Where-Object { $_.request.request_id -ceq $Id }).Count -eq 1 } ('provider request published ' + $Id) 45
}
function Wait-HostedChoices([int]$Count) {
    Wait-Until { $c = Read-HostedChoices; $null -ne $c -and $c.live -eq 1 -and $c.count -eq $Count } ('hosted cards painted: ' + $Count) 45
}
function Click-HostedChoice([int]$Index) {
    $card = (Read-HostedChoices).cards[$Index]
    if ($card.index -ne $Index -or $card.right -le $card.left -or $card.bottom -le $card.top) { throw 'Hosted card rectangle invalid' }
    Doctor
    Assert-Foreground
    Record ('Click hosted choice ' + $Index)
    [VerifyNative]::ClickClient($hostedTranscript, [int](($card.left + $card.right) / 2), [int](($card.top + $card.bottom) / 2))
}
function Copy-HostedTranscript {
    [Windows.Forms.Clipboard]::Clear()
    $offset = (Read-SharedText $hostedLog).Length
    Palette 'select all text'
    Wait-SlashPalette 6364 $offset
    Press @(0x0D) 'Enter: select the actual transcript'
    $offset = (Read-SharedText $hostedLog).Length
    Palette 'copy selection'
    Wait-SlashPalette 6363 $offset
    Press @(0x0D) 'Enter: copy the actual transcript'
    Wait-Until { [Windows.Forms.Clipboard]::ContainsText() } 'native transcript copied through palette'
    $script:hostedCopied = [Windows.Forms.Clipboard]::GetText()
    Press @(0x1B) 'Escape: clear transcript selection'
    [VerifyNative]::ClickClient($script:slashComposer, 8, 8)
    Wait-ChatFocus 'Edit' 'hosted-composer'
}
function Assert-HostedContinued([string]$Id, [string]$Operation, [string]$Behavior) {
    Wait-Until { @(Read-HostedRows 'hosted-continuations' | Where-Object { $_.request_id -ceq $Id }).Count -eq 1 } ('provider resumed ' + $Id) 45
    $rows = @(Read-HostedRows 'hosted-replies' | Where-Object { $_.query.request_id -ceq $Id })
    if ($rows.Count -ne 1 -or $rows[0].query.op -cne $Operation -or $rows[0].sid -cne $remoteSids['live-slash'] -or $rows[0].reply.status -cne 'ok') { throw ('Wrong or duplicate reply: ' + $Id) }
    $response = $rows[0].responses[0].response
    if ($response.request_id -cne $Id -or $response.response.toolUseID -cne ('tool-' + $Id) -or $response.response.behavior -cne $Behavior) { throw ('Wrong provider response: ' + $Id) }
    Wait-Until { Copy-HostedTranscript; $script:hostedCopied.Contains('Hosted request continued: ' + $Id) } ('continuation copied from native transcript ' + $Id) 45
    [IO.File]::WriteAllText((Join-Path $Evidence ($Id + '-transcript.txt')), $script:hostedCopied)
    Snapshot ($Id + '-continued')
    return $rows[0]
}
Start-HostedRequest 'hosted-allow' 'Bash' @{ command = 'printf hosted-proof' }
Wait-HostedChoices 3
Snapshot 'hosted-approval'
Click-HostedChoice 0
$allowed = Assert-HostedContinued 'hosted-allow' 'approval_reply' 'allow'
if ($allowed.query.decision -cne 'accept' -or $allowed.responses[0].response.response.updatedInput.command -cne 'printf hosted-proof') { throw 'Approval changed the tool input or decision' }
Start-HostedRequest 'hosted-cancel' 'Bash' @{ command = 'printf should-not-run' }
Wait-HostedChoices 3
[VerifyNative]::ClickClient($script:slashComposer, 8, 8)
Press @(0x1B) 'Escape: cancel the hosted approval'
$cancelled = Assert-HostedContinued 'hosted-cancel' 'approval_reply' 'deny'
if ($cancelled.query.decision -cne 'cancel' -or -not $cancelled.responses[0].response.response.interrupt) { throw 'Escape failed to cancel the waiting tool' }
$questions = @(
    @{ header = 'Accent'; question = 'Which colour?'; options = @(@{ label = 'Lime' }, @{ label = 'Orange' }); multiSelect = $false },
    @{ header = 'Devices'; question = 'Which devices?'; options = @(@{ label = 'Desktop' }, @{ label = 'Phone' }); multiSelect = $true },
    @{ header = 'Other'; question = 'Which other colour?'; options = @(@{ label = 'Lime' }, @{ label = 'Orange' }); multiSelect = $false }
)
Start-HostedRequest 'hosted-question' 'AskUserQuestion' @{ questions = $questions }
Wait-HostedChoices 3
Snapshot 'hosted-question'
Click-HostedChoice 1
Wait-HostedChoices 4
Snapshot 'hosted-question-multiple'
Click-HostedChoice 0
Click-HostedChoice 1
Click-HostedChoice 3
Wait-HostedChoices 3
Click-HostedChoice 2
Type-Text 'Blue'
Press @(0x0D) 'Enter: answer the hosted Other question'
$answered = Assert-HostedContinued 'hosted-question' 'question_reply' 'allow'
$answers = $answered.responses[0].response.response.updatedInput.answers
if ($answers.'Which colour?' -cne 'Orange' -or $answers.'Which devices?' -cne 'Desktop, Phone' -or $answers.'Which other colour?' -cne 'Blue') { throw 'Hosted answers lost labels, choices or question identity' }
foreach ($case in @(@{ id = 'hosted-implement'; text = 'implement'; action = 'implement'; behavior = 'allow' }, @{ id = 'hosted-feedback'; text = 'Also cover empty folders'; action = 'feedback'; behavior = 'deny' })) {
    Start-HostedRequest $case.id 'ExitPlanMode' @{ plan = ('## Hosted plan ' + $case.id + "`n1. List the folder") }
    Wait-Until { Copy-HostedTranscript; $script:hostedCopied.Contains('Hosted plan ' + $case.id) -and $script:hostedCopied.Contains('Plan ready') } 'hosted plan markdown and prompt copied from native transcript' 45
    Snapshot ($case.id + '-proposed')
    Type-Text $case.text
    Press @(0x0D) ('Enter: reply to plan with ' + $case.action)
    $planned = Assert-HostedContinued $case.id 'plan_reply' $case.behavior
    if ($planned.query.action -cne $case.action) { throw 'Plan action changed' }
    if ($case.action -eq 'feedback' -and $planned.responses[0].response.response.message -cne $case.text) { throw 'Plan feedback did not reach the waiting agent' }
}
if (@(Read-HostedRows 'hosted-replies').Count -ne 5 -or @(Read-HostedRows 'hosted-continuations').Count -ne 5) { throw 'Hosted requests were answered more than once' }
$outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
if ((Test-Path $outboxPath) -and (Read-SharedText $outboxPath) -match 'implement|Blue|Also cover empty folders') { throw 'Hosted answer leaked into ordinary message delivery' }
Copy-Item (Join-Path $remoteState 'hosted-*.jsonl') $Evidence
Snapshot 'after'
$result.checks += @{ name = 'hosted-requests'; requests = 5; approval = @('allow', 'cancel'); questions = @('single', 'multiple', 'Other'); plans = @('implement', 'feedback'); protocol = 'Production Claude event adapter, parked requests and host answer; scripted provider stdin and SSH'; visibleContinuation = $true }
