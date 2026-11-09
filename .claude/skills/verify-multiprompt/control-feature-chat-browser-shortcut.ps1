$script:browserShellId = (Read-Inbox).shells[0].sid
$debug = Join-Path $scratch 'roaming/ZigShell/debug.log'
Press @(0x12, 0x43) 'Alt+C: open Chat View'
Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved for the only session'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count -eq 1
} 'visible native Chat View transcript control'
Start-Sleep -Seconds 3
Snapshot 'chat-view'
$closedBefore = Read-BrowserPane
if ($closedBefore.browser_state -ne 'closed') { throw 'Browser was already open before Alt+A' }
if ([VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero) { throw 'A browser window was docked before Alt+A' }
$toggles = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=' -ErrorAction SilentlyContinue).Count
Assert-Foreground
Press @(0x12, 0x41) 'Alt+A: open the browser from the Chat View tab'
Wait-Until { @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=' -ErrorAction SilentlyContinue).Count -gt $toggles } 'Alt+A reached the app' 10
$opened = Assert-BrowserPane 'open' 'chat-alt-a'
Focus-BrowserPaneOwner 'chat-alt-a' $opened.browser_connection_id
$browser = [VerifyNative]::DockedPaneWindow($script:window)
if ($browser -eq [IntPtr]::Zero) { throw 'Alt+A left the Browser not open placeholder: no browser window is docked in the pane' }
$class = [VerifyNative]::Class($browser)
$title = [VerifyNative]::Title($browser)
if ($title -match 'Browser not open') { throw 'The docked pane window is the Browser not open placeholder' }
Save-Json @{ state = $opened.browser_state; connection_id = $opened.browser_connection_id; docked = $true; visible = [VerifyNative]::PaneVisible($script:window); window_class = $class; window_title = $title } 'chat-browser-shortcut.json'
$result.checks += @{ name = 'chat-alt-a-opens-browser'; entry = 'Alt+A'; connectionId = $opened.browser_connection_id; windowClass = $class }
Snapshot 'action'
Press-CloseBrowserPane 'Alt+A: close the browser again'
$null = Assert-BrowserPane 'closed' 'chat-alt-a-close'
Snapshot 'after'
