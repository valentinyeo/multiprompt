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
    $chat.shellId = [int]$created.tab
    $chats += $chat
}
Wait-Until {
    $state = Read-Session
    if ($null -eq $state) { return $false }
    $bound = @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -in @('live-1', 'live-2') })
    $bound.Count -eq 2 -and @($bound | Where-Object { $_.kind -cne 'tmux' }).Count -eq 0
} 'two saved tabs bound to live-* tmux sessions'
$state = Read-Session
$tabs = @($state.tabs)
foreach ($chat in $chats) {
    $chat.index = -1
    for ($i = 0; $i -lt $tabs.Count; $i++) {
        if (-not $tabs[$i].PSObject.Properties['tmux_session']) { continue }
        if ($tabs[$i].tmux_session -cne $chat.tmux) { continue }
        $chat.index = $i
        if ([int]$tabs[$i].shell_id -ne $chat.shellId) { throw ('saved tab for ' + $chat.tmux + ' carries another id') }
    }
    if ($chat.index -lt 0) { throw ('saved tab for ' + $chat.tmux + ' is missing') }
}
$chatIds = @($chats | ForEach-Object { $_.shellId })
Wait-Until {
    $inbox = Read-Inbox
    $null -ne $inbox -and @($inbox.shells | Where-Object { $_.sid -in $chatIds }).Count -eq 2
} 'published state lists both live chat tabs' 25
Save-Json $state 'session-live-chats.json'
$pageRoot = Join-Path $scratch 'live-chat-pages'
New-Item -ItemType Directory -Force $pageRoot | Out-Null
$pageJob = New-Object VerifyJob
try {
    foreach ($chat in $chats) {
        [IO.File]::WriteAllText((Join-Path $pageRoot ($chat.tmux + '.html')), ('<!doctype html><title>' + $chat.marker + '</title><body style="background:#123456;color:#fff;font:48px sans-serif"><h1>' + $chat.marker + '</h1></body>'))
        $chat.page = 'http://127.0.0.1:19284/' + $chat.tmux + '.html'
        $chat.other = 'http://127.0.0.1:19284/' + $chat.tmux + '-second.html'
        [IO.File]::WriteAllText((Join-Path $pageRoot ($chat.tmux + '-second.html')), ('<!doctype html><title>' + $chat.marker + ' second</title><body style="background:#654321;color:#fff;font:48px sans-serif"><h1>' + $chat.marker + ' second</h1></body>'))
    }
    $pageJob.Start((Get-Command python.exe).Source, $pageRoot, (Join-Path $Evidence 'live-chat-page.stdout.log'), (Join-Path $Evidence 'live-chat-page.stderr.log'), '-m http.server 19284 --bind 127.0.0.1') | Out-Null
    Wait-Until { foreach ($chat in $chats) { try { if (-not (Invoke-WebRequest -UseBasicParsing $chat.page).Content.Contains($chat.marker)) { return $false } } catch { return $false } }; $true } 'both live chat test pages'
    $one = $chats[0]
    $two = $chats[1]
    $selectChat = {
        param([hashtable]$Chat)
        $inbox = Read-Inbox
        if ($null -ne $inbox -and $inbox.active_shell_id -eq $Chat.shellId) { return }
        for ($slot = 1; $slot -le 3; $slot++) {
            Press @(0x11, (0x30 + $slot)) ('Ctrl+' + $slot + ': open sidebar session ' + $slot + ' looking for ' + $Chat.name)
            Start-Sleep -Milliseconds 700
            $inbox = Read-Inbox
            if ($null -ne $inbox -and $inbox.active_shell_id -eq $Chat.shellId) { return }
        }
        for ($row = 0; $row -lt 3; $row++) {
            Doctor
            Assert-Foreground
            Record ('Click sidebar row ' + ($row + 1) + ' looking for ' + $Chat.name)
            [VerifyNative]::ClickClient($script:window, 150, (96 + 60 * $row))
            Start-Sleep -Milliseconds 400
            $inbox = Read-Inbox
            if ($null -ne $inbox -and $inbox.active_shell_id -eq $Chat.shellId) { return }
        }
        Wait-Until { $inbox = Read-Inbox; $null -ne $inbox -and $inbox.active_shell_id -eq $Chat.shellId } ($Chat.name + ' selected')
    }
    & $selectChat $two
    Wait-Until { -not [VerifyNative]::PaneVisible($script:window) } ($two.name + ' shows no browser pane yet') 20
    $twoBefore = Invoke-Zsb @('status') $script:liveChatPort 'chat-two-status-before' -Session $two.tmux
    if ($twoBefore.session -cne $two.tmux -or $twoBefore.pane -cne 'closed') { throw ('zsb status from the ' + $two.tmux + ' chat did not report its own closed pane: ' + (ConvertTo-Json -InputObject $twoBefore -Compress)) }
    Snapshot 'chat-two-without-page'
    & $selectChat $one
    Wait-Until { -not [VerifyNative]::PaneVisible($script:window) } ($one.name + ' shows no browser pane yet') 20
    $oneBefore = Invoke-Zsb @('status') $script:liveChatPort 'chat-one-status-before' -Session $one.tmux
    if ($oneBefore.session -cne $one.tmux -or $oneBefore.pane -cne 'closed') { throw ('zsb status from the ' + $one.tmux + ' chat did not report its own closed pane: ' + (ConvertTo-Json -InputObject $oneBefore -Compress)) }
    $oneOpen = Invoke-Zsb @('open', $one.page) $script:liveChatPort 'chat-one-open' -Session $one.tmux -AllowPlainOk
    Wait-Until {
        $pane = Read-BrowserPaneFor $one.shellId
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::PaneVisible($script:window)
    } ($one.name + ' pane opened by its own zsb open') 25
    $oneStatus = Invoke-Zsb @('status') $script:liveChatPort 'chat-one-status' -Session $one.tmux
    if ($oneStatus.session -cne $one.tmux -or $oneStatus.pane -cne 'open' -or $oneStatus.windowId -le 0) { throw ('zsb status from the ' + $one.tmux + ' chat did not find that chat pane: ' + (ConvertTo-Json -InputObject $oneStatus -Compress)) }
    $onePane = Invoke-Zsb @('pane-info') $script:liveChatPort 'chat-one-pane-info' -Session $one.tmux
    if ($onePane.tab_name -cne $one.name -or [int]$onePane.shell_id -ne $one.shellId) { throw ('pane-info from the ' + $one.tmux + ' chat named another tab: ' + (ConvertTo-Json -InputObject $onePane -Compress)) }
    $oneWant = ([string]$one.page).TrimEnd('/')
    $oneTables = Invoke-Zsb @('tabs') $script:liveChatPort 'chat-one-tabs' -Session $one.tmux
    if (@($oneTables.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $oneWant }).Count -ne 1) { throw ('The ' + $one.tmux + ' chat pane holds no tab for ' + $one.page) }
    Snapshot 'chat-one-page'
    $oneNavigate = Invoke-Zsb @('navigate', $one.other) $script:liveChatPort 'chat-one-navigate' -Session $one.tmux
    $oneOtherWant = ([string]$one.other).TrimEnd('/')
    if (([string]$oneNavigate.result.tab.url).TrimEnd('/') -cne $oneOtherWant -or $oneNavigate.result.tab.title -cne ($one.marker + ' second')) { throw ('zsb navigate from the ' + $one.tmux + ' chat did not reach that chat pane: ' + (ConvertTo-Json -InputObject $oneNavigate -Compress)) }
    $oneAgainTabs = Invoke-Zsb @('tabs') $script:liveChatPort 'chat-one-tabs-second' -Session $one.tmux
    if (@($oneAgainTabs.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $oneOtherWant }).Count -ne 1) { throw ('The ' + $one.tmux + ' chat pane lost the page its agent opened') }
    $result.checks += @{ name = 'chat-one-agent-path'; session = $one.tmux; tab = $one.shellId; beforeOpen = $oneBefore; opened = $oneOpen; status = $oneStatus; paneInfo = $onePane; navigated = $oneNavigate.result.tab; page = $one.page }
    Wait-Until {
        $pane = Read-BrowserPaneFor $two.shellId
        $null -ne $pane -and $pane.PSObject.Properties['browser_state'] -and $pane.browser_state -eq 'closed' -and $pane.browser_connection_id -eq 0
    } ('The ' + $two.tmux + ' chat still keeps no browser pane') 20
    $twoOpen = Invoke-Zsb @('open', $two.page) $script:liveChatPort 'chat-two-open' -Session $two.tmux -AllowPlainOk
    Wait-Until {
        $pane = Read-BrowserPaneFor $two.shellId
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0
    } ($two.name + ' opens its own pane in the background') 25
    $twoStatus = Invoke-Zsb @('status') $script:liveChatPort 'chat-two-status' -Session $two.tmux
    if ($twoStatus.session -cne $two.tmux -or $twoStatus.pane -cne 'open' -or $twoStatus.windowId -le 0) { throw ('zsb status from the ' + $two.tmux + ' chat did not find that chat pane: ' + (ConvertTo-Json -InputObject $twoStatus -Compress)) }
    if ($twoStatus.windowId -eq $oneStatus.windowId) { throw 'Both live chats reported the same browser window' }
    $twoPane = Invoke-Zsb @('pane-info') $script:liveChatPort 'chat-two-pane-info' -Session $two.tmux
    if ($twoPane.tab_name -cne $two.name -or [int]$twoPane.shell_id -ne $two.shellId) { throw ('pane-info from the ' + $two.tmux + ' chat named another tab: ' + (ConvertTo-Json -InputObject $twoPane -Compress)) }
    $twoWant = ([string]$two.page).TrimEnd('/')
    $twoTables = Invoke-Zsb @('tabs') $script:liveChatPort 'chat-two-tabs' -Session $two.tmux
    if (@($twoTables.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $twoWant }).Count -ne 1) { throw ('The ' + $two.tmux + ' chat pane holds no tab for ' + $two.page) }
    if (@($twoTables.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $oneWant }).Count -ne 0) { throw ('The ' + $two.tmux + ' chat pane holds the other chat page') }
    if (@($twoTables.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $oneOtherWant }).Count -ne 0) { throw ('The ' + $two.tmux + ' chat pane holds the page the other chat navigated to') }
    Snapshot 'chat-two-own-page'
    $result.checks += @{ name = 'chat-two-own-page'; session = $two.tmux; tab = $two.shellId; beforeOpen = $twoBefore; opened = $twoOpen; status = $twoStatus; paneInfo = $twoPane; page = $two.page }
    $oneKept = Invoke-Zsb @('status') $script:liveChatPort 'chat-one-status-after' -Session $one.tmux
    if ($oneKept.pane -cne 'open' -or $oneKept.windowId -ne $oneStatus.windowId) { throw ('The ' + $one.tmux + ' chat lost its own pane after the other chat opened one: ' + (ConvertTo-Json -InputObject $oneKept -Compress)) }
    $oneKeptTabs = Invoke-Zsb @('tabs') $script:liveChatPort 'chat-one-tabs-after' -Session $one.tmux
    if (@($oneKeptTabs.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $oneOtherWant }).Count -ne 1) { throw ('The ' + $one.tmux + ' chat lost its own page after the other chat opened one') }
    if (@($oneKeptTabs.result.tabs | Where-Object { $_.url -and ([string]$_.url).TrimEnd('/') -ceq $twoWant }).Count -ne 0) { throw ('The ' + $one.tmux + ' chat shows the other chat page') }
    Snapshot 'chat-one-keeps-page'
    $result.checks += @{ name = 'chats-keep-their-own-pages'; first = $one.tmux; second = $two.tmux; firstStatusAfter = $oneKept; firstWindowId = $oneStatus.windowId; secondWindowId = $twoStatus.windowId; firstPage = $one.page; secondPage = $two.page }
    Save-Json (Read-BrowserPaneFor $one.shellId) 'pane-chat-one.json'
    Save-Json (Read-BrowserPaneFor $two.shellId) 'pane-chat-two.json'
    $result.chatBoundary.verified = $true
    $result.chatBoundary.observed = @{ chats = @($chats | ForEach-Object { @{ tmux = $_.tmux; tab = $_.shellId; page = $_.page } }); port = $script:liveChatPort }
    Save-Json (Read-Session) 'session-live-chats-after.json'
} finally {
    $null = $pageJob.Stop()
    $pageJob.Dispose()
}
