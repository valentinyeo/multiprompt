$pageJob = $null
$pageServer = $null
$typingObservations = New-Object 'System.Collections.Generic.List[object]'
function Observe-TypingFocus([string]$Phase, [int]$Round) {
    $typingObservations.Add(@{
        phase = $Phase; round = $Round; time = [DateTime]::UtcNow.ToString('o')
        foreground = [VerifyNative]::GetForegroundWindow().ToInt64()
        focus = [VerifyNative]::GetFocusedWindow($script:window).ToInt64()
        alt = [VerifyNative]::IsDown(0x12); ctrl = [VerifyNative]::IsDown(0x11); shift = [VerifyNative]::IsDown(0x10)
    })
}
try {
$pageJob = New-Object VerifyJob
$pageRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-browser-typing')).Path
$url = 'http://127.0.0.1:18792/'
$pageServer = $pageJob.Start((Get-Command python.exe -ErrorAction Stop | Select-Object -First 1).Source, $pageRoot, (Join-Path $Evidence 'browser-typing-page.stdout.log'), (Join-Path $Evidence 'browser-typing-page.stderr.log'), '-m http.server 18792 --bind 127.0.0.1', $true)
Wait-Until {
    $pageServer.Refresh()
    if ($pageServer.HasExited) { throw 'Local page server exited before readiness' }
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        $response.StatusCode -eq 200 -and $response.Content -ceq [IO.File]::ReadAllText((Join-Path $pageRoot 'index.html'))
    } catch { $false }
} 'owned local page server responds with the typing fixture' 20
Add-Type -ReferencedAssemblies System, System.Core -Path (Join-Path $PSScriptRoot '../../../tools/verify-browser-typing/fault.cs')
$script:browserShellId = (Read-Inbox).shells[0].sid
$null = Open-BrowserPane 'typing'
$browser = [VerifyNative]::DockedPaneWindow($script:window)
if ($browser -eq [IntPtr]::Zero -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Typing journey has no owned docked browser' }

function Get-TypingUrlBar {
    $bar = [IntPtr]::Zero
    while ($true) {
        $bar = [VerifyNative]::FindWindowEx([IntPtr]::Zero, $bar, 'ZigShellUrlBar', [System.Management.Automation.Language.NullString]::Value)
        if ($bar -eq [IntPtr]::Zero) { return $bar }
        [uint32]$ownedProcessId = 0
        [void][VerifyNative]::GetWindowThreadProcessId($bar, [ref]$ownedProcessId)
        if ($ownedProcessId -eq $process.Id -and [VerifyNative]::GetAncestor($bar, 3) -eq $script:window -and [VerifyNative]::IsWindowVisible($bar)) { return $bar }
    }
}
function Get-TypingEditChild([IntPtr]$Bar) {
    $edit = [VerifyNative]::FindWindowEx($Bar, [IntPtr]::Zero, 'Edit', [System.Management.Automation.Language.NullString]::Value)
    if ($edit -eq [IntPtr]::Zero) { return $edit }
    [uint32]$ownedProcessId = 0
    [void][VerifyNative]::GetWindowThreadProcessId($edit, [ref]$ownedProcessId)
    if ($ownedProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($edit, 2) -ne $Bar) { throw 'URL Edit ownership mismatch' }
    return $edit
}
function Leave-TypingBrowser {
    if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Expected owned browser foreground before Alt+Q' }
    [VerifyNative]::Chord(@(0x12, 0x51))
    Wait-Until {
        $foreground = [VerifyNative]::GetForegroundWindow()
        $foreground -ne [IntPtr]::Zero -and $foreground -ne $browser -and [VerifyNative]::GetAncestor($foreground, 3) -eq $script:window
    } 'Alt+Q returns to owned console or frame' 10 -PollMilliseconds 20
}
function Get-TypingEdit([IntPtr]$Bar) {
    $edit = [VerifyNative]::GetFocusedWindow($script:window)
    if ($edit -eq [IntPtr]::Zero -or [VerifyNative]::Class($edit) -cne 'Edit' -or [VerifyNative]::GetAncestor($edit, 2) -ne $Bar) { return [IntPtr]::Zero }
    return $edit
}
function Wait-TypingEdit([IntPtr]$Bar) {
    Wait-Until { (Get-TypingEdit $Bar) -ne [IntPtr]::Zero } 'owned URL bar Edit has focus' 5 -PollMilliseconds 20
    return Get-TypingEdit $Bar
}
function Page-TypingFocus {
    [VerifyNative]::Chord(@(0x12, 0x51))
    Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $browser } 'Alt+Q focuses the owned browser page' 10 -PollMilliseconds 20
}

[uint32]$browserPid = 0
[void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
[VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
[VerifyNative]::Chord(@(0x11, 0x4C))
$browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
$omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
Wait-Until {
    $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
    $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus
} 'owned browser omnibox focused for local page setup' 5
[VerifyNative]::Text($url)
Wait-Until {
    $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
    $null -ne $omnibox -and $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value -ceq $url
} 'local page URL typed into owned browser omnibox' 5
[VerifyNative]::Chord(@(0x0D))
Wait-Until { [VerifyNative]::Title($browser).StartsWith('typing-ready', [StringComparison]::Ordinal) } 'local data page loaded in owned browser' 20
if ([VerifyNative]::GetForegroundWindow() -ne $browser -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Local page browser is not owned and foreground' }
[VerifyNative]::ClickBrowserContent($browser, $script:window)
$expectedPage = ''
for ($round = 1; $round -le 20; $round++) {
    if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw "Native round $round browser page lost foreground" }
    [VerifyNative]::Text('abc')
    $expectedPage += 'abc'
    Wait-Until { [VerifyNative]::Title($browser).StartsWith($expectedPage + ' ', [StringComparison]::Ordinal) } "native round $round page receives exact typed prefix" 5 -PollMilliseconds 20
    [VerifyNative]::Chord(@(0x11, 0x4C))
    Wait-Until {
        $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
        $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus
    } "native round $round Ctrl+L focuses the omnibox" 5 -PollMilliseconds 20
    [VerifyNative]::Text('abc')
    $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
    $actual = $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
    $result.checks += @{ name = 'native-page-and-omnibox-typing'; round = $round; text = $actual; pageText = $expectedPage }
    if ($actual -cne 'abc') { throw "Native round $round expected omnibox text abc, got '$actual'" }
    [VerifyNative]::Chord(@(0x1B))
    [VerifyNative]::Chord(@(0x12, 0x51))
    Wait-Until { [VerifyNative]::GetForegroundWindow() -ne $browser } "native round $round Alt+Q leaves browser" 10 -PollMilliseconds 20
    Page-TypingFocus
}
Focus-Palette 'browser url' 6236
Press @(0x0D) 'Enter: choose browser URL'
Type-Text $url
Press @(0x0D) 'Enter: save the synthetic local page URL'
Wait-Until { (Read-Session).tabs[0].burl -ceq $url } 'synthetic local page URL saved through the app UI'
Focus-Palette 'browser mode' 6244
Press @(0x0D) 'Enter: use the app address bar'
$oldModeBrowser = $browser
Wait-Until {
    $candidate = [VerifyNative]::DockedPaneWindow($script:window)
    $candidate -ne [IntPtr]::Zero -and $candidate -ne $oldModeBrowser -and
        [VerifyNative]::GetProp($candidate, 'ZigShellPaneOwner') -eq $script:window -and
        (Get-TypingUrlBar) -ne [IntPtr]::Zero
} 'owned browser shows the app address bar' 30
$browser = [VerifyNative]::DockedPaneWindow($script:window)
if ([VerifyNative]::GetForegroundWindow() -ne $browser) { Page-TypingFocus }

for ($round = 1; $round -le 20; $round++) {
    Observe-TypingFocus 'before-leave' $round
    Leave-TypingBrowser
    Observe-TypingFocus 'after-leave' $round
    $bar = Get-TypingUrlBar
    if ($bar -eq [IntPtr]::Zero) { throw 'Owned visible ZigShellUrlBar missing' }
    [VerifyNative]::Chord(@(0x11, 0x10, 0x4C))
    $edit = Wait-TypingEdit $bar
    Observe-TypingFocus 'before-text' $round
    [VerifyNative]::Text('abc')
    Observe-TypingFocus 'after-text' $round
    $actual = [VerifyNative]::EditText($edit)
    $result.checks += @{ name = 'ordinary-address-typing'; round = $round; text = $actual }
    if ($actual -cne 'abc') { throw "Round $round expected address text abc, got '$actual'" }
    [VerifyNative]::Chord(@(0x1B))
    Page-TypingFocus
}
Snapshot 'action'
Leave-TypingBrowser
$bar = Get-TypingUrlBar
if ($bar -eq [IntPtr]::Zero) { throw 'Owned visible ZigShellUrlBar missing before held-Ctrl case' }
if ([VerifyNative]::IsDown(0x11) -or [VerifyNative]::IsDown(0x10)) { throw 'Unexpected held modifier before held-Ctrl case' }
try {
    [VerifyNative]::KeyDown(0x11)
    [VerifyNative]::KeyDown(0x10)
    [VerifyNative]::KeyDown(0x4C)
    [VerifyNative]::KeyUp(0x4C)
    [VerifyNative]::KeyUp(0x10)
    $heldEdit = Wait-TypingEdit $bar
    if (-not [VerifyNative]::IsDown(0x11)) { throw 'Address handoff released the fixture-held Ctrl key' }
    $result.checks += @{ name = 'held-ctrl-address-focus'; ctrlPreserved = $true; edit = $heldEdit.ToInt64() }
} finally {
    [VerifyNative]::KeyUp(0x4C)
    [VerifyNative]::KeyUp(0x10)
    [VerifyNative]::KeyUp(0x11)
}
[VerifyNative]::Text('abc')
$heldText = [VerifyNative]::EditText($heldEdit)
if ($heldText -cne 'abc') { throw "Held-Ctrl release expected address text abc, got '$heldText'" }
$result.checks += @{ name = 'held-ctrl-release-typing'; text = $heldText }
[VerifyNative]::Chord(@(0x1B))
Page-TypingFocus
Leave-TypingBrowser
$bar = Get-TypingUrlBar
if ($bar -eq [IntPtr]::Zero) { throw 'Owned visible ZigShellUrlBar missing before fault' }

$fault = New-Object BrowserTypingFault
$record = [ordered]@{ boundary = 'One deliberately suppressed app-injected Alt release during Ctrl+Shift+L address focus; not a natural failure rate'; injectedDown = $false; droppedUp = $false; events = @(); expected = 'abc'; actual = $null; germanAltGr = 'not exercised'; error = $null }
try {
    $fault.Start()
    $fault.Arm()
    try {
        [VerifyNative]::Chord(@(0x11, 0x10, 0x4C))
    } finally { $fault.Disarm() }
    Wait-Until { (Get-TypingEditChild $bar) -ne [IntPtr]::Zero } 'owned URL bar Edit exists after Ctrl+Shift+L' 5 -PollMilliseconds 20
    $edit = Get-TypingEditChild $bar
    if (-not $fault.Down) { $edit = Wait-TypingEdit $bar }
    $record.injectedDown = $fault.Down
    $record.droppedUp = $fault.Dropped
    $record.events = @($fault.Events)
    $record.altDownBeforeTyping = $fault.AltDown
    $record.ctrlDownBeforeTyping = $fault.CtrlDown
    $record.foregroundBeforeTyping = [VerifyNative]::GetForegroundWindow().ToInt64()
    $record.edit = $edit.ToInt64()
    $record.urlBar = $bar.ToInt64()
    $record.focusBeforeTyping = [VerifyNative]::GetFocusedWindow($script:window).ToInt64()
    $record.menuBeforeTyping = [BrowserTypingFault]::MenuState($script:window)
    WindowShot 'fault-before-typing'
    [VerifyNative]::Text('abc')
    if ([BrowserTypingFault]::IsWindow($edit)) {
        if ((Get-TypingEditChild $bar) -ne $edit) { throw 'Verified URL Edit ownership changed after typing' }
        $record.actual = [VerifyNative]::EditText($edit)
    } else {
        $record.actual = $null
        $record.editDestroyed = $true
    }
    $record.foregroundAfterTyping = [VerifyNative]::GetForegroundWindow().ToInt64()
    $record.focusAfterTyping = [VerifyNative]::GetFocusedWindow($script:window).ToInt64()
    $record.menuAfterTyping = [BrowserTypingFault]::MenuState($script:window)
    $record.altDownAfterTyping = $fault.AltDown
    $record.ctrlDownAfterTyping = $fault.CtrlDown
    WindowShot 'fault-after-typing'
    if ($record.actual -cne 'abc') { throw "Fault case expected address text abc, got '$($record.actual)'" }
    if ($record.injectedDown -and -not $record.droppedUp) { throw 'Injected Alt down observed without a suppressed release' }
    $result.checks += @{ name = 'controlled-lost-alt-release'; injectedDown = $record.injectedDown; droppedUp = $record.droppedUp; text = $record.actual }
} catch {
    $record.error = $_.Exception.Message
    throw
} finally {
    $record.injectedDown = $fault.Down
    $record.droppedUp = $fault.Dropped
    $record.events = @($fault.Events)
    try { WindowShot 'fault-final' } catch { $record.screenshotError = $_.Exception.Message }
    try { $fault.Dispose() } finally { Save-Json $record 'browser-typing-fault.json' }
}
Snapshot 'after'
} finally {
    try { Save-Json @($typingObservations.ToArray()) 'browser-typing-observations.json' } catch { Write-Warning $_.Exception.Message }
    if ($null -ne $pageJob) {
        try {
            $beforeStop = $pageJob.ReadAccounting()
            $stopped = $pageJob.Stop()
            Save-Json @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } 'browser-typing-page-cleanup.json'
            if ($stopped.ActiveProcesses -ne 0) { throw 'Local page server job still has active processes' }
        } catch {
            Save-Json @{ error = $_.Exception.Message } 'browser-typing-page-cleanup.json'
            throw
        } finally {
            if ($null -ne $pageServer) { $pageServer.Dispose() }
            $pageJob.Dispose()
        }
    }
}
