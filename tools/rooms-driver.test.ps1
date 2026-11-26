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
foreach ($name in @('Open-Room', 'Room-Events')) {
    $definition = $tree.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name }.GetNewClosure(), $true)
    . ([scriptblock]::Create($definition.Extent.Text))
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
function Open-Member([string]$Name) { $script:member = $Name; $script:opening = $false }
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
    return ($script:events | Where-Object { $_.type -eq 'agent_reply' } | ForEach-Object { $_.text }) -join ' '
}
function Save($Value, [string]$Path) {}
function Copy-Chat([string]$Name) {
    if ($script:member -ceq 'Alpha') { return 'Bravo says ONE Alpha says TWO' }
    return 'Bravo says ONE No answer. Alpha did not complete a reply. No answer. Alpha could not accept this question. Bravo says TWO'
}
function Snapshot([string]$Name) {
    $rows = @($script:events | ForEach-Object { @{ body = ($_ | ConvertTo-Json -Compress -Depth 10) } })
    return [pscustomobject]@{
        rooms = @(@{ tables = @{ members = $script:members; events = $rows } })
        inputs = $script:inputs
        transcripts = $script:transcripts
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
    $script:Evidence = 'fixture'
    $script:events = @()
    $script:inputs = @()
    $script:transcripts = [pscustomobject]@{}
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
