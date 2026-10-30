param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output, [switch]$MemoryProof)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
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

if ($MemoryProof) {
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
    public static void Drag(IntPtr hwnd, uint pid, int from, int to, int y) {
        var start = new Point { X = from, Y = y };
        var end = new Point { X = to, Y = y };
        uint owner;
        GetWindowThreadProcessId(hwnd, out owner);
        if (!ClientToScreen(hwnd, ref start) || !ClientToScreen(hwnd, ref end) || owner != pid || GetForegroundWindow() != hwnd || WindowFromPoint(start) != hwnd || WindowFromPoint(end) != hwnd) throw new InvalidOperationException("Sidebar drag ownership mismatch");
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
    Shot $Name
    $script:frames += $Name
}
function Memory-ToggleUnread([bool]$Expected, [string]$Name) {
    Focus
    $log = "$settings/debug.log"
    $start = (Get-Content $log -Raw).Length
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x4B))
    $result.actions += 'Ctrl+K: open command palette'
    [void](Wait-For 'palette ready' { ((Get-Content $log -Raw).Substring($start)) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($char in 'toggle unread only'.ToCharArray()) { [ChatDeliveryDesktop]::Character($char) }
    $result.actions += 'Type toggle unread only'
    [void](Wait-For 'unread command selected' { ((Get-Content $log -Raw).Substring($start)) -match '\[palette\] ready chars=18 count=[1-9]\d* target=6219(?:\r?\n|$)' })
    [ChatDeliveryDesktop]::Chord(@(0x0D))
    $result.actions += 'Enter: toggle unread only'
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
    Focus
    Memory-Evidence "after-$Stage"
    # Turning the restored filter off makes both headers visible again.
    Memory-ToggleUnread $false "$Stage-unread-off"
    Memory-Click 64 'Click group: prove restored open' { Memory-GroupCollapsed } "$Stage-group-closed"
    Memory-Click 92 'Click Recents: prove restored closed' { -not (Flag (Session) 'recents_section_collapsed') } "$Stage-recents-open"
    Memory-Click 64 'Click group: reopen' { -not (Memory-GroupCollapsed) } "$Stage-group-open"
    Memory-Click 150 'Click Recents: close again' { Flag (Session) 'recents_section_collapsed' } "$Stage-recents-closed"
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
    Focus
}
function Memory-Journey {
    $script:frames = @()
    $result.identities = @()
    $result.exits = @()
    if ([SidebarDrag]::GetDpiForWindow($main) -ne 96) { throw 'Memory journey requires 96 DPI' }
    $result.limitations = @('Expanded Pinned header is suppressed by the existing tile layout; group and Recents used instead', 'Other groups and Starred groups not exercised', 'Updater helper relaunch exercised; download, signature and binary replacement not exercised')
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
    [SidebarDrag]::Drag($main, $app.Id, 44, 300, 200)
    $result.actions += 'Drag collapsed sidebar boundary right; release expanded'
    [void](Wait-For 'drag expanded saved on release' { -not (Flag (Session) 'sidebar_collapsed') })
    Memory-Evidence 'drag-expanded'
    Memory-ToggleUnread $true 'unread-on'
    Memory-ToggleUnread $false 'unread-off'
    Memory-ToggleUnread $true 'configured'
    Memory-Restart $false
    Memory-Recheck 'restart'
    Memory-Restart $true
    Memory-Recheck 'updater'
    Memory-Gif
    $result.passed = $true
}

try {
    New-Item -ItemType Directory -Force $settings, "$profile/local", "$profile/home" | Out-Null
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'; $env:IGSH_246 = '0'; $env:ZIGSHELL_DEBUG = '1'
    $tabs = @('First shell', 'Second shell', 'Third shell') | ForEach-Object { @{kind='cmd'; name=$_; manual=$true; cv=$false; pid=0} }
    if ($MemoryProof) {
        $tabs[1].group_id = 17
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs); groups=@(@{id=17; name='Proof group'})} "$settings/session.json"
    } else {
        Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs)} "$settings/session.json"
    }
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Output/stdout.log", "$Output/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'three restored sessions' { (Session).tabs.Count -eq 3 })
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    [void](Wait-For 'three sidebar sessions published' {
        if (-not (Test-Path "$settings/inbox-default.json")) { return $false }
        $inbox = Read-Json "$settings/inbox-default.json"
        @($inbox.shells).Count -eq 3
    })
    if ($MemoryProof) { Memory-Journey } else {
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
    $selectedName = (Session).tabs[(Session).active_tab].name
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 285, 229)
    [void](Wait-For 'sidebar close removes a session' { (Session).tabs.Count -eq 2 })
    if ((Session).tabs[(Session).active_tab].name -cne $selectedName) { throw 'Closing another session changed selection' }
    $result.actions += 'sidebar-close'
    $result.passed = $true
    }
} catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() }
    if ($null -ne $nextJob) { $nextStopped = $nextJob.Stop(); if ($result.cleanup -eq 'pending') { $result.cleanup = 0 }; $result.cleanup += $nextStopped.ActiveProcesses; $nextJob.Dispose() }
    foreach ($name in @('session.json', 'debug.log', 'inbox-default.json')) { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } }
    if ($MemoryProof) {
        if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
        $result.scratchRemoved = -not (Test-Path $profile)
        Save $result "$Output/result.json"
    } else {
        Save $result "$Output/result.json"
        if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
    }
}
if (-not $result.passed -or $result.cleanup -ne 0 -or ($MemoryProof -and -not $result.scratchRemoved)) { throw 'Shared sidebar journey failed; see result.json' }
Write-Host 'SHARED_SIDEBAR_JOURNEY_OK'
