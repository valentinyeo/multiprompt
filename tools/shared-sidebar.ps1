param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output, [switch]$MemoryProof, [switch]$OrderProof, [switch]$ChangelogProof, [switch]$ChangelogLinks, [switch]$HighlightProof, [switch]$StarBadgeProof, [switch]$DensityProof)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($DensityProof -and ($MemoryProof -or $OrderProof -or $ChangelogProof -or $ChangelogLinks -or $HighlightProof -or $StarBadgeProof)) { throw 'Invalid proof modes' }
if ($StarBadgeProof -and ($MemoryProof -or $OrderProof -or $ChangelogProof -or $ChangelogLinks -or $HighlightProof)) { throw 'Invalid proof modes' }
if (($MemoryProof -and $OrderProof) -or ($ChangelogProof -and ($MemoryProof -or $OrderProof)) -or ($ChangelogLinks -and -not $ChangelogProof) -or ($HighlightProof -and ($MemoryProof -or $OrderProof -or $ChangelogProof -or $ChangelogLinks))) { throw 'Invalid proof modes' }
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$profile = Join-Path $env:RUNNER_TEMP "shared-sidebar-$PID"
$settings = "$profile/roaming/ZigShell"
$job = $null
$script:toggleReady = [DateTime]::MinValue
$result = @{passed=$false; error=$null; cleanup='pending'; comparisons=@(); actions=@()}
if ($OrderProof) { $result.reportedUserTriggerConfirmed = $false }
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 30) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Description"
}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Flag($Value, [string]$Name) { $property = $Value.PSObject.Properties[$Name]; $null -ne $property -and $property.Value -eq $true }
function Chat-On { $s = Session; Flag $s.tabs[$s.active_tab] 'cv' }
function Read-Json([string]$Path) {
    Wait-For 'readable saved state' {
        try {
            $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            if ($null -ne $document) { return $document }
        } catch { return $false }
        $false
    }
}
function Session { Read-Json "$settings/session.json" }
function Focus {
    [void](Wait-For 'owned app foreground' {
        $target = [ChatDeliveryDesktop]::Composer($main)
        if ($target -eq [IntPtr]::Zero) { $target = $main }
        [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $target)
    })
}
function Toggle-View {
    [void](Wait-For 'existing shortcut debounce' { [DateTime]::UtcNow -ge $script:toggleReady })
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
    $script:toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
}
function Capture([string]$Name) {
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    $bitmap = [Drawing.Bitmap]::new(299, 320)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $bitmap.Save("$Output/$Name.png")
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    (Get-FileHash "$Output/$Name.png" -Algorithm SHA256).Hash
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Output/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Compare-Views([string]$Name) {
    Focus
    $selected = (Session).active_tab
    $script:previousHash = ''
    $before = Wait-For 'stable shell sidebar' {
        $hash = Capture "$Name-shell-sidebar"
        if ($hash -eq $script:previousHash) { return $hash }
        $script:previousHash = $hash
        $false
    }
    Shot "$Name-shell"
    Toggle-View
    [void](Wait-For 'Chat View visible' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero -and (Chat-On) })
    Focus
    $hash = Wait-For 'sidebar unchanged across shell and chat' { $h = Capture "$Name-chat-sidebar"; if ($h -eq $before) { $h } }
    Shot "$Name-chat"
    if ((Session).active_tab -ne $selected) { throw 'View toggle changed selection' }
    $result.comparisons += @{name=$Name; shell=$before; chat=$hash; selected=$selected}
    Toggle-View
    [void](Wait-For 'shell view restored' { -not (Chat-On) })
    Focus
    [void](Wait-For 'return sidebar unchanged' { (Capture "$Name-return-sidebar") -eq $before })
}

if ($HighlightProof -or $StarBadgeProof -or $DensityProof) { Add-Type -Path "$PSScriptRoot/../.claude/skills/verify-multiprompt/title-bar-native.cs" }
if ($MemoryProof -or $OrderProof -or $HighlightProof -or $StarBadgeProof -or $DensityProof) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class SidebarDrag {
    [StructLayout(LayoutKind.Sequential)] struct MouseInput { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct KeyboardInput { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] struct InputUnion { [FieldOffset(0)] public MouseInput Mouse; [FieldOffset(0)] public KeyboardInput Keyboard; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint Type; public InputUnion Data; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    static void Mouse(int x, int y, uint flags) {
        var input = new Input();
        input.Data.Mouse = new MouseInput { X = (int)Math.Round(x * 65535.0 / (GetSystemMetrics(0) - 1)), Y = (int)Math.Round(y * 65535.0 / (GetSystemMetrics(1) - 1)), Flags = 0x8001 | flags };
        if (SendInput(1, new[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Sidebar mouse input failed");
    }
    public static void DragVertical(IntPtr hwnd, uint pid, int x, int from, int to) {
        var start = new Point { X = x, Y = from };
        var end = new Point { X = x, Y = to };
        uint owner;
        GetWindowThreadProcessId(hwnd, out owner);
        if (!ClientToScreen(hwnd, ref start) || !ClientToScreen(hwnd, ref end) || owner != pid || GetForegroundWindow() != hwnd || WindowFromPoint(start) != hwnd || GetAncestor(WindowFromPoint(end), 2) != hwnd) throw new InvalidOperationException("Sidebar drag ownership mismatch");
        Mouse(start.X, start.Y, 0);
        Mouse(start.X, start.Y, 2);
        try {
            for (int step = 1; step <= 16; step++) {
                Mouse(start.X, start.Y + (end.Y - start.Y) * step / 16, 0);
                Thread.Sleep(20);
            }
        } finally { Mouse(end.X, end.Y, 4); }
    }
    public static void Drag(IntPtr hwnd, uint pid, int from, int to, int y) {
        var start = new Point { X = from, Y = y };
        var end = new Point { X = to, Y = y };
        uint owner;
        GetWindowThreadProcessId(hwnd, out owner);
        if (!ClientToScreen(hwnd, ref start) || !ClientToScreen(hwnd, ref end) || owner != pid || GetForegroundWindow() != hwnd || WindowFromPoint(start) != hwnd || GetAncestor(WindowFromPoint(end), 2) != hwnd) throw new InvalidOperationException("Sidebar drag ownership mismatch");
        Mouse(start.X, start.Y, 0);
        Mouse(start.X, start.Y, 2);
        try {
            for (int step = 1; step <= 16; step++) {
                Mouse(start.X + (end.X - start.X) * step / 16, start.Y, 0);
                Thread.Sleep(20);
            }
        } finally { Mouse(end.X, end.Y, 4); }
    }
}
'@
}
$script:nextJob = $null

function Memory-Evidence([string]$Name) {
    Copy-Item "$settings/session.json" "$Output/$Name.session.json"
    if (Test-Path "$settings/session.json.launch.json") { Copy-Item "$settings/session.json.launch.json" "$Output/$Name.session.json.launch.json" }
    Shot $Name
    $script:frames += $Name
}
function Memory-ToggleUnread([bool]$Expected, [string]$Name) {
    Focus
    if ((Flag (Session) 'unread_only') -eq $Expected) { throw "unread_only already $Expected before toggle" }
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x10, 0x55))
    $result.actions += 'Ctrl+Shift+U: toggle unread only'
    [void](Wait-For "unread_only saved $Expected" { (Flag (Session) 'unread_only') -eq $Expected })
    Memory-Evidence $Name
}
function Memory-Gif {
    Add-Type -AssemblyName PresentationCore, WindowsBase
    $encoder = [System.Windows.Media.Imaging.GifBitmapEncoder]::new()
    foreach ($name in $script:frames) {
        $image = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new("$Output/$name.png"), [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $metadata = [System.Windows.Media.Imaging.BitmapMetadata]::new('gif')
        $metadata.SetQuery('/grctlext/Delay', [UInt16]100)
        $metadata.SetQuery('/grctlext/Disposal', [byte]1)
        $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($image, $null, $metadata, $null))
    }
    $stream = [IO.File]::Create("$Output/sidebar-memory.gif")
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}
function Memory-GroupCollapsed {
    $groups = @((Session).groups | Where-Object { $_.id -eq 17 })
    if ($groups.Count -ne 1) { throw 'Saved group identity missing or duplicated' }
    Flag $groups[0] 'collapsed'
}
function Memory-Click([int]$Y, [string]$Description, [scriptblock]$Check, [string]$Name) {
    Focus
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, $Y)
    $result.actions += $Description
    [void](Wait-For $Description $Check)
    Memory-Evidence $Name
}
function Memory-Identity([string]$Stage) {
    $saved = Session
    if (@($saved.tabs).Count -ne 3 -or @($saved.tabs | Where-Object { $_.name -ceq 'Second shell' -and $_.PSObject.Properties['group_id'] -and $_.group_id -eq 17 }).Count -ne 1 -or @($saved.groups | Where-Object { $_.id -eq 17 -and $_.name -ceq 'Proof group' }).Count -ne 1) { throw "$Stage session identities changed" }
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Window($app.Id) -ne $main -or -not $job.Contains($app)) { throw "$Stage window ownership mismatch" }
    $app.Refresh()
    $result.identities += @{ stage=$Stage; pid=$app.Id; hwnd=$main.ToInt64(); title=$app.MainWindowTitle; path=$app.Path }
}
function Memory-Recheck([string]$Stage) {
    Memory-Identity $Stage
    if (-not (Flag (Session) 'unread_only') -or -not (Flag (Session) 'recents_section_collapsed') -or -not (Memory-GroupCollapsed)) { throw "$Stage nondefault sidebar choices not restored" }
    Focus
    Memory-Evidence "after-$Stage"
    Memory-ToggleUnread $false "$Stage-unread-off"
    Memory-Click 64 'Click group: prove restored closed' { -not (Memory-GroupCollapsed) } "$Stage-group-open"
    Memory-Click 150 'Click Recents: prove restored closed' { -not (Flag (Session) 'recents_section_collapsed') } "$Stage-recents-open"
    Memory-Click 64 'Click group: close again' { Memory-GroupCollapsed } "$Stage-group-closed"
    Memory-Click 92 'Click Recents: close again' { Flag (Session) 'recents_section_collapsed' } "$Stage-recents-closed"
    Memory-ToggleUnread $true "$Stage-configured"
}
function Memory-Restart([bool]$Updater) {
    $oldPid = $app.Id
    $logStart = (Get-Content "$settings/debug.log" -Raw).Length
    if ($Updater) {
        $script:nextJob = [VerifyJob]::new()
        $helper = $nextJob.Start($Exe, $profile, "$Output/updater-stdout.log", "$Output/updater-stderr.log", "--relaunch-after $oldPid")
        if ($helper.HasExited) { throw 'Updater relaunch helper exited before close' }
        $result.actions += "Start updater relaunch helper $($helper.Id) for $oldPid"
        Save @{oldPid=$oldPid; helperPid=$helper.Id; arguments="--relaunch-after $oldPid"} "$Output/updater-helper.json"
    }
    $result.actions += "Close owned window $oldPid normally"
    if (-not $app.CloseMainWindow()) { throw 'Owned window refused normal close' }
    if (-not $app.WaitForExit(20000)) { throw 'Owned app did not exit' }
    $stopped = $job.Stop()
    $result.exits += @{ pid=$oldPid; activeAfterStop=$stopped.ActiveProcesses; updater=$Updater }
    if ($stopped.ActiveProcesses -ne 0) { throw 'Old owned processes remained after close' }
    $app.Dispose(); $job.Dispose(); $script:job = $null
    if ($Updater) {
        [void](Wait-For 'updater helper publishes new owned application' {
            try {
                $inbox = Read-Json "$settings/inbox-default.json"
                $window = [IntPtr]([long]$inbox.hwnd)
                $owner = [ChatDeliveryDesktop]::Owner($window)
                if ($owner -eq 0 -or $owner -eq $oldPid -or $owner -eq $helper.Id) { return $false }
                $candidate = Get-Process -Id $owner -ErrorAction SilentlyContinue
                if ($null -eq $candidate) { return $false }
                if (-not $nextJob.Contains($candidate) -or $candidate.Path -ine $Exe) { $candidate.Dispose(); throw 'Updater app is not owned by helper job or executable differs' }
                if ([ChatDeliveryDesktop]::Window($owner) -ne $window) { $candidate.Dispose(); return $false }
                $script:app = $candidate; $script:main = $window
                return $true
            } catch [System.Management.Automation.RuntimeException] { throw }
        } 60)
        if (-not $helper.WaitForExit(20000) -or $helper.ExitCode -ne 0) { throw 'Updater relaunch helper did not exit successfully' }
        $helper.Dispose()
        $script:job = $nextJob; $script:nextJob = $null
        $result.actions += 'Updater helper published new owned window'
    } else {
        $script:job = [VerifyJob]::new()
        $script:app = $job.Start($Exe, $profile, "$Output/restart-stdout.log", "$Output/restart-stderr.log", '--no-window-restore')
        $script:main = Wait-For 'restarted owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
        $result.actions += 'Relaunch same executable and profile'
    }
    [void](Wait-For 'restarted app publishes owned window and three sessions' {
        $inbox = Read-Json "$settings/inbox-default.json"
        $trace = (Get-Content "$settings/debug.log" -Raw).Substring($logStart)
        [string]$inbox.hwnd -eq [string]$main.ToInt64() -and @($inbox.shells).Count -eq 3 -and $trace -match 'launch step=browser'
    } 60)
    [void](Wait-For 'new process applied sidebar width 340' {
        $trace = (Get-Content "$settings/debug.log" -Raw).Substring($logStart)
        $trace -match '(?s)launch step=snapshot[^\r\n]*\r?\n.*?\[reposition\] client=\d+x\d+ sidebar=340(?:\r?\n|$)'
    } 60)
    Focus
}
function Memory-Journey {
    $script:frames = @()
    $result.identities = @()
    $result.exits = @()
    if ([SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Memory journey requires 96 DPI' }
    $result.limitations = @('Expanded Pinned header is suppressed by the existing tile layout; group and Recents used instead', 'Other groups and Starred groups not exercised', 'Restart while sidebar collapsed not exercised', 'Updater helper relaunch exercised; download, signature, version and binary replacement not exercised')
    $result.executable = @{ path=$Exe; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Exe).FileVersion }
    Memory-Identity 'initial'
    if ((Flag (Session) 'unread_only') -or (Flag (Session) 'recents_section_collapsed') -or (Memory-GroupCollapsed)) { throw 'Missing flags did not default off' }
    Memory-Evidence 'before-actions'
    # Header starts at 8 + 52 = 60; group is 28 high, expanded tab 58 high.
    Memory-Click 64 'Click group: collapse' { Memory-GroupCollapsed } 'group-closed'
    Memory-Click 92 'Click Recents: collapse' { Flag (Session) 'recents_section_collapsed' } 'recents-closed'
    Memory-Click 64 'Click group: reopen' { -not (Memory-GroupCollapsed) } 'group-open'
    Focus
    [SidebarDrag]::Drag($main, $app.Id, 300, 50, 200)
    $result.actions += 'Drag sidebar boundary left; release to snap collapsed'
    [void](Wait-For 'drag collapsed saved on release' { Flag (Session) 'sidebar_collapsed' })
    Memory-Evidence 'drag-collapsed'
    Focus
    [SidebarDrag]::Drag($main, $app.Id, 44, 340, 200)
    $result.actions += 'Drag collapsed sidebar boundary right; release expanded'
    [void](Wait-For 'drag expanded saved on release' { -not (Flag (Session) 'sidebar_collapsed') })
    [void](Wait-For 'sidebar width 340 saved in launch snapshot' {
        if (-not (Test-Path "$settings/session.json.launch.json")) { return $false }
        $snapshot = Read-Json "$settings/session.json.launch.json"
        $property = $snapshot.PSObject.Properties['sidebar_width']
        $null -ne $property -and $property.Value -eq 340
    })
    Memory-Evidence 'drag-expanded'
    Memory-ToggleUnread $true 'unread-on'
    Memory-ToggleUnread $false 'unread-off'
    Memory-Click 64 'Click group: close again' { Memory-GroupCollapsed } 'group-configured-closed'
    Memory-ToggleUnread $true 'configured'
    Memory-Restart $false
    Memory-Recheck 'restart'
    Memory-Restart $true
    Memory-Recheck 'updater'
    Memory-Gif
    $result.passed = $true
}

function Order-State([string]$Stage, [bool]$AllowCollapsedC = $false) {
    $saved = Session
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Window($app.Id) -ne $main -or -not $job.Contains($app)) { throw "$Stage window ownership mismatch" }
    if (@($saved.groups).Count -ne 3 -or @($saved.tabs).Count -ne 3 -or (Flag $saved 'single_window') -or (Flag $saved 'sidebar_collapsed') -or (Flag $saved 'starred_view') -or (Flag $saved 'unread_only')) { throw "$Stage fixture layout changed" }
    foreach ($id in @(17, 18, 19)) {
        $groups = @($saved.groups | Where-Object { $_.id -eq $id })
        $tabs = @($saved.tabs | Where-Object { $_.group_id -eq $id })
        if ($groups.Count -ne 1 -or $tabs.Count -ne 1 -or ((Flag $groups[0] 'collapsed') -and -not ($AllowCollapsedC -and $id -eq 19)) -or (Flag $tabs[0] 'pinned_top') -or (Flag $tabs[0] 'cv')) { throw "$Stage group $id fixture changed" }
        $index = $id - 17
        if ($groups[0].name -cne @('A','B','C')[$index] -or $tabs[0].name -cne @('First shell','Second shell','Third shell')[$index] -or $tabs[0].kind -cne 'cmd' -or -not (Flag $tabs[0] 'manual')) { throw "$Stage group $id identity changed" }
    }
    return $saved
}
function Order-Ids($Saved) { $Saved.groups | ForEach-Object { [int]$_.id } }
function Order-Expect($Saved, [int[]]$Expected, [string]$Stage) {
    $actual = @(Order-Ids $Saved)
    if (($actual -join ',') -cne ($Expected -join ',')) { throw "$Stage unexpected order: $($actual -join ',')" }
}
function Order-Evidence([string]$Name) {
    Copy-Item "$settings/session.json" "$Output/$Name.session.json"
    Shot $Name
}
function Order-Journey {
    $result.limitations = @('Fixture coordinates are source-derived hypotheses, not screenshot recognition', 'Reported screenshot identity and trigger remain unknown')
    $result.geometry = @{dpi=96; headerY=@(60,146,232); tabHeight=58; source='src/sidebar.zig layoutRowsInner'; screenshot='before-actions.png'}
    $result.executable = @{path=$Exe; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Exe).FileVersion}
    $result.identities = @(); $result.exits = @(); $result.classification = 'none'
    if ([SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Order journey requires 96 DPI' }
    $saved = Order-State 'initial'
    Order-Expect $saved @(17,18,19) 'initial'
    $result.identities += @{stage='initial'; pid=$app.Id; hwnd=$main.ToInt64()}
    Focus
    Order-Evidence 'before-actions'
    foreach ($entry in @(@{id=18; y=185}, @{id=19; y=271}, @{id=17; y=99})) {
        $saved = Order-State 'before click'
        Order-Expect $saved @(17,18,19) 'before click'
        Focus
        $result.actions += @{action='select'; x=100; y=$entry.y; groupId=$entry.id; before=@(Order-Ids $saved)}
        [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, $entry.y)
        [void](Wait-For 'selected group saved' { $s = Session; $s.tabs[$s.active_tab].group_id -eq $entry.id })
        $saved = Order-State 'after click'
        $result.actions[-1].after = @(Order-Ids $saved)
        Order-Expect $saved @(17,18,19) 'after click'
    }
    $saved = Order-State 'before wobble'
    Order-Expect $saved @(17,18,19) 'before wobble'
    Focus
    $result.actions += @{action='wobble'; x=100; fromY=235; toY=227; before=@(Order-Ids $saved); expected=@(17,18,19)}
    [SidebarDrag]::DragVertical($main, $app.Id, 100, 235, 227)
    Start-Sleep -Seconds 2
    $saved = Order-State 'after wobble' $true
    $order = @(Order-Ids $saved)
    $collapsedC = Flag (@($saved.groups | Where-Object { $_.id -eq 19 })[0]) 'collapsed'
    $result.actions[-1].after = $order
    $result.actions[-1].collapsedC = $collapsedC
    Order-Evidence 'after-wobble'
    if (($order -join ',') -eq '17,19,18') { $result.classification = 'accidental_header_drag_reordered' }
    elseif (($order -join ',') -ne '17,18,19') { throw "Wobble unexpected order: $($order -join ',')" }
    if ($collapsedC) {
        Order-Expect $saved @(17,18,19) 'before reopening C'
        Focus
        $result.actions += @{action='reopen C'; x=100; y=235; before=$order}
        [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, 235)
        [void](Wait-For 'group C reopened' {
            $state = Order-State 'reopening C' $true
            Order-Expect $state @(17,18,19) 'reopening C'
            -not (Flag (@($state.groups | Where-Object { $_.id -eq 19 })[0]) 'collapsed')
        })
        $saved = Order-State 'after reopening C'
        Order-Expect $saved @(17,18,19) 'after reopening C'
        $result.actions[-1].after = @(Order-Ids $saved)
    }
    $fromY = if ($order[1] -eq 19) { 149 } else { 235 }
    $saved = Order-State 'before deliberate drag'
    Order-Expect $saved $order 'before deliberate drag'
    Focus
    $result.actions += @{action='deliberate'; x=100; fromY=$fromY; toY=63; before=$order; expected=@(19,17,18)}
    [SidebarDrag]::DragVertical($main, $app.Id, 100, $fromY, 63)
    Start-Sleep -Seconds 2
    $saved = Order-State 'after deliberate drag'
    $result.actions[-1].after = @(Order-Ids $saved)
    Order-Evidence 'after-deliberate'
    Order-Expect $saved @(19,17,18) 'after deliberate drag'
    $oldPid = $app.Id; $oldHwnd = $main
    Focus
    $result.actions += @{action='normal restart'; before=@(Order-Ids $saved); pid=$oldPid; hwnd=$oldHwnd.ToInt64()}
    if (-not $app.CloseMainWindow() -or -not $app.WaitForExit(20000)) { throw 'Owned app did not close normally' }
    $stopped = $job.Stop()
    $result.exits += @{pid=$oldPid; activeAfterStop=$stopped.ActiveProcesses}
    if ($stopped.ActiveProcesses -ne 0) { throw 'Old owned processes remained after close' }
    $app.Dispose(); $job.Dispose(); $script:job = $null
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, "$Output/restart-stdout.log", "$Output/restart-stderr.log", '--no-window-restore')
    $script:main = Wait-For 'restarted owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    if ($app.Id -eq $oldPid -or $main -eq $oldHwnd) { throw 'Restart did not create new PID and HWND' }
    [void](Wait-For 'restarted owned sessions published' {
        if (-not (Test-Path "$settings/inbox-default.json")) { return $false }
        $inbox = Read-Json "$settings/inbox-default.json"
        [string]$inbox.hwnd -eq [string]$main.ToInt64() -and @($inbox.shells).Count -eq 3
    } 60)
    $saved = Order-State 'after restart'
    $result.identities += @{stage='restart'; pid=$app.Id; hwnd=$main.ToInt64()}
    $result.actions[-1].after = @(Order-Ids $saved)
    Focus
    Order-Evidence 'after-restart'
    Order-Expect $saved @(19,17,18) 'after restart'
    $result.passed = $result.classification -eq 'none'
}

function Open-Changelog {
    $logStart = (Get-Content "$settings/debug.log" -Raw).Length
    Focus
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x4B))
    $result.actions += 'Ctrl+K: open command palette'
    [void](Wait-For 'palette initialized' { (Get-Content "$settings/debug.log" -Raw).Substring($logStart) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($key in @(0x43,0x48,0x41,0x4E,0x47,0x45,0x4C,0x4F,0x47)) { [ChatDeliveryDesktop]::Type($key) }
    $result.actions += 'Type changelog (9 characters)'
    [void](Wait-For 'changelog selected in palette' {
        $trace = (Get-Content "$settings/debug.log" -Raw).Substring($logStart)
        $lines = [regex]::Matches($trace, '\[palette\] ready chars=\d+ count=\d+ target=\d+')
        $lines.Count -gt 0 -and $lines[$lines.Count - 1].Value -match '^\[palette\] ready chars=9 count=[1-9]\d* target=6241$'
    })
    Shot 'changelog-palette'
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App lost foreground before Enter' }
    [ChatDeliveryDesktop]::Chord(@(0x0D))
    $result.actions += 'Enter: open selected changelog'
    Start-Sleep -Seconds 2
}
function Highlight-Owned {
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Window($app.Id) -ne $main -or -not $job.Contains($app)) { throw 'Highlight window ownership mismatch' }
}
function Highlight-State([string]$Name) {
    $saved = Session
    $inbox = Read-Json "$settings/inbox-default.json"
    $matches = @($inbox.shells | Where-Object { $_.name -ceq $Name -and $_.sid -eq $inbox.active_shell_id })
    $tab = $saved.tabs[$saved.active_tab]
    if (-not (Flag $inbox 'starred_view') -or $matches.Count -ne 1 -or $inbox.active_shell_id -eq 0 -or $tab.name -cne $Name -or -not $tab.PSObject.Properties['shell_id'] -or $tab.shell_id -ne $inbox.active_shell_id -or [string]$inbox.hwnd -ne [string]$main.ToInt64()) { return $false }
    return $matches[0]
}
function Highlight-Click($Target, [string]$Name) {
    Highlight-Owned
    Focus
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Highlight click lost foreground' }
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, ($Target.x + 10), ($Target.y + 15))
    $selected = Wait-For "selected $Name" { Highlight-State $Name }
    $result.actions += @{input='mouse'; x=($Target.x + 10); y=($Target.y + 15); name=$Name; id=$selected.sid}
}
function Highlight-Frame([string]$Theme, [string]$Kind, [string]$Name, $Target) {
    Highlight-Owned
    $selected = Highlight-State $Name
    if (-not $selected) { throw "Active session changed before $Theme $Kind" }
    if ((Get-Content "$settings/theme-mode.txt" -Raw).Trim() -cne $Theme) { throw 'Theme changed before capture' }
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    $script:previousHash = ''
    [void](Wait-For 'stable sidebar paint' { $hash = Capture 'highlight-stability'; if ($hash -eq $script:previousHash) { return $true }; $script:previousHash = $hash; $false })
    $frame = [ChatDeliveryDesktop+Rect]::new()
    $client = [ChatDeliveryDesktop+Rect]::new()
    $outerOk = [ChatDeliveryDesktop]::GetWindowRect($main, [ref]$frame)
    $clientOk = [ChatDeliveryDesktop]::GetClientRect($main, [ref]$client)
    $origin = $null; $originError = $null
    try { $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0) } catch { $originError = $_.Exception.Message }
    $dpi = [SidebarDrag]::GetDpiForWindow($main)
    $desktop = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $width = $client.Right - $client.Left; $height = $client.Bottom - $client.Top
    $attempt = @{theme=$Theme; kind=$Kind; pid=$app.Id; hwnd=$main.ToInt64(); outerOk=$outerOk; outer=@($frame.Left,$frame.Top,$frame.Right,$frame.Bottom); clientOk=$clientOk; client=@($client.Left,$client.Top,$client.Right,$client.Bottom); clientWidth=$width; clientHeight=$height; originOk=($null -ne $origin); originError=$originError; clientOrigin=if ($null -ne $origin) { @($origin.X,$origin.Y) } else { $null }; dpi=$dpi; desktop=@($desktop.Left,$desktop.Top,$desktop.Right,$desktop.Bottom); foreground=[ChatDeliveryDesktop]::GetForegroundWindow().ToInt64()}
    $result.captureAttempts += $attempt
    if (-not $clientOk -or $null -eq $origin -or $width -ne 1920 -or $height -ne 1032 -or $dpi -ne 96 -or $origin.X -lt $desktop.Left -or $origin.Y -lt $desktop.Top -or ($origin.X + $width) -gt $desktop.Right -or ($origin.Y + $height) -gt $desktop.Bottom) { throw "Invalid client capture geometry: clientOk=$clientOk size=${width}x${height} origin=$($attempt.clientOrigin -join ',') originError=$originError dpi=$dpi desktop=$($attempt.desktop -join ',')" }
    if ($Kind -eq 'tile') { $fillX = $Target.x - 11; $fillY = $Target.y + 38; $ringX = $Target.x - 16; $ringY = $Target.y + 38 }
    else { $fillX = $Target.x + $Target.size + 5; $fillY = $Target.y + $Target.size + 5; $ringX = $Target.x - $(if ($Target.size -eq 40) { 10 } else { 12 }); $ringY = $Target.y + [int]($Target.size / 2) }
    $bitmap = [Drawing.Bitmap]::new(1920, 1032)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        Highlight-Owned
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $bitmap.Save("$Output/highlight-$Theme-$Kind.png")
        $fx = $fillX; $fy = $fillY; $rx = $ringX; $ry = $ringY
        $fill = $bitmap.GetPixel($fx, $fy); $ring = $bitmap.GetPixel($rx, $ry); $inside = $bitmap.GetPixel($rx + 1, $ry)
        $result.frames += @{theme=$Theme; kind=$Kind; name=$Name; id=$selected.sid; capture='owned-client'; captureRect=@($origin.X,$origin.Y,($origin.X + $width),($origin.Y + $height)); avatar=$Target; fill=@{point=@($fx,$fy); rgb=@([int]$fill.R,[int]$fill.G,[int]$fill.B)}; ring=@{point=@($rx,$ry); rgb=@([int]$ring.R,[int]$ring.G,[int]$ring.B)}; insideRing=@{point=@(($rx + 1),$ry); rgb=@([int]$inside.R,[int]$inside.G,[int]$inside.B)}}
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Highlight-ThemeLight {
    Highlight-Owned
    Focus
    $start = (Get-Content "$settings/debug.log" -Raw).Length
    [ChatDeliveryDesktop]::Chord(@(0x11,0x4B))
    [void](Wait-For 'palette initialized' { (Get-Content "$settings/debug.log" -Raw).Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($key in @(0x54,0x48,0x45,0x4D,0x45,0x53)) { [ChatDeliveryDesktop]::Type($key) }
    try { [void](Wait-For 'Themes command selected' { (Get-Content "$settings/debug.log" -Raw).Substring($start) -match '\[palette\] ready chars=6 count=[1-9]\d* target=4000(?:\r?\n|$)' }) } catch {
        $lines = [regex]::Matches((Get-Content "$settings/debug.log" -Raw).Substring($start), '\[palette\] ready chars=\d+ count=\d+ target=\d+')
        $result.paletteLastReady = if ($lines.Count) { $lines[$lines.Count - 1].Value } else { $null }
        throw
    }
    Highlight-Owned
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Theme palette lost foreground' }
    [ChatDeliveryDesktop]::Chord(@(0x0D))
    foreach ($key in @(0x4C,0x49,0x47,0x48,0x54)) { [ChatDeliveryDesktop]::Type($key) }
    try { [void](Wait-For 'Light theme selected' { (Get-Content "$settings/debug.log" -Raw).Substring($start) -match '\[palette\] ready chars=5 count=[1-9]\d* target=4012(?:\r?\n|$)' }) } catch {
        $lines = [regex]::Matches((Get-Content "$settings/debug.log" -Raw).Substring($start), '\[palette\] ready chars=\d+ count=\d+ target=\d+')
        $result.paletteLastReady = if ($lines.Count) { $lines[$lines.Count - 1].Value } else { $null }
        throw
    }
    Highlight-Owned
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Theme palette lost foreground' }
    [ChatDeliveryDesktop]::Chord(@(0x0D))
    [void](Wait-For 'app persisted light theme' { (Get-Content "$settings/theme-mode.txt" -Raw).Trim() -ceq 'light' })
    [ChatDeliveryDesktop]::Chord(@(0x1B))
    $result.actions += @{input='Ctrl+K Themes Light'; theme='light'}
}
function Highlight-Journey {
    $result.executable = @{path=$Exe; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Exe).FileVersion; tag=$env:RELEASE_TAG}
    $result.frames = @()
    $result.captureAttempts = @()
    $result.limitations = @('Avatar positions come from native debug layout', 'Outline and edge antialiasing require visual review of all four photos; exact ring colour is not automatically verified', 'Selection-only styling inspected in source, not exercised')
    Highlight-Owned
    if ([ChatDeliveryDesktop]::GetSystemMetrics(0) -ne 1920 -or [ChatDeliveryDesktop]::GetSystemMetrics(1) -ne 1080 -or [SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Highlight proof requires 1920x1080 at 96 DPI' }
    [void](Wait-For 'restored Starred fixture' {
        $saved = Session; $inbox = Read-Json "$settings/inbox-default.json"
        if (-not (Flag $inbox 'starred_view') -or -not (Flag $saved 'starred_view') -or @($saved.tabs).Count -ne 3 -or @($inbox.shells).Count -ne 3) { return $false }
        for ($i = 0; $i -lt 3; $i++) {
            $tab = $saved.tabs[$i]
            if ($tab.name -cne @('First shell','Second shell','Third shell')[$i] -or -not (Flag $tab 'favorite') -or (Flag $tab 'starred_pinned_top') -ne ($i -lt 2)) { return $false }
            if (@($inbox.shells | Where-Object { $_.sid -ne 0 -and $_.name -ceq $tab.name }).Count -ne 1) { return $false }
        }
        return $true
    } 60)
    Highlight-Owned
    $positions = Wait-For 'two pinned avatars and one list avatar' {
        $found = @{}
        foreach ($m in [regex]::Matches((Get-Content "$settings/debug.log" -Raw), '\[bots\] face=\d+ color=\d+ rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
            $x=[int]$m.Groups[1].Value; $y=[int]$m.Groups[2].Value; $size=[int]$m.Groups[3].Value-$x
            if ($size -eq 56 -or $size -eq 40 -or $size -eq 36) { $found["$x,$y,$size"] = @{x=$x; y=$y; size=$size} }
        }
        $pins = @($found.Values | Where-Object { $_.size -eq 56 } | Sort-Object { [int]($_['x']) })
        $rows = @($found.Values | Where-Object { $_.size -eq 40 -or $_.size -eq 36 } | Sort-Object { [int]($_['y']) })
        if ($pins.Count -eq 2 -and $rows.Count -eq 1) { return @{pins=$pins; row=$rows[0]} }
    } 60
    $result.geometry = @{source='native avatar layout; tile radius 16, row radius 12'; pins=$positions.pins; row=$positions.row; dpi=96; pinDeltaX=($positions.pins[1].x - $positions.pins[0].x); rowDeltaY=($positions.row.y - $positions.pins[0].y)}
    if ($positions.pins[0].y -ne $positions.pins[1].y -or ($positions.pins[1].x - $positions.pins[0].x) -ne 92 -or ($positions.row.y - $positions.pins[0].y) -ne $(if ($positions.row.size -eq 36) { 107 } else { 105 })) { throw 'Unexpected Starred layout' }
    Highlight-Click $positions.row 'Third shell'
    Highlight-Click $positions.pins[0] 'First shell'
    Highlight-Click $positions.pins[1] 'Second shell'
    Highlight-Frame 'amoled' 'tile' 'Second shell' $positions.pins[1]
    Highlight-Click $positions.row 'Third shell'
    Highlight-Frame 'amoled' 'row' 'Third shell' $positions.row
    Highlight-ThemeLight
    Highlight-Click $positions.pins[0] 'First shell'
    Highlight-Frame 'light' 'tile' 'First shell' $positions.pins[0]
    Highlight-Click $positions.row 'Third shell'
    Highlight-Frame 'light' 'row' 'Third shell' $positions.row
    foreach ($frame in $result.frames) {
        $fill = if ($frame.theme -eq 'light') { 214 } else { 58 }
        if (@($frame.fill.rgb | Where-Object { $_ -ne $fill }).Count -ne 0) { throw 'Highlight fill differs; see all frames' }
    }
    $result.passed = $true
}
function Density-Journey {
    $result.limitations = @('Label case, font and spacing require visual review', 'Row crops include native pixels and nearest-neighbor 2x copies')
    Highlight-Owned
    $desktop = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    if ($desktop.Width -ne 1920 -or $desktop.Height -ne 1080 -or [SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Density proof requires 1920x1080 at 96 DPI' }
    $positions = Wait-For 'one pinned and four normal avatars' {
        $found = @{}
        foreach ($m in [regex]::Matches((Get-Content "$settings/debug.log" -Raw), '\[bots\] face=\d+ color=\d+ rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
            $x=[int]$m.Groups[1].Value; $y=[int]$m.Groups[2].Value; $size=[int]$m.Groups[3].Value-$x
            if ($size -eq 36 -or $size -eq 56) { $found["$x,$y,$size"] = @{x=$x; y=$y; size=$size} }
        }
        $pins = @($found.Values | Where-Object { $_['size'] -eq 56 })
        $rows = @($found.Values | Where-Object { $_['size'] -eq 36 } | Sort-Object { [int]($_['y']) })
        if ($pins.Count -eq 1 -and $rows.Count -eq 4) { return @{pin=$pins[0]; rows=$rows} }
    } 60
    $rows = $positions.rows
    if (($rows[1].y - $rows[0].y) -ne 58 -or ($rows[3].y - $rows[2].y) -ne 58 -or @($rows | Where-Object { $_['x'] -ne 20 }).Count) { throw 'Unexpected density geometry' }
    $fixture = Session
    if (@($fixture.tabs).Count -ne 5 -or @($fixture.groups | Where-Object { $_.name -ceq 'Managers' -or $_.name -ceq 'Other' }).Count -ne 2 -or $fixture.tabs[$fixture.active_tab].name -cne 'Manager one') { throw 'Density fixture changed' }
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    $script:previousHash = ''
    [void](Wait-For 'stable density paint' { $hash = Capture 'density-stability'; if ($hash -eq $script:previousHash) { return $true }; $script:previousHash = $hash; $false })
    $client = [ChatDeliveryDesktop+Rect]::new()
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    if (-not [ChatDeliveryDesktop]::GetClientRect($main, [ref]$client) -or ($client.Right - $client.Left) -ne 1920 -or ($client.Bottom - $client.Top) -ne 1032 -or $origin.X -lt $desktop.Left -or $origin.Y -lt $desktop.Top -or $origin.X + 1920 -gt $desktop.Right -or $origin.Y + 1032 -gt $desktop.Bottom) { throw 'Invalid density client capture geometry' }
    $bitmap = [Drawing.Bitmap]::new(1920, 1032)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        Highlight-Owned
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $bitmap.Save("$Output/density-client.png")
        foreach ($entry in @(@('selected', $rows[0]), @('plain', $rows[1]))) {
            $rect = [Drawing.Rectangle]::new(8, ($entry[1].y - 11), 291, 58)
            $crop = $bitmap.Clone($rect, $bitmap.PixelFormat)
            try {
                $crop.Save("$Output/density-$($entry[0])-row.png")
                $scaled = [Drawing.Bitmap]::new(($rect.Width * 2), ($rect.Height * 2))
                $scaledGraphics = [Drawing.Graphics]::FromImage($scaled)
                try {
                    $scaledGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
                    $scaledGraphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
                    $scaledGraphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
                    $scaledGraphics.DrawImage($crop, [Drawing.Rectangle]::new(0, 0, $scaled.Width, $scaled.Height), 0, 0, $crop.Width, $crop.Height, [Drawing.GraphicsUnit]::Pixel)
                    $scaled.Save("$Output/density-$($entry[0])-row-2x.png")
                } finally { $scaledGraphics.Dispose(); $scaled.Dispose() }
            } finally { $crop.Dispose() }
        }
        $yellow = @()
        foreach ($row in $rows) {
            $pixel = $bitmap.GetPixel(($row.x + $row.size + 1), ($row.y + $row.size - 4))
            $yellow += ($pixel.R -ge 225 -and $pixel.G -ge 175 -and $pixel.G -le 210 -and $pixel.B -le 100)
        }
        if (-not $yellow[0] -or $yellow[1] -or -not $yellow[2] -or $yellow[3]) { throw 'Density favorite badges differ' }
        $selectedFill = $bitmap.GetPixel(200, ($rows[0].y + 41))
        $plainFill = $bitmap.GetPixel(200, ($rows[1].y + 41))
        if ($selectedFill.R -ne 58 -or $selectedFill.G -ne 58 -or $selectedFill.B -ne 58 -or ($plainFill.R -eq 58 -and $plainFill.G -eq 58 -and $plainFill.B -eq 58)) { throw 'Initial row selection differs' }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    Highlight-Owned
    Focus
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, ($rows[1].x + 10), ($rows[1].y + 15))
    [void](Wait-For 'other row selected' { $saved = Session; $saved.tabs[$saved.active_tab].name -ceq 'Manager two' })
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    [void](Wait-For 'highlight moved' {
        $probe = [Drawing.Bitmap]::new(1, 1); $g = [Drawing.Graphics]::FromImage($probe)
        try { $g.CopyFromScreen(($origin.X + 200), ($origin.Y + $rows[1].y + 41), 0, 0, $probe.Size); $c = $probe.GetPixel(0, 0); $c.R -eq 58 -and $c.G -eq 58 -and $c.B -eq 58 } finally { $g.Dispose(); $probe.Dispose() }
    })
    $probe = [Drawing.Bitmap]::new(1, 1); $g = [Drawing.Graphics]::FromImage($probe)
    try {
        $g.CopyFromScreen(($origin.X + 200), ($origin.Y + $rows[0].y + 41), 0, 0, $probe.Size)
        $c = $probe.GetPixel(0, 0)
        if ($c.R -eq 58 -and $c.G -eq 58 -and $c.B -eq 58) { throw 'Previous row remains highlighted' }
    } finally { $g.Dispose(); $probe.Dispose() }
    $result.geometry = $positions; $result.badges = $yellow
    $result.actions += @{input='mouse'; name='Manager two'; highlightMoved=$true}
    $result.passed = $true
}
function StarBadge-Journey {
    $result.executable = @{sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; tag=$env:RELEASE_TAG; version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Exe).FileVersion}
    $result.limitations = @('Avatar positions use native debug layout; hover appearance requires human review', 'Badge pixels and input actions run independently of geometry tests')
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or -not $job.Contains($app)) { throw 'Window ownership mismatch' }
    if ([SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Star badge proof requires 96 DPI' }
    [void](Wait-For 'initial console poll' {
        if (-not (Test-Path "$settings/debug.log")) { return $false }
        try { (Get-Content "$settings/debug.log" -Raw) -match 'POLL\[t=[^\r\n]+,#1\]' } catch { $false }
    })
    $fixture = Session
    if (@($fixture.tabs).Count -ne 3 -or $fixture.tabs[0].name -cne 'First shell' -or $fixture.tabs[1].name -cne 'Second shell' -or $fixture.tabs[2].name -cne 'Third shell' -or -not (Flag $fixture.tabs[0] 'pinned_top') -or -not (Flag $fixture.tabs[0] 'favorite') -or -not (Flag $fixture.tabs[1] 'favorite') -or (Flag $fixture.tabs[2] 'favorite')) { throw 'Star badge fixture changed' }
    $positions = Wait-For 'pinned and list avatar positions' {
        $found = @{}
        foreach ($m in [regex]::Matches((Get-Content "$settings/debug.log" -Raw), '\[bots\] face=\d+ color=\d+ rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
            $x=[int]$m.Groups[1].Value; $y=[int]$m.Groups[2].Value; $size=[int]$m.Groups[3].Value-$x
            if ($size -eq 56 -or $size -eq 40 -or $size -eq 36) { $found["$x,$y,$size"] = @{x=$x; y=$y; size=$size} }
        }
        $pins = @($found.Values | Where-Object { $_.size -eq 56 })
        $rows = @($found.Values | Where-Object { $_.size -eq 40 -or $_.size -eq 36 } | Sort-Object { [int]($_['y']) })
        if ($pins.Count -eq 1 -and $rows.Count -eq 2) { return @{pin=$pins[0]; rows=$rows} }
    } 60
    $result.geometry = $positions
    $result.initial = Session
    $result.initialInbox = Read-Json "$settings/inbox-default.json"
    $script:previousHash = ''
    [void](Wait-For 'stable badge paint' { $hash = Capture 'star-stability'; if ($hash -eq $script:previousHash) { return $true }; $script:previousHash = $hash; $false })
    Shot 'star-mixed'
    $hover = $positions.rows[0]
    $hoverPoint = [ChatDeliveryDesktop]::ScreenPoint($main, 285, ($hover.y + 20))
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new($hoverPoint.X, $hoverPoint.Y)
    Start-Sleep -Milliseconds 500
    Shot 'star-hover'
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    $bitmap = [Drawing.Bitmap]::new("$Output/star-mixed.png")
    try {
        $yellow = @()
        foreach ($target in @($positions.pin, $positions.rows[0], $positions.rows[1])) {
            $pixel = $bitmap.GetPixel(($origin.X + $target.x + $target.size + 1), ($origin.Y + $target.y + $target.size - 4))
            $yellow += ($pixel.R -ge 225 -and $pixel.G -ge 175 -and $pixel.G -le 210 -and $pixel.B -le 100)
        }
        $result.yellow = @(
            @{name=$fixture.tabs[0].name; favorite=$true; yellow=[bool]$yellow[0]},
            @{name=$fixture.tabs[1].name; favorite=$true; yellow=[bool]$yellow[1]},
            @{name=$fixture.tabs[2].name; favorite=$false; yellow=[bool]$yellow[2]}
        )
    } finally { $bitmap.Dispose() }
    if (-not $yellow[0] -or -not $yellow[1] -or $yellow[2]) { throw 'Star badge pixels missing' }
    Focus
    $before = Session
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 285, ($hover.y + 20))
    [void](Wait-For 'former close location selects second shell without closing' { $s = Session; @($s.tabs).Count -eq 3 -and $s.active_tab -ne $before.active_tab -and $s.tabs[$s.active_tab].name -ceq 'Second shell' })
    $result.actions += @{input='former close location'; count=@((Session).tabs).Count; active=(Session).active_tab}
    $selected = (Session).active_tab
    $beforeFavorite = Flag (Session).tabs[$selected] 'favorite'
    Focus
    [ChatDeliveryDesktop]::Chord(@(0x12,0x53))
    [void](Wait-For 'favorite toggled and persisted' { (Flag (Session).tabs[$selected] 'favorite') -ne $beforeFavorite })
    $result.actions += @{input='Alt+S'; before=$beforeFavorite; after=(Flag (Session).tabs[$selected] 'favorite')}
    $script:previousHash = ''
    [void](Wait-For 'stable toggled paint' { $hash = Capture 'star-toggle-stability'; if ($hash -eq $script:previousHash) { return $true }; $script:previousHash = $hash; $false })
    Shot 'star-toggled'
    Focus
    $start = (Get-Content "$settings/debug.log" -Raw).Length
    [ChatDeliveryDesktop]::Chord(@(0x11,0x4B))
    [void](Wait-For 'palette initialized' { (Get-Content "$settings/debug.log" -Raw).Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($key in @(0x43,0x4C,0x4F,0x53,0x45,0x20,0x54,0x41,0x42)) { [ChatDeliveryDesktop]::Type($key) }
    [void](Wait-For 'close tab selected' { (Get-Content "$settings/debug.log" -Raw).Substring($start) -match '\[palette\] ready chars=9 count=[1-9]\d* target=6232(?:\r?\n|$)' })
    [ChatDeliveryDesktop]::Chord(@(0x0D))
    [void](Wait-For 'palette close removes fixture session' { @((Session).tabs).Count -eq 2 })
    $result.actions += @{input='Ctrl+K Close Tab'; count=@((Session).tabs).Count}
    $result.passed = $true
}
$linkFixtureLoaded = $false
$displayAttempted = $false
try {
    if ($HighlightProof -or $StarBadgeProof -or $DensityProof) { $displayAttempted = $true; [CaptionProof]::SetDpi(96) }
    New-Item -ItemType Directory -Force $settings, "$profile/local", "$profile/home" | Out-Null
    if ($ChangelogLinks) {
        $result.registryRestored = $false; $result.receipts = @()
        $receiverSource = (Resolve-Path -LiteralPath "$PSScriptRoot/changelog-receiver.cs" -ErrorAction Stop).ProviderPath
        . "$PSScriptRoot/changelog-link-fixture.ps1"
        $linkFixtureLoaded = $true
        Start-LinkFixture -ReceiverSource $receiverSource
    }
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'; $env:IGSH_246 = '0'; $env:ZIGSHELL_DEBUG = '1'
    $tabs = @('First shell', 'Second shell', 'Third shell') | ForEach-Object { @{kind='cmd'; name=$_; manual=$true; cv=$false; pid=0} }
    if ($DensityProof) {
        $tabs = @('Pinned shell', 'Manager one', 'Manager two', 'Other one', 'Other two') | ForEach-Object { @{kind='cmd'; name=$_; manual=$true; cv=$false; pid=0} }
        $tabs[0].pinned_top = $true; $tabs[0].favorite = $true
        $tabs[1].group_id = 17; $tabs[1].favorite = $true; $tabs[2].group_id = 17
        $tabs[3].group_id = 18; $tabs[3].favorite = $true; $tabs[4].group_id = 18
        Save @{active_tab=1; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs); groups=@(@{id=17; name='Managers'}, @{id=18; name='Other'})} "$settings/session.json"
    } elseif ($StarBadgeProof) {
        $tabs[0].favorite = $true; $tabs[0].pinned_top = $true
        $tabs[1].favorite = $true; $tabs[2].favorite = $false
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs)} "$settings/session.json"
    } elseif ($HighlightProof) {
        for ($i = 0; $i -lt 3; $i++) { $tabs[$i].favorite = $true; $tabs[$i].starred_pinned_top = $i -lt 2 }
        Save @{active_tab=0; single_window=$true; starred_view=$true; chat_active=$false; amoled_theme=$true; tabs=@($tabs)} "$settings/session.json"
    } elseif ($OrderProof) {
        for ($i = 0; $i -lt 3; $i++) { $tabs[$i].group_id = 17 + $i }
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs); groups=@(@{id=17; name='A'}, @{id=18; name='B'}, @{id=19; name='C'})} "$settings/session.json"
    } elseif ($MemoryProof) {
        $tabs[1].group_id = 17
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs); groups=@(@{id=17; name='Proof group'})} "$settings/session.json"
    } else {
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs)} "$settings/session.json"
    }
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Output/stdout.log", "$Output/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'restored sessions' { (Session).tabs.Count -eq $(if ($DensityProof) { 5 } else { 3 }) })
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    [void](Wait-For 'sidebar sessions published' {
        if (-not (Test-Path "$settings/inbox-default.json")) { return $false }
        $inbox = Read-Json "$settings/inbox-default.json"
        @($inbox.shells).Count -eq $(if ($DensityProof) { 5 } else { 3 })
    })
    if ($ChangelogProof) {
        if (-not $ChangelogLinks) { $result.limitations = @('Screenshot requires human review; bitmap stability does not establish overlay contents', 'Bundled changelog is not published release-notes JSON') }
        $result.executable = @{path=$Exe; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Exe).FileVersion}
        if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or -not $job.Contains($app)) { throw 'Window ownership mismatch' }
        Open-Changelog
        $script:previousHash = ''
        [void](Wait-For 'stable full-screen frame after Enter' {
            Shot 'changelog-first-page'
            $hash = (Get-FileHash "$Output/changelog-first-page.png" -Algorithm SHA256).Hash
            if ($hash -eq $script:previousHash) { return $true }
            $script:previousHash = $hash
            $false
        } 30)
        if ($ChangelogLinks) {
            $rect = [LinkFixtureNative+Rect]::new()
            if (-not [LinkFixtureNative]::GetClientRect($main, [ref]$rect) -or $rect.Right -ne 1024 -or $rect.Bottom -ne 720 -or [LinkFixtureNative]::GetDpiForWindow($main) -ne 96) { throw 'Changelog click fixture requires 1024x720 client and 96 DPI' }
            $result.geometry = @{clientWidth=$rect.Right; clientHeight=$rect.Bottom; dpi=96; x=869; y=126; source='calcChangelogLayout and observed first bullet'}
            Prepare-LinkReceipt
            Focus
            if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main -or -not $job.Contains($app)) { throw 'Mouse target is not owned foreground' }
            $result.actions += @{input='mouse'; x=869; y=126; target='current first bullet'}
            [ChatDeliveryDesktop]::PressClient($main, $app.Id, 869, 126)
            Receive-Link $result.audit.currentTicket 'current-mouse'
            Open-Changelog
            if ($result.audit.oldIndex -lt 1 -or $result.audit.oldIndex -gt 1000) { throw '1048 manifest index outside bounded journey' }
            Focus
            for ($i = 0; $i -lt $result.audit.oldIndex; $i++) {
                if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main -or -not $job.Contains($app)) { throw 'Keyboard target is not owned foreground' }
                [ChatDeliveryDesktop]::Chord(@(0x28)); Start-Sleep -Milliseconds 80
            }
            $result.actions += @{input='Down'; count=$result.audit.oldIndex; target='1048 manifest index hypothesis'}
            Shot 'changelog-1048-selected'
            Prepare-LinkReceipt
            if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main -or -not $job.Contains($app)) { throw 'Enter target is not owned foreground' }
            $result.actions += @{input='Enter'; target='1048 first ticket hypothesis'}
            [ChatDeliveryDesktop]::Chord(@(0x0D))
            Receive-Link $result.audit.oldTicket '1048-keyboard'
        }
        $result.passed = $true
    } elseif ($DensityProof) { Density-Journey } elseif ($StarBadgeProof) { StarBadge-Journey } elseif ($HighlightProof) { Highlight-Journey } elseif ($MemoryProof) { Memory-Journey } elseif ($OrderProof) { Order-Journey } else {
    Toggle-View
    [void](Wait-For 'initial Chat View' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero -and (Chat-On) })
    [void](Wait-For 'initial console poll' {
        if (-not (Test-Path "$settings/debug.log")) { return $false }
        try { (Get-Content "$settings/debug.log" -Raw) -match 'POLL\[t=[^\r\n]+,#1\]' } catch { $false }
    } 60)
    Focus
    Toggle-View
    [void](Wait-For 'initial shell view' { -not (Chat-On) })
    Compare-Views 'expanded'
    $previous = (Session).active_tab
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 120, 171)
    [void](Wait-For 'sidebar click changes the selected session' { (Session).active_tab -ne $previous })
    $result.actions += 'sidebar-select'
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    Compare-Views 'selected'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, 64)
    [void](Wait-For 'Recents collapsed' { (Flag (Session) 'recents_section_collapsed') })
    $result.actions += 'section-collapse'
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    Compare-Views 'section-collapsed'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, 64)
    [void](Wait-For 'Recents reopened' { -not (Flag (Session) 'recents_section_collapsed') })
    $result.actions += 'section-expand'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 285, 229)
    [void](Wait-For 'sidebar edge selects without closing' { (Session).tabs.Count -eq 3 -and (Session).tabs[(Session).active_tab].name -ceq 'Third shell' })
    $result.actions += 'sidebar-edge-select'
    $result.passed = $true
    }
} catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    if ($MemoryProof -or $OrderProof -or $ChangelogProof -or $HighlightProof -or $StarBadgeProof -or $DensityProof) {
        $result.scratchRemoved = $false
        $result.cleanupErrors = @()
        try {
            $result.cleanup = 0
            if ($linkFixtureLoaded -and $linkAck) { try { [void]$linkAck.Set() } catch { $result.cleanupErrors += 'Receiver acknowledgement failed' } }
            $cleanupKnown = $true
            foreach ($ownedJob in @($job, $nextJob)) {
                if ($null -eq $ownedJob) { continue }
                try {
                    $stopped = $ownedJob.Stop()
                    if ($cleanupKnown) { $result.cleanup += $stopped.ActiveProcesses }
                } catch {
                    $cleanupKnown = $false
                    $result.cleanup = 'unknown'
                    $result.cleanupErrors += $_.Exception.Message
                } finally { try { $ownedJob.Dispose() } catch { $result.cleanupErrors += 'Owned job disposal failed' } }
            }
            if ($linkFixtureLoaded) { try { Stop-LinkFixture } catch { $result.cleanupErrors += "Association restoration failed: $($_.Exception.Message)"; $result.registryRestored = $false } }
            foreach ($name in @('session.json', 'session.json.launch.json', 'debug.log', 'inbox-default.json')) {
                try { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } } catch { $result.cleanupErrors += $_.Exception.Message }
            }
            if ($result.cleanup -eq 0) {
                $deadline = [DateTime]::UtcNow.AddSeconds(20)
                $lastError = ''
                while (Test-Path -LiteralPath $profile) {
                    try { Remove-Item -LiteralPath $profile -Recurse -Force } catch { $lastError = $_.Exception.Message }
                    if (-not (Test-Path -LiteralPath $profile)) { break }
                    if ([DateTime]::UtcNow -ge $deadline) {
                        $result.cleanupErrors += "Scratch removal failed: $lastError"
                        break
                    }
                    Start-Sleep -Milliseconds 200
                }
            }
        } catch {
            $result.cleanupErrors += $_.Exception.Message
        } finally {
            if ($HighlightProof -or $StarBadgeProof -or $DensityProof) {
                $result.displayRestored = $false
                try { if ($displayAttempted) { [CaptionProof]::RestoreDpi() }; $result.displayRestored = $true } catch { $result.cleanupErrors += "Display restoration failed: $($_.Exception.Message)" }
            }
            try { $result.scratchRemoved = -not (Test-Path -LiteralPath $profile) } catch { $result.cleanupErrors += $_.Exception.Message }
            if ($result.cleanupErrors.Count -gt 0 -or ($ChangelogLinks -and -not $result.registryRestored)) { $result.passed = $false }
            Save $result "$Output/result.json"
        }
    } else {
        if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() }
        if ($null -ne $nextJob) { $nextStopped = $nextJob.Stop(); if ($result.cleanup -eq 'pending') { $result.cleanup = 0 }; $result.cleanup += $nextStopped.ActiveProcesses; $nextJob.Dispose() }
        foreach ($name in @('session.json', 'debug.log', 'inbox-default.json')) { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } }
        Save $result "$Output/result.json"
        if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
    }
}
if (-not $result.passed -or $result.cleanup -ne 0 -or (($MemoryProof -or $OrderProof -or $ChangelogProof -or $HighlightProof -or $StarBadgeProof -or $DensityProof) -and -not $result.scratchRemoved) -or (($HighlightProof -or $StarBadgeProof -or $DensityProof) -and -not $result.displayRestored)) { throw 'Shared sidebar journey failed; see result.json' }
Write-Host 'SHARED_SIDEBAR_JOURNEY_OK'
