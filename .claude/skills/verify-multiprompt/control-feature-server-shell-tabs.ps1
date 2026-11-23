$result.serverShellTabs = @{
    soft3002 = 'A saved tmux row with no session name survives launch and restart, and Reopen server shell attaches a detached session'
    soft3003 = 'The desktop opens a plain VPS shell tab on the chat host below the chat tab and runs the chat folder first'
}

function Save-ShellCheck([string]$Name, [hashtable]$Values) {
    $check = [ordered]@{ name = $Name }
    foreach ($key in $Values.Keys) { $check[$key] = $Values[$key] }
    $result.checks += $check
}

function Get-LiveShellTransports {
    $live = @{}
    foreach ($file in @(Get-ChildItem (Join-Path $shellState 'transport-*.txt') -ErrorAction SilentlyContinue)) {
        $transportPid = [int]($file.BaseName -replace '^transport-', '')
        if ($null -eq (Get-Process -Id $transportPid -ErrorAction SilentlyContinue)) { continue }
        $live[$transportPid] = (Get-Content $file.FullName -Raw).Trim()
    }
    return $live
}

function Find-ConsumerConsole {
    $script:consoleWindow = [IntPtr]::Zero
    Wait-Until {
        $after = [IntPtr]::Zero
        while ($true) {
            $candidate = [VerifyNative]::FindWindowEx($script:window, $after, 'MPTerminal', $null)
            if ($candidate -eq [IntPtr]::Zero) { return $false }
            $after = $candidate
            if ([VerifyNative]::IsWindowVisible($candidate) -and [VerifyNative]::GetAncestor($candidate, 2) -eq $script:window) {
                $script:consoleWindow = $candidate
                return $true
            }
        }
    } 'visible native terminal for the active server tab' 60
    $client = New-Object VerifyNative+Rect
    Wait-Until {
        [void][VerifyNative]::GetClientRect($script:consoleWindow, [ref]$client)
        $client.Right -gt 0 -and $client.Bottom -gt 0
    } 'native terminal client area' 30
    [VerifyNative]::ClickClient($script:consoleWindow, [int]($client.Right / 2), [int]($client.Bottom - 12))
    Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -eq $script:consoleWindow } 'native terminal holds keyboard focus' 30
    return $script:consoleWindow
}

$shellState = $serverShellTabsState
$interruptFile = Join-Path $shellState 'interrupt.json'
$invocations = Join-Path $shellState 'invocations.jsonl'
$chatFolder = '/home/inne/projects/sample'

Wait-Until {
    $saved = Read-Session
    @($saved.tabs | Where-Object { $_.name -ceq 'Server work' -and $_.kind -ceq 'tmux' }).Count -eq 1 -and
        @($saved.tabs | Where-Object { $_.name -ceq 'Server shell' }).Count -eq 1
} 'the saved tmux row without a session name and the plain server shell tabs both load' 120
$launchSession = Read-Session
Save-Json $launchSession 'server-shell-tabs-launch.json'
Record 'SOFT-3002: the session-less tmux row is still a tab after the first launch'

Wait-Until {
    @((Get-LiveShellTransports).Values | Where-Object { $_ -ceq 'server-shell' }).Count -eq 1
} 'the plain server shell attached its remote transport before the restart' 90
$beforeRestart = Get-LiveShellTransports
$beforePids = @($beforeRestart.Keys)
Save-Json @{ step = 'before-restart'; transports = $beforeRestart } 'server-shell-tabs-before-restart.json'
Snapshot 'before'

Restart-SessionRestore 'server-shell-restart' $false
$restartTick = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Wait-Until {
    $saved = Read-Session
    @($saved.tabs | Where-Object { $_.name -ceq 'Server work' -and $_.kind -ceq 'tmux' }).Count -eq 1 -and
        @($saved.tabs | Where-Object { $_.name -ceq 'Server shell' }).Count -eq 1
} 'both server tabs came back after the restart' 120
Save-Json (Read-Session) 'server-shell-tabs-after-restart.json'

Wait-Until {
    $live = Get-LiveShellTransports
    @($live.GetEnumerator() | Where-Object { $_.Value -ceq 'server-shell' -and $_.Key -notin $beforePids }).Count -eq 1
} 'the restored plain server shell opened a fresh remote transport' 120
$afterPids = @((Get-LiveShellTransports).Keys)
Remove-Item -LiteralPath $interruptFile -ErrorAction SilentlyContinue
[void](Find-ConsumerConsole)
Press @(0x11, 0x43) 'Ctrl+C in the restored server shell with nothing selected'
Wait-Until { Test-Path $interruptFile } 'the restored server shell received the keystroke' 30
$interruptReceipt = Get-Content $interruptFile -Raw | ConvertFrom-Json
Save-Json @{ step = 'after-restart'; beforePids = $beforePids; afterPids = $afterPids; inputBytes = $interruptReceipt.bytes } 'server-shell-tabs-input.json'
Snapshot 'server-shell-after-restart'
Save-ShellCheck 'SOFT-3002 restore' @{ passed = $true; launch = 'server-shell-tabs-launch.json'; afterRestart = 'server-shell-tabs-after-restart.json'; input = 'server-shell-tabs-input.json'; screenshot = 'server-shell-after-restart.png' }

$plainIndex = -1
for ($i = 0; $i -lt @((Read-Session).tabs).Count; $i++) { if ((Read-Session).tabs[$i].name -ceq 'Server shell') { $plainIndex = $i } }
if ($plainIndex -lt 0 -or $plainIndex -gt 8) { throw 'The plain server shell tab is not addressable by Ctrl+digit' }
if ([int](Read-Session).active_tab -ne $plainIndex) {
    Press @(0x11, (0x31 + $plainIndex)) ('Ctrl+' + ($plainIndex + 1) + ': select the plain server shell tab before closing it')
}
Wait-Until { (Read-Session).tabs[(Read-Session).active_tab].name -ceq 'Server shell' } 'plain server shell tab selected'
Press @(0x11, 0x10, 0x57) 'Ctrl+Shift+W: delete the server shell session'
Wait-Until {
    $saved = Read-Session
    @($saved.tabs | Where-Object { $_.name -ceq 'Server shell' }).Count -eq 0 -and
        @($saved.tabs | Where-Object { $_.name -ceq 'Server work' }).Count -eq 1
} 'the server shell tab closed and the server work tab stayed' 60

Wait-Until {
    if (-not (Test-Path $invocations)) { return $false }
    @(Get-Content $invocations | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } | Where-Object { $null -ne $_ -and $_.operation -eq 'list-sessions' -and $_.ms -gt $restartTick }).Count -ge 1
} 'the app polled the detached tmux sessions on the server after the restart' 120
Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
Type-Text 'reopen server shell'
Snapshot 'server-shell-reopen-row'
Press @(0x0D) 'Enter: Reopen server shell'
Start-Sleep -Milliseconds 600
Type-Text 'verify-agent-1'
Press @(0x0D) 'Enter: attach the detached verify-agent-1 session'
Wait-Until {
    @((Read-Session).tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-agent-1' }).Count -eq 1
} 'Reopen server shell attached verify-agent-1' 90
Wait-Until {
    @((Get-LiveShellTransports).Values | Where-Object { $_ -ceq 'verify-agent-1' }).Count -eq 1
} 'the reopened server shell attached to its remote session' 90
Snapshot 'action'
Save-Json @{ step = 'reopened'; transports = (Get-LiveShellTransports); session = (Read-Session) } 'server-shell-tabs-reopened.json'
Save-ShellCheck 'SOFT-3002 reopen' @{ passed = $true; command = 'Ctrl+K Reopen server shell'; session = 'verify-agent-1'; screenshot = 'action.png'; state = 'server-shell-tabs-reopened.json' }

$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$script:zsbPort = 0
Wait-Until {
    if (-not (Test-Path $log)) { return $false }
    $listeners = [regex]::Matches(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
    if ($listeners.Count -eq 0) { return $false }
    $script:zsbPort = [int]$listeners[$listeners.Count - 1].Groups[1].Value
    @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
} 'app-owned loopback tunnel-inbound listener after the restart' 60
$listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
$anchor = $null
$anchorWorkspace = ''
foreach ($workspace in @($listed.workspaces)) {
    foreach ($tab in @($workspace.tabs)) { if ($tab.tmux -ceq 'verify-agent-1') { $anchor = $tab; $anchorWorkspace = $workspace.name } }
    foreach ($group in @($workspace.groups)) {
        foreach ($tab in @($group.tabs)) { if ($tab.tmux -ceq 'verify-agent-1') { $anchor = $tab; $anchorWorkspace = $workspace.name } }
    }
}
if ($null -eq $anchor -or -not $anchor.host) { throw 'workspace-list did not report the reopened server tab host' }
$chatRun = 'cd ' + $chatFolder + ' && exec ${SHELL:-bash} -l'
$openArgs = @('shell-open', '--workspace', $anchorWorkspace, '--after-tab', [string]$anchor.id, '--host', $anchor.host, '--name', 'Chat shell', '--run', $chatRun)
$opened = Invoke-Zsb $openArgs $script:zsbPort 'shell-open'
Wait-Until {
    $saved = Read-Session
    $tabs = @($saved.tabs)
    $indexes = @()
    for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Chat shell') { $indexes += $i } }
    $anchorIndexes = @()
    for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].PSObject.Properties['tmux_session'] -and $tabs[$i].tmux_session -ceq 'verify-agent-1') { $anchorIndexes += $i } }
    $indexes.Count -eq 1 -and $anchorIndexes.Count -eq 1 -and $indexes[0] -eq $anchorIndexes[0] + 1 -and [int]$tabs[$indexes[0]].tmux_host -eq 0
} 'the chat shell tab opened below its anchor on the chat host' 90
Wait-Until {
    $live = Get-LiveShellTransports
    @($live.GetEnumerator() | Where-Object { $_.Value -ceq 'server-shell' -and $_.Key -notin $afterPids }).Count -eq 1
} 'the new server shell connected to the chat host' 120
$request = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $Evidence 'shell-open.request.bin')))
if ($request -notlike ('*' + $chatFolder + '*')) { throw 'The recorded shell-open request lost the chat folder' }
Save-Json @{ step = 'chat-shell'; request = $request; reply = $opened; transports = (Get-LiveShellTransports); session = (Read-Session) } 'server-shell-tabs-chat-shell.json'
Snapshot 'server-shell-chat-tab'
Snapshot 'after'
Save-ShellCheck 'SOFT-3003' @{ passed = $true; host = $anchor.host; workspace = $anchorWorkspace; afterTab = $anchor.id; folder = $chatFolder; splash = 'server-shell-chat-tab.png'; state = 'server-shell-tabs-chat-shell.json' }
