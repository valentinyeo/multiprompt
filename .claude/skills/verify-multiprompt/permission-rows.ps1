$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$keys = Join-Path $scratch 'stub-keys.txt'
$events = Join-Path $scratch 'stub-events.txt'
$agent = Join-Path (Split-Path $Exe) 'claude.exe'
$initial = Read-Session
if ($initial.tabs[$initial.active_tab].PSObject.Properties['cv'] -and $initial.tabs[$initial.active_tab].cv) {
    Press @(0x12, 0x43) 'Alt+C: show console'
}
Type-Text ('"' + $agent + '"')
Press @(0x0D) 'Enter: start permission console stand-in'
Wait-Until { Test-Path (Join-Path $scratch 'stub-pid.txt') } 'permission console ready' 45
$fixturePid = [int](Get-Content (Join-Path $scratch 'stub-pid.txt') -Raw)
$fixtureProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $fixturePid"
if ($null -eq $fixtureProcess -or $fixtureProcess.ExecutablePath -ine $agent) { throw 'Permission fixture identity mismatch' }
Wait-Until {
    $inbox = Read-Inbox
    @($inbox.shells | Where-Object { $_.sid -eq $initial.tabs[$initial.active_tab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
} 'owned Claude stand-in detected' 45
Select-Theme 'amoled' 'permission-amoled'
Press @(0x12, 0x43) 'Alt+C: open permission chat'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $script:permissionTranscript = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    $null -ne $script:permissionTranscript -and -not $script:permissionTranscript.Current.IsOffscreen
} 'owned transcript visible' 45
$transcript = [IntPtr]$script:permissionTranscript.Current.NativeWindowHandle
if ($script:permissionTranscript.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($transcript, 2) -ne $script:window) { throw 'Transcript ownership mismatch' }
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
    $script:permissionComposer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    $null -ne $script:permissionComposer -and -not $script:permissionComposer.Current.IsOffscreen
} 'owned composer visible' 45
$composer = [IntPtr]$script:permissionComposer.Current.NativeWindowHandle
if ($script:permissionComposer.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($composer, 2) -ne $script:window) { throw 'Composer ownership mismatch' }
function Read-PermissionChoices {
    $text = Read-SharedText $log
    $found = [regex]::Matches($text, 'CHAT_CHOICES prompt=(\d) live=(\d) chosen=(-?\d+) n=(\d+)((?: c\d+=-?\d+,-?\d+,-?\d+,-?\d+)*)')
    if ($found.Count -eq 0) { return $null }
    $last = $found[$found.Count - 1]
    $cards = @([regex]::Matches($last.Groups[5].Value, 'c(\d+)=(-?\d+),(-?\d+),(-?\d+),(-?\d+)') | ForEach-Object { @{ index = [int]$_.Groups[1].Value; left = [int]$_.Groups[2].Value; top = [int]$_.Groups[3].Value; right = [int]$_.Groups[4].Value; bottom = [int]$_.Groups[5].Value } })
    return @{ live = [int]$last.Groups[2].Value; chosen = [int]$last.Groups[3].Value; count = [int]$last.Groups[4].Value; cards = $cards }
}
if ($env:RELEASE_TAG) {
    Wait-Until { (Read-SharedText $log) -match '\[chat\] permission rect ' } 'published permission buttons painted' 45
    Snapshot 'before'
    Snapshot 'action'
    Snapshot 'after'
    $result.checks += @{ name = 'published-permission-baseline'; fixture = 'Claude console menu'; scope = 'before screenshot only' }
    return
}
Wait-Until { $c = Read-PermissionChoices; $null -ne $c -and $c.count -eq 3 -and $c.cards.Count -eq 3 -and $c.live -eq 1 } 'three pending permission rows' 45
Snapshot 'before'
Snapshot 'pending'
[VerifyNative]::ClickClient($composer, 8, 8)
Wait-ChatFocus 'Edit' 'permission-composer'
Type-Text 'Keep this draft'
Wait-Until { [VerifyNative]::EditText($composer) -ceq 'Keep this draft' } 'draft typed'
$permissionKeyOffset = (Read-SharedText $keys).Length
$permissionKeyDowns = @([regex]::Matches((Read-SharedText $events), 'KEY .*down=1')).Count
function Read-PermissionKeys { (Read-SharedText $keys).Substring($permissionKeyOffset) }
$expectedKeys = ''
$permissionCases = @(
    foreach ($entry in @('click', 'key', 'alt', 'palette')) {
        @{ entry=$entry; index=0; digit='1'; alt=0x59; command='Chat View: Allow' }
        @{ entry=$entry; index=1; digit='2'; alt=0x4F; command='Chat View: Always allow' }
        @{ entry=$entry; index=2; digit='4'; alt=0x44; command='Chat View: Deny' }
    }
)
$permissionInputs = @()
foreach ($case in $permissionCases) {
    $choices = Read-PermissionChoices
    $card = $choices.cards[$case.index]
    if ($card.index -ne $case.index -or $card.right -le $card.left -or $card.bottom -le $card.top) { throw 'Invalid permission card rectangle' }
    if ($case.entry -eq 'click') {
        Doctor
        Assert-Foreground
        Record ('Click permission row ' + $case.index)
        [VerifyNative]::ClickClient($transcript, [int](($card.left + $card.right) / 2), [int](($card.top + $card.bottom) / 2))
    } elseif ($case.entry -eq 'palette') {
        Invoke-JourneyCommand $case.command
    } else {
        [VerifyNative]::ClickClient($composer, 8, 8)
        Wait-ChatFocus 'Edit' 'permission-shortcut'
        if ($case.entry -eq 'alt') {
            Press @(0x12, $case.alt) ('Permission Alt shortcut ' + ($case.index + 1))
        } else {
            Press @((0x31 + $case.index)) ('Permission shortcut ' + ($case.index + 1))
        }
    }
    $expectedKeys += $case.digit
    Wait-Until { [string]::Equals((Read-PermissionKeys), $expectedKeys, [StringComparison]::Ordinal) } 'exact provider digit received' 45
    Wait-Until { $c = Read-PermissionChoices; $null -ne $c -and $c.chosen -eq $case.index } 'picked row recorded' 45
    Snapshot ($case.entry + '-' + ($case.index + 1) + '-picked')
    if ($case.entry -ne 'key' -and [VerifyNative]::EditText($composer) -cne 'Keep this draft') { throw 'Click changed the existing draft' }
    Doctor
    Assert-Foreground
    [VerifyNative]::ClickClient($transcript, [int](($card.left + $card.right) / 2), [int](($card.top + $card.bottom) / 2))
    Start-Sleep -Milliseconds 700
    if (-not [string]::Equals((Read-PermissionKeys), $expectedKeys, [StringComparison]::Ordinal)) { throw 'Picked permission sent twice' }
    $keyDowns = @([regex]::Matches((Read-SharedText $events), 'KEY .*down=1'))
    if ($keyDowns.Count -ne $permissionKeyDowns + $expectedKeys.Length) { throw 'Unexpected extra console keydown' }
    $permissionInputs += @{ entry=$case.entry; choice=$case.index; digit=$case.digit; received=Read-PermissionKeys; draft=[VerifyNative]::EditText($composer); screenshot=($case.entry + '-' + ($case.index + 1) + '-picked.png') }
    if ($case.entry -eq 'click' -and $case.index -eq 2) {
        [VerifyNative]::ClickClient($composer, 8, 8)
        Press @(0x11, 0x41) 'Select draft'
        Press @(0x08) 'Clear draft for empty-composer shortcuts'
        Wait-Until { [VerifyNative]::EditText($composer) -ceq '' } 'composer empty'
    }
    if ($case.entry -eq 'key' -and [VerifyNative]::EditText($composer) -cne '') { throw 'Permission shortcut changed the composer' }
    if ($case.entry -eq 'key' -and $case.index -eq 2) {
        [VerifyNative]::ClickClient($composer, 8, 8)
        Wait-ChatFocus 'Edit' 'permission-draft-before-alt'
        Type-Text 'Keep this draft'
        Wait-Until { [VerifyNative]::EditText($composer) -ceq 'Keep this draft' } 'draft restored before Alt and palette paths'
    }
    $logBefore = (Read-SharedText $log).Length
    [IO.File]::WriteAllText((Join-Path $scratch 'permission-clear.txt'), 'clear')
    Wait-Until { (Read-SharedText $log).Substring($logBefore) -match '\[chat\] permission cleared' } 'old permission cleared' 45
    [IO.File]::WriteAllText((Join-Path $scratch 'permission-next.txt'), 'next')
    Wait-Until { $c = Read-PermissionChoices; $null -ne $c -and $c.count -eq 3 -and $c.live -eq 1 -and $c.chosen -eq -1 } 'new permission rearmed' 45
}
Snapshot 'action'
Snapshot 'after'
Copy-Item $keys, $events $Evidence
Save-Json @{ keyOffset=$permissionKeyOffset; keyDownOffset=$permissionKeyDowns; inputs=$permissionInputs; providerDigits=$expectedKeys } 'permission-inputs.json'
& node (Join-Path $PSScriptRoot 'chat-control-coverage.test.cjs') --permission-evidence $Evidence
if ($LASTEXITCODE -ne 0) { throw 'Permission route receipts do not cover the declared input matrix' }
$result.checks += @{ name = 'permission-input'; providerDigits = $expectedKeys; clicks = 3; composerKeys = 3; altKeys = 3; palette = 3; draftPreserved = $true; boundary = 'synthetic Claude console; no live provider' }
