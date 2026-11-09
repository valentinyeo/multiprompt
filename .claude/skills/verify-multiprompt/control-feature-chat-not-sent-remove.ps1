$script:browserShellId = 1
$outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
$debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$stuckKey = $script:notSentKey
$stuckText = $script:notSentText
function Read-StuckMessages {
    if (-not (Test-Path -LiteralPath $outboxPath)) { return @() }
    try { $outbox = Get-Content -LiteralPath $outboxPath -Raw | ConvertFrom-Json } catch { throw "Outbox JSON unreadable: $_" }
    $found = @()
    foreach ($queue in @($outbox.queues)) {
        foreach ($message in @($queue.messages)) {
            if ($message.t -ne $stuckText) { continue }
            $found += $message
            if ($queue.key) { $script:stuckKey = $queue.key }
        }
    }
    return $found
}
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 } 'seeded session restored'
$seeded = Read-StuckMessages
if (@($seeded).Count -ne 1) { throw 'The stuck message from the old session is not in the outbox after launch' }
Save-Json $seeded 'outbox-before.json'
Press @(0x12, 0x43) 'Alt+C: open Chat View'
Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count -eq 1
} 'visible native Chat View transcript control'
Wait-ChatFocus 'Edit' 'not-sent-composer'
Wait-Until {
    (Test-Path $debugLog) -and (Get-Content $debugLog -Raw) -match '\[switch\] chat content shown shell='
} 'transcript content painted before removal' 45
Start-Sleep -Seconds 2
Press @(0x11, 0x41) 'Ctrl+A: clear composer before remove'
Press @(0x08) 'Backspace: empty composer before remove'
Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -ne [IntPtr]::Zero } 'composer still focused before Delete' 15
Press @(0x1B) 'Escape: leave message focus before remove'
Wait-ChatFocus 'Edit' 'not-sent-composer after Escape'
Snapshot 'action'
Assert-Foreground
$removed = $false
for ($attempt = 1; $attempt -le 3 -and -not $removed; $attempt++) {
    Wait-ChatFocus 'Edit' "not-sent-composer attempt $attempt"
    Press @(0x2E) "Delete: Remove the Not sent message, attempt $attempt"
    try {
        $waitSeconds = if ($attempt -eq 3) { 30 } else { 10 }
        Wait-Until { $left = Read-StuckMessages; @($left).Count -eq 0 } "Remove cleared the old-session message, attempt $attempt" $waitSeconds
        $removed = $true
    } catch { if ($attempt -eq 3) { Snapshot 'remove-failed'; throw } }
}
Save-Json @{ removed = $removed; key = $stuckKey; text = $stuckText; remaining = @(Read-StuckMessages).Count } 'outbox-after.json'
$result.checks += @{ name = 'old-session-not-sent-removed'; entry = 'Delete with empty composer'; removed = $removed }
Snapshot 'after'
