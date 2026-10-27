Add-Type -AssemblyName System.Windows.Forms
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
function Read-Choices([string]$Expect) {
    if (-not (Test-Path $log)) { return $null }
    $text = (Get-Content $log -Raw) -join ''
    $found = [regex]::Matches($text, 'CHAT_CHOICES prompt=(\d) live=(\d) chosen=(-?\d+) n=(\d+)((?: c\d+=-?\d+,-?\d+,-?\d+,-?\d+)+)')
    if ($found.Count -eq 0) { return $null }
    $last = $found[$found.Count - 1]
    $cards = @([regex]::Matches($last.Groups[5].Value, 'c(\d+)=(-?\d+),(-?\d+),(-?\d+),(-?\d+)') | ForEach-Object { @{ index = [int]$_.Groups[1].Value; left = [int]$_.Groups[2].Value; top = [int]$_.Groups[3].Value; right = [int]$_.Groups[4].Value; bottom = [int]$_.Groups[5].Value } })
    return @{ prompt = [int]$last.Groups[1].Value; live = [int]$last.Groups[2].Value; chosen = [int]$last.Groups[3].Value; count = [int]$last.Groups[4].Value; cards = $cards }
}
function Find-Transcript {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    if ($null -eq $element -or $element.Current.IsOffscreen) { return [IntPtr]::Zero }
    return [IntPtr]$element.Current.NativeWindowHandle
}
function Click-Card([IntPtr]$Transcript, $Card) {
    [VerifyNative]::ClickClient($Transcript, [int](($Card.left + $Card.right) / 2), [int](($Card.top + $Card.bottom) / 2))
}
function Open-FreshCmd {
    $before = @((Read-Session).tabs).Count
    Palette 'new cmd'
    Press @(0x0D) 'Enter: new CMD tab'
    Wait-Until { $state = Read-Session; @($state.tabs).Count -eq $before + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd' } 'fresh CMD tab saved'
    $state = Read-Session
    Wait-WorkspaceSurface $state.active_workspace $state.active_tab $false
}

$headingsScript = Join-Path $scratch 'section-headings.ps1'
$headingsReady = Join-Path $scratch 'section-headings-ready.txt'
$headingsLines = @(
    "'1. What a pro would add'",
    "'A shared build check catches broken releases.'",
    "'2. Raw material'",
    "'Start from build logs and the failing run.'",
    "'Should I file a ticket for this?'",
    "Set-Content -Path '$headingsReady' -Value 'ready'",
    '[void][Console]::In.ReadLine()'
)
Set-Content -Path $headingsScript -Value $headingsLines -Encoding ASCII
$logStart = if (Test-Path $log) { (Get-Content $log -Raw).Length } else { 0 }
Type-Text ('powershell -nop -ExecutionPolicy Bypass -File "' + $headingsScript + '"')
Press @(0x0D) 'Enter: print numbered sections followed by a yes-no question'
Wait-Until { Test-Path $headingsReady } 'synthetic section headings printed'
Press @(0x12, 0x43) 'Alt+C: inspect the question without answer options'
Wait-Until { (Find-Transcript) -ne [IntPtr]::Zero } 'section question transcript visible'
Wait-Until {
    [System.Windows.Forms.Clipboard]::Clear()
    Palette 'select all text'
    Press @(0x0D) 'Enter: select rendered transcript'
    Press @(0x11, 0x43) 'Ctrl+C: copy selected transcript without opening another overlay'
    [System.Windows.Forms.Clipboard]::GetText().Contains('Should I file a ticket for this?')
} 'the final question is present in the actual rendered transcript'
Press @(0x1B) 'Escape: clear transcript selection'
Snapshot 'section-question'
$sectionLog = (Get-Content $log -Raw).Substring($logStart)
if ($sectionLog -match 'CHAT_CHOICES[^\r\n]* n=[1-9]') { throw 'Section headings became answer cards for the final yes-no question' }
$result.checks += @{ name = 'section-headings-not-answers'; cards = 0; renderedQuestion = 'Should I file a ticket for this?' }
Open-FreshCmd

$replyAnswer = Join-Path $scratch 'reply-answer.txt'
$replyScript = Join-Path $scratch 'reply-options.ps1'
$replyLines = @(
    "'Which key should the inne bot use?'",
    "'A. Create an OpenRouter account for inne. Own key and spend cap.'",
    "'B. Reuse the Yeo UX key for now. Fastest, move it later.'",
    '$answer = [Console]::In.ReadLine()',
    "Set-Content -Path '$replyAnswer' -Value `$answer"
)
Set-Content -Path $replyScript -Value $replyLines -Encoding ASCII
Type-Text ('powershell -nop -ExecutionPolicy Bypass -File "' + $replyScript + '"')
Press @(0x0D) 'Enter: print a reply with two lettered options and wait for an answer'
Press @(0x12, 0x43) 'Alt+C: open Chat View'
Wait-Until { (Find-Transcript) -ne [IntPtr]::Zero } 'Chat View transcript visible'
$transcript = Find-Transcript
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.prompt -eq 0 -and $c.live -eq 1 -and $c.count -eq 2 } 'two live reply option cards painted'
Snapshot 'before'
$cards = (Read-Choices).cards
if ($cards[0].bottom -gt $cards[1].top) { throw 'Option cards overlap' }
Snapshot 'action'
Click-Card $transcript $cards[1]
Wait-Until { Test-Path $replyAnswer } 'console received the clicked answer' 30
$delivered = ((Get-Content $replyAnswer -Raw) -join '').Trim()
if ($delivered -cne 'B: Reuse the Yeo UX key for now') { throw "Clicking B delivered '$delivered'" }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.prompt -eq 0 -and $c.live -eq 0 -and $c.chosen -eq 1 } 'chosen card highlighted and cards no longer clickable'
Snapshot 'after'
$firstState = Read-Choices
Click-Card $transcript $firstState.cards[0]
Start-Sleep -Seconds 2
$again = Read-Choices
if ($again.chosen -ne 1 -or $again.live -ne 0) { throw 'An answered reply still accepted a click' }
$result.checks += @{ name = 'reply-options-click'; delivered = $delivered; cards = $firstState.count; chosen = $again.chosen; liveAfter = $again.live }

$promptAnswer = Join-Path $scratch 'prompt-answer.txt'
$promptScript = Join-Path $scratch 'question-prompt.ps1'
$promptLines = @'
$bar = ([string][char]0x2500) * 40
$bullet = [string][char]0x00B7
$rows = @(
    'Previous chat',
    $bar,
    "$([char]0x2610) Accent colour",
    'Which contrast colour for the icon?',
    '',
    "$([char]0x276F) 1. Lime",
    '     Bright, friendly, high contrast.',
    '  2. Orange',
    '     Warm, stands out on dark.',
    '  3. Type something.',
    $bar,
    "Enter to select $bullet Tab/Arrow keys to navigate $bullet Esc to cancel"
)
$rows | Out-Host
$key = [Console]::ReadKey($true)
'@
Set-Content -Path $promptScript -Value ($promptLines + "`n" + "Set-Content -Path '$promptAnswer' -Value `$key.KeyChar") -Encoding ASCII
Open-FreshCmd
Type-Text ('powershell -nop -ExecutionPolicy Bypass -File "' + $promptScript + '"')
Press @(0x0D) 'Enter: print the Claude Code question prompt and wait for a key'
Press @(0x12, 0x43) 'Alt+C: open Chat View'
Wait-Until { (Find-Transcript) -ne [IntPtr]::Zero } 'Chat View transcript visible for the question prompt'
$transcript = Find-Transcript
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.prompt -eq 1 -and $c.live -eq 1 -and $c.count -eq 3 } 'question prompt cards painted with the other-answer card'
Snapshot 'prompt-before'
$promptCards = (Read-Choices).cards
Click-Card $transcript $promptCards[1]
Wait-Until { Test-Path $promptAnswer } 'console received the clicked key' 30
$key = ((Get-Content $promptAnswer -Raw) -join '').Trim()
if ($key -cne '2') { throw "Clicking the second question card sent '$key'" }
Wait-Until { $c = Read-Choices; $null -ne $c -and $c.prompt -eq 1 -and $c.chosen -eq 1 } 'question card highlighted after the click'
Snapshot 'prompt-after'
$result.checks += @{ name = 'question-prompt-click'; key = $key; cards = $promptCards.Count }
