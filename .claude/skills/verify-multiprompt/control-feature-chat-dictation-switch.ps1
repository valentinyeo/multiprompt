$script:auditPath = Join-Path $scratch 'roaming/ZigShell/dictation-audit.log'
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 0 } 'two seeded chats restored with the first selected'
Select-Theme 'dark' 'dictation-switch-dark'
Press @(0x12, 0x43) 'Alt+C: open Chat View on the first chat'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
    $script:composerElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    $null -ne $script:composerElement -and -not $script:composerElement.Current.IsOffscreen
} 'owned visible composer on the first chat'
$handle = [IntPtr]$script:composerElement.Current.NativeWindowHandle
if ($script:composerElement.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Composer is not owned by this app' }
[VerifyNative]::BringToForeground($script:window)
Record 'Click the owned composer to recover typing focus from the hidden console'
[VerifyNative]::ClickClient($handle, 8, 8)
Wait-ChatFocus 'Edit' 'dictation-switch-composer'
$composer = [System.Windows.Automation.AutomationElement]::FocusedElement
$handle = [IntPtr]$composer.Current.NativeWindowHandle
if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Dictation requires the owned composer' }
$mic = Get-DictationMic $handle
Assert-DictationMic $mic $false 'dictation-switch-idle'
if ([VerifyNative]::EditText($handle) -cne '') { throw 'The first chat must start with an empty message box' }
Snapshot 'before'
Press @(0x11, 0x44) 'Ctrl+D: start dictation in the first chat'
Wait-Until {
    (Test-Path $script:auditPath) -and @((Read-DictationAudit $script:auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq 1
} 'recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
Assert-DictationMic $mic $true 'dictation-switch-listening'
Snapshot 'listening'
Doctor
Assert-Foreground
$immediate = [Diagnostics.Stopwatch]::StartNew()
Press @(0x11, 0x09) 'Ctrl+Tab: switch to the second chat while dictating'
Wait-Until { (Read-Session).active_tab -eq 1 } 'second chat selected'
Wait-Until {
    @((Read-DictationAudit $script:auditPath) | Where-Object { $_ -match '\tchat-switch\t0$' }).Count -eq 1
} 'switching chats stopped the dictation recording' -Seconds 2 -PollMilliseconds 20
$stoppedMs = $immediate.ElapsedMilliseconds
Snapshot 'action'
$audit = @((Read-DictationAudit $script:auditPath))
if (@($audit | Where-Object { $_ -match '\tcancel\t0$' }).Count -ne 1) { throw 'The chat switch must stop the recording through the existing cancel path' }
foreach ($stage in @('fixture-response-bytes', 'http-status', 'target-chat-composer', 'target-shell', 'shell-output-verified', 'target-browser')) {
    if (@($audit | Where-Object { $_ -match ('\t' + $stage + '\t') }).Count -ne 0) { throw "Switching chats let the recording reach $stage" }
}
Wait-Until {
    @((Read-DictationAudit $script:auditPath) | Where-Object { $_ -match '\taudio-bytes\t89160$' }).Count -eq 1
} 'the recording capture worker finished after the chat switch' -Seconds 2 -PollMilliseconds 20
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
    $script:composerElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    $null -ne $script:composerElement -and -not $script:composerElement.Current.IsOffscreen
} 'owned visible composer on the second chat'
$second = [IntPtr]$script:composerElement.Current.NativeWindowHandle
if ($script:composerElement.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($second, 2) -ne $script:window) { throw 'The second chat composer is not owned by this app' }
Wait-Until { [VerifyNative]::EditText($second) -ceq '' } 'the second chat message box stays empty' -Seconds 1 -PollMilliseconds 10
if ([VerifyNative]::EditText($second) -cne '') { throw 'Dictated text landed in the second chat' }
$micSecond = Get-DictationMic $second
Assert-DictationMic $micSecond $false 'dictation-switch-stopped'
Snapshot 'second-chat'
Press @(0x11, 0x09) 'Ctrl+Tab: return to the first chat'
Wait-Until { (Read-Session).active_tab -eq 0 } 'first chat selected again'
Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'the abandoned dictation left the first chat message box empty' -Seconds 1 -PollMilliseconds 10
if ([VerifyNative]::EditText($handle) -cne '') { throw 'The abandoned dictation words came back to the first chat' }
$audit = @((Read-DictationAudit $script:auditPath))
if (@($audit | Where-Object { $_ -match '\tchat-switch\t0$' }).Count -ne 1) { throw 'A second chat switch stopped a recording that was already stopped' }
foreach ($stage in @('fixture-response-bytes', 'http-status', 'target-chat-composer', 'target-shell')) {
    if (@($audit | Where-Object { $_ -match ('\t' + $stage + '\t') }).Count -ne 0) { throw "The abandoned dictation reached $stage after the round trip" }
}
Save-Json @{ stoppedMilliseconds = $stoppedMs; firstChatBox = [VerifyNative]::EditText($handle); secondChatBox = [VerifyNative]::EditText($second); audit = $audit; mic = $mic; keysSent = @('Ctrl+D', 'Ctrl+Tab', 'Ctrl+Tab') } 'switch-stop.json'
$result.checks += @{ name = 'dictation-stops-on-chat-switch'; passed = $true; stoppedMilliseconds = $stoppedMs; firstChatBox = [VerifyNative]::EditText($handle); secondChatBox = [VerifyNative]::EditText($second); idleMicPixels = $true }
Snapshot 'after'
