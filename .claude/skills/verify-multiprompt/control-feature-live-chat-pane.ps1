$result.chatBoundary = @{
    verified = $false
    expected = 'A live chat tab is a tmux tab named live-*, so this journey binds two tabs to live-* session names and drives their zsb requests; the real reader host and Claude agent are not on a Windows runner'
    observed = 'pending'
}
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial session'
$initial = Read-Session
$initialGroupIds = @()
if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
$groupCount = $initialGroupIds.Count
Palette 'move to group'
Press @(0x0D) 'Enter: Move to Group submenu'
Type-Text 'new group'
Press @(0x0D) 'Enter: New group'
Wait-Until {
    $state = Read-Session
    if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
    $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
    $newGroups.Count -eq 1 -and $state.tabs[$state.active_tab].group_id -eq $newGroups[0].id
} 'user-created group contains the initial tab'
$baseline = Read-Session
$group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
Save-Json $baseline 'session-before.json'
$script:liveChatPort = 0
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
Wait-Until {
    if (-not (Test-Path $log)) { return $false }
    $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
    if (-not $listener.Success) { return $false }
    $script:liveChatPort = [int]$listener.Groups[1].Value
    @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:liveChatPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
} 'app-owned loopback tunnel-inbound listener' 30
$listed = Invoke-Zsb @('workspace-list') $script:liveChatPort 'workspace-list'
$workspaceName = $baseline.workspaces[$baseline.active_workspace].name
if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($baseline.active_workspace + 1) }
if (@($listed.hosts).Count -lt 1 -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
$hostName = $listed.hosts[0]
$chats = @()
foreach ($chat in @(
        @{ tmux = 'live-1'; name = 'Live chat one'; marker = 'Live chat one page' },
        @{ tmux = 'live-2'; name = 'Live chat two'; marker = 'Live chat two page' }
    )) {
    $openArgs = @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $hostName, '--tmux', $chat.tmux, '--name', $chat.name)
    $created = Invoke-Zsb $openArgs $script:liveChatPort ('session-open-' + $chat.tmux)
    if ($created.created -ne $true -or $created.tab -le 0) { throw ('session-open did not create the ' + $chat.tmux + ' chat') }
    $chat.shellId = [uint32]$created.tab
    $chats += $chat
}
Wait-Until {
    $state = Read-Session
    if ($null -eq $state) { return $false }
    $bound = @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -in @('live-1', 'live-2') })
    $bound.Count -eq 2 -and @($bound | Where-Object { $_.kind -cne 'tmux' }).Count -eq 0
} 'two saved tabs bound to live-* tmux sessions'
$state = Read-Session
foreach ($chat in $chats) {
    $chat.index = [array]::IndexOf(@($state.tabs | ForEach-Object { $_.shell_id }), $chat.shellId)
    if ($chat.index -lt 0) { throw ('saved tab for ' + $chat.tmux + ' is missing') }
}
Save-Json $state 'session-live-chats.json'
$pageRoot = Join-Path $scratch 'live-chat-pages'
New-Item -ItemType Directory -Force $pageRoot | Out-Null
$pageJob = New-Object VerifyJob
try {
    foreach ($chat in $chats) {
        [IO.File]::WriteAllText((Join-Path $pageRoot ($chat.tmux + '.html')), ('<!doctype html><title>' + $chat.marker + '</title><body style="background:#123456;color:#fff;font:48px sans-serif"><h1>' + $chat.marker + '</h1></body>'))
        $chat.page = 'http://127.0.0.1:19284/' + $chat.tmux + '.html'
    }
    $pageServer = $pageJob.Start((Get-Command python.exe).Source, $pageRoot, (Join-Path $Evidence 'live-chat-page.stdout.log'), (Join-Path $Evidence 'live-chat-page.stderr.log'), '-m http.server 19284 --bind 127.0.0.1')
    Wait-Until { foreach ($chat in $chats) { try { if (-not (Invoke-WebRequest -UseBasicParsing $chat.page).Content.Contains($chat.marker)) { return $false } } catch { return $false } }; $true } 'both live chat test pages'
    $one = $chats[0]
    $two = $chats[1]
    Press @(0x11, (0x31 + $one.index)) ('Ctrl+' + ($one.index + 1) + ': select ' + $one.name)
    Wait-Until { (Read-Inbox).active_shell_id -eq $one.shellId } ($one.name + ' selected')
    Palette 'open browser'
    Press @(0x0D) ('Enter: open ' + $one.name + ' browser pane')
    Wait-Until {
        $pane = Read-BrowserPaneFor $one.shellId
        $null -ne $pane -and $pane.browser_state -in @('opening', 'connected') -and $pane.browser_connection_id -gt 0
    } ($one.name + ' browser pane opening')
    Wait-Until {
        $pane = Read-BrowserPaneFor $one.shellId
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::PaneVisible($script:window)
    } ($one.name + ' pane docked with an extension window id') 25
    Save-Json (Read-BrowserPaneFor $one.shellId) 'pane-chat-one-connected.json'
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'main window foreground'
    $oneStatus = Invoke-Zsb @('status') $script:liveChatPort 'chat-one-status' -Session $one.tmux
    if ($oneStatus.session -cne $one.tmux -or $oneStatus.pane -cne 'open' -or $oneStatus.windowId -le 0) { throw ('zsb status from the ' + $one.tmux + ' chat did not find that chat pane: ' + (ConvertTo-Json -InputObject $oneStatus -Compress)) }
    $oneNavigate = Invoke-Zsb @('navigate', $one.page) $script:liveChatPort 'chat-one-navigate' -Session $one.tmux
    if ($oneNavigate.ok -ne $true) { throw ('zsb navigate from the ' + $one.tmux + ' chat failed') }
    Wait-Until { [VerifyNative]::Title([VerifyNative]::PaneWindow($script:window)).Contains($one.marker) } ($one.name + ' pane shows ' + $one.marker) 25
    Snapshot 'chat-one-page'
    $result.checks += @{ name = 'chat-one-agent-path'; session = $one.tmux; tab = $one.shellId; status = $oneStatus; page = $one.page; paneTitle = [VerifyNative]::Title([VerifyNative]::PaneWindow($script:window)) }
    $twoBefore = Read-BrowserPaneFor $two.shellId
    if ($null -eq $twoBefore -or $twoBefore.browser_state -ne 'closed' -or $twoBefore.browser_connection_id -ne 0) { throw ('The ' + $two.tmux + ' chat gained a browser pane from the other chat request') }
    Snapshot 'chat-one-page-chat-two-closed'
    Press @(0x11, (0x31 + $two.index)) ('Ctrl+' + ($two.index + 1) + ': select ' + $two.name)
    Wait-Until { (Read-Inbox).active_shell_id -eq $two.shellId } ($two.name + ' selected')
    if ([VerifyNative]::PaneVisible($script:window)) { throw ('The ' + $two.name + ' tab shows another chat browser page') }
    $twoStatus = Invoke-Zsb @('status') $script:liveChatPort 'chat-two-status' -Session $two.tmux
    if ($twoStatus.session -cne $two.tmux -or $twoStatus.pane -cne 'closed') { throw ('zsb status from the ' + $two.tmux + ' chat did not report its own closed pane') }
    Snapshot 'chat-two-without-page'
    Palette 'open browser'
    Press @(0x0D) ('Enter: open ' + $two.name + ' browser pane')
    Wait-Until {
        $pane = Read-BrowserPaneFor $two.shellId
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::PaneVisible($script:window)
    } ($two.name + ' pane docked with an extension window id') 25
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'main window foreground'
    $twoNavigate = Invoke-Zsb @('navigate', $two.page) $script:liveChatPort 'chat-two-navigate' -Session $two.tmux
    if ($twoNavigate.ok -ne $true) { throw ('zsb navigate from the ' + $two.tmux + ' chat failed') }
    Wait-Until { [VerifyNative]::Title([VerifyNative]::PaneWindow($script:window)).Contains($two.marker) } ($two.name + ' pane shows ' + $two.marker) 25
    Snapshot 'chat-two-own-page'
    Save-Json (Read-BrowserPaneFor $two.shellId) 'pane-chat-two-connected.json'
    $result.checks += @{ name = 'chat-two-own-page'; session = $two.tmux; tab = $two.shellId; page = $two.page; paneTitle = [VerifyNative]::Title([VerifyNative]::PaneWindow($script:window)) }
    Press @(0x11, (0x31 + $one.index)) ('Ctrl+' + ($one.index + 1) + ': return to ' + $one.name)
    Wait-Until { (Read-Inbox).active_shell_id -eq $one.shellId } ($one.name + ' selected again')
    Wait-Until { [VerifyNative]::Title([VerifyNative]::PaneWindow($script:window)).Contains($one.marker) } ($one.name + ' pane kept ' + $one.marker) 25
    $oneAgain = Invoke-Zsb @('status') $script:liveChatPort 'chat-one-status-after' -Session $one.tmux
    if ($oneAgain.pane -cne 'open' -or $oneAgain.windowId -le 0) { throw ('The ' + $one.tmux + ' chat lost its own pane after the other chat opened one') }
    Snapshot 'chat-one-keeps-page'
    $result.checks += @{ name = 'chats-keep-their-own-pages'; first = $one.tmux; second = $two.tmux; firstStatusAfter = $oneAgain; firstPage = $one.page; secondPage = $two.page }
    $result.chatBoundary.verified = $true
    $result.chatBoundary.observed = @{ chats = @($chats | ForEach-Object { @{ tmux = $_.tmux; tab = $_.shellId; page = $_.page } }); port = $script:liveChatPort }
    Save-Json (Read-Session) 'session-live-chats-after.json'
} finally {
    $null = $pageJob.Stop()
    $pageJob.Dispose()
}
