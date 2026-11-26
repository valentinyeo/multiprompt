$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$driver = Join-Path $PSScriptRoot '../.claude/skills/verify-multiprompt/rooms-driver.ps1'
$tokens = $null
$parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile($driver, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors -join "`n") }
function Driver-Case([string]$Step) {
    $command = $tree.Find({ param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Case' -and
            $node.CommandElements[1].Value -ceq $Step
    }.GetNewClosure(), $true)
    if ($null -eq $command) { throw "Missing production case $Step" }
    return $command.CommandElements[-1].ScriptBlock.GetScriptBlock()
}
foreach ($name in @('Open-Room', 'Room-Events', 'Wait-Or', 'Read-Clipboard', 'Clear-Clipboard', 'Copy-Chat', 'Copy-Chat-Until')) {
    $definition = $tree.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name }.GetNewClosure(), $true)
    if ($null -eq $definition) { throw "Missing production helper $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('room-driver-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $scratch | Out-Null
$script:watcher = [IO.FileSystemWatcher]::new($scratch)
$script:app = $null
$result = @{ observations = @(); cases = @(); driverErrors = @() }
function Press([int[]]$Keys, [string]$Label) { $script:presses += $Label }
function Focus-Control([IntPtr]$Control) {}
function Clear-Clipboard { return $true }
function Read-Clipboard {
    $values = $null
    if ($script:clipboards.ContainsKey([string]$script:member)) { $values = @($script:clipboards[[string]$script:member]) }
    if ($null -ne $values -and $values.Count) {
        $value = if ($script:clipboardIndex -lt $values.Count) { $values[$script:clipboardIndex] } else { $values[$values.Count - 1] }
        $script:clipboardIndex++
        return $value
    }
    if ($script:member -ceq 'Alpha') { return 'Bravo says ONE Alpha says TWO' }
    if ($script:member -ceq 'Bravo') { return 'Bravo says ONE No answer. Alpha did not complete a reply. No answer. Alpha could not accept this question. Bravo says TWO' }
    return ''
}
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Reject([scriptblock]$Body, [string]$Message) {
    $caught = $false
    try { & $Body } catch { $caught = $true }
    Require $caught $Message
}
function Wait-For([string]$Name, [scriptblock]$Body, [int]$Seconds = 30) {
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $value = & $Body
        if ($value) { return $value }
    }
    throw "Timed out: $Name"
}
function Read-Shared([string]$Path) { return $script:log }
function Invoke-JourneyCommand([string]$Text) { $script:opening = $true; $script:windowChecks = 0; $script:log += '[rooms] bridge reply received' }
function Room-Window {
    if ($script:opening) {
        $script:windowChecks++
        if ($script:windowChecks -ge 3) { return 1 }
    }
}
function Open-Member([string]$Name) { $script:member = $Name; $script:opening = $false; $script:clipboardIndex = 0 }
function Restart-Desktop { $script:opening = $false }
function Visible-Children([string]$Class) { return 1 }
function Release-Replies([string]$Marker) { $script:released = $true }
function Await-Replies([string]$Marker) { Require $script:released 'Replies were not released' }
function Shot([string]$Name) { return 'private chat pixels' }
function Shot-Room([string]$Name) {
    Require ([bool](Room-Window)) 'Read before the room window was ready'
    if ($Name -ceq 'restart-return') {
        Require $script:released 'Restart answers were not saved before returning'
        if ($script:badPixels) { return 'Alpha says RESTART534' }
        return 'Alpha says RESTART534 Bravo says RESTART534'
    }
    if ($Name -ceq 'failed-turn-recovered') { return 'Alpha says FAIL534 Bravo says FAIL534' }
    if ($Name -ceq 'interrupted-answer') { return 'Alpha says INTERRUPT534 Bravo says INTERRUPT534' }
    return ($script:events | Where-Object { $_.type -eq 'agent_reply' } | ForEach-Object { $_.text }) -join ' '
}
function Save($Value, [string]$Path) {}
function Snapshot([string]$Name) {
    $rows = @($script:events | ForEach-Object { @{ body = ($_ | ConvertTo-Json -Compress -Depth 10) } })
    if ($script:snapshots.ContainsKey($Name)) {
        $override = $script:snapshots[$Name]
        if ($override -is [scriptblock]) { return (& $override) }
        return $override
    }
    return [pscustomobject]@{
        rooms = @(@{ tables = @{ members = $script:members; events = $rows } })
        inputs = $script:inputs
        transcripts = $script:transcripts
        hosts = $script:hosts
    }
}
function Send-Text([string]$Text, [switch]$Room) {
    if ($Text -ceq '@Alpha FAIL534') {
        $targets = @(if ($script:retryEveryone) { 'alpha', 'bravo' } else { 'alpha' })
        $script:events += @{ type = 'human'; id = 'retry'; seq = 7; text = $Text; recipients = $targets }
        $script:events += @{ type = 'agent_reply'; id = 'recovered'; seq = 8; text = 'Alpha says FAIL534'; member_id = 'alpha'; parent_event_id = 'retry' }
        $script:inputs += @{ marker = 'FAIL534'; sid = 'sid-alpha' }
        if ($script:duplicateOther) {
            $script:events += @{ type = 'agent_reply'; id = 'duplicate'; seq = 9; text = 'Bravo says FAIL534'; member_id = 'bravo'; parent_event_id = 'retry' }
            $script:inputs += @{ marker = 'FAIL534'; sid = 'sid-bravo' }
        }
    }
}
function Reset-Fixture {
    $script:opening = $false
    $script:log = ''
    $script:windowChecks = 0
    $script:released = $false
    $script:badPixels = $false
    $script:retryEveryone = $false
    $script:duplicateOther = $false
    $script:member = ''
    $script:settings = 'fixture'
    $script:Evidence = $scratch
    $script:events = @()
    $script:inputs = @()
    $script:transcripts = [pscustomobject]@{}
    $script:hosts = @()
    $script:snapshots = @{}
    $script:clipboards = @{}
    $script:clipboardIndex = 0
    $script:copy_attempts = 0
    $script:copy_ever_read = $false
    $script:presses = @()
    $script:result = @{ observations = @(); cases = @(); driverErrors = @() }
    $script:members = @(
        @{ id = 'alpha'; display_name = 'Alpha'; provider_sid = 'sid-alpha'; active = 1 },
        @{ id = 'bravo'; display_name = 'Bravo'; provider_sid = 'sid-bravo'; active = 1 }
    )
}
$restartCase = Driver-Case '8'
Reset-Fixture
$script:inputs = @(@{ marker = 'RESTART534' }, @{ marker = 'RESTART534' })
& $restartCase
Require ($script:windowChecks -ge 3) 'Restart did not wait for the delayed room window'
$script:badPixels = $true
Reject { & $restartCase } 'Restart accepted missing Bravo pixels'
Write-Host 'PASS restart waits for the window and still rejects missing answer pixels'

$failedCase = Driver-Case '12'
function Failure-Fixture {
    Reset-Fixture
    $script:events = @(
        @{ type = 'human'; id = 'old'; seq = 1; text = 'OLDER'; recipients = @('bravo') },
        @{ type = 'agent_reply'; id = 'old-failure'; seq = 2; text = 'No answer. Bravo did not complete a reply.'; member_id = 'bravo'; parent_event_id = 'old' },
        @{ type = 'human'; id = 'question'; seq = 3; text = 'FAIL534'; recipients = @('alpha', 'bravo') },
        @{ type = 'agent_reply'; id = 'failure'; seq = 4; text = 'No answer. Alpha did not complete a reply.'; member_id = 'alpha'; parent_event_id = 'question' },
        @{ type = 'agent_reply'; id = 'other'; seq = 5; text = 'Bravo says FAIL534'; member_id = 'bravo'; parent_event_id = 'question' }
    )
    $script:inputs = @(@{ marker = 'FAIL534'; sid = 'sid-alpha' }, @{ marker = 'FAIL534'; sid = 'sid-bravo' })
}
Failure-Fixture
& $failedCase
Failure-Fixture
$script:retryEveryone = $true
Reject { & $failedCase } 'Retry accepted recipients beyond the failed member'
Failure-Fixture
$script:duplicateOther = $true
Reject { & $failedCase } 'Retry accepted a duplicate answer from the member that already answered'
Failure-Fixture
$script:events = @($script:events | Where-Object { $_.id -cne 'other' })
Reject { & $failedCase } 'Retry accepted a missing successful baseline answer'
Write-Host 'PASS failed turn is parent-scoped and retry rejects fanout, duplicates and a missing baseline'

$orderCase = Driver-Case '6'
function Transcript-Row([string]$Role, [string]$Text) { return @{ type = $Role; message = @{ content = @(@{ type = 'text'; text = $Text }) } } }
function Order-Fixture {
    Reset-Fixture
    $script:events = @(
        @{ type = 'human'; id = 'one'; seq = 1; recipients = @('alpha', 'bravo') },
        @{ type = 'agent_reply'; id = 'bravo-one'; seq = 2; member_id = 'bravo'; text = 'Bravo says ONE' },
        @{ type = 'agent_reply'; id = 'failure'; seq = 3; member_id = 'alpha'; text = 'No answer. Alpha did not complete a reply.' },
        @{ type = 'human'; id = 'private'; seq = 4; recipients = @('alpha') },
        @{ type = 'agent_reply'; id = 'admission-failure'; seq = 5; member_id = 'alpha'; text = 'No answer. Alpha could not accept this question.' },
        @{ type = 'human'; id = 'two'; seq = 6; recipients = @('alpha', 'bravo') },
        @{ type = 'agent_reply'; id = 'alpha-two'; seq = 7; member_id = 'alpha'; text = 'Alpha says TWO' },
        @{ type = 'agent_reply'; id = 'bravo-two'; seq = 8; member_id = 'bravo'; text = 'Bravo says TWO' }
    )
    $script:transcripts = [pscustomobject]@{
        '/sid-alpha.jsonl' = @((Transcript-Row 'user' 'bravo: Bravo says ONE'), (Transcript-Row 'assistant' 'Alpha says TWO'))
        '/sid-bravo.jsonl' = @((Transcript-Row 'assistant' 'Bravo says ONE'), (Transcript-Row 'user' 'alpha: No answer. Alpha did not complete a reply. alpha: No answer. Alpha could not accept this question.'), (Transcript-Row 'assistant' 'Bravo says TWO'))
    }
}
Order-Fixture
& $orderCase
Order-Fixture
$script:transcripts.'/sid-bravo.jsonl' = @((Transcript-Row 'assistant' 'Bravo says ONE'), (Transcript-Row 'assistant' 'Bravo says TWO'))
Reject { & $orderCase } 'Order check dropped the legitimate failure from delivered peer context'
Order-Fixture
$script:transcripts.'/sid-bravo.jsonl'[1] = Transcript-Row 'user' 'alpha: No answer. Alpha could not accept this question. alpha: No answer. Alpha did not complete a reply.'
Reject { & $orderCase } 'Order check accepted reordered failure context'
Order-Fixture
$script:transcripts.'/sid-bravo.jsonl' += (Transcript-Row 'assistant' 'No answer. Alpha did not complete a reply.')
Reject { & $orderCase } 'Order check accepted peer context as native assistant text'
Order-Fixture
$script:transcripts.'/sid-alpha.jsonl' = @((Transcript-Row 'user' 'bravo: Bravo says ONE'))
Reject { & $orderCase } 'Order check accepted a missing native assistant answer'
Write-Host 'PASS native assistant checks exclude generated failures but retain peer context and roles'

function Failure([scriptblock]$Body) {
    try { & $Body } catch { return $_.Exception.Message }
    throw 'Expected the driver check to fail'
}
$privateCase = Driver-Case 'private'
Reset-Fixture
$script:clipboards = @{
    Alpha = @('', 'Alpha says READY534 Alpha says PRIVATE534')
    Bravo = @('', 'Bravo says READY534 PRIVATE534', 'Bravo says READY534 PRIVATE534 Bravo says PRIVATE534')
}
& $privateCase
Require ($script:copy_attempts -ge 2) 'Private case did not re-read the clipboard after an empty or reply-less copy'
Write-Host 'PASS private chats survive a transient empty copy and still require the real reply'

Reset-Fixture
$script:member = 'Bravo'
$script:clipboards = @{ Bravo = @('') }
$message = Failure { Copy-Chat-Until 'Bravo' 'Bravo real private reply' { param($text) $text.Contains('Bravo says PRIVATE534') } -Seconds 5 -Attempts 1 -ReadSeconds 1 }
Require ($message -match 'Ctrl\+C copy produced nothing') "A copy that never produced text reported '$message' instead of the copy failure"
Write-Host 'PASS a copy that never produces text still fails the case with the copy diagnosis'

Reset-Fixture
$script:member = 'Bravo'
$script:clipboards = @{ Bravo = @('Bravo says PRIVATE534') }
$message = Failure { Copy-Chat-Until 'Bravo' 'Bravo real private reply' { param($text) $text.Contains('wrong reply') } -Seconds 5 -Attempts 1 -ReadSeconds 1 }
Require ($message -match 'Timed out: Bravo real private reply') "A copied chat without the reply reported '$message' instead of the reply timeout"
Write-Host 'PASS copied text without the reply still fails the case'

Reset-Fixture
$script:clipboards = @{ Alpha = @('Alpha says READY534'); Bravo = @('Bravo says READY534') }
Reject { & $privateCase } 'Private case accepted copied chats that never contain the member reply'
Write-Host 'PASS private case refuses a chat whose copied text never holds the reply'

function Away-Rows { @($script:events | ForEach-Object { @{ body = ($_ | ConvertTo-Json -Compress -Depth 10) } }) }
function Away-State {
    [pscustomobject]@{
        rooms = @(@{ tables = @{ members = $script:members; events = (Away-Rows) } })
        inputs = $script:inputs
        transcripts = $script:transcripts
        hosts = $script:hosts
    }
}
function Away-Fixture([bool]$bothWhileClosed, [bool]$bothAfterOpen) {
    Reset-Fixture
    $script:events = @(
        @{ type = 'human'; id = 'away'; seq = 10; text = 'AWAY534'; recipients = @('alpha', 'bravo') },
        @{ type = 'agent_reply'; id = 'alpha-away'; seq = 11; text = 'Alpha says AWAY534'; member_id = 'alpha'; parent_event_id = 'away' }
    )
    $script:inputs = @(@{ marker = 'AWAY534' }, @{ marker = 'AWAY534' })
    $script:transcripts = [pscustomobject]@{
        '/sid-alpha.jsonl' = @(@{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = 'Alpha says AWAY534' }) } })
        '/sid-bravo.jsonl' = @(@{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = 'Bravo says AWAY534' }) } })
    }
    $script:awaySamples = 0
    $script:awayBothWhileClosed = $bothWhileClosed
    $script:awayBothAfterOpen = $bothAfterOpen
    $script:snapshots['away-held'] = { Away-State }
    $script:snapshots['away-question'] = { Away-State }
    $script:snapshots['away-while-closed'] = {
        $script:awaySamples++
        if ($script:awayBothWhileClosed -and $script:awaySamples -ge 2 -and -not @($script:events | Where-Object { $_.id -ceq 'bravo-away' }).Count) {
            $script:events += @{ type = 'agent_reply'; id = 'bravo-away'; seq = 12; text = 'Bravo says AWAY534'; member_id = 'bravo'; parent_event_id = 'away' }
        }
        Away-State
    }
    $script:snapshots['away-return-poll'] = {
        if ($script:awayBothAfterOpen -and -not @($script:events | Where-Object { $_.id -ceq 'bravo-away' }).Count) {
            $script:events += @{ type = 'agent_reply'; id = 'bravo-away'; seq = 12; text = 'Bravo says AWAY534'; member_id = 'bravo'; parent_event_id = 'away' }
        }
        Away-State
    }
}
$awayCase = Driver-Case '7'
Away-Fixture -bothWhileClosed $true -bothAfterOpen $true
& $awayCase
Require ($script:awaySamples -ge 2) 'Away gate accepted the first closed-room sample without waiting for both replies'
$awayObservation = @($result.observations | Where-Object { $_.fact -like '*stayed closed*' })
Require ($awayObservation.Count -eq 1 -and $awayObservation[0].count -eq 2) 'Away case did not record both replies saved while the room stayed closed'
Write-Host 'PASS away replies are gated on both providers and both saved rows before the room opens'
Away-Fixture -bothWhileClosed $false -bothAfterOpen $true
Reject { & $awayCase } 'Away case accepted a reply that was saved only after the room opened'
Write-Host 'PASS away case refuses a reply saved only after the room opens'

function Interrupted-Fixture([bool]$duplicate, [string]$status, [bool]$partial) {
    Reset-Fixture
    $script:events = @(
        @{ type = 'human'; id = 'interrupt'; seq = 20; text = 'INTERRUPT534'; recipients = @('alpha', 'bravo') },
        @{ type = 'agent_reply'; id = 'alpha-interrupt'; seq = 21; text = 'Alpha says INTERRUPT534'; member_id = 'alpha'; parent_event_id = 'interrupt' }
    )
    if ($partial) { $script:events += @{ type = 'agent_reply'; id = 'bravo-interrupt'; seq = 22; text = 'Bravo says INTERRUPT534'; member_id = 'bravo'; parent_event_id = 'interrupt' } }
    if ($duplicate) { $script:events += @{ type = 'agent_reply'; id = 'bravo-interrupt-again'; seq = 23; text = 'Bravo says INTERRUPT534'; member_id = 'bravo'; parent_event_id = 'interrupt' } }
    $script:inputs = @(@{ marker = 'INTERRUPT534' })
    $bravoRows = @()
    if ($partial) { $bravoRows = @(@{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = 'Bravo says INTERRUPT534' }) } }) }
    $script:transcripts = [pscustomobject]@{
        '/a1b2c3d4-0534-4000-8000-000000000001.jsonl' = @(@{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = 'Alpha says INTERRUPT534' }) } })
        '/a1b2c3d4-0534-4000-8000-000000000002.jsonl' = $bravoRows
    }
    $script:hosts = @(@{ state = @{ native_session = 'a1b2c3d4-0534-4000-8000-000000000002'; result = @{ subtype = $status } } })
}
$interruptedCase = Driver-Case '12-interrupted'
Interrupted-Fixture -duplicate $false -status 'interrupted' -partial $true
& $interruptedCase
Write-Host 'PASS an interrupted turn keeps its partial answer exactly once'
Interrupted-Fixture -duplicate $true -status 'interrupted' -partial $true
Reject { & $interruptedCase } 'Interrupted case accepted a duplicated partial answer'
Interrupted-Fixture -duplicate $false -status 'failed' -partial $true
Reject { & $interruptedCase } 'Interrupted case accepted a turn the host never marked interrupted'
Interrupted-Fixture -duplicate $false -status 'interrupted' -partial $false
Reject { & $interruptedCase } 'Interrupted case accepted a turn with no saved partial answer'
Write-Host 'PASS interrupted case refuses duplicates, a missing interrupt and a missing partial answer'
