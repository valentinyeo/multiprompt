Add-Type -AssemblyName System.Windows.Forms
$proofLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$script:proofSteps = @()
$script:proofShell = [IntPtr]::Zero
$script:proofVideo = $null
$script:proofTabReady = $false

function Proof-ShellWindow {
    foreach ($class in @('MPTerminal', 'ConsoleWindowClass')) {
        $after = [IntPtr]::Zero
        while ($true) {
            $candidate = [VerifyNative]::FindWindowEx($script:window, $after, $class, $null)
            if ($candidate -eq [IntPtr]::Zero) { break }
            $after = $candidate
            if ([VerifyNative]::IsWindowVisible($candidate)) { return $candidate }
        }
    }
    return [IntPtr]::Zero
}

function Proof-ShellFocus([IntPtr]$Shell) {
    try { if ([VerifyNative]::GetFocusedWindow($Shell) -eq $Shell) { return $true } } catch {}
    try { if ([VerifyNative]::GetFocusedWindow($script:window) -eq $Shell) { return $true } } catch {}
    try { if ([VerifyNative]::GetForegroundWindow() -eq $Shell) { return $true } } catch {}
    return $false
}

function Proof-FocusShell {
    Wait-Until {
        $candidate = Proof-ShellWindow
        if ($candidate -eq [IntPtr]::Zero) { return $false }
        $script:proofShell = $candidate
        return $true
    } 'visible terminal window for the active shell tab' 30
    $client = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$client)
    [VerifyNative]::ClickClient($script:proofShell, 40, [int]($client.Bottom - 8))
    try {
        Wait-Until { Proof-ShellFocus $script:proofShell } 'shell terminal owns keyboard focus' 20
    } catch {
        Snapshot 'shell-focus-timeout'
        throw $_.Exception.Message
    }
}

function Proof-Palette([string]$Query, [string]$Shot, [int]$Seconds = 20) {
    $offset = (Read-SharedText $proofLog).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' } 'empty command palette' 20
    Type-Text $Query
    $pattern = "\[palette\] ready chars=" + $Query.Length + " count=[1-9]\d* target=\d+"
    Wait-Until { (Read-SharedText $proofLog).Substring($offset) -match $pattern } ('single palette command: ' + $Query) $Seconds
    $observed = [regex]::Match((Read-SharedText $proofLog).Substring($offset), $pattern).Value
    Save-Json @{ query = $Query; observed = $observed } ($Shot + '-palette.json')
    Snapshot $Shot
    Press @(0x0D) ('Enter: ' + $Query)
}

function Proof-Line([string]$Command) {
    if ($script:proofShell -eq [IntPtr]::Zero -or -not (Proof-ShellFocus $script:proofShell)) {
        Snapshot 'shell-focus-before-type'
        throw 'keyboard focus is not on the shell terminal window before typing'
    }
    Press @(0x11, 0x43) 'Ctrl+C: clear the prompt before typing'
    Type-Text $Command
    Press @(0x0D) ('Enter: ' + $Command)
}

function Proof-ServerText([string]$Command, [string]$Name) {
    try { return (Read-ProofServer $Command $Name).Trim() }
    catch {
        Proof-SyncKnownHosts
        return (Read-ProofServer $Command $Name).Trim()
    }
}

function Proof-ConsoleDocumentText([IntPtr]$Shell) {
    try {
        $element = [System.Windows.Automation.AutomationElement]::FromHandle($Shell)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
        $document = $element.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        if ($null -eq $document) { return $null }
        $pattern = $document.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
        return $pattern.DocumentRange.GetText(-1)
    } catch { return $null }
}

function Proof-ShellReadableText([ValidateSet('prompt', 'scrollback')][string]$Region = 'scrollback') {
    if ($script:proofShell -eq [IntPtr]::Zero) { throw 'shell terminal is not set' }
    if ([VerifyNative]::Class($script:proofShell) -ceq 'ConsoleWindowClass') {
        $document = Proof-ConsoleDocumentText $script:proofShell
        if ($null -ne $document) { return $document }
    }
    $client = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$client)
    if ($Region -eq 'prompt') {
        $y = [int]($client.Bottom - 8)
        if ($y -lt 2) { $y = 2 }
        [VerifyNative]::DragSelectClient($script:proofShell, 2, $y, [int]($client.Right - 20), $y)
    } else {
        [VerifyNative]::DragSelectClient($script:proofShell, 2, 2, [int]($client.Right - 20), [int]($client.Bottom - 20))
    }
    try { [System.Windows.Forms.Clipboard]::Clear() } catch {}
    Press @(0x11, 0x43) ('Ctrl+C: copy ' + $Region + ' shell text for visibility read')
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        try { if ([System.Windows.Forms.Clipboard]::ContainsText()) { return [System.Windows.Forms.Clipboard]::GetText() } } catch {}
    }
    throw ('Ctrl+C did not copy ' + $Region + ' shell text for visibility read')
}

function Proof-VisibleContains([string]$Needle, [ValidateSet('prompt', 'scrollback')][string]$Region = 'scrollback') {
    try { return (Proof-ShellReadableText $Region).Contains($Needle) } catch { return $false }
}

function Proof-Attached([string]$Session, [string]$Name) {
    return Proof-ServerText ('tmux display-message -p -t ' + $Session + ' "#{session_attached}"') $Name
}

function Proof-ClearReceipts {
    try { [void](Read-ProofServer 'rm -f /home/mpverify/shell-interrupt.json /home/mpverify/shell-heartbeat.json' 'clear-receipts') } catch {}
}

function Proof-SetClipboard([string]$Text) {
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try { [System.Windows.Forms.Clipboard]::SetText($Text); return } catch { Start-Sleep -Milliseconds 100 }
    }
    throw 'the harness could not put text on the Windows clipboard'
}

function Proof-Step([string]$Name, [string]$Ticket, [scriptblock]$Body) {
    $step = [ordered]@{ name = $Name; ticket = $Ticket; passed = $false; startedAt = [DateTime]::UtcNow.ToString('o') }
    $script:proofSteps += $step
    Write-Host ('Step: ' + $Name)
    try {
        & $Body
        $step.passed = $true
    } catch {
        $step.error = $_.Exception.Message
        Write-Host ('Step failed: ' + $Name + ': ' + $_.Exception.Message)
        try { Snapshot ($Name.Replace('/', '-') + '-failed') } catch {}
    }
    $step.finishedAt = [DateTime]::UtcNow.ToString('o')
    $result.journeySteps = @($script:proofSteps)
    Save-Json @($script:proofSteps) 'journey-steps.json'
}

function Proof-Measure([string]$Name) {
    $window = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:window, [ref]$window)
    $shell = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$shell)
    $heightFill = 0
    $widthFill = 0
    if ($window.Bottom -gt 0) { $heightFill = [Math]::Round([double]$shell.Bottom / [double]$window.Bottom, 3) }
    if ($window.Right -gt 0) { $widthFill = [Math]::Round([double]$shell.Right / [double]$window.Right, 3) }
    $measured = [ordered]@{
        step = $Name
        shellClass = [VerifyNative]::Class($script:proofShell)
        windowWidth = $window.Right
        windowHeight = $window.Bottom
        shellWidth = $shell.Right
        shellHeight = $shell.Bottom
        heightFill = $heightFill
        widthFill = $widthFill
    }
    Save-Json $measured ($Name + '.json')
    return $measured
}

function Proof-Layout([string]$Name) {
    $measured = Proof-Measure $Name
    if ($measured.heightFill -lt 0.8 -or $measured.widthFill -lt 0.5) {
        throw ('shell terminal fills ' + $measured.widthFill + ' width and ' + $measured.heightFill + ' height of the tab window')
    }
    return $measured
}

function Proof-CopyVisible([string]$Name) {
    $client = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$client)
    [VerifyNative]::DragSelectClient($script:proofShell, 2, 2, [int]($client.Right - 20), [int]($client.Bottom - 20))
    Start-Sleep -Milliseconds 250
    try { [System.Windows.Forms.Clipboard]::Clear() } catch {}
    Press @(0x11, 0x43) ('Ctrl+C: copy all visible shell text for ' + $Name)
    Wait-Until {
        try { return [System.Windows.Forms.Clipboard]::ContainsText() } catch { return $false }
    } ('Ctrl+C copied the visible shell text for ' + $Name) 10
    return [System.Windows.Forms.Clipboard]::GetText()
}

function Proof-ScrollIndex([string]$Text) {
    $found = [regex]::Matches($Text, 'SOFTSCROLL-(\d{3})')
    if ($found.Count -eq 0) { return -1 }
    $lowest = 9999
    foreach ($match in $found) {
        $value = [int]$match.Groups[1].Value
        if ($value -lt $lowest) { $lowest = $value }
    }
    return $lowest
}

function Proof-StartVideo {
    $ffmpeg = (Get-Command ffmpeg.exe -ErrorAction Stop).Source
    $path = Join-Path $Evidence 'journey.mp4'
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $ffmpeg
    $info.Arguments = '-y -f gdigrab -framerate 8 -i desktop -an -t 420 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "' + $path + '"'
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.CreateNoWindow = $true
    $script:proofVideo = [Diagnostics.Process]::Start($info)
    Start-Sleep -Seconds 3
    if ($script:proofVideo.HasExited) { throw ('screen recorder exited before the journey: ' + $script:proofVideo.ExitCode) }
    Save-Json @{ path = $path; framerate = 8; startedAt = [DateTime]::UtcNow.ToString('o'); pid = $script:proofVideo.Id } 'journey-video.json'
}

function Proof-StopVideo {
    if ($null -eq $script:proofVideo) { return }
    try { $script:proofVideo.StandardInput.WriteLine('q'); $script:proofVideo.StandardInput.Close() } catch {}
    if (-not $script:proofVideo.WaitForExit(45000)) { $script:proofVideo.Kill(); $script:proofVideo.WaitForExit() }
    $path = Join-Path $Evidence 'journey.mp4'
    $size = if (Test-Path $path) { (Get-Item $path).Length } else { 0 }
    Save-Json @{ path = $path; exitCode = $script:proofVideo.ExitCode; bytes = $size; stoppedAt = [DateTime]::UtcNow.ToString('o') } 'journey-video.json'
    if ($script:proofVideo.ExitCode -ne 0 -or $size -lt 102400) { throw ('screen recording failed: exit ' + $script:proofVideo.ExitCode + ', ' + $size + ' bytes') }
}

function Proof-TypeLine([string]$Command) {
    Proof-FocusShell
    Proof-Line $Command
}

function Proof-CopyShortcut([string]$Step, [int[]]$Keys, [string]$Label) {
    if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
    Proof-FocusShell
    $token = 'SOFTCOPY-' + $Step.ToUpperInvariant()
    Proof-TypeLine ("clear; printf '" + $token + "\n'")
    Start-Sleep -Milliseconds 900
    $client = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$client)
    [VerifyNative]::DragSelectClient($script:proofShell, 2, 2, [int]($client.Right - 20), 2)
    Snapshot ($Step + '-selected')
    $sentinel = 'clipboard sentinel before ' + $Label
    Proof-SetClipboard $sentinel
    Press $Keys ($Label + ': copy the selected shell line')
    Wait-Until {
        try { return [System.Windows.Forms.Clipboard]::GetText() -cne $sentinel } catch { return $false }
    } ($Label + ' changed the clipboard') 10
    $copied = ([System.Windows.Forms.Clipboard]::GetText()).Trim()
    [IO.File]::WriteAllText((Join-Path $Evidence ($Step + '-clipboard.txt')), $copied)
    [IO.File]::WriteAllText((Join-Path $Evidence ($Step + '-expected.txt')), $token)
    if ($copied -cne $token) { throw ($Label + ' copied "' + $copied + '" instead of the selected ' + $token) }
    Snapshot ($Step + '-copied')
}

function Proof-PasteShortcut([string]$Step, [int[]]$Keys, [string]$Label) {
    if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
    $receipt = '/home/mpverify/' + $Step + '.txt'
    $marker = 'SOFTPASTE-' + $Step.ToUpperInvariant()
    Proof-FocusShell
    Press @(0x1B) 'Escape: leave an empty prompt before pasting'
    Proof-SetClipboard ('echo ' + $marker + ' > ' + $receipt)
    Snapshot ($Step + '-clipboard-ready')
    Press $Keys ($Label + ': paste the command into the shell')
    Wait-Until { Proof-VisibleContains $marker 'prompt' } ($Label + ' pasted the command onto the shell prompt') 15
    Snapshot ($Step + '-pasted')
    Proof-FocusShell
    Press @(0x0D) 'Enter: run the pasted command'
    Wait-Until {
        try { return (Read-ProofServer ('cat ' + $receipt) ($Step + '-receipt')).Trim() -ceq $marker } catch { return $false }
    } ($Label + ' pasted text that ran on the server') 25
    Snapshot ($Step + '-ran')
}

function Proof-Interrupt([string]$Tag) {
    if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
    Proof-ClearReceipts
    Proof-TypeLine 'python3 /home/mpverify/shell-proof.py'
    $script:proofHeartbeat = $null
    Wait-Until { Proof-VisibleContains 'SOFT3001-COPY-EXACT' } 'the running proof command painted output in the shell' 30
    Wait-Until {
        try { $script:proofHeartbeat = (Proof-ServerText 'cat /home/mpverify/shell-heartbeat.json' 'interrupt-heartbeat') | ConvertFrom-Json; return $script:proofHeartbeat.tick -gt 0 } catch { return $false }
    } 'the running proof command wrote a real heartbeat' 30
    $before = $script:proofHeartbeat
    Proof-FocusShell
    Press @(0x11, 0x43) 'Ctrl+C: interrupt the running command with no selection'
    Wait-Until {
        if (Proof-VisibleContains 'SOFT3001 INTERRUPTED') { return $true }
        try {
            $script:proofInterrupt = (Proof-ServerText 'cat /home/mpverify/shell-interrupt.json' 'interrupt-receipt') | ConvertFrom-Json
            return $script:proofInterrupt.pid -eq $before.pid -and $script:proofInterrupt.interrupted
        } catch { return $false }
    } 'the same running command received the interrupt' 25
    Save-Json @{ before = $before; interrupt = $script:proofInterrupt } ($Tag + '-interrupt.json')
    Snapshot ($Tag + '-interrupt-receipt')
}

function Proof-Scroll([string]$Tag) {
    if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
    Proof-TypeLine "clear; seq -f 'SOFTSCROLL-%03g' 1 200"
    Start-Sleep -Seconds 2
    Snapshot ($Tag + '-scroll-printed')
    $beforeText = ''
    try { $beforeText = Proof-CopyVisible ($Tag + ' before wheel') } catch { Save-Json @{ error = $_.Exception.Message } ($Tag + '-scroll-before-error.json') }
    [IO.File]::WriteAllText((Join-Path $Evidence ($Tag + '-scroll-before.txt')), $beforeText)
    $beforeIndex = Proof-ScrollIndex $beforeText
    Proof-FocusShell
    $client = New-Object VerifyNative+Rect
    [void][VerifyNative]::GetClientRect($script:proofShell, [ref]$client)
    $wheelX = [int]($client.Right / 2)
    $wheelY = [int]($client.Bottom / 2)
    for ($notch = 0; $notch -lt 40; $notch++) {
        [VerifyNative]::WheelClientPoint($script:window, [uint32]$process.Id, $script:proofShell, $wheelX, $wheelY, 120)
        Start-Sleep -Milliseconds 40
    }
    Start-Sleep -Milliseconds 800
    Snapshot ($Tag + '-scroll-wheeled')
    $afterText = ''
    try { $afterText = Proof-CopyVisible ($Tag + ' after wheel') } catch { Save-Json @{ error = $_.Exception.Message } ($Tag + '-scroll-after-error.json') }
    [IO.File]::WriteAllText((Join-Path $Evidence ($Tag + '-scroll-after.txt')), $afterText)
    $afterIndex = Proof-ScrollIndex $afterText
    $scrolled = $beforeIndex - $afterIndex
    Save-Json @{ beforeIndex = $beforeIndex; afterIndex = $afterIndex; scrolled = $scrolled; notches = 40; required = 100 } ($Tag + '-scroll.json')
    if ($beforeIndex -lt 0 -or $afterIndex -lt 0) { throw 'Ctrl+C copied no numbered shell scrollback, so the wheel could not be measured' }
    if ($scrolled -lt 100) { throw ('the wheel moved the visible output from line ' + $beforeIndex + ' to ' + $afterIndex + ', less than 100 lines') }
}

function Proof-TabSteps([string]$Tab) {
    Proof-Step ($Tab + '/layout-open') 'SOFT-3007' {
        if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
        Proof-FocusShell
        Start-Sleep -Milliseconds 800
        Snapshot ($Tab + '-layout-open')
        [void](Proof-Layout ($Tab + '-layout-open'))
    }
    Proof-Step ($Tab + '/copy-ctrl-c') 'SOFT-3001' {
        Proof-CopyShortcut ($Tab + '-copy-ctrl-c') @(0x11, 0x43) 'Ctrl+C'
    }
    Proof-Step ($Tab + '/copy-ctrl-shift-c') 'SOFT-3001' {
        Proof-CopyShortcut ($Tab + '-copy-ctrl-shift-c') @(0x11, 0x10, 0x43) 'Ctrl+Shift+C'
    }
    Proof-Step ($Tab + '/paste-ctrl-v') 'SOFT-3001' {
        Proof-PasteShortcut ($Tab + '-paste-ctrl-v') @(0x11, 0x56) 'Ctrl+V'
    }
    Proof-Step ($Tab + '/paste-ctrl-shift-v') 'SOFT-3001' {
        Proof-PasteShortcut ($Tab + '-paste-ctrl-shift-v') @(0x11, 0x10, 0x56) 'Ctrl+Shift+V'
    }
    Proof-Step ($Tab + '/scroll-wheel') 'SOFT-3001' {
        Proof-Scroll ($Tab + '-scroll')
    }
    Proof-Step ($Tab + '/interrupt-ctrl-c') 'SOFT-3001' {
        Proof-Interrupt ($Tab + '-interrupt')
    }
    Proof-Step ($Tab + '/layout-resize') 'SOFT-3007' {
        if (-not $script:proofTabReady) { throw 'the shell tab never showed a usable terminal window' }
        Proof-FocusShell
        $before = Proof-Measure ($Tab + '-layout-before-resize')
        [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1200, 800, $true)
        Start-Sleep -Seconds 2
        Snapshot ($Tab + '-layout-resized')
        $after = Proof-Layout ($Tab + '-layout-resized')
        [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
        Start-Sleep -Seconds 2
        Save-Json @{ before = $before; after = $after } ($Tab + '-layout-resize.json')
        if ($after.shellHeight -lt ($before.shellHeight + 80)) { throw ('the console grew only ' + ($after.shellHeight - $before.shellHeight) + ' px when the tab grew 150 px') }
    }
}

$script:proofVideoError = ''
try { Proof-StartVideo } catch { $script:proofVideoError = $_.Exception.Message; Write-Host ('Screen recorder did not start: ' + $script:proofVideoError) }

try {
Proof-SyncKnownHosts
Wait-Until {
    $state = Read-Session
    return $null -ne $state -and $state.shared_server_connection -eq $true
} 'the launched app published a shared server connection' 90
Proof-SyncKnownHosts

Proof-Step 'tmux/restore-attached' 'SOFT-3002' {
    Proof-SyncKnownHosts
    Proof-ClearReceipts
    $active = $false
    for ($attempt = 0; $attempt -lt 8 -and -not $active; $attempt++) {
        $state = Read-Session
        if ($null -ne $state) {
            $tab = $state.tabs[$state.active_tab]
            if ($tab.PSObject.Properties['tmux_session'] -and $tab.tmux_session -ceq 'proof-shell') { $active = $true; break }
        }
        Press @(0x11, 0x09) 'Ctrl+Tab: reach the restored proof-shell tab'
        Start-Sleep -Milliseconds 500
    }
    if (-not $active) { throw 'the launched app did not restore a tab bound to the proof-shell tmux session' }
    $restored = Read-Session
    Save-Json $restored 'restored-session.json'
    Wait-Until {
        $candidate = Proof-ShellWindow
        if ($candidate -eq [IntPtr]::Zero) { return $false }
        $script:proofShell = $candidate
        return $true
    } 'the restored tmux tab shows a terminal window' 45
    Proof-FocusShell
    $script:proofTabReady = $true
    Proof-TypeLine 'echo restored > /home/mpverify/shell-restore.txt'
    Wait-Until {
        try { return (Proof-ServerText 'cat /home/mpverify/shell-restore.txt' 'restored-receipt') -ceq 'restored' } catch { return $false }
    } 'the restored tmux tab accepted real keyboard input' 25
    $attached = 'unknown'
    $identity = ''
    try { $attached = Proof-Attached 'proof-shell' 'restored-attached' } catch {}
    try { $identity = Proof-ServerText 'tmux display-message -p -t proof-shell "#{session_id}|#{pane_id}|#{pane_pid}"' 'restored-identity' } catch {}
    Save-Json @{ tab = 'tmux'; session = 'proof-shell'; identity = $identity; attached = $attached; input = 'restored' } 'restore.json'
    Snapshot 'tmux-restored'
}

$script:proofTabReady = $false
try { Proof-FocusShell; $script:proofTabReady = $true } catch { Write-Host ('Restored tab is not drivable: ' + $_.Exception.Message) }
Proof-TabSteps 'tmux'

$script:proofTabReady = $false
Proof-Step 'shell/open-tab' 'SOFT-3007' {
    $before = Read-Session
    if ($null -eq $before) { throw 'the app published no saved tab to open a second shell tab from' }
    $tabsBeforeOpen = @($before.tabs).Count
    Proof-Palette 'open shell on vps 1' 'shell-open-row'
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state) { return $false }
        return (@($state.tabs).Count -eq $tabsBeforeOpen + 1 -and $state.tabs[$state.active_tab].kind -in @('vps', 'vps2'))
    } 'the chat palette opened a plain server shell tab on the host' 45
    Wait-Until {
        $candidate = Proof-ShellWindow
        if ($candidate -eq [IntPtr]::Zero) { return $false }
        $script:proofShell = $candidate
        return $true
    } 'the plain server shell tab shows a terminal window' 45
    $script:proofTabReady = $true
    Snapshot 'shell-opened'
}
try { Proof-FocusShell; $script:proofTabReady = $true } catch { Write-Host ('Plain server shell tab is not drivable: ' + $_.Exception.Message) }
Proof-TabSteps 'shell'

Proof-Step 'video' 'SOFT-3001' {
    if ($script:proofVideoError) { throw $script:proofVideoError }
    Proof-StopVideo
}

$result.checks += @($script:proofSteps)
Save-Json @($script:proofSteps) 'journey-steps.json'
Snapshot 'after'
$failed = @($script:proofSteps | Where-Object { -not $_.passed })
if ($failed.Count -gt 0) {
    throw ('Shell release journey failed ' + $failed.Count + ' step(s): ' + (@($failed | ForEach-Object { $_.name }) -join ', '))
}
} finally {
    if ($null -ne $script:proofVideo -and -not $script:proofVideo.HasExited) {
        try { Proof-StopVideo } catch { $script:proofVideoError = $_.Exception.Message }
    }
}
