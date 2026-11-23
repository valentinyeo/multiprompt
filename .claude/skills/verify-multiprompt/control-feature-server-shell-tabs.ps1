Add-Type -AssemblyName System.Windows.Forms
$proofLog = Join-Path $scratch 'roaming/ZigShell/debug.log'

function Focus-ProofShell {
    $script:proofTerminal = [IntPtr]::Zero
    Wait-Until {
        $after = [IntPtr]::Zero
        while ($true) {
            $candidate = [VerifyNative]::FindWindowEx($script:window, $after, 'MPTerminal', $null)
            if ($candidate -eq [IntPtr]::Zero) { return $false }
            $after = $candidate
            if ([VerifyNative]::IsWindowVisible($candidate)) { $script:proofTerminal = $candidate; return $true }
        }
    } 'visible native terminal for the active server shell' 60
    $script:proofClient = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofTerminal, [ref]$script:proofClient)
    [VerifyNative]::ClickClient($script:proofTerminal, [int]($script:proofClient.Right / 2), [int]($script:proofClient.Bottom - 12))
    Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -eq $script:proofTerminal } 'server shell owns keyboard focus' 30
}

function Proof-Palette([string]$Query, [int]$Target, [string]$Shot) {
    $offset = (Read-SharedText $proofLog).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' } 'empty command palette'
    Type-Text $Query
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match ("\[palette\] ready chars=" + $Query.Length + " count=\d+ target=" + $Target + '(?:\s|$)') } ('exact palette command: ' + $Query)
    Snapshot $Shot
    Press @(0x0D) ('Enter: ' + $Query)
}

function Proof-Line([string]$Command) {
    Focus-ProofShell
    Type-Text $Command
    Press @(0x0D) ('Enter: ' + $Command)
}

function Proof-Check([string]$Ticket, [scriptblock]$Journey) {
    $check = @{ name = $Ticket; passed = $false }
    $result.checks += $check
    try {
        & $Journey
        $check.passed = $true
    } catch {
        $check.error = $_.Exception.Message
        Snapshot ($Ticket + '-failure')
        try { Press @(0x1B) 'Escape: dismiss any open overlay after the failed case' } catch {}
    }
    Save-Json $check ($Ticket + '-result.json')
}

Proof-Palette 'server shell proof' 1 'SOFT-3001-shell-row'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_session -ceq 'proof-shell' } 'proof-shell selected'

Proof-Check 'SOFT-3001' {
    Wait-Until { (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_attached}"' 'shell-attached').Trim() -eq '1' } 'real tmux shell transport attached before typing' 90
    Proof-Line 'python3 /home/mpverify/shell-proof.py'
    Wait-Until {
        try { $script:heartbeat = (Read-ProofServer 'cat /home/mpverify/shell-heartbeat.json' 'heartbeat-ready') | ConvertFrom-Json; return $script:heartbeat.tick -gt 0 } catch { return $false }
    } 'real remote command is running' 30
    Focus-ProofShell
    [System.Windows.Forms.Clipboard]::SetText('clipboard sentinel before selected Ctrl+C')
    [VerifyNative]::DragSelectClient($script:proofTerminal, 1, 1, [int]($script:proofClient.Right - 2), 1)
    Snapshot 'SOFT-3001-selected'
    $before = (Read-ProofServer 'cat /home/mpverify/shell-heartbeat.json' 'heartbeat-before-copy') | ConvertFrom-Json
    Press @(0x11, 0x43) 'Ctrl+C: copy the exact first terminal row while the command runs'
    Wait-Until { [System.Windows.Forms.Clipboard]::GetText() -cne 'clipboard sentinel before selected Ctrl+C' } 'Ctrl+C changed the clipboard' 10
    $copied = [System.Windows.Forms.Clipboard]::GetText()
    $expected = 'SOFT3001-COPY-EXACT'.PadRight([int]$before.columns)
    [IO.File]::WriteAllText((Join-Path $Evidence 'SOFT-3001-clipboard.txt'), $copied)
    [IO.File]::WriteAllText((Join-Path $Evidence 'SOFT-3001-expected.txt'), $expected)
    if ($copied -cne $expected) { throw 'Clipboard does not equal the selected terminal row, including its trailing spaces' }
    Wait-Until {
        $script:afterCopy = (Read-ProofServer 'cat /home/mpverify/shell-heartbeat.json; test ! -e /home/mpverify/shell-interrupt.json' 'heartbeat-after-copy') | ConvertFrom-Json
        $script:afterCopy.pid -eq $before.pid -and $script:afterCopy.tick -gt $before.tick
    } 'the same command kept running without an interrupt after selected Ctrl+C' 10
    Save-Json @{ before = $before; after = $script:afterCopy; exactClipboard = $true } 'SOFT-3001-copy.json'
    Snapshot 'SOFT-3001-copied-running'
    Press @(0x11, 0x43) 'Ctrl+C: interrupt with no selection'
    Wait-Until {
        try { $script:interrupt = (Read-ProofServer 'cat /home/mpverify/shell-interrupt.json' 'interrupt-receipt') | ConvertFrom-Json; return $script:interrupt.pid -eq $before.pid -and $script:interrupt.interrupted } catch { return $false }
    } 'the same command received an interrupt with no selection' 20
    Save-Json $script:interrupt 'SOFT-3001-interrupt.json'
    Snapshot 'SOFT-3001-interrupted'
}

Proof-Check 'SOFT-3002' {
    Focus-ProofShell
    Press @(0x11, 0x43) 'Ctrl+C: clear any surviving shell command'
    Press @(0x11, 0x43) 'Ctrl+C: leave no selection or blocking command'
    $identity = (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_id}|#{pane_id}|#{pane_pid}"' 'session-before-restart').Trim()
    Proof-Line 'echo before-restart > /home/mpverify/shell-restore.txt; echo SOFT3002-BEFORE-RESTART'
    Wait-Until { (Read-ProofServer 'cat /home/mpverify/shell-restore.txt' 'restore-before-input').Trim() -ceq 'before-restart' } 'shell accepted input before quitting'
    Snapshot 'SOFT-3002-before-restart'
    Restart-SessionRestore 'SOFT-3002-restart' $false
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'proof-shell' }).Count -eq 1 } 'the server shell tab returned after normal quit and restart' 60
    Wait-Until { (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_attached}"' 'restored-attached').Trim() -eq '1' } 'restored tmux transport attached before typing' 90
    Proof-Line 'echo after-restart > /home/mpverify/shell-restore.txt; echo SOFT3002-ATTACHED-AFTER-RESTART'
    Wait-Until { (Read-ProofServer 'cat /home/mpverify/shell-restore.txt' 'restore-after-input').Trim() -ceq 'after-restart' } 'restored tab accepted real input'
    $afterRestart = (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_id}|#{pane_id}|#{pane_pid}"' 'session-after-restart').Trim()
    if ($afterRestart -cne $identity) { throw 'Restart did not reattach the same remote session and pane process' }
    Save-Json @{ before = $identity; afterRestart = $afterRestart; session = (Read-Session) } 'SOFT-3002-restored.json'
    Snapshot 'SOFT-3002-restored-attached'
    Proof-Palette 'close tab' 6232 'SOFT-3002-close-row'
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'proof-shell' }).Count -eq 0 } 'close tab detached the server shell without deleting its remote session' 30
    Wait-Until { (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_attached}"' 'detached-session').Trim() -ceq '0' } 'the same remote tmux session is detached' 30
    Proof-Palette 'reopen server shell' 6315 'SOFT-3002-reopen-row'
    Type-Text 'proof-shell'
    Snapshot 'SOFT-3002-detached-row'
    Press @(0x0D) 'Enter: reopen the same proof-shell session'
    Wait-Until { $state = Read-Session; $tab = $state.tabs[$state.active_tab]; $tab.PSObject.Properties['tmux_session'] -and $tab.tmux_session -ceq 'proof-shell' } 'Reopen server shell selected proof-shell' 60
    Wait-Until { (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_attached}"' 'reopened-attached').Trim() -eq '1' } 'reopened tmux transport attached before typing' 90
    Proof-Line 'echo reopened > /home/mpverify/shell-restore.txt; echo SOFT3002-REOPENED-SAME-SESSION'
    Wait-Until { (Read-ProofServer 'cat /home/mpverify/shell-restore.txt' 'reopened-input').Trim() -ceq 'reopened' } 'reopened shell accepted real input' 30
    $reopened = (Read-ProofServer 'tmux display-message -p -t proof-shell "#{session_id}|#{pane_id}|#{pane_pid}"' 'session-reopened').Trim()
    if ($reopened -cne $identity) { throw 'Reopen server shell attached a different remote session or pane process' }
    Save-Json @{ before = $identity; afterRestart = $afterRestart; reopened = $reopened; session = (Read-Session) } 'SOFT-3002-reopened.json'
    Snapshot 'SOFT-3002-reopened-attached'
}

Proof-Check 'SOFT-3003' {
    Proof-Palette 'runner server chat' 0 'SOFT-3003-chat-row'
    Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_session -ceq 'live-ci' } 'runner server chat selected'
    if (-not (Read-Session).tabs[(Read-Session).active_tab].cv) { Press @(0x12, 0x43) 'Alt+C: open the server chat view' }
    Wait-Until { (Read-SharedText $proofLog) -match '\[chat-live\] page shell=\d+ n=[1-9]\d*' -or (Read-SharedText $proofLog) -match '\[chat\] transcript load shell=\d+ ok' } 'real server chat transcript loaded' 90
    Snapshot 'SOFT-3003-server-chat'
    $before = Read-Session
    $count = @($before.tabs).Count
    Proof-Palette 'open shell on vps 1' 2003 'SOFT-3003-open-shell-row'
    Wait-Until { $state = Read-Session; @($state.tabs).Count -eq $count + 1 -and $state.tabs[$state.active_tab].kind -in @('vps', 'tmux') } 'the chat palette opened a server shell tab' 60
    $opened = Read-Session
    $tab = $opened.tabs[$opened.active_tab]
    if ([int]$tab.tmux_host -ne 0) { throw 'New shell opened on a different server from the chat' }
    Proof-Line 'pwd > /home/mpverify/chat-shell-folder.txt; echo SOFT3003-SHELL-FOLDER; pwd'
    Wait-Until { try { $script:chatShellFolder = (Read-ProofServer 'cat /home/mpverify/chat-shell-folder.txt' 'chat-shell-folder').Trim(); return $script:chatShellFolder.Length -gt 0 } catch { return $false } } 'new server shell accepted input and reported its real folder' 30
    Save-Json @{ command = 'Ctrl+K Open shell on VPS 1'; expectedFolder = '/home/mpverify/shell-proof-folder'; actualFolder = $script:chatShellFolder; host = $tab.tmux_host; before = $before; after = (Read-Session); sourceNote = 'SOFT-3003 shipped mp-shell open. No chat-specific open-shell row is present in the shortcut table.' } 'SOFT-3003-folder.json'
    Snapshot 'SOFT-3003-opened-shell'
    if ($script:chatShellFolder -cne '/home/mpverify/shell-proof-folder') { throw ('Shell tab opened on the right server but not in the chat folder: ' + $script:chatShellFolder) }
}
Snapshot 'after'
if (@($result.checks | Where-Object { -not $_.passed }).Count -gt 0) { throw 'One or more shell release proof cases failed; see the per-ticket results and screenshots' }
