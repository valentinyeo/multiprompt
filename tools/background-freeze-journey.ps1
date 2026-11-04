param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Background freeze journey requires a GitHub-hosted Windows runner' }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class BackgroundFreezeJourney {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct WindowPos { public IntPtr Window, InsertAfter; public int X, Y, Width, Height; public uint Flags; }
    [StructLayout(LayoutKind.Sequential)] public struct NcCalcSizeParams { public Rect Proposed, PreviousWindow, PreviousClient; public IntPtr WindowPos; }
    [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo { public uint Size; public Rect Monitor, Work; public uint Flags; }
    public sealed class Calculation {
        public Rect Proposed, Result, Work, SelectedWork, BeforeBounds, AfterBounds;
        public int ParamsBytes, WindowPosBytes, ProposedWidth, ClientWidth, OldIntersectionWidth;
        public ulong MessageResult;
        public double ElapsedMs;
        public bool Delivered;
    }
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsChild(IntPtr parent, IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr window);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromRect(ref Rect rect, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW")] public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wp, IntPtr lp, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW")] static extern IntPtr SendNcCalcSizeTimeout(IntPtr window, uint message, UIntPtr wp, [In, Out] ref NcCalcSizeParams parameters, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll", EntryPoint="PostMessageW")] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr wp, IntPtr lp);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern bool InvalidateRect(IntPtr window, IntPtr rect, bool erase);
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr window, IntPtr rect, IntPtr region, uint flags);
    public static void Focus(IntPtr window) {
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(window);
    }
    public static Calculation Calculate(IntPtr window, bool offscreen) {
        var info = new MonitorInfo { Size = (uint)Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(MonitorFromWindow(window, 2), ref info)) throw new InvalidOperationException("Monitor bounds unavailable");
        var work = info.Work;
        var proposed = offscreen
            ? new Rect { Left = work.Right - 8, Top = work.Top - 8, Right = work.Right - 8 + work.Right - work.Left + 16, Bottom = work.Bottom + 8 }
            : new Rect { Left = work.Left - 8, Top = work.Top - 8, Right = work.Right + 8, Bottom = work.Bottom + 8 };
        var selected = new MonitorInfo { Size = info.Size };
        if (!GetMonitorInfo(MonitorFromRect(ref proposed, 2), ref selected)) throw new InvalidOperationException("Proposed monitor unavailable");
        var result = new Calculation { Proposed = proposed, Work = work, SelectedWork = selected.Work, ParamsBytes = Marshal.SizeOf<NcCalcSizeParams>(), WindowPosBytes = Marshal.SizeOf<WindowPos>() };
        if (result.ParamsBytes != (IntPtr.Size == 8 ? 56 : 52) || result.WindowPosBytes != (IntPtr.Size == 8 ? 40 : 28)) throw new InvalidOperationException("Native structure size mismatch");
        if (!GetWindowRect(window, out result.BeforeBounds)) throw new InvalidOperationException("Window bounds unavailable");
        Rect client;
        var origin = new Point();
        if (!GetClientRect(window, out client) || !ClientToScreen(window, ref origin)) throw new InvalidOperationException("Client bounds unavailable");
        client.Left += origin.X; client.Right += origin.X; client.Top += origin.Y; client.Bottom += origin.Y;
        var position = new WindowPos { Window = window, X = proposed.Left, Y = proposed.Top, Width = proposed.Right - proposed.Left, Height = proposed.Bottom - proposed.Top, Flags = 4 };
        var memory = Marshal.AllocHGlobal(result.WindowPosBytes);
        try {
            Marshal.StructureToPtr(position, memory, false);
            var parameters = new NcCalcSizeParams { Proposed = proposed, PreviousWindow = result.BeforeBounds, PreviousClient = client, WindowPos = memory };
            UIntPtr reply;
            var clock = Stopwatch.StartNew();
            result.Delivered = SendNcCalcSizeTimeout(window, 0x0083, new UIntPtr(1), ref parameters, 2, 1000, out reply) != IntPtr.Zero;
            result.ElapsedMs = clock.Elapsed.TotalMilliseconds;
            result.MessageResult = reply.ToUInt64();
            result.Result = parameters.Proposed;
            result.ProposedWidth = proposed.Right - proposed.Left;
            result.ClientWidth = parameters.Proposed.Right - parameters.Proposed.Left;
        } finally { Marshal.FreeHGlobal(memory); }
        if (!GetWindowRect(window, out result.AfterBounds)) throw new InvalidOperationException("Result bounds unavailable");
        result.OldIntersectionWidth = Math.Min(proposed.Right, work.Right) - Math.Max(proposed.Left, work.Left);
        return result;
    }
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr Window; public uint Id; public UIntPtr Word; public IntPtr Parameter; public uint Time; public Point Point; public uint Private; }
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr CreateWindowEx(uint extended, string className, string title, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr window);
    [DllImport("user32.dll", EntryPoint="GetMessageW")] static extern int GetMessage(out Message message, IntPtr window, uint first, uint last);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref Message message);
    [DllImport("user32.dll", EntryPoint="DispatchMessageW")] static extern IntPtr DispatchMessage(ref Message message);
    [DllImport("user32.dll", EntryPoint="PostThreadMessageW")] static extern bool PostThreadMessage(uint thread, uint message, UIntPtr word, IntPtr parameter);
    static Thread otherThread;
    static uint otherThreadId;
    static IntPtr otherWindow;
    static ManualResetEventSlim ready = new ManualResetEventSlim();
    public static IntPtr StartOther() {
        otherThread = new Thread(() => {
            otherThreadId = GetCurrentThreadId();
            otherWindow = CreateWindowEx(0, "STATIC", "Background return fixture", 0x10CF0000, 0, 0, 320, 160, IntPtr.Zero, IntPtr.Zero, GetModuleHandle(null), IntPtr.Zero);
            ready.Set();
            if (otherWindow == IntPtr.Zero) return;
            try {
                Message message;
                while (GetMessage(out message, IntPtr.Zero, 0, 0) > 0) { TranslateMessage(ref message); DispatchMessage(ref message); }
            } finally { DestroyWindow(otherWindow); }
        });
        otherThread.IsBackground = true;
        otherThread.Start();
        if (!ready.Wait(5000) || otherWindow == IntPtr.Zero) throw new TimeoutException("Alternate window unavailable");
        return otherWindow;
    }
    public static bool StopOther() {
        if (otherThread == null) return true;
        PostThreadMessage(otherThreadId, 0x0012, UIntPtr.Zero, IntPtr.Zero);
        return otherThread.Join(3000);
    }
}
'@
$Exe = (Resolve-Path $Exe).Path
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('background-freeze-' + [guid]::NewGuid().ToString('N'))
$crashes = Join-Path $scratch 'roaming/ZigShell/crashes'
$app = $null
$main = [IntPtr]::Zero
$samples = [Collections.Generic.List[object]]::new()
$shots = [Collections.Generic.List[object]]::new()
$injections = [Collections.Generic.List[object]]::new()
$journeyClock = [Diagnostics.Stopwatch]::StartNew()
$result = [ordered]@{
    status = 'failed'; phase = 'launch'; exeHash = (Get-FileHash $Exe -Algorithm SHA256).Hash
    cycles = @(); cancellations = @(); samples = $samples; screenshots = $shots; syntheticPostedMessages = $injections
    scope = @('Offline NO_LOGIN profile; no account, sync, SSH or browser proof.', 'Native foreground and minimize/restore cycles, not mouse or keyboard shortcut coverage.', 'NCCALCSIZE and ordered paint suppression are synthetic fixtures, not user input.', 'Single chosen work area; no physical multi-monitor or DPI-transition proof.', 'Paint report reason 2; no upload or real-world freeze reproduction claim.')
    redrawRestored = $false; appStopped = $false; helperStopped = $false; scratchRemoved = $false
}
function Assert-Owned {
    $app.Refresh()
    $owner = [uint32]0
    [void][BackgroundFreezeJourney]::GetWindowThreadProcessId($main, [ref]$owner)
    if ($app.HasExited -or -not [BackgroundFreezeJourney]::IsWindow($main) -or $owner -ne $app.Id) { throw 'Owned main window is no longer alive' }
}
function Wait-Condition([string]$Name, [scriptblock]$Check, [int]$TimeoutMs = 1000) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        if (& $Check) { return }
        Start-Sleep -Milliseconds 25
    } while ($clock.ElapsedMilliseconds -lt $TimeoutMs)
    throw "Timed out waiting for $Name"
}
function Send-Checked([uint32]$Message, [uint64]$Word = 0) {
    Assert-Owned
    $reply = [UIntPtr]::Zero
    if ([BackgroundFreezeJourney]::SendMessageTimeout($main, $Message, [UIntPtr]$Word, [IntPtr]::Zero, 2, 1000, [ref]$reply) -eq [IntPtr]::Zero) { throw "Message $Message timed out or failed" }
}
function Measure-Response([string]$Stage) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Send-Checked 0
    $elapsed = $clock.Elapsed.TotalMilliseconds
    $foreground = [BackgroundFreezeJourney]::GetForegroundWindow()
    $samples.Add(@{ stage = $Stage; atMs = $journeyClock.Elapsed.TotalMilliseconds; wmNullMs = $elapsed; iconic = [int][BackgroundFreezeJourney]::IsIconic($main); foregroundMain = $foreground -eq $main; foregroundChild = [BackgroundFreezeJourney]::IsChild($main, $foreground) })
    if ($elapsed -ge 1000) { throw "WM_NULL exceeded 1000 ms during $Stage" }
}
function Report-Files { return @(Get-ChildItem -LiteralPath $crashes -Filter 'freeze-*.txt' -ErrorAction SilentlyContinue) }
function Observe([string]$Stage, [int]$Milliseconds, [int]$Count) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Measure-Response $Stage
        if (@(Report-Files).Count -ne $Count) { throw "Unexpected freeze report count during $Stage" }
        Start-Sleep -Milliseconds 200
    } while ($clock.ElapsedMilliseconds -lt $Milliseconds)
    if (@(Report-Files).Count -ne $Count) { throw "Unexpected final report count during $Stage" }
}
function Read-Bounds([bool]$Client = $true) {
    Assert-Owned
    $rect = [BackgroundFreezeJourney+Rect]::new()
    $ok = if ($Client) { [BackgroundFreezeJourney]::GetClientRect($main, [ref]$rect) } else { [BackgroundFreezeJourney]::GetWindowRect($main, [ref]$rect) }
    if (-not $ok -or $rect.Right - $rect.Left -lt 200 -or $rect.Bottom - $rect.Top -lt 150) { throw 'Main client or window collapsed' }
    return $rect
}
function Same-Rect($Left, $Right) {
    return $Left.Left -eq $Right.Left -and $Left.Top -eq $Right.Top -and $Left.Right -eq $Right.Right -and $Left.Bottom -eq $Right.Bottom
}
function Foreground([IntPtr]$Window) {
    [BackgroundFreezeJourney]::Focus($Window)
    Wait-Condition 'foreground window' { [BackgroundFreezeJourney]::GetForegroundWindow() -eq $Window }
}
function Return-Main([string]$Stage, [bool]$Restore = $false) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    if ($Restore) { [void][BackgroundFreezeJourney]::ShowWindowAsync($main, 9) }
    Foreground $main
    Wait-Condition 'restored window' { -not [BackgroundFreezeJourney]::IsIconic($main) }
    Measure-Response $Stage
    $elapsed = $clock.Elapsed.TotalMilliseconds
    if ($elapsed -ge 1000) { throw "Foreground return exceeded 1000 ms during $Stage" }
    return $elapsed
}
function Save-Shot([string]$Name) {
    $foreground = [BackgroundFreezeJourney]::GetForegroundWindow()
    if (($foreground -ne $main -and -not [BackgroundFreezeJourney]::IsChild($main, $foreground)) -or [BackgroundFreezeJourney]::IsIconic($main)) { throw 'Screenshot requires the foreground app or its hosted console' }
    $rect = Read-Bounds
    $origin = [BackgroundFreezeJourney+Point]::new()
    if (-not [BackgroundFreezeJourney]::ClientToScreen($main, [ref]$origin)) { throw 'Screenshot client origin unavailable' }
    $area = [Drawing.Rectangle]::new($origin.X, $origin.Y, $rect.Right - $rect.Left, $rect.Bottom - $rect.Top)
    $area = [Drawing.Rectangle]::Intersect($area, [Windows.Forms.Screen]::FromHandle($main).Bounds)
    if ($area.Width -lt 200 -or $area.Height -lt 150) { throw 'Screenshot client is off screen' }
    $bitmap = [Drawing.Bitmap]::new($area.Width, $area.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $file = Join-Path $Evidence ($Name + '.png')
    try {
        $graphics.CopyFromScreen($area.Location, [Drawing.Point]::Empty, $area.Size)
        $bitmap.Save($file, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $shots.Add(@{ name = $Name + '.png'; width = $area.Width; height = $area.Height; sha256 = (Get-FileHash $file -Algorithm SHA256).Hash })
}
function Inject-PaintSuppression {
    Assert-Owned
    [void](Return-Main 'paint-fixture-focus')
    if ([BackgroundFreezeJourney]::IsIconic($main) -or [BackgroundFreezeJourney]::GetForegroundWindow() -ne $main) { throw 'Paint fixture requires the restored foreground main' }
    foreach ($message in @(@(0x001C, 0), @(0x000B, 0), @(0x001C, 1))) {
        if (-not [BackgroundFreezeJourney]::PostMessage($main, $message[0], [UIntPtr]$message[1], [IntPtr]::Zero)) { throw 'Cannot post ordered paint suppression fixture' }
    }
    $injections.Add(@{ atMs = $journeyClock.Elapsed.TotalMilliseconds; messages = @(0x001C, 0x000B, 0x001C); wParams = @(0, 0, 1) })
    Wait-Condition 'redraw suppression' { [BackgroundFreezeJourney]::GetProp($main, 'SysSetRedraw') -ne [IntPtr]::Zero }
}
function Recover-Paint {
    Send-Checked 0x000B 1
    if (-not [BackgroundFreezeJourney]::InvalidateRect($main, [IntPtr]::Zero, $true) -or -not [BackgroundFreezeJourney]::RedrawWindow($main, [IntPtr]::Zero, [IntPtr]::Zero, 0x485)) { throw 'Cannot invalidate recovered main window' }
    Foreground $other
    [void](Return-Main 'paint-recovery' $true)
    Wait-Condition 'redraw enabled' { [BackgroundFreezeJourney]::GetProp($main, 'SysSetRedraw') -eq [IntPtr]::Zero }
}
try {
    foreach ($directory in @('roaming', 'local', 'profile', 'temp')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $start = [Diagnostics.ProcessStartInfo]::new($Exe)
    $start.UseShellExecute = $false
    $start.WorkingDirectory = $scratch
    $start.ArgumentList.Add('--single-window')
    $start.ArgumentList.Add('--no-window-restore')
    foreach ($entry in @{ APPDATA = 'roaming'; LOCALAPPDATA = 'local'; USERPROFILE = 'profile'; HOME = 'profile'; TEMP = 'temp'; TMP = 'temp' }.GetEnumerator()) { $start.Environment[$entry.Key] = Join-Path $scratch $entry.Value }
    $start.Environment['MULTIPROMPT_NO_LOGIN'] = '1'
    $start.Environment['IGSH_246'] = '0'
    $start.Environment['ZIGSHELL_DEBUG'] = '1'
    $app = [Diagnostics.Process]::new()
    $app.StartInfo = $start
    if (-not $app.Start()) { throw 'Cannot launch isolated app' }
    Wait-Condition 'owned main window' { $app.Refresh(); if ($app.HasExited) { throw 'App exited during launch' }; $script:main = $app.MainWindowHandle; $main -ne [IntPtr]::Zero } 45000
    Assert-Owned
    $class = [Text.StringBuilder]::new(128)
    [void][BackgroundFreezeJourney]::GetClassName($main, $class, $class.Capacity)
    if ($class.ToString() -ne 'ZigShell') { throw 'Unexpected main window class' }
    Wait-Condition 'responsive owned main' {
        Assert-Owned
        $reply = [UIntPtr]::Zero
        [BackgroundFreezeJourney]::SendMessageTimeout($main, 0, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 500, [ref]$reply) -ne [IntPtr]::Zero
    } 45000
    $other = [BackgroundFreezeJourney]::StartOther()
    [void](Return-Main 'startup' $true)
    Observe 'foreground-idle' 6000 0
    Save-Shot 'foreground-idle'
    $result.foregroundIdleReports = @(Report-Files).Count
    $result.phase = 'geometry'
    [void][BackgroundFreezeJourney]::ShowWindowAsync($main, 3)
    Wait-Condition 'maximized main' { [BackgroundFreezeJourney]::IsZoomed($main) }
    Measure-Response 'maximized'
    $control = [BackgroundFreezeJourney]::Calculate($main, $false)
    $result.geometryControl = $control
    if (-not $control.Delivered) { throw 'WM_NCCALCSIZE control timed out or failed' }
    if ($control.MessageResult -ne 0 -or -not (Same-Rect $control.Work $control.Result) -or (Same-Rect $control.Proposed $control.Result)) { throw 'WM_NCCALCSIZE control did not marshal back the modified client rect' }
    $calculation = [BackgroundFreezeJourney]::Calculate($main, $true)
    $result.geometry = $calculation
    if (-not $calculation.Delivered) { throw 'WM_NCCALCSIZE timed out or failed; this is not an expected red result' }
    if (-not (Same-Rect $calculation.Work $calculation.SelectedWork) -or $calculation.OldIntersectionWidth -ne 8) { throw 'Geometry fixture requires the chosen monitor with an eight-pixel old intersection' }
    if ($calculation.MessageResult -ne 0 -or $calculation.ClientWidth -ne $calculation.ProposedWidth -or -not (Same-Rect $calculation.Proposed $calculation.Result)) { throw "WM_NCCALCSIZE clipped the proposal from $($calculation.ProposedWidth) to $($calculation.ClientWidth) pixels" }
    if (-not (Same-Rect $calculation.BeforeBounds $calculation.AfterBounds)) { throw 'Synthetic geometry changed the real window bounds' }
    Save-Shot 'maximized-geometry'
    [void](Return-Main 'geometry-restore' $true)
    Wait-Condition 'normal main' { -not [BackgroundFreezeJourney]::IsZoomed($main) }
    $normalClient = Read-Bounds
    $normalWindow = Read-Bounds $false
    $result.normalClient = $normalClient
    $result.normalWindow = $normalWindow
    $result.phase = 'background-cycles'
    $cycles = [Collections.Generic.List[object]]::new()
    for ($cycle = 1; $cycle -le 5; $cycle++) {
        Foreground $other
        Observe 'cycle-background' 500 0
        $backgroundMs = Return-Main 'background-return'
        $backgroundClient = Read-Bounds
        if (-not (Same-Rect $normalClient $backgroundClient) -or -not (Same-Rect $normalWindow (Read-Bounds $false))) { throw 'Background return changed normal bounds' }
        [void][BackgroundFreezeJourney]::ShowWindowAsync($main, 6)
        Wait-Condition 'minimized main' { [BackgroundFreezeJourney]::IsIconic($main) }
        Observe 'cycle-minimized' 500 0
        $restoreMs = Return-Main 'minimized-return' $true
        $client = Read-Bounds
        $bounds = Read-Bounds $false
        if (-not (Same-Rect $normalClient $client) -or -not (Same-Rect $normalWindow $bounds)) { throw 'Minimize/restore changed normal bounds' }
        Save-Shot "cycle-$cycle"
        $cycles.Add(@{ cycle = $cycle; backgroundReturnMs = $backgroundMs; restoreMs = $restoreMs; backgroundClient = $backgroundClient; client = $client; bounds = $bounds })
        $result.cycles = $cycles.ToArray()
    }
    Foreground $other
    Observe 'background-idle' 6000 0
    $result.backgroundIdleReports = @(Report-Files).Count
    [void](Return-Main 'idle-background-return')
    $result.phase = 'paint-cancellation'
    $cancellations = [Collections.Generic.List[object]]::new()
    foreach ($cancel in @('deactivate', 'minimize')) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        Inject-PaintSuppression
        Observe 'before-cancellation' 1000 0
        if ($cancel -eq 'deactivate') {
            if (-not [BackgroundFreezeJourney]::PostMessage($main, 0x001C, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Cannot post cancellation deactivation' }
        } else {
            [void][BackgroundFreezeJourney]::ShowWindowAsync($main, 6)
            Wait-Condition 'cancellation minimized main' { [BackgroundFreezeJourney]::IsIconic($main) }
        }
        $cancelMs = $clock.Elapsed.TotalMilliseconds
        if ($cancelMs -ge 5000) { throw 'Cancellation missed the five-second threshold' }
        Observe 'cancelled-paint-demand' 6500 0
        Recover-Paint
        Observe 'cancelled-recovery' 1000 0
        $cancellations.Add(@{ kind = $cancel; cancelMs = $cancelMs; reports = @(Report-Files).Count })
        $result.cancellations = $cancellations.ToArray()
    }
    $result.phase = 'responsive-paint-freeze'
    Save-Shot 'before-paint-suppression'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Inject-PaintSuppression
    do {
        Measure-Response 'paint-suppressed'
        if ([BackgroundFreezeJourney]::IsIconic($main) -or [BackgroundFreezeJourney]::GetProp($main, 'SysSetRedraw') -eq [IntPtr]::Zero) { throw 'Paint suppression fixture lost its precondition' }
        if (@(Report-Files).Count -gt 1) { throw 'Paint suppression produced duplicate reports' }
        Start-Sleep -Milliseconds 200
    } while ($clock.ElapsedMilliseconds -lt 8000)
    if (@(Report-Files).Count -ne 1) { throw 'Responsive paint starvation must save exactly one report' }
    Observe 'paint-report-deduplication' 2000 1
    $report = @(Report-Files)[0]
    $text = [IO.File]::ReadAllText($report.FullName)
    $reason = [regex]::Match($text, '(?m)^reason: (\d+)\r?$')
    $duration = [regex]::Match($text, '(?m)^unresponsive_ms: (\d+)\r?$')
    if (-not $reason.Success -or [int]$reason.Groups[1].Value -ne 2 -or -not $duration.Success -or [uint64]$duration.Groups[1].Value -le 5000) { throw 'Report does not identify responsive paint starvation' }
    $result.paintReport = @{ count = 1; reason = [int]$reason.Groups[1].Value; durationMs = [uint64]$duration.Groups[1].Value; observedMs = $clock.Elapsed.TotalMilliseconds; sha256 = (Get-FileHash $report.FullName -Algorithm SHA256).Hash }
    Save-Shot 'paint-suppressed'
    Recover-Paint
    Observe 'paint-recovered-foreground-idle' 6000 1
    if (-not (Same-Rect $normalClient (Read-Bounds))) { throw 'Paint recovery changed normal client bounds' }
    Save-Shot 'paint-recovered'
    $result.phase = 'complete'
    $result.status = 'passed'
} finally {
    try {
        if ($app -and -not $app.HasExited -and $main -ne [IntPtr]::Zero) {
            Assert-Owned
            Send-Checked 0x000B 1
            [void][BackgroundFreezeJourney]::InvalidateRect($main, [IntPtr]::Zero, $true)
            [void][BackgroundFreezeJourney]::RedrawWindow($main, [IntPtr]::Zero, [IntPtr]::Zero, 0x485)
            $result.redrawRestored = [BackgroundFreezeJourney]::GetProp($main, 'SysSetRedraw') -eq [IntPtr]::Zero
        }
    } finally {
        try {
            if ($app) {
                if (-not $app.HasExited) { $app.Kill($true) }
                $result.appStopped = $app.WaitForExit(5000)
                $app.Dispose()
            } else { $result.appStopped = $true }
        } finally {
            $result.helperStopped = [BackgroundFreezeJourney]::StopOther()
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
            $result.scratchRemoved = -not (Test-Path -LiteralPath $scratch)
            if (-not $result.appStopped -or -not $result.helperStopped -or -not $result.scratchRemoved -or -not $result.redrawRestored) { $result.status = 'failed' }
            $result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $Evidence 'result.json')
        }
    }
}
if ($result.status -ne 'passed') { throw 'Background freeze cleanup failed' }
Write-Host 'BACKGROUND_FREEZE_JOURNEY_OK'
