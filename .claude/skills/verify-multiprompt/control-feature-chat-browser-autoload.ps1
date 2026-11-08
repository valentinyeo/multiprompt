$script:browserShellId = 2
$debug = Join-Path $scratch 'roaming/ZigShell/debug.log'
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 0 } 'seeded terminal and chat tabs restored with the terminal selected'
Wait-Until { $null -ne (Read-BrowserPaneFor 2) } 'chat tab published in the Inbox'
Start-Sleep -Seconds 10
$idle = Read-BrowserPaneFor 2
if ($idle.browser_state -eq 'connected' -or [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero) { throw 'The chat tab browser opened before the tab was shown' }
Save-Json $idle 'browser-pane-before-switch.json'
Assert-Foreground
$toggles = @(Select-String -Path $debug -Pattern 'shortcutToggle' -ErrorAction SilentlyContinue).Count
Press @(0x11, 0x09) 'Ctrl+Tab: show the chat tab whose browser slot is on'
Wait-Until { (Read-Session).active_tab -eq 1 } 'chat tab selected'
Snapshot 'action'
Wait-Until {
    $pane = Read-BrowserPane
    $null -ne $pane -and $pane.browser_state -in @('opening', 'connected') -and $pane.browser_connection_id -gt 0
} 'browser started by itself for the shown chat tab' 30
Focus-BrowserPaneOwner 'chat-autoload' (Read-BrowserPane).browser_connection_id
$pane = Read-BrowserPane
$browser = [VerifyNative]::DockedPaneWindow($script:window)
if ($browser -eq [IntPtr]::Zero) { throw 'The chat tab still shows the Browser not open placeholder' }
$after = @(Select-String -Path $debug -Pattern 'shortcutToggle' -ErrorAction SilentlyContinue).Count
if ($after -ne $toggles) { throw 'A browser shortcut was pressed; the browser must start without any key' }
Save-Json @{ state = $pane.browser_state; connection_id = $pane.browser_connection_id; docked = $true; visible = [VerifyNative]::PaneVisible($script:window); shortcut_presses = $after - $toggles; keys_sent = @('Ctrl+Tab') } 'chat-browser-autoload.json'
$result.checks += @{ name = 'chat-switch-starts-browser'; entry = 'Ctrl+Tab'; connectionId = $pane.browser_connection_id; shortcutPresses = 0 }
Snapshot 'after'
