function Save-Json($Value, [string]$Name) {
    Write-Host "Evidence: serialize $Name"
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}

function Record([string]$Action) {
    Write-Host $Action
    [void]$script:actions.Add(@{ time = [DateTime]::UtcNow.ToString('o'); action = $Action; title = [VerifyNative]::Title($script:window) })
    Save-Json @($script:actions.ToArray()) 'actions.json'
}

function Release-ScratchConsoleFonts([string]$Path) {
    $fontRoot = Join-Path $Path 'local/ZigShell/fonts'
    if (-not (Test-Path -LiteralPath $fontRoot)) { return }
    $released = @()
    foreach ($entry in Get-ChildItem -LiteralPath $fontRoot -Force) {
        if ($entry -isnot [IO.FileInfo] -or $entry.Extension -ine '.ttf' -or
            ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint) { continue }
        $count = 0
        while ([VerifyNative]::RemoveFontResourceEx($entry.FullName, 0, [IntPtr]::Zero)) { $count++ }
        $released += @{ name = $entry.Name; registrations = $count }
    }
    Save-Json @($released) 'console-font-cleanup.json'
}

function Test-VanishedScratchItem($Failure, [string]$Path) {
    if (Test-Path -LiteralPath $Path) { return $false }
    $exception = $Failure.Exception
    while ($null -ne $exception) {
        if ($exception -is [System.Management.Automation.ItemNotFoundException] -or
            $exception -is [IO.FileNotFoundException] -or $exception -is [IO.DirectoryNotFoundException]) { return $true }
        $exception = $exception.InnerException
    }
    return $false
}

function Prepare-ScratchEvidence([string]$Path) {
    $blockedAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    try {
        foreach ($entry in Get-ChildItem -LiteralPath $Path -Force) {
            try {
                if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $script:scratchLinks += @{ path = $entry.FullName.Substring($scratch.Length + 1); attributes = $entry.Attributes.ToString(); linkType = $entry.LinkType; target = @($entry.Target) }
                    Save-Json @($script:scratchLinks) 'scratch-links.json'
                    $entry.Delete()
                    Record 'Cleanup: recorded and unlinked scratch reparse point without traversing its target'
                } else {
                    $entry.Attributes = $entry.Attributes -band (-bnot $blockedAttributes)
                    if ($entry -is [IO.DirectoryInfo]) { Prepare-ScratchEvidence $entry.FullName }
                }
            } catch {
                if (-not (Test-VanishedScratchItem $_ $entry.FullName)) { throw }
            }
        }
    } catch {
        if (-not (Test-VanishedScratchItem $_ $Path)) { throw }
    }
}

function Remove-ScratchPath([string]$Path, [int]$Seconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    while (Test-Path -LiteralPath $Path) {
        try { Remove-Item $Path -Recurse -Force } catch {
            $failedPath = if ($_.TargetObject -is [string]) { $_.TargetObject } else { $Path }
            if (-not (Test-VanishedScratchItem $_ $failedPath)) {
                if (-not (Test-Path -LiteralPath $Path)) { throw }
                $lastError = $_.Exception.Message
            }
        }
        if (Test-Path -LiteralPath $Path) {
            if ([DateTime]::UtcNow -ge $deadline) {
                $leftovers = @($Path) + @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Select-Object -ExpandProperty FullName)
                throw ("Scratch cleanup left paths: " + ($leftovers -join ', ') + ". " + $lastError)
            }
            Start-Sleep -Milliseconds 200
        }
    }
}

function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20, [int]$PollMilliseconds = 200, [switch]$Tight) {
    Write-Host "Wait: $Description (timeout $Seconds s)"
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    do {
        if ($null -ne $process -and $process.HasExited) { throw "App exited while waiting for $Description" }
        try { if (& $Condition) { return } } catch { $lastError = $_.Exception.Message }
        if ($Tight) { [Threading.Thread]::Sleep(1) } else { Start-Sleep -Milliseconds $PollMilliseconds }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Waited $Seconds s for $Description. $lastError"
}

function Read-Session {
    $path = Join-Path $scratch 'roaming/ZigShell/session.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Read-Inbox {
    $path = Join-Path $scratch 'roaming/ZigShell/inbox-default.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Wait-ChatViews([bool[]]$Views, [int]$Active, [string]$Step, [bool]$Pinned = $true) {
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state -or @($state.tabs).Count -ne 3 -or $state.active_tab -ne $Active) { return $false }
        if ($state.PSObject.Properties['chat_view_mode']) { throw 'Global forcing mode was saved again' }
        for ($i = 0; $i -lt 3; $i++) {
            $on = $state.tabs[$i].PSObject.Properties['cv'] -and $state.tabs[$i].cv -eq $true
            if ($on -ne $Views[$i]) { return $false }
        }
        if (@($state.tabs | Where-Object { $_.PSObject.Properties['chat_view_lock'] -or $_.PSObject.Properties['locked'] }).Count -ne 0) { throw 'Removed session locks were saved again' }
        $pin = $state.tabs[2].PSObject.Properties['pinned_top'] -and $state.tabs[2].pinned_top -eq $true
        $pin -eq $Pinned
    } "app-written views and pin: $Step"
    Wait-Until {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
        $visible = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count
        $visible -eq [int]$Views[$Active]
    } "visible active view: $Step"
    Save-Json (Read-Session) ($Step + '.session.json')
    Snapshot $Step
}

function Read-BrowserPane {
    $state = Read-Inbox
    if ($null -eq $state) { return $null }
    return @($state.shells | Where-Object { $_.sid -eq $script:browserShellId })[0]
}

function Wait-SwitchNativeHost {
    Wait-Until {
        $pipe = New-Object IO.Pipes.NamedPipeClientStream('.', 'multiprompt-browser-isolated', [IO.Pipes.PipeDirection]::Out)
        try { $pipe.Connect(100); return $pipe.IsConnected } catch { return $false } finally { $pipe.Dispose() }
    } 'native messaging host reconnect on extension keepalive' 90
}

function Read-BrowserFrozen([uint32]$SessionId) {
    $path = Join-Path $scratch ("roaming/ZigShell/panehib-zss-$SessionId.flag")
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { if ((Get-Content -LiteralPath $path -Raw -ErrorAction Stop).Trim() -ceq '1') { return $true } } catch { return $null }
        return $null
    }
    return $false
}

function Assert-BrowserPane([string]$State, [string]$Step, [long]$PreviousId = 0) {
    Wait-Until {
        $pane = Read-BrowserPane
        $null -ne $pane -and
            (($State -eq 'open' -and $pane.browser_state -in @('opening', 'connected')) -or $pane.browser_state -eq $State) -and
            (($State -in @('open', 'opening', 'connected') -and $pane.browser_connection_id -gt $PreviousId) -or
             ($State -in @('closed', 'failed') -and $pane.browser_connection_id -eq 0))
    } "browser-pane-stuck ${Step}: $State and connection identity" 25
    $pane = Read-BrowserPane
    if ($Feature -notin @('browser-switch-speed', 'chat-switch-speed') -and $pane.browser_window_id -ne 0) { throw 'Unexpected browser extension connection in the no-extension journey' }
    Save-Json $pane ("browser-pane-$Step.json")
    $result.checks += @{ name = "browser-pane-stuck $Step"; state = $pane.browser_state; connectionId = $pane.browser_connection_id }
    Write-Host "browser-pane-stuck $Step PASS"
    return $pane
}

function Press-CloseBrowserPane([string]$Label) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Press @(0x12, 0x41) $Label
        try {
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_state -eq 'closed' } "Alt+A attempt $attempt closed the browser pane" 3
            return
        } catch { if ($attempt -eq 3) { throw } }
    }
}

function Focus-BrowserPaneOwner([string]$Step, [long]$ConnectionId) {
    Wait-Until {
        $pane = Read-BrowserPane
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and
            $pane.browser_connection_id -eq $ConnectionId -and [VerifyNative]::PaneVisible($script:window)
    } "browser-pane-stuck ${Step}: docked pane ready for main-window activation" 25
    Doctor
    Record "Activate main window after browser-pane-stuck ${Step} docking"
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } "browser-pane-stuck ${Step}: main window is foreground" 5
}

function Open-BrowserPane([string]$Step, [long]$PreviousId = 0) {
    Palette 'open browser'
    Press @(0x0D) 'Enter: Open Browser Pane'
    $pane = Assert-BrowserPane 'open' $Step $PreviousId
    Focus-BrowserPaneOwner $Step $pane.browser_connection_id
    return $pane
}

function Assert-BrowserPaneMonitors([string]$Step, [switch]$RequireParked) {
    $ownerMonitor = [VerifyNative]::MonitorFromWindow($script:window, 2)
    $previousDpiContext = [VerifyNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
    if ($previousDpiContext -eq [IntPtr]::Zero) { throw 'Could not query pane monitors as per-monitor aware' }
    try {
        $proof = @([VerifyNative]::OwnedPaneWindows($script:window) | ForEach-Object {
            $paneHwnd = $_
            $rect = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($paneHwnd, [ref]$rect)) { throw 'Owned pane rectangle unavailable' }
            $parked = [VerifyNative]::MonitorFromRect([ref]$rect, 0) -eq [IntPtr]::Zero
            $paneMonitor = [VerifyNative]::MonitorFromWindow($paneHwnd, 2)
            $visible = [VerifyNative]::IsWindowVisible($paneHwnd) -and -not $parked
            $paneDpi = [VerifyNative]::GetDpiForWindow($paneHwnd)
            [uint32]$monitorDpiX = 0; [uint32]$monitorDpiY = 0
            $monitorDpiResult = [VerifyNative]::GetDpiForMonitor($paneMonitor, 0, [ref]$monitorDpiX, [ref]$monitorDpiY)
            if ($parked -and $paneMonitor -ne $ownerMonitor) { throw 'Parked pane is nearest a different monitor than its owner' }
            if ($visible -and ($monitorDpiResult -ne 0 -or $monitorDpiX -eq 0 -or $paneDpi -ne $monitorDpiX -or $paneDpi -ne $monitorDpiY)) { throw 'Visible pane DPI differs from its monitor DPI' }
            @{ hwnd = $paneHwnd.ToInt64(); rect = $rect; parked = $parked; visible = $visible; monitor = $paneMonitor.ToInt64(); ownerMonitor = $ownerMonitor.ToInt64(); paneDpi = $paneDpi; monitorDpiX = $monitorDpiX; monitorDpiY = $monitorDpiY }
        })
        if ($proof.Count -eq 0) { throw 'No owned panes for monitor verification' }
        if ($RequireParked -and @($proof | Where-Object { $_.parked }).Count -eq 0) { throw 'No parked pane exercised by the overlay' }
        Save-Json $proof ("browser-pane-locked-monitors-$Step.json")
        return $proof
    }
    finally { [void][VerifyNative]::SetThreadDpiAwarenessContext($previousDpiContext) }
}

function Assert-BrowserLaunchOnOwnMonitor([string]$Step) {
    Doctor
    $browser = [VerifyNative]::PaneWindow($script:window)
    if ($browser -eq [IntPtr]::Zero -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Launch scale requires an owned pane HWND' }
    $monitor = [VerifyNative]::MonitorFromWindow($script:window, 1)
    $info = New-Object VerifyNative+MonitorInfo
    $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
    if (-not [VerifyNative]::GetMonitorInfoW($monitor, [ref]$info)) { throw 'Owner monitor rectangle unavailable' }
    $profile = (Join-Path $env:LOCALAPPDATA 'ZigShell') -replace '\\', '/'
    $profileArgument = '(?:^|\s)--user-data-dir="?' + [regex]::Escape($profile) + '/(?:ChromeUserData|EdgeUserData)"?(?=\s|$)'
    $launches = @(Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe' OR Name = 'msedge.exe'" | Where-Object {
        ($_.CommandLine -replace '\\', '/') -match $profileArgument -and $_.CommandLine.Contains('--window-position=')
    } | ForEach-Object {
        $point = [regex]::Match($_.CommandLine, '(?:^|\s)--window-position=(-?\d+),(-?\d+)(?:\s|$)')
        $x = $null; $y = $null; $inside = $false
        if ($point.Success) {
            $x = [int]$point.Groups[1].Value; $y = [int]$point.Groups[2].Value
            $inside = $x -ge $info.Monitor.Left -and $x -lt $info.Monitor.Right -and
                $y -ge $info.Monitor.Top -and $y -lt $info.Monitor.Bottom
        }
        @{ pid = $_.ProcessId; commandLine = $_.CommandLine; parsed = $point.Success; x = $x; y = $y; inside = $inside }
    })
    [uint32]$browserPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
    $mainDpi = [VerifyNative]::GetDpiForWindow($script:window)
    $paneDpi = [VerifyNative]::GetDpiForWindow($browser)
    $paneMonitor = [VerifyNative]::MonitorFromWindow($browser, 2)
    [uint32]$monitorDpiX = 0; [uint32]$monitorDpiY = 0
    $previousDpiContext = [VerifyNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
    if ($previousDpiContext -eq [IntPtr]::Zero) { throw 'Could not query effective monitor DPI as per-monitor aware' }
    try { $monitorDpiResult = [VerifyNative]::GetDpiForMonitor($monitor, 0, [ref]$monitorDpiX, [ref]$monitorDpiY) }
    finally { [void][VerifyNative]::SetThreadDpiAwarenessContext($previousDpiContext) }
    $proof = @{ step = $Step; launches = $launches; monitor = $info.Monitor; mainHwnd = $script:window.ToInt64(); paneHwnd = $browser.ToInt64(); panePid = $browserPid; mainDpi = $mainDpi; paneDpi = $paneDpi; paneMonitor = $paneMonitor.ToInt64(); monitorDpiX = $monitorDpiX; monitorDpiY = $monitorDpiY }
    Save-Json $proof ("browser-pane-locked-launch-$Step.json")
    if ($launches.Count -eq 0 -or $browserPid -notin @($launches | ForEach-Object { $_.pid })) { throw 'No isolated browser launch command line for the owned pane' }
    if (@($launches | Where-Object { -not $_.parsed -or -not $_.inside }).Count -ne 0) { throw 'Browser launch point is outside the owner monitor' }
    if ($mainDpi -eq 0 -or $paneDpi -ne $mainDpi) { throw "Pane DPI $paneDpi differs from owner DPI $mainDpi" }
    if ($paneMonitor -ne $monitor -or $monitorDpiResult -ne 0 -or $monitorDpiX -eq 0 -or $paneDpi -ne $monitorDpiX -or $paneDpi -ne $monitorDpiY) { throw "Pane DPI $paneDpi differs from its target monitor DPI $monitorDpiX,$monitorDpiY" }
    $null = Assert-BrowserPaneMonitors $Step
    return $proof
}

function Focus-LockedBrowser([IntPtr]$Browser) {
    Doctor
    if ([VerifyNative]::GetProp($Browser, 'ZigShellPaneOwner') -ne $script:window -or
        [VerifyNative]::PaneWindow($script:window) -ne $Browser) { throw 'Browser lock ownership changed' }
    [uint32]$browserPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($Browser, [ref]$browserPid)
    Wait-Until {
        [VerifyNative]::FocusOwnedWindow($Browser, $browserPid, $script:window)
        [VerifyNative]::GetForegroundWindow() -eq $Browser
    } 'locked browser has real keyboard focus' 5
}

function Assert-LockedBrowserRect([IntPtr]$Browser, $DockRect, [string]$Step) {
    $settle = [Diagnostics.Stopwatch]::StartNew()
    Wait-Until {
        $current = New-Object VerifyNative+Rect
        $settle.ElapsedMilliseconds -ge 1000 -and
            [VerifyNative]::GetProp($Browser, 'ZigShellPaneOwner') -eq $script:window -and
            [VerifyNative]::PaneWindow($script:window) -eq $Browser -and
            -not [VerifyNative]::IsZoomed($Browser) -and
            [VerifyNative]::GetWindowRect($Browser, [ref]$current) -and
            $current.Left -eq $DockRect.Left -and $current.Top -eq $DockRect.Top -and
            $current.Right -eq $DockRect.Right -and $current.Bottom -eq $DockRect.Bottom
    } "browser-pane-locked ${Step}: exact dock rectangle and not zoomed" 5
    $current = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($Browser, [ref]$current)) { throw 'Locked browser rect unavailable' }
    Save-Json @{ hwnd = $Browser.ToInt64(); dock = $DockRect; actual = $current; zoomed = [VerifyNative]::IsZoomed($Browser); tolerance = 0 } ("browser-pane-locked-$Step.json")
    $result.checks += @{ name = "browser-pane-locked $Step"; rect = $current; tolerance = 0 }
    Write-Host "browser-pane-locked $Step PASS"
}

function Get-LockedBrowserStrip([IntPtr]$Browser, $DockRect) {
    $point = New-Object VerifyNative+Point
    $point.X = $DockRect.Right - 160
    $point.Y = $DockRect.Top + 8
    if ($point.X -le $DockRect.Left -or $point.Y -ge $DockRect.Bottom) { throw 'Browser strip is too small' }
    $hit = [System.Windows.Automation.AutomationElement]::FromPoint([Windows.Point]::new($point.X, $point.Y))
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    $observed = @()
    while ($null -ne $hit) {
        $type = $hit.Current.ControlType.ProgrammaticName
        $observed += @{ type = $type; name = $hit.Current.Name; handle = $hit.Current.NativeWindowHandle }
        if ($type -in @('ControlType.TabItem', 'ControlType.Button', 'ControlType.Edit', 'ControlType.Hyperlink', 'ControlType.MenuItem')) { throw "Strip target is a control, not empty title area: $type" }
        if ($hit.Current.NativeWindowHandle -eq $Browser.ToInt64()) { break }
        $hit = $walker.GetParent($hit)
    }
    if ($null -eq $hit) { throw 'Strip UIA ancestry does not reach the owned browser' }
    Save-Json @{ point = $point; ancestry = $observed } 'browser-pane-locked-strip.json'
    return $point
}

function Assert-ConnectedPaneStaysVisible([long]$ConnectionId) {
    $connected = Assert-BrowserPane 'connected' 'connected-pane-docked' ($ConnectionId - 1)
    if ($connected.browser_connection_id -ne $ConnectionId) { throw 'Docking replaced the browser connection' }
    Wait-Until { [VerifyNative]::PaneVisible($script:window) } 'docked browser pane is visible inside the app'
    $deadline = [DateTime]::UtcNow.AddSeconds(21)
    do {
        $pane = Read-BrowserPane
        if ($null -eq $pane -or $pane.browser_state -ne 'connected' -or $pane.browser_connection_id -ne $ConnectionId -or
            $pane.browser_window_id -ne 0 -or -not [VerifyNative]::PaneVisible($script:window)) {
            throw 'Connected pane closed, hid, or lost its identity past the opening deadline'
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    $pane = Assert-BrowserPane 'connected' 'connected-pane-stays-visible' ($ConnectionId - 1)
    Snapshot 'connected'
}

function Get-SwitchMedian($Values) {
    if (@($Values).Count -eq 0) { return $null }
    foreach ($value in $Values) { if ($null -eq $value) { return $null } }
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return [double]$sorted[$middle] }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2
}

function Doctor {
    Write-Host 'Doctor: checking owned executable and UI Automation window'
    $process.Refresh()
    if ($process.HasExited -or $script:window -eq [IntPtr]::Zero) { throw 'Doctor: owned app window missing' }
    [uint32]$owner = 0
    [void][VerifyNative]::GetWindowThreadProcessId($script:window, [ref]$owner)
    if ($owner -ne $process.Id -or [VerifyNative]::Class($script:window) -ne 'ZigShell') { throw 'Doctor: window ownership mismatch' }
    if ($process.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    $title = [VerifyNative]::Title($script:window)
    $legacyTitle = '(?:^| - )multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?= |$)(?: .*)?$'
    if ($title -cne 'Multi Bot' -and $title -cnotmatch $legacyTitle) { throw "Doctor: wrong window title: $title" }
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Doctor: executable version mismatch' }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    if ($element.Current.ProcessId -ne $process.Id -or $element.Current.IsOffscreen) { throw 'Doctor: UI Automation cannot see owned window' }
    $state = Read-Inbox
    if ($null -eq $state -or @($state.shells).Count -lt 1) { throw 'Doctor: no usable initial shell published' }
    Save-Json @{ pid = $process.Id; hwnd = $script:window.ToInt64(); title = $title; class = $element.Current.ClassName; version = $ExpectedVersion; sha256 = $ExpectedHash; shellCount = @($state.shells).Count; data = $scratch } 'doctor.json'
}

function WindowShot([string]$Name) {
    [void][VerifyNative]::DwmFlush()
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $shotPath = Join-Path $Evidence "$Name.png"
        $bitmap.Save($shotPath, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Snapshot([string]$Name) {
    Write-Host "Evidence: snapshot $Name, focused UI Automation element"
    $foreground = [VerifyNative]::GetForegroundWindow()
    $focus = @{ foreground = $foreground.ToInt64(); capturedAt = [DateTime]::UtcNow.ToString('o') }
    try {
        $focus.foregroundWindow = [VerifyNative]::WindowIdentity($foreground)
        $focus.foregroundRoot = [VerifyNative]::WindowIdentity([VerifyNative]::GetAncestor($foreground, 2))
        $focus.foregroundRootOwner = [VerifyNative]::WindowIdentity([VerifyNative]::GetAncestor($foreground, 3))
    } catch { $focus.foregroundError = $_.Exception.Message }
    try { $focus.native = [VerifyNative]::GetFocusedWindow($script:window).ToInt64() } catch { $focus.nativeError = $_.Exception.Message }
    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $focus.uia = @{ handle = $focused.Current.NativeWindowHandle; pid = $focused.Current.ProcessId; class = $focused.Current.ClassName }
    } catch { $focus.uiaError = $_.Exception.Message }
    try { $focus.desktopWindows = @([VerifyNative]::DesktopWindows()) } catch { $focus.desktopError = $_.Exception.Message }
    try {
        $focus.processes = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, CreationDate | Select-Object ProcessId, ParentProcessId, Name, CreationDate)
    } catch { $focus.processError = $_.Exception.Message }
    Save-Json $focus ($Name + '.focus.json')
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    Write-Host "Evidence: snapshot $Name, UI Automation subtree"
    $nodes = $element.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
    $tree = foreach ($node in $nodes) {
        @{ name = $node.Current.Name; class = $node.Current.ClassName; type = $node.Current.ControlType.ProgrammaticName; pid = $node.Current.ProcessId; handle = $node.Current.NativeWindowHandle }
    }
    Save-Json @($tree) ($Name + '.uia.json')
    [void][VerifyNative]::DwmFlush()
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $Evidence ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Assert-Foreground {
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $foreground = [VerifyNative]::GetForegroundWindow()
        $root = [VerifyNative]::GetAncestor($foreground, 2)
        $rootOwner = [VerifyNative]::GetAncestor($foreground, 3)
        [uint32]$foregroundOwner = 0
        [void][VerifyNative]::GetWindowThreadProcessId($rootOwner, [ref]$foregroundOwner)
        if ($foreground -ne [IntPtr]::Zero -and $root -ne [IntPtr]::Zero -and $rootOwner -ne [IntPtr]::Zero -and
            ($root -eq $script:window -or $foregroundOwner -eq $process.Id)) { return }
        if ($attempt -lt 4) { Start-Sleep -Milliseconds 100 }
    }
    throw 'Refusing input: owned app is not foreground'
}

function Wait-Foreground {
    try { Assert-Foreground; return } catch {}
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        [void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)
        [void][VerifyNative]::SetForegroundWindow($script:window)
        try { Assert-Foreground; return } catch {}
        if ($attempt -lt 49) { Start-Sleep -Milliseconds 100 }
    }
    Assert-Foreground
}

function Press([int[]]$Keys, [string]$Label) {
    Doctor
    Wait-Foreground
    Record $Label
    Assert-Foreground
    [VerifyNative]::Chord($Keys)
}

function Type-Text([string]$Text) {
    Doctor
    Wait-Foreground
    Record ('Type ' + $Text)
    Assert-Foreground
    [VerifyNative]::Text($Text)
}

function Click-WorkspacePill([int]$Workspace) {
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and $state.single_window -and $state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills -and -not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -and -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed) -and $Workspace -ge 0 -and $Workspace -lt $state.workspace_count -and @($state.workspaces | Where-Object { $_.PSObject.Properties['snoozed'] -and $_.snoozed }).Count -eq 0 -and (-not $state.PSObject.Properties['ui_scale'] -or $state.ui_scale -eq 100)
    } "visible unsnoozed workspace pill $Workspace at default layout"
    Doctor
    Assert-Foreground
    Record ("Click workspace pill for stored workspace $Workspace")
    [void][VerifyNative]::DwmFlush()
    [VerifyNative]::ClickClient($script:window, (8 + ($Workspace + 1) * 29 + 12), 17)
}

function Press-ShiftEnter([string]$Label) {
    Doctor
    Wait-Foreground
    Record $Label
    Assert-Foreground
    $composer = [VerifyNative]::GetFocusedWindow($script:window)
    if ([VerifyNative]::GetAncestor($composer, 2) -ne $script:window -or [VerifyNative]::Class($composer) -cne 'Edit') { throw 'Shift+Enter needs the owned focused composer' }
    $before = @([VerifyNative]::EditText($composer) -split "`r?`n").Count
    [VerifyNative]::KeyDown(0x10)
    try {
        Start-Sleep -Milliseconds 35
        [VerifyNative]::KeyDown(0x0D)
        Start-Sleep -Milliseconds 35
        [VerifyNative]::KeyUp(0x0D)
        Wait-Until { @([VerifyNative]::EditText($composer) -split "`r?`n").Count -eq ($before + 1) } 'native composer shows the Shift+Enter newline while Shift is held' -Tight
    } finally {
        [VerifyNative]::KeyUp(0x10)
    }
    Wait-Until { -not [VerifyNative]::IsDown(0x10) } 'Shift is released after Shift+Enter'
    Record 'Shift released after Shift+Enter'
}

function Activate-OwnedFrame {
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        [void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)
        [void][VerifyNative]::SetForegroundWindow($script:window)
        if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window) { return }
        Start-Sleep -Milliseconds 100
    }
}

function Retry-PaletteOpen([string]$Log, [int]$Start) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $deadline = [DateTime]::UtcNow.AddSeconds(6)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ((((Get-Content $Log -Raw) -join '').Substring($Start)) -match '\[palette\] ready chars=0 count=\d+ target=\d+') { return }
            Start-Sleep -Milliseconds 200
        }
        if ($attempt -eq 3) { return }
        Record ('Command palette trace missing after Ctrl+K attempt ' + $attempt)
        Activate-OwnedFrame
        Press @(0x11, 0x4B) 'Ctrl+K: open command palette again'
    }
}

function Focus-Palette([string]$Query, [int]$Target) {
    if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -ne $script:window) { Activate-OwnedFrame }
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $start = ((Get-Content $log -Raw) -join '').Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Retry-PaletteOpen $log $start
    Wait-Until {
        $trace = ((Get-Content $log -Raw) -join '').Substring($start)
        if ($trace -notmatch '\[palette\] ready chars=0 count=\d+ target=\d+') { return $false }
        Doctor
        Assert-Foreground
        [void][VerifyNative]::SetForegroundWindow($script:window)
        $trace -match '\[palette\] ready chars=0 count=\d+ target=\d+' -and [VerifyNative]::GetForegroundWindow() -eq $script:window -and [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
    } 'command palette initialized and owned frame focused' 20
    Type-Text $Query
    Wait-Until {
        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] ready chars=' + $Query.Length + ' count=[1-9]\d* target=' + $Target + '(?:\r?\n|$)')
    } "palette query consumed and expected command $Target selected"
}

function Wait-WorkspaceSurface([int]$Workspace, [int]$Tab, [bool]$Chat, [int]$Composer = 0) {
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state -or $state.active_workspace -ne $Workspace -or $state.active_tab -ne $Tab -or $state.tabs[$Tab].kind -ne 'cmd' -or [bool]($state.tabs[$Tab].PSObject.Properties['cv'] -and $state.tabs[$Tab].cv) -ne $Chat) { return $false }
        $foreground = [VerifyNative]::GetForegroundWindow()
        if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window) { return $false }
        if (-not $Chat) {
            return [VerifyNative]::Class($foreground) -eq 'ConsoleWindowClass' -and [VerifyNative]::Title($foreground).EndsWith(('ZigShell-' + $state.tabs[$Tab].shell_id), [StringComparison]::Ordinal)
        }
        $element = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$Composer)
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $foreground -eq $script:window -and $element.Current.ProcessId -eq $process.Id -and -not $element.Current.IsOffscreen -and $focused.Current.NativeWindowHandle -eq $Composer
    } "workspace $Workspace session $Tab Chat View=$Chat visible and input ready"
}

function Wait-ConsoleText([string]$Command) {
    Wait-Until {
        $foreground = [VerifyNative]::GetForegroundWindow()
        if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window -or [VerifyNative]::Class($foreground) -ne 'ConsoleWindowClass') { return $false }
        $console = [System.Windows.Automation.AutomationElement]::FromHandle($foreground)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
        $document = $console.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        if ($null -eq $document) { return $false }
        $pattern = $document.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
        $text = $pattern.DocumentRange.GetText(-1) -replace '[\r\n]', ''
        $text.TrimEnd().EndsWith($Command, [StringComparison]::Ordinal)
    } "console visibly contains staged command: $Command"
}

function Send-ProfileScreenshot([string]$Step, [string]$Profile, [int]$ExpectedUpload) {
    $pane = Read-BrowserPane
    $windowId = [int64]$pane.browser_window_id
    if ($windowId -le 0) { throw "screenshot ${Step}: pane has no bound browser window" }
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $logStart = (Read-SharedText $log).Length
    $bridge = Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'
    $arguments = ''
    if ($Profile -ne '') { $arguments += "--profile $Profile " }
    $arguments += "--window $windowId shoturl --user-initiated"
    $stdout = Join-Path $Evidence "screenshot-$Step.stdout.txt"
    $stderr = Join-Path $Evidence "screenshot-$Step.stderr.txt"
    $shot = Start-Process -FilePath $bridge -ArgumentList $arguments -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    [void]$shot.Handle
    if (-not $shot.WaitForExit(60000)) { $shot.Kill(); throw "screenshot ${Step}: shoturl did not finish in 60 seconds" }
    $exitCode = $shot.ExitCode
    $output = (([string](Get-Content -LiteralPath $stdout -Raw)) + ([string](Get-Content -LiteralPath $stderr -Raw))).Trim()
    if ($exitCode -ne 0) { throw "screenshot ${Step}: shoturl failed with exit ${exitCode}: $output" }
    $expectedUrl = "https://example.invalid/shot-$ExpectedUpload.png"
    Wait-Until {
        $trace = (Read-SharedText $log).Substring($logStart)
        $trace.Contains("notify: payload=SHOTUSER:${windowId}:$expectedUrl") -and $trace -match '\[paste-focus\] queued shell=\d+ user=true' -and $trace -match '\[paste-focus\] (console|composer) paste applied'
    } "screenshot ${Step}: the app received and pasted the link from window $windowId" 60
    $uploads = @(Get-Content -LiteralPath (Join-Path $script:uploadReceiverDir 'uploads.jsonl'))
    if ($uploads.Count -ne $ExpectedUpload) { throw "screenshot ${Step}: expected $ExpectedUpload uploads but the receiver saw $($uploads.Count)" }
    $result.checks += @{ name = "browser-own-profile screenshot $Step"; windowId = $windowId; url = $expectedUrl; profile = $(if ($Profile -eq '') { 'shared' } else { $Profile }) }
}

function Palette([string]$Query) {
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Wait-Foreground
    Type-Text $Query
}

function Invoke-Zsb([string[]]$Arguments, [int]$Port, [string]$Name) {
    Doctor
    Assert-Foreground
    Record ('zsb ' + ($Arguments -join ' '))
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Arguments -join [char]0x1F) + [char]0x1F))
    $wire = [Text.Encoding]::UTF8.GetBytes("ZSB:workspace:${payload}`n")
    [IO.File]::WriteAllBytes((Join-Path $Evidence ($Name + '.request.bin')), $wire)
    $client = New-Object Net.Sockets.TcpClient
    $reply = New-Object IO.MemoryStream
    try {
        $connecting = $client.ConnectAsync('127.0.0.1', $Port)
        if (-not $connecting.Wait(5000)) { throw 'zsb local bridge connection timed out' }
        [void]$connecting.GetAwaiter().GetResult()
        $stream = $client.GetStream()
        $stream.WriteTimeout = 5000
        $stream.Write($wire, 0, $wire.Length)
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $buffer = New-Object byte[] 65536
        do {
            $remaining = 90000 - $timer.ElapsedMilliseconds
            if ($remaining -le 0) { throw 'zsb reply exceeded 90 seconds' }
            $stream.ReadTimeout = [int]$remaining
            $count = $stream.Read($buffer, 0, $buffer.Length)
            if ($reply.Length + $count -gt 16 * 1024 * 1024) { throw 'zsb reply exceeded 16 MiB' }
            $reply.Write($buffer, 0, $count)
        } while ($count -gt 0)
        $raw = [Text.Encoding]::UTF8.GetString($reply.ToArray())
        [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '.reply.json')), $raw)
        $response = $raw | ConvertFrom-Json
        if ($response.ok -ne $true) { throw "zsb rejected $Name`: $raw" }
        return $response
    } finally { $reply.Dispose(); $client.Dispose() }
}

function Prepare-SessionRestoreGroupOrder([string]$Stage) {
    $saved = Read-Session
    $tabs = @($saved.tabs)
    $middle = [int]$saved.active_tab
    if (-not $saved.starred_view -or $tabs[$middle].name -cne 'Restore middle') { throw 'Group reorder requires the selected middle favorite in Starred' }
    $first = -1
    $last = -1
    for ($i = 0; $i -lt $tabs.Count; $i++) {
        if ($tabs[$i].name -ceq 'Restore first') { $first = $i }
        if ($tabs[$i].name -ceq 'Restore last') { $last = $i }
    }
    if ($first -lt 0 -or $last -lt 0 -or $first -ge $middle -or $first -ge $last -or
        -not $tabs[$first].PSObject.Properties['group_id'] -or -not $tabs[$middle].PSObject.Properties['group_id'] -or
        $tabs[$first].group_id -eq 0 -or $tabs[$first].group_id -ne $tabs[$middle].group_id -or
        $tabs[$last].PSObject.Properties['group_id'] -or $tabs[$middle].PSObject.Properties['starred_group_id'] -or
        $tabs[$last].PSObject.Properties['starred_group_id']) { throw 'Expected one home group and an ungrouped Starred neighbor' }
    if ($middle + 1 -eq $last) {
        Press @(0x11, 0x10, 0x28) 'Ctrl+Shift+Down: split the home group by moving its selected favorite below the ungrouped favorite in Starred'
    } elseif ($last + 1 -ne $middle) {
        throw 'Expected adjacent middle and last sessions before the Starred reorder'
    }
    Wait-Until {
        $saved = Read-Session
        $tabs = @($saved.tabs)
        $middle = [int]$saved.active_tab
        $state = Read-Inbox
        $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
        $middle -ge 2 -and $saved.starred_view -and $state.starred_view -and
            $tabs[$middle].name -ceq 'Restore middle' -and $tabs[$middle - 1].name -ceq 'Restore last' -and
            $tabs[$middle - 2].name -ceq 'Restore first' -and [int]$tabs[$middle].group_id -ne 0 -and
            $tabs[$middle - 2].group_id -eq $tabs[$middle].group_id -and -not $tabs[$middle - 1].PSObject.Properties['group_id'] -and
            $selected.Count -eq 1 -and $selected[0].name -ceq 'Restore middle'
    } "$Stage saved selected index moves left when the split home group is normalized"
    $saved = Read-Session
    $middle = [int]$saved.active_tab
    Save-Json @{ savedIndex = $middle; normalizedIndex = ($middle - 1); selected = 'Restore middle'; wrongAtSavedIndex = 'Restore last'; session = $saved } ($Stage + '-group-order.json')
}

function Restart-SessionRestore([string]$Stage, [bool]$Crash, [bool]$Updater = $false, [scriptblock]$BeforeStart = $null) {
    Doctor
    if ($process.MainWindowHandle -ne $script:window) { throw 'Refusing to close a different window' }
    Save-Json (Read-Inbox) ($Stage + '-before.inbox.json')
    Save-Json (Read-Session) ($Stage + '-before.session.json')
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $logStart = ((Get-Content $log -Raw) -join '').Length
    $oldPid = $process.Id
    $nextJob = $null
    $helper = $null
    try {
    if ($Updater) {
        if ($Crash) { throw 'Updater restart requires WM_CLOSE' }
        $nextJob = New-Object VerifyJob
        Record 'Start the real updater relaunch helper before WM_CLOSE'
        $helper = $nextJob.Start($Exe, $scratch, (Join-Path $Evidence ($Stage + '-stdout.log')), (Join-Path $Evidence ($Stage + '-stderr.log')), ('--relaunch-after ' + $oldPid))
        if ($helper.HasExited) { throw 'Updater helper exited before the old app closed' }
        Save-Json @{ oldPid = $oldPid; helperPid = $helper.Id; arguments = ('--relaunch-after ' + $oldPid) } ($Stage + '-helper.json')
    }
    if ($Crash) {
        Record 'Kill only the verified owned app PID after selection persistence'
        Stop-Process -Id $process.Id -Force
    } else {
        Record 'WM_CLOSE: close only the verified owned main window normally'
        if (-not $process.CloseMainWindow()) { throw 'Owned window refused WM_CLOSE' }
    }
    if (-not $process.WaitForExit(20000)) { throw "$Stage app did not exit" }
    $stopped = $job.Stop()
    Save-Json @{ pid = $process.Id; activeAfterStop = $stopped.ActiveProcesses; crash = $Crash } ($Stage + '-exit.json')
    $process.Dispose()
    $job.Dispose()
    $script:process = $null
    $script:job = $null
    $script:window = [IntPtr]::Zero
    if ($null -ne $BeforeStart) { & $BeforeStart }
    if ($Updater) {
        Wait-Until {
            $state = Read-Inbox
            if ($null -eq $state -or -not $state.hwnd) { return $false }
            $candidateWindow = [IntPtr]([long]$state.hwnd)
            [uint32]$owner = 0
            [void][VerifyNative]::GetWindowThreadProcessId($candidateWindow, [ref]$owner)
            if ($owner -eq 0 -or $owner -eq $oldPid -or $owner -eq $helper.Id) { return $false }
            $candidate = Get-Process -Id $owner -ErrorAction SilentlyContinue
            if ($null -eq $candidate) { return $false }
            if (-not $nextJob.Contains($candidate) -or $candidate.Path -ne $Exe) {
                $candidate.Dispose()
                throw 'Updater relaunched window is not owned by the helper job'
            }
            $script:process = $candidate
            $script:window = $candidateWindow
            return $true
        } "$Stage updater helper publishes its new owned app" 60
        if (-not $helper.WaitForExit(20000) -or $helper.ExitCode -ne 0) { throw 'Updater helper did not exit successfully' }
        $script:job = $nextJob
        $nextJob = $null
    } else {
        $script:job = New-Object VerifyJob
        $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence ($Stage + '-stdout.log')), (Join-Path $Evidence ($Stage + '-stderr.log')), '--single-window')
    }
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $trace = ((Get-Content $log -Raw) -join '').Substring($logStart)
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and
            $state.hwnd -eq $script:window.ToInt64().ToString() -and @($state.shells).Count -gt 0 -and
            $trace -match 'launch step=browser'
    } "$Stage relaunch publishes its owned window and restored shells before activation" 60
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    Wait-Until {
        [VerifyNative]::BringToForeground($script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
    } "$Stage relaunched window foreground before input"
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $trace = ((Get-Content $log -Raw) -join '').Substring($logStart)
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and
            $state.hwnd -eq $script:window.ToInt64().ToString() -and @($state.shells).Count -gt 0 -and
            $trace -match 'launch step=browser' -and $trace -match 'installHook: KEYBOARD_LL installed'
    } "$Stage relaunch owns its published state after session restore" 60
    Doctor
    } finally {
        if ($null -ne $helper) { $helper.Dispose() }
        if ($null -ne $nextJob) {
            try { $null = $nextJob.Stop() } finally { $nextJob.Dispose() }
        }
    }
}

function Assert-SessionRestoreSelection([string]$Name, [int]$Workspace, [string]$WorkspaceId, [bool]$Starred = $false) {
    Wait-Until {
        $state = Read-Inbox
        $saved = Read-Session
        if ($null -eq $state -or $null -eq $saved) { return $false }
        $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
        $state.PSObject.Properties['starred_view'] -and $saved.PSObject.Properties['starred_view'] -and
            $state.starred_view -eq $Starred -and $saved.starred_view -eq $Starred -and
            $selected.Count -eq 1 -and $selected[0].name -ceq $Name -and
            $selected[0].ws -eq $Workspace -and $state.active_workspace -eq $Workspace -and
            $saved.active_workspace -eq $Workspace -and $saved.workspaces[$Workspace].wid -ceq $WorkspaceId -and
            $saved.tabs[$saved.active_tab].name -ceq $Name -and
            @($state.shells | Where-Object { $_.name -in @('Restore first', 'Restore middle', 'Restore last') }).Count -eq 3
    } "published and persisted selection is $Name in the original workspace, Starred=$Starred"
}

function Get-OwnProfileToken([string]$WorkspaceId) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($WorkspaceId)) } finally { $sha.Dispose() }
    return 'own-' + (-join ($digest | ForEach-Object { $_.ToString('x2') })).Substring(0, 24)
}

function Get-PaneUserDataDir([IntPtr]$Browser) {
    [uint32]$browserPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($Browser, [ref]$browserPid)
    if ($browserPid -eq 0) { throw 'Docked pane has no browser process' }
    $line = (Get-CimInstance Win32_Process -Filter "ProcessId = $browserPid").CommandLine
    $match = [regex]::Match($line, '(?:^|\s)(?:"--user-data-dir=([^"]+)"|--user-data-dir=(?:"([^"]+)"|(\S+)))')
    if (-not $match.Success) { throw 'Docked pane browser has no user data directory' }
    $dir = @(1, 2, 3 | Where-Object { $match.Groups[$_].Success } | ForEach-Object { $match.Groups[$_].Value })[0]
    return @{ pid = $browserPid; hwnd = $Browser.ToInt64(); commandLine = $line; userDataDir = [IO.Path]::GetFullPath($dir).TrimEnd('\') }
}

function Get-SharedProfileListing([string]$Root) {
    $names = @(Get-ChildItem -LiteralPath $Root -Force -Directory | ForEach-Object { $_.Name })
    $default = Join-Path $Root 'Default'
    if (Test-Path -LiteralPath $default) { $names += @(Get-ChildItem -LiteralPath $default -Force -Directory | ForEach-Object { 'Default/' + $_.Name }) }
    return @($names | Sort-Object)
}

function Get-SharedProfileCore([string]$Root) {
    $names = @(Get-ChildItem -LiteralPath $Root -Force -Directory | Where-Object { $_.Name -match '^(Default|Profile \d+)$' } | ForEach-Object { $_.Name })
    if (Test-Path -LiteralPath (Join-Path $Root 'Local State') -PathType Leaf) { $names += 'Local State' }
    if (Test-Path -LiteralPath (Join-Path $Root 'Default/Preferences') -PathType Leaf) { $names += 'Default/Preferences' }
    return @($names | Sort-Object)
}

function Wait-OwnProfilePipe([string]$Token, [string]$Step) {
    Wait-Until {
        $pipe = New-Object IO.Pipes.NamedPipeClientStream('.', ('multiprompt-browser-isolated-' + $Token), [IO.Pipes.PipeDirection]::Out)
        try { $pipe.Connect(100); return $pipe.IsConnected } catch { return $false } finally { $pipe.Dispose() }
    } "browser-own-profile ${Step}: native host serves the own profile pipe" 90
}

function Assert-WorkspaceBrowser([string]$Step, [string]$ExpectedRoot = '', [int]$Workspace = -1) {
    Wait-Until {
        $state = Read-Inbox
        if ($null -eq $state) { return $false }
        $activeSessionId = $state.active_shell_id
        $selected = @($state.shells | Where-Object { $_.sid -eq $activeSessionId })
        if ($selected.Count -ne 1 -or ($Workspace -ge 0 -and $selected[0].ws -ne $Workspace)) { return $false }
        $script:browserShellId = $activeSessionId
        $pane = Read-BrowserPane
        $browser = [VerifyNative]::DockedPaneWindow($script:window)
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and
            $browser -ne [IntPtr]::Zero -and [VerifyNative]::Title($browser) -notmatch '^ZSPANE'
    } "browser-own-profile ${Step}: docked pane bound and launch placeholder replaced" 60
    $pane = Read-BrowserPane
    $browser = [VerifyNative]::DockedPaneWindow($script:window)
    if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Docked pane is not owned by the app window' }
    $proof = Get-PaneUserDataDir $browser
    if ($ExpectedRoot -ne '' -and $proof.userDataDir -ine $ExpectedRoot) { throw ('Browser switched to the wrong profile at ' + $Step) }
    Save-Json @{ pane = $pane; browser = $proof; title = [VerifyNative]::Title($browser) } ("browser-own-profile-$Step.json")
    Focus-BrowserPaneOwner $Step $pane.browser_connection_id
    return $proof
}

function Open-WorkspaceBrowser([string]$Step) {
    Palette 'open browser'
    Press @(0x0D) ('Enter: Open Browser Pane for ' + $Step)
    return Assert-WorkspaceBrowser $Step
}

function Select-Theme([string]$Theme, [string]$ActionShot, [string]$SavedTheme = $Theme) {
    Focus-Palette 'themes' 4000
    Press @(0x0D) 'Enter: Themes...'
    Type-Text $Theme
    Snapshot $ActionShot
    Press @(0x0D) ('Enter: choose ' + $Theme)
    $path = Join-Path $scratch 'roaming/ZigShell/theme-mode.txt'
    Wait-Until { (Test-Path $path) -and (Get-Content $path -Raw).Trim() -eq $SavedTheme } "app-written theme-mode.txt equals $SavedTheme"
    Snapshot ($ActionShot + '-selected')
    Press @(0x1B) 'Esc: close Themes palette'
}

function Measure-StatusCard([string]$Name) {
    $frame = New-Object VerifyNative+Rect
    $client = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
        -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'status-card native geometry unavailable' }
    $dpi = [VerifyNative]::GetDpiForWindow($script:window)
    $scale = $dpi / 96.0
    $offsetX = $origin.X - $frame.Left
    $offsetY = $origin.Y - $frame.Top
    $pill = $Name -eq 'status-card-3'
    $x = $offsetX + [int][Math]::Round($(if ($pill) { 60 } else { 14 }) * $scale)
    $limit = $offsetY
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $y = $offsetY + $client.Bottom - 1
        $background = $image.GetPixel($x, $y)
        while ($y -gt $limit) {
            $pixel = $image.GetPixel($x, $y)
            if ([Math]::Max([Math]::Abs($pixel.R - $background.R), [Math]::Max([Math]::Abs($pixel.G - $background.G), [Math]::Abs($pixel.B - $background.B))) -gt 8) { break }
            $y--
        }
        $bottom = $y
        $fill = $image.GetPixel($x, $bottom - [Math]::Max(2, [int][Math]::Round(3 * $scale)))
        $y = $bottom - 1
        while ($y -gt $limit) {
            $pixel = $image.GetPixel($x, $y)
            if ($pill) {
                if ([Math]::Max([Math]::Abs($pixel.R - $background.R), [Math]::Max([Math]::Abs($pixel.G - $background.G), [Math]::Abs($pixel.B - $background.B))) -le 8) { $y++; break }
            } elseif ([Math]::Max([Math]::Abs($pixel.R - $fill.R), [Math]::Max([Math]::Abs($pixel.G - $fill.G), [Math]::Abs($pixel.B - $fill.B))) -gt 8) { break }
            $y--
        }
        $top = $y
        $borderColor = $image.GetPixel($x, $bottom)
        $fillColor = @($fill.R, $fill.G, $fill.B)
    } finally { $image.Dispose() }
    if ($bottom -le $limit -or $top -le $limit) { throw "status-card: no card frame found in $Name.png" }
    $pixels = $bottom - $top + 1
    return [ordered]@{
        screenshot = $Name + '.png'; x = $x; top = $top; bottom = $bottom; clientBottom = $offsetY + $client.Bottom
        border = @($borderColor.R, $borderColor.G, $borderColor.B); fill = $fillColor
        devicePixels = $pixels; dpi = $dpi; height = [Math]::Round($pixels / $scale, 1)
    }
}

function Sidebar-Luminance([string]$Name) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $total = 0.0
        $count = 0
        for ($x = 25; $x -lt 130; $x += 7) {
            for ($y = 170; $y -lt 550; $y += 7) {
                $pixel = $image.GetPixel($x, $y)
                $total += ($pixel.R + $pixel.G + $pixel.B) / 3.0
                $count++
            }
        }
        return $total / $count
    } finally { $image.Dispose() }
}

function Sidebar-Dominant([string]$Name) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $counts = @{}
        for ($x = 25; $x -lt 130; $x += 7) {
            for ($y = 170; $y -lt 550; $y += 7) {
                $pixel = $image.GetPixel($x, $y)
                $key = '{0},{1},{2}' -f $pixel.R, $pixel.G, $pixel.B
                $counts[$key] = 1 + [int]$counts[$key]
            }
        }
        $top = $counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        $channels = $top.Key.Split(',') | ForEach-Object { [int]$_ }
        return @{ r = $channels[0]; g = $channels[1]; b = $channels[2] }
    } finally { $image.Dispose() }
}

function Restart-ChatView([int]$ShellCount) {
    Doctor
    Record 'Close only the owned app normally and restart with the same isolated data directory'
    if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)) { throw 'Owned app did not close normally for view persistence restart' }
    $stopped = $job.Stop()
    Save-Json $stopped 'restart-process-tree.json'
    if ($stopped.ActiveProcesses -ne 0) { throw 'Owned descendants survived before restart' }
    $job.Dispose()
    $script:job = New-Object VerifyJob
    $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'relaunch.stdout.log'), (Join-Path $Evidence 'relaunch.stderr.log'))
    $script:window = [IntPtr]::Zero
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -eq $ShellCount
    } 'restarted owned window and restored sessions' 60
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    Wait-Until {
        Doctor
        [VerifyNative]::BringToForeground($script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
    } 'restarted app foreground'
    Doctor
}

function Read-SharedText([string]$Path) {
    $file = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = New-Object IO.StreamReader($file)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Read-DictationAudit([string]$Path) {
    $file = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = New-Object IO.StreamReader($file)
    try { return $reader.ReadToEnd().Split([char]10, [StringSplitOptions]::RemoveEmptyEntries) } finally { $reader.Dispose() }
}

function Get-DictationMic([IntPtr]$Composer) {
    $state = Read-Session
    if ($null -eq $state -or ($state.PSObject.Properties['ui_scale'] -and $state.ui_scale -ne 100)) { throw 'Dictation geometry requires the isolated default UI scale' }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $transcript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    if ($null -eq $transcript -or $transcript.Current.ProcessId -ne $process.Id -or $transcript.Current.IsOffscreen) { throw 'Dictation requires the owned visible transcript' }
    $transcriptHandle = [IntPtr]$transcript.Current.NativeWindowHandle
    if ([VerifyNative]::Class($Composer) -cne 'Edit' -or [VerifyNative]::GetAncestor($Composer, 2) -ne $script:window -or
        [VerifyNative]::GetAncestor($transcriptHandle, 2) -ne $script:window) { throw 'Dictation composer/transcript ownership mismatch' }
    $edit = New-Object VerifyNative+Rect
    $thread = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($Composer, [ref]$edit) -or -not [VerifyNative]::GetWindowRect($transcriptHandle, [ref]$thread) -or
        -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Dictation geometry unavailable' }
    $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
    $size = [int][Math]::Floor(32 * $scale)
    $margin = [Math]::Max([Math]::Floor(4 * $scale), [Math]::Floor(([Math]::Floor(44 * $scale) - $size) / 2))
    $left = $thread.Right - $origin.X - $margin - $size - [Math]::Floor(6 * $scale) - $size
    $top = $edit.Top - $origin.Y - [Math]::Floor(12 * $scale) + $margin
    if ($left -lt $edit.Right - $origin.X) { throw 'Microphone must sit left of send, outside the native Edit' }
    return ,([int[]]@($left, $top, ($left + $size), ($top + $size)))
}

function Get-DictationSend([int[]]$Mic) {
    $state = Read-Session
    if ($null -eq $state -or ($state.PSObject.Properties['ui_scale'] -and $state.ui_scale -ne 100)) { throw 'Send geometry requires the isolated default UI scale' }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $transcript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
    if ($null -eq $transcript -or $transcript.Current.ProcessId -ne $process.Id -or $transcript.Current.IsOffscreen) { throw 'Send geometry requires the owned visible transcript' }
    $thread = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect([IntPtr]$transcript.Current.NativeWindowHandle, [ref]$thread) -or
        -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Send geometry unavailable' }
    $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
    $size = [int][Math]::Floor(32 * $scale)
    $margin = [Math]::Max([Math]::Floor(4 * $scale), [Math]::Floor(([Math]::Floor(44 * $scale) - $size) / 2))
    $left = $thread.Right - $origin.X - $margin - $size
    if ($left -le $Mic[2] -or $left + $size -gt $thread.Right - $origin.X) { throw 'Send must sit at the far right, right of the microphone' }
    return ,([int[]]@($left, $Mic[1], ($left + $size), $Mic[3]))
}

function Assert-DictationMic([int[]]$Rect, [bool]$Active, [string]$Step) {
    Wait-Until {
        [void][VerifyNative]::DwmFlush()
        $pixels = [VerifyNative]::DictationMicPixels($script:window, $Rect, $Active, (Join-Path $Evidence ($Step + '-mic.png')))
        $pixels[1] -ge 3 -and $(if ($Active) { $pixels[0] -gt $pixels[2] / 2 } else { $pixels[0] -eq 0 })
    } ("IGSH-812 visible microphone active=$Active at $Step") -Seconds 2 -PollMilliseconds 20
    $pixels = [VerifyNative]::DictationMicPixels($script:window, $Rect, $Active, (Join-Path $Evidence ($Step + '-mic.png')))
    Save-Json @{ active = $Active; rect = $Rect; fillPixels = $pixels[0]; glyphPixels = $pixels[1]; area = $pixels[2] } ($Step + '-mic.json')
}

function Wait-ChatFocus([string]$Class, [string]$Step) {
    Wait-Until {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $focused.Current.ProcessId -eq $process.Id -and $focused.Current.ClassName -ceq $Class -and
            -not $focused.Current.IsOffscreen -and $focused.Current.NativeWindowHandle -ne 0 -and
            [VerifyNative]::GetAncestor([IntPtr]$focused.Current.NativeWindowHandle, 2) -eq $script:window
    } ("owned focused $Class`: $Step")
    Snapshot $Step
}

function Assert-ChatTyping([string]$Text, [string]$Step, [scriptblock]$TypingAction) {
    Wait-ChatFocus 'Edit' ($Step + '-focused')
    $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
    $handle = [IntPtr]$composer.Current.NativeWindowHandle
    if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::Class($handle) -cne 'Edit' -or
        [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Expected the owned composer Edit before reading text' }
    if ([VerifyNative]::EditText($handle) -cne '') { throw 'Expected an empty composer before typing proof' }
    if ($null -ne $TypingAction) { & $TypingAction } else { Type-Text $Text }
    Wait-Until { [VerifyNative]::EditText($handle) -ceq $Text } ("WM_GETTEXT typing landed: $Step")
    Wait-ChatFocus 'Edit' $Step
    if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -ne $handle) { throw 'Typing focus left the original composer Edit' }
    Save-Json @{ WM_GETTEXT = [VerifyNative]::EditText($handle); handle = $composer.Current.NativeWindowHandle; pid = $composer.Current.ProcessId } ($Step + '.text.json')
}

function New-RelaunchSeed {
    $groups = @(@{ id = 1; name = 'Hypertask' }, @{ id = 2; name = 'Software Factory' }, @{ id = 3; name = 'inne' })
    $tabs = New-Object System.Collections.ArrayList
    $live = New-Object System.Collections.ArrayList
    $seedId = 100
    foreach ($i in 1..14) {
        $name = 'Relaunch {0:00}' -f $i
        $group = ($i % 3) + 1
        $tab = [ordered]@{ kind = 'cmd'; name = $name; shell_id = $seedId; workspace = $(if ($i -le 10) { 0 } else { 1 }); group_id = $group }
        if ($i -le 12) { $tab.favorite = $true; $tab.starred_group_id = $group }
        [void]$tabs.Add($tab)
        [void]$live.Add($name)
        $seedId++
    }
    foreach ($i in 1, 3, 5, 7, 9, 11) {
        $name = 'Relaunch {0:00}' -f $i
        $group = ($i % 3) + 1
        [void]$tabs.Add([ordered]@{ kind = 'tmux'; name = $name; shell_id = $seedId; workspace = $(if ($i -le 10) { 0 } else { 1 }); favorite = $true; starred_group_id = $group })
        $seedId++
    }
    $selected = 'Relaunch 07'
    $selectedIndex = 0
    foreach ($index in 0..($tabs.Count - 1)) { if ($tabs[$index].name -ceq $selected -and $tabs[$index].kind -eq 'cmd') { $selectedIndex = $index } }
    $document = [ordered]@{
        single_window = $true
        active_workspace = 0
        workspace_count = 2
        workspaces = @(@{ name = 'Main'; wid = 'relaunch-main' }, @{ name = 'Work'; wid = 'relaunch-work' })
        starred_view = $true
        active_tab = $selectedIndex
        active_shell_id = $tabs[$selectedIndex].shell_id
        groups = $groups
        tabs = @($tabs.ToArray())
    }
    return @{ document = $document; live = @($live.ToArray()); savedTabs = $tabs.Count; ghosts = 6; groups = @($groups | ForEach-Object { $_.name }); selected = $selected }
}

function Get-NotifyPorts {
    $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../../src/notify_ports.zig'))
    $first = [regex]::Match($source, 'pub const FIRST_PORT: u16 = (\d+);')
    $count = [regex]::Match($source, 'pub const PORT_COUNT: usize = (\d+);')
    if (-not $first.Success -or -not $count.Success) { throw 'Notification port range missing' }
    return @([int]$first.Groups[1].Value..([int]$first.Groups[1].Value + [int]$count.Groups[1].Value - 1))
}

function Open-NotifyPortListeners {
    $opened = New-Object System.Collections.ArrayList
    foreach ($port in Get-NotifyPorts) {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
        $listener.Start()
        [void]$opened.Add($listener)
    }
    return $opened
}

function Assert-RelaunchSessions([string]$Stage, $Seed) {
    Wait-Until {
        $state = Read-Inbox
        if ($null -eq $state) { return $false }
        $names = @($state.shells | ForEach-Object { $_.name })
        @($Seed.live | Where-Object { $_ -cnotin $names }).Count -eq 0
    } "$Stage every live saved session is published" 60
    Start-Sleep -Seconds 3
    $state = Read-Inbox
    Save-Json $state ($Stage + '.inbox.json')
    $published = @($state.shells | ForEach-Object { $_.name })
    $listedTwice = @($published | Group-Object -CaseSensitive | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name + ' x' + $_.Count })
    if ($listedTwice.Count -gt 0) { throw "$Stage sessions listed twice in the sidebar: $($listedTwice -join ', ')" }
    $extra = @($published | Where-Object { $_ -cnotin $Seed.live })
    if ($extra.Count -gt 0) { throw "$Stage sidebar lists sessions that were never saved: $($extra -join ', ')" }
    Wait-Until {
        $saved = Read-Session
        $null -ne $saved -and @($saved.tabs).Count -eq $Seed.live.Count
    } "$Stage saved file holds exactly the $($Seed.live.Count) live sessions, with no cached copies" 30
    $saved = Read-Session
    Save-Json $saved ($Stage + '.session.json')
    $savedTwice = @(@($saved.tabs | ForEach-Object { $_.name }) | Group-Object -CaseSensitive | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name + ' x' + $_.Count })
    if ($savedTwice.Count -gt 0) { throw "$Stage saved file lists sessions twice: $($savedTwice -join ', ')" }
    $savedGroups = @($saved.groups | ForEach-Object { $_.name })
    $missingGroups = @($Seed.groups | Where-Object { $_ -cnotin $savedGroups })
    if ($missingGroups.Count -gt 0) { throw "$Stage group headers missing: $($missingGroups -join ', ')" }
    $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
    if ($selected.Count -ne 1) { throw "$Stage selected chat is not one published session" }
    return @{ stage = $Stage; published = $published.Count; saved = @($saved.tabs).Count; groups = $savedGroups.Count; selected = $selected[0].name; starred_view = [bool]$state.starred_view }
}

$usageCollector = $null
Write-Host 'Launch: validate executable and prepare isolated profile'
