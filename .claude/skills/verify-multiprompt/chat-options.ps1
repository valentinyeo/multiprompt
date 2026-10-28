$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
function Read-Choices {
    if (-not (Test-Path $log)) { return $null }
    $found = [regex]::Matches((Get-Content $log -Raw), 'CHAT_CHOICES prompt=(\d) live=(\d) chosen=(-?\d+) n=(\d+)((?: c\d+=-?\d+,-?\d+,-?\d+,-?\d+)*)')
    if ($found.Count -eq 0) { return $null }
    $last = $found[$found.Count - 1]
    $cards = @([regex]::Matches($last.Groups[5].Value, 'c(\d+)=(-?\d+),(-?\d+),(-?\d+),(-?\d+)') | ForEach-Object { @{ index = [int]$_.Groups[1].Value; left = [int]$_.Groups[2].Value; top = [int]$_.Groups[3].Value; right = [int]$_.Groups[4].Value; bottom = [int]$_.Groups[5].Value } })
    return @{ prompt = [int]$last.Groups[1].Value; live = [int]$last.Groups[2].Value; count = [int]$last.Groups[4].Value; cards = $cards }
}
function Find-Transcript {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $element -or $element.Current.IsOffscreen) { return [IntPtr]::Zero }
    return [IntPtr]$element.Current.NativeWindowHandle
}
function Click-Card([int]$Index) {
    $card = (Read-Choices).cards[$Index]
    [VerifyNative]::ClickClient($script:transcript, [int](($card.left + $card.right) / 2), [int](($card.top + $card.bottom) / 2))
}
function Question-Answers {
    $path = Join-Path $remoteState 'question-answers.jsonl'
    if (Test-Path $path) { return @(Get-Content $path | ForEach-Object { $_ | ConvertFrom-Json }) }
    return @()
}
Select-Theme 'amoled' 'theme-amoled'
Press @(0x12, 0x43) 'Alt+C: show transcript'
Wait-Until { (Find-Transcript) -ne [IntPtr]::Zero } 'Chat View visible'
$script:transcript = Find-Transcript
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.count -eq 0 -and (Get-Content $log -Raw) -match 'transcript load shell=\d+ ok' } 'ordinary list remains text without cards' 45
Snapshot 'plain-list-amoled'
Snapshot 'before'
$fixture = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-1063/questions.json')).Path
& $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell question $fixture
if ($LASTEXITCODE -ne 0) { throw 'Structured question fixture failed' }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.prompt -eq 1 -and $c.live -eq 1 -and $c.count -eq 3 } 'real question and Other cards painted' 45
Snapshot 'question-amoled'
Snapshot 'action'
Click-Card 1
Wait-Until { @(Question-Answers).Count -eq 1 } 'chosen answer received'
$first = @(Question-Answers)[0]
if ($first.labels.Count -ne 1 -or $first.labels[0] -cne 'Orange') { throw 'Single answer changed the provider label' }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.count -eq 4 } 'multiple selection includes Submit' 30
Click-Card 0
Click-Card 1
Click-Card 3
Wait-Until { @(Question-Answers).Count -eq 2 } 'multiple answers submitted'
$second = @(Question-Answers)[1]
if (($second.labels -join ',') -cne 'Desktop,Phone') { throw 'Multiple selection lost an answer' }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.count -eq 0 } 'completed question cards disappear' 30
Snapshot 'answered-amoled'
& $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell question $fixture
if ($LASTEXITCODE -ne 0) { throw 'Second structured question fixture failed' }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.count -eq 3 } 'fresh question has fresh choices' 30
Click-Card 2
Type-Text 'Purple'
Press @(0x0D) 'Enter: submit Other answer'
Wait-Until { @(Question-Answers).Count -eq 3 } 'Other text received'
$other = @(Question-Answers)[2]
if ($other.labels[0] -cne 'Purple') { throw 'Other answer changed typed text' }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.count -eq 4 -and $c.live -eq 1 } 'Other answer advances to the next question' 30
Snapshot 'other-amoled'
Snapshot 'after'
$outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
if (Test-Path $outboxPath) {
    $outbox = Get-Content $outboxPath -Raw | ConvertFrom-Json
    if (@($outbox).Count -gt 0) { throw 'Question answer became an ordinary queued message' }
}
$result.checks += @{ name = 'structured-question-cards'; plainLists = 'no cards'; single = $first.labels; multiple = $second.labels; other = $other.labels; boundary = 'Real reader and app; scripted provider UI, no paid provider calls' }
