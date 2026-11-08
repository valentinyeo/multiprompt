$script:browserShellId = 1
$outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
$debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$stuckKey = $script:notSentKey
$stuckText = $script:notSentText
function Read-StuckMessages {
    if (-not (Test-Path -LiteralPath $outboxPath)) { return @() }
    try { $outbox = Get-Content -LiteralPath $outboxPath -Raw | ConvertFrom-Json } catch { return $null }
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
Snapshot 'action'
Assert-Foreground
Focus-Palette 'discard unsent' 6368
Press @(0x0D) 'Enter: Chat View discard unsent messages'
Wait-Until { $left = Read-StuckMessages; $null -ne $left -and @($left).Count -eq 0 } 'Discard removed the old-session message' 30
Save-Json @{ removed = $true; key = $stuckKey; text = $stuckText; remaining = @(Read-StuckMessages).Count } 'outbox-after.json'
$result.checks += @{ name = 'old-session-not-sent-removed'; entry = 'Ctrl+K discard unsent'; removed = $true }
Snapshot 'after'
