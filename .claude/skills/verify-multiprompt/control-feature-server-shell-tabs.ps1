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

function Proof-Palette([string]$Query, [int]$Target, [string]$Shot, [int]$Seconds = 20) {
    $offset = (Read-SharedText $proofLog).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' } 'empty command palette'
    Type-Text $Query
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match ("\[palette\] ready chars=" + $Query.Length + " count=\d+ target=" + $Target + '(?:\s|$)') } ('exact palette command: ' + $Query) $Seconds
    Snapshot $Shot
    Press @(0x0D) ('Enter: ' + $Query)
}

function Proof-Line([string]$Command) {
    Focus-ProofShell
    Type-Text $Command
    Press @(0x0D) ('Enter: ' + $Command)
}

function Proof-ServerText([string]$Command, [string]$Name) {
    return (Read-ProofServer $Command $Name).Trim()
}

function Proof-Attached([string]$Name) {
    return Proof-ServerText 'tmux display-message -p -t proof-shell "#{session_attached}"' $Name
}

function Proof-Identity([string]$Name) {
    return Proof-ServerText 'tmux display-message -p -t proof-shell "#{session_id}|#{pane_id}|#{pane_pid}"' $Name
}

function Proof-RestoreText([string]$Name) {
    return Proof-ServerText 'cat /home/mpverify/shell-restore.txt' $Name
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

$proofTabsBeforeOpen = @((Read-Session).tabs).Count
Proof-Palette 'open shell on vps 1' 2003 'SOFT-3001-open-shell-row'
Wait-Until {
    $state = Read-Session
    $null -ne $state -and @($state.tabs).Count -eq $proofTabsBeforeOpen + 1 -and $state.tabs[$state.active_tab].kind -in @('vps', 'tmux')
} 'the chat palette opened a plain server shell tab on the host' 60
Proof-Line 'tmux attach -t proof-shell'
Wait-Until { (Proof-Attached 'shell-attached') -ceq '1' } 'the plain server shell attached the fixture tmux session' 90
Snapshot 'SOFT-3001-attached'

Proof-Check 'SOFT-3001' {
    Proof-Line 'python3 /home/mpverify/shell-proof.py'
    Wait-Until {
        try { $script:heartbeat = (Read-ProofServer 'cat /home/mpverify/shell-heartbeat.json' 'heartbeat-ready') | ConvertFrom-Json; return $script:heartbeat.tick -gt 0 } catch { return $false }
    } 'real remote command is running' 30
    Focus-ProofShell
    [System.Windows.Forms.Clipboard]::SetText('clipboard sentinel before selected Ctrl+C')
    [VerifyNative]::DragSelectClient($script:proofTerminal, 1, 1, 2, 1)
    Snapshot 'SOFT-3001-selected'
    $before = (Read-ProofServer 'cat /home/mpverify/shell-heartbeat.json' 'heartbeat-before-copy') | ConvertFrom-Json
    Press @(0x11, 0x43) 'Ctrl+C: copy the selected first character while the command runs'
    Wait-Until { [System.Windows.Forms.Clipboard]::GetText() -cne 'clipboard sentinel before selected Ctrl+C' } 'Ctrl+C changed the clipboard' 10
    $copied = [System.Windows.Forms.Clipboard]::GetText()
    $expected = 'S'
    [IO.File]::WriteAllText((Join-Path $Evidence 'SOFT-3001-clipboard.txt'), $copied)
    [IO.File]::WriteAllText((Join-Path $Evidence 'SOFT-3001-expected.txt'), $expected)
    if ($copied -cne $expected) { throw 'Clipboard does not equal the selected first character S' }
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
    $identity = Proof-Identity 'session-before-close'
    Proof-Line 'echo before-close > /home/mpverify/shell-restore.txt; echo SOFT3002-BEFORE-CLOSE'
    Wait-Until { (Proof-RestoreText 'restore-before-close') -ceq 'before-close' } 'shell accepted input before closing its tab'
    Snapshot 'SOFT-3002-before-close'
    $appPid = $process.Id
    $bridges = @(Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object { $_.ParentProcessId -eq $appPid })
    if ($bridges.Count -eq 0) { throw 'The app owned no ssh transport to drop before the close' }
    Save-Json @{ appPid = $appPid; dropped = @($bridges | ForEach-Object { $_.ProcessId }) } 'SOFT-3002-transport-drop.json'
    foreach ($bridge in $bridges) { Stop-Process -Id $bridge.ProcessId -Force -ErrorAction SilentlyContinue }
    Wait-Until { (Proof-Attached 'dropped-session') -ceq '0' } 'the dropped transport detached the same tmux session' 60
    Snapshot 'SOFT-3002-transport-dropped'
    $proofTabsOpen = @((Read-Session).tabs).Count
    Proof-Palette 'close tab' 7110 'SOFT-3002-close-row'
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and @($state.tabs).Count -eq $proofTabsOpen - 1
    } 'the close row removed the server shell tab' 30
    Wait-Until { (Proof-Attached 'detached-session') -ceq '0' } 'the same remote tmux session is alive and detached' 30
    Snapshot 'SOFT-3002-detached'
    Proof-Palette 'reopen server shell' 6315 'SOFT-3002-reopen-row' 60
    Type-Text 'proof-shell'
    Snapshot 'SOFT-3002-reopen-shell'
    Press @(0x0D) 'Enter: reopen the same proof-shell session'
    Wait-Until { $state = Read-Session; $tab = $state.tabs[$state.active_tab]; $tab.PSObject.Properties['tmux_session'] -and $tab.tmux_session -ceq 'proof-shell' } 'Reopen server shell selected proof-shell' 60
    Wait-Until { (Proof-Attached 'reopened-attached') -ceq '1' } 'reopened tmux transport attached before typing' 90
    Proof-Line 'echo reopened > /home/mpverify/shell-restore.txt; echo SOFT3002-REOPENED-SAME-SESSION'
    Wait-Until { (Proof-RestoreText 'restore-reopened') -ceq 'reopened' } 'reopened shell accepted real input' 30
    $reopened = Proof-Identity 'session-reopened'
    if ($reopened -cne $identity) { throw 'Reopen server shell attached a different remote session or pane process' }
    Save-Json @{ before = $identity; reopened = $reopened; session = (Read-Session) } 'SOFT-3002-reopened.json'
    Snapshot 'SOFT-3002-reopened-attached'
    Restart-SessionRestore 'SOFT-3002-restart' $false
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'proof-shell' }).Count -eq 1 } 'the server shell tab returned after normal quit and restart' 60
    Wait-Until { (Proof-Attached 'restored-attached') -ceq '1' } 'restored tmux transport attached before typing' 90
    Proof-Line 'echo after-restart > /home/mpverify/shell-restore.txt; echo SOFT3002-ATTACHED-AFTER-RESTART'
    Wait-Until { (Proof-RestoreText 'restore-after-restart') -ceq 'after-restart' } 'restored tab accepted real input'
    $afterRestart = Proof-Identity 'session-after-restart'
    if ($afterRestart -cne $identity) { throw 'Restart did not reattach the same remote session and pane process' }
    Save-Json @{ before = $identity; reopened = $reopened; afterRestart = $afterRestart; session = (Read-Session) } 'SOFT-3002-restored.json'
    Snapshot 'SOFT-3002-restored-attached'
}

Snapshot 'after'
if (@($result.checks | Where-Object { -not $_.passed }).Count -gt 0) { throw 'One or more shell release proof cases failed; see the per-ticket results and screenshots' }
