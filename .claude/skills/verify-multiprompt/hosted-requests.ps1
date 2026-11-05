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
$script:hostedLastClick = [DateTime]::MinValue
function Click-HostedChoice([int]$Index) {
    Wait-Until { ([DateTime]::UtcNow - $script:hostedLastClick).TotalMilliseconds -gt [Windows.Forms.SystemInformation]::DoubleClickTime } 'separate single card clicks from native double-clicks'
    $card = (Read-HostedChoices).cards[$Index]
    if ($card.index -ne $Index -or $card.right -le $card.left -or $card.bottom -le $card.top) { throw 'Hosted card rectangle invalid' }
    Doctor
    Assert-Foreground
    Record ('Click hosted choice ' + $Index)
    [VerifyNative]::ClickClient($hostedTranscript, [int](($card.left + $card.right) / 2), [int](($card.top + $card.bottom) / 2))
    $script:hostedLastClick = [DateTime]::UtcNow
}
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$script:hostedOcr = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]::TryCreateFromUserProfileLanguages()
if ($null -eq $script:hostedOcr) { throw 'Windows screenshot text recognition is unavailable' }
$script:hostedAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await-HostedOperation($Operation, [Type]$ResultType) {
    $task = $script:hostedAsTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    if (-not $task.Wait(15000)) { throw 'Windows screenshot text recognition timed out' }
    return $task.Result
}
function Read-HostedScreenText([string]$Name) {
    Snapshot $Name
    $path = (Resolve-Path (Join-Path $Evidence ($Name + '.png'))).Path
    $file = Await-HostedOperation ([Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime])
    $stream = Await-HostedOperation ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType=WindowsRuntime])
    try {
        $decoder = Await-HostedOperation ([Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType=WindowsRuntime]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType=WindowsRuntime])
        $bitmap = Await-HostedOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType=WindowsRuntime])
        try {
            $recognized = Await-HostedOperation ($script:hostedOcr.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime])
            $script:hostedScreenText = $recognized.Text
            [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '-screen.txt')), $script:hostedScreenText)
        } finally { $bitmap.Dispose() }
    } finally { $stream.Dispose() }
}
function Assert-HostedContinued([string]$Id, [string]$Operation, [string]$Behavior) {
    Wait-Until { @(Read-HostedRows 'hosted-continuations' | Where-Object { $_.request_id -ceq $Id }).Count -eq 1 } ('provider resumed ' + $Id) 45
    $rows = @(Read-HostedRows 'hosted-replies' | Where-Object { $_.query.request_id -ceq $Id })
    if ($rows.Count -ne 1 -or $rows[0].query.op -cne $Operation -or $rows[0].sid -cne $remoteSids['live-slash'] -or $rows[0].reply.status -cne 'ok') { throw ('Wrong or duplicate reply: ' + $Id) }
    $response = $rows[0].responses[0].response
    if ($response.request_id -cne $Id -or $response.response.toolUseID -cne ('tool-' + $Id) -or $response.response.behavior -cne $Behavior) { throw ('Wrong provider response: ' + $Id) }
    $expected = ('Hosted request continued: ' + $Id).ToLowerInvariant() -replace '[^a-z0-9]', ''
    Wait-Until { Read-HostedScreenText ($Id + '-continued'); ($script:hostedScreenText.ToLowerInvariant() -replace '[^a-z0-9]', '').Contains($expected) } ('continuation visible in native screenshot ' + $Id) 45
    return $rows[0]
}
Read-HostedScreenText 'hosted-before'
if (($script:hostedScreenText.ToLowerInvariant() -replace '[^a-z0-9]', '').Contains('hostedrequestcontinued')) { throw 'Screenshot oracle found a continuation before any hosted request' }
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
Wait-Until { $c = Read-HostedChoices; $null -ne $c -and $c.live -eq 0 } 'Other is active before entering an answer'
Wait-ChatFocus 'Edit' 'hosted-other-composer'
Snapshot 'hosted-question-other'
Type-Text 'Blue'
Wait-Until { [VerifyNative]::EditText($script:slashComposer) -ceq 'Blue' } 'Other answer typed without ordinary submission'
Press @(0x0D) 'Enter: answer the hosted Other question'
$answered = Assert-HostedContinued 'hosted-question' 'question_reply' 'allow'
$answers = $answered.responses[0].response.response.updatedInput.answers
if ($answers.'Which colour?' -cne 'Orange' -or $answers.'Which devices?' -cne 'Desktop, Phone' -or $answers.'Which other colour?' -cne 'Blue') { throw 'Hosted answers lost labels, choices or question identity' }
foreach ($case in @(@{ id = 'hosted-implement'; text = 'implement'; action = 'implement'; behavior = 'allow' }, @{ id = 'hosted-feedback'; text = 'Also cover empty folders'; action = 'feedback'; behavior = 'deny' })) {
    Start-HostedRequest $case.id 'ExitPlanMode' @{ plan = ('## Hosted plan ' + $case.id + "`n1. List the folder") }
    Wait-Until { (Read-SharedText $hostedLog).Substring($script:hostedOffset) -match '\[chat-live\] draw shell=\d+ n=[1-9]\d* f=[1-9]' } 'hosted plan reached native transcript layout' 45
    $expectedPlan = ('Hosted plan ' + $case.id).ToLowerInvariant() -replace '[^a-z0-9]', ''
    Wait-Until { Read-HostedScreenText ($case.id + '-proposed'); $visible = $script:hostedScreenText.ToLowerInvariant() -replace '[^a-z0-9]', ''; $visible.Contains($expectedPlan) -and $visible.Contains('planready') -and $visible.Contains('listthefolder') } 'exact hosted plan words visible in native screenshot' 45
    [VerifyNative]::ClickClient($script:slashComposer, 8, 8)
    Wait-ChatFocus 'Edit' 'hosted-plan-composer'
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
