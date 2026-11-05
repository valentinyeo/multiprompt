$result.computerBoundary = 'Offline profile; app-owned session-open creates one remote identity. No SSH credentials, remote desktop, VNC connection or agent delivery is verified. Only menu routing, saved pane selection and preserved chat are verified.'
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 } 'one initial local session'
$initial = Read-Session
$groupIds = @()
if ($initial.PSObject.Properties['groups']) { $groupIds = @($initial.groups | ForEach-Object { $_.id }) }
Palette 'move to group'
Press @(0x0D) 'Enter: Move to Group'
Type-Text 'new group'
Press @(0x0D) 'Enter: create isolated group'
Wait-Until {
    $state = Read-Session
    $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups | Where-Object { $_.id -notin $groupIds }).Count -eq 1
} 'user-created group saved'
$baseline = Read-Session
$group = @($baseline.groups | Where-Object { $_.id -notin $groupIds })[0]
$workspace = $baseline.workspaces[$baseline.active_workspace].name
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$script:computerPort = 0
Wait-Until {
    if (-not (Test-Path -LiteralPath $log)) { return $false }
    $listener = [regex]::Match((Get-Content -LiteralPath $log -Raw), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
    if (-not $listener.Success) { return $false }
    $script:computerPort = [int]$listener.Groups[1].Value
    @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:computerPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
} 'app-owned session command listener' 30
$listed = Invoke-Zsb @('workspace-list') $script:computerPort 'workspace-list'
$hostName = $listed.hosts[0]
$created = Invoke-Zsb @('session-open', '--workspace', $workspace, '--group', $group.name, '--host', $hostName, '--tmux', 'verify-computer', '--name', 'Computer parity') $script:computerPort 'session-created'
if ($created.created -ne $true -or $created.tab -le 0) { throw 'Session command did not create the isolated remote identity' }
Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.name -ceq 'Computer parity' }).Count -eq 1 } 'remote identity saved by the app'
Palette 'Computer parity'
Press @(0x0D) 'Enter: select Computer parity chat'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].name -ceq 'Computer parity' } 'remote chat selected'
$selected = Read-Session
if (-not ($selected.tabs[$selected.active_tab].PSObject.Properties['cv'] -and $selected.tabs[$selected.active_tab].cv)) {
    Press @(0x12, 0x43) 'Alt+C: open Chat View'
}
Wait-ChatFocus 'Edit' 'computer-chat'
Assert-ChatTyping 'keep this draft' 'computer-draft'
Save-Json (Read-Session) 'session-before.json'
Snapshot 'before'
Palette 'more menu'
Press @(0x0D) 'Enter: open the existing three-dots menu'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptMoreMenu')
    $menus = @($root.FindAll([System.Windows.Automation.TreeScope]::Children, $condition) | Where-Object { -not $_.Current.IsOffscreen })
    if ($menus.Count -ne 1) { return $false }
    $script:computerMenu = [IntPtr]$menus[0].Current.NativeWindowHandle
    [VerifyNative]::GetAncestor($script:computerMenu, 2) -eq $script:window
} 'visible owned three-dots menu'
Snapshot 'action'
$rows = [regex]::Matches((Get-Content -LiteralPath $log -Raw), '\[chat\] menu computer rect=(\d+),(\d+),(\d+),(\d+)')
if ($rows.Count -eq 0) { throw 'Three-dots menu has no Computer row' }
$row = $rows[$rows.Count - 1]
$x = [int](([int]$row.Groups[1].Value + [int]$row.Groups[3].Value) / 2)
$y = [int](([int]$row.Groups[2].Value + [int]$row.Groups[4].Value) / 2)
Doctor
Assert-Foreground
Record 'Click Computer inside the ownership-checked three-dots menu'
[VerifyNative]::ClickClient($script:computerMenu, $x, $y)
$choicePath = Join-Path $scratch 'roaming/ZigShell/session.json.computer'
Wait-Until {
    (Test-Path -LiteralPath $choicePath) -and (Get-Content -LiteralPath $choicePath -Raw) -match '\A[0-9a-f]{64}1\r?\n\z'
} 'Computer menu action selected the pane' 15
Copy-Item -LiteralPath $choicePath (Join-Path $Evidence 'computer-selected.txt')
$after = Read-Session
if (@($after.tabs).Count -ne @($baseline.tabs).Count + 1 -or $after.tabs[$after.active_tab].name -cne 'Computer parity' -or -not $after.tabs[$after.active_tab].cv) { throw 'Computer menu action changed or closed the chat' }
Save-Json $after 'session-selected.json'
Snapshot 'computer-pane'
Palette 'computer'
Press @(0x0D) 'Enter: return from Computer using its existing toggle'
Wait-Until { (Test-Path -LiteralPath $choicePath) -and [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $choicePath -Raw)) } 'Computer selection cleared by the existing action'
Wait-ChatFocus 'Edit' 'computer-return'
$composer = [System.Windows.Automation.AutomationElement]::FocusedElement
$draft = [VerifyNative]::EditText([IntPtr]$composer.Current.NativeWindowHandle)
if ($draft -cne 'keep this draft') { throw "Computer menu round trip changed the draft: $draft" }
Save-Json @{ draft = $draft; selectedTab = (Read-Session).active_tab; computerChoiceCleared = $true } 'computer-return.json'
Snapshot 'after'
$result.checks += @{ name = 'computer-in-three-dots'; menuEntry = 'Chat View: More Menu'; action = 'Computer'; selectedPane = $true; chatPreserved = $true; draftPreserved = $true; directHeaderButtonAdded = $false; remoteDesktopVerified = $false }
