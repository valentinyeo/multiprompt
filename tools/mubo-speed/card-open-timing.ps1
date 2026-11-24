param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [Parameter(Mandatory=$true)][string]$Tag,
    [int]$Samples = 7,
    [int]$HoverDelayMs = 20
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Card timing runs only on GitHub Windows' }
$exePath = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$evidencePath = (Resolve-Path $Evidence).Path
$root = Join-Path $env:RUNNER_TEMP ('card-timing-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $root 'roaming'
$env:LOCALAPPDATA = Join-Path $root 'local'
$env:USERPROFILE = Join-Path $root 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '1'
New-Item -ItemType Directory -Force $root, $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
Add-Type -Path tools/verify-chat-delivery/job.cs
Add-Type -Path tools/verify-chat-delivery/desktop.cs
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public sealed class CardSpeedSample {
    public double RawMs;
    public double BlockedMs;
    public bool Painted;
    public bool TimedOut;
}

public sealed class CardSpeedReport {
    public CardSpeedSample[] Samples;
    public int Painted;
    public double P50;
    public double Max;
    public double OpenP50;
    public double OpenMax;
    public int Errors;
    public int PanelPixels;
    public double SmoothMaxMs;
    public string CardTitle;
    public int CardWidth;
    public int CardHeight;
    public int HoverDelayMs;
}

public static class CardSpeed {
    [StructLayout(LayoutKind.Sequential)] struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] struct Union { [FieldOffset(0)] public Mouse Mouse; [FieldOffset(0)] public Keyboard Keyboard; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint Type; public Union Data; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    public delegate bool EnumProc(IntPtr window, IntPtr parameter);

    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr window);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr window, IntPtr dc);
    [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc, int x, int y);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW", SetLastError=true)] static extern IntPtr SendPing(IntPtr window, uint message, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)] static extern bool SpiGet(uint action, uint param, ref uint value, uint flags);
    [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)] static extern bool SpiSet(uint action, uint param, IntPtr value, uint flags);

    static string ClassOf(IntPtr window) {
        StringBuilder text = new StringBuilder(256);
        GetClassName(window, text, text.Capacity);
        return text.ToString();
    }

    public static string Title(IntPtr window) {
        StringBuilder text = new StringBuilder(256);
        GetWindowTextW(window, text, text.Capacity);
        return text.ToString();
    }

    public static IntPtr Main(uint pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((window, parameter) => {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner == pid && IsWindowVisible(window) && ClassOf(window) == "ZigShell") { found = window; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static IntPtr Find(IntPtr main, string cardClass) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(main, (window, parameter) => {
            if (ClassOf(window) == cardClass) { found = window; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static int[] Client(IntPtr window) {
        Rect rect;
        if (!GetClientRect(window, out rect)) throw new InvalidOperationException("client rectangle unavailable");
        return new[] { rect.Right, rect.Bottom };
    }

    public static int[] ScreenPoint(IntPtr window, int x, int y) {
        Point point = new Point { X = x, Y = y };
        if (!ClientToScreen(window, ref point)) throw new InvalidOperationException("ClientToScreen failed");
        return new[] { point.X, point.Y };
    }

    public static string HitClass(int x, int y) {
        IntPtr hit = WindowFromPoint(new Point { X = x, Y = y });
        return hit == IntPtr.Zero ? "" : ClassOf(hit);
    }

    public static uint Dpi(IntPtr window) { return GetDpiForWindow(window); }

    public static uint HoverDelay() {
        uint value = 0;
        if (!SpiGet(0x0066, 0, ref value, 0)) throw new InvalidOperationException("SPI_GETMOUSEHOVERTIME failed");
        return value;
    }

    public static void SetHoverDelay(uint milliseconds) {
        if (!SpiSet(0x0067, milliseconds, IntPtr.Zero, 3)) throw new InvalidOperationException("SPI_SETMOUSEHOVERTIME failed");
    }

    public static void MoveTo(int x, int y) {
        SetCursorPos(x, y);
        Input[] inputs = new Input[1];
        inputs[0].Data.Mouse = new Mouse { X = (int)Math.Round(x * 65535.0 / (GetSystemMetrics(0) - 1)), Y = (int)Math.Round(y * 65535.0 / (GetSystemMetrics(1) - 1)), Flags = 0x8001 };
        if (SendInput(1, inputs, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("pointer move failed");
    }

    static bool Ping(IntPtr main, uint timeout) {
        IntPtr result;
        return SendPing(main, 0, IntPtr.Zero, IntPtr.Zero, 2, timeout, out result) != IntPtr.Zero;
    }

    static int PanelScan(IntPtr card, int[] panel) {
        Rect rect;
        if (!GetWindowRect(card, out rect)) throw new InvalidOperationException("card bounds unavailable");
        IntPtr dc = GetDC(IntPtr.Zero);
        if (dc == IntPtr.Zero) throw new InvalidOperationException("screen DC unavailable");
        try {
            int hits = 0;
            int step = Math.Max(3, (rect.Right - rect.Left) / 40);
            for (int y = rect.Top + 4; y < rect.Bottom - 4; y += step) {
                for (int x = rect.Left + 4; x < rect.Right - 4; x += step) {
                    uint pixel = GetPixel(dc, x, y);
                    if (pixel == 0xFFFFFFFF) continue;
                    int red = (int)(pixel & 0xFF), green = (int)((pixel >> 8) & 0xFF), blue = (int)((pixel >> 16) & 0xFF);
                    if (Math.Abs(red - panel[0]) <= 2 && Math.Abs(green - panel[1]) <= 2 && Math.Abs(blue - panel[2]) <= 2) hits++;
                }
            }
            return hits;
        } finally { ReleaseDC(IntPtr.Zero, dc); }
    }

    public static CardSpeedReport Measure(IntPtr main, string cardClass, int iconX, int iconY, int awayX, int awayY, int samples, int hoverDelayMs, int[] panel) {
        CardSpeedReport report = new CardSpeedReport();
        report.HoverDelayMs = hoverDelayMs;
        report.Samples = new CardSpeedSample[Math.Max(1, samples)];
        double[] raw = new double[report.Samples.Length];
        IntPtr card = Find(main, cardClass);
        for (int i = 0; i < report.Samples.Length; i++) {
            CardSpeedSample sample = new CardSpeedSample();
            report.Samples[i] = sample;
            MoveTo(awayX, awayY);
            Stopwatch hide = Stopwatch.StartNew();
            while (card != IntPtr.Zero && IsWindowVisible(card) && hide.Elapsed.TotalMilliseconds < 4000) System.Threading.Thread.Sleep(2);
            if (card == IntPtr.Zero) card = Find(main, cardClass);
            Stopwatch clock = Stopwatch.StartNew();
            MoveTo(iconX, iconY);
            double blocked = 0.0, since = 0.0, lastPing = -10.0;
            bool blockedNow = false;
            for (;;) {
                double now = clock.Elapsed.TotalMilliseconds;
                if (now - lastPing >= 2.0) {
                    lastPing = now;
                    if (!Ping(main, 0)) { if (!blockedNow) { blockedNow = true; since = now; } }
                    else if (blockedNow) { blocked += now - since; blockedNow = false; }
                }
                if (card == IntPtr.Zero) card = Find(main, cardClass);
                if (card != IntPtr.Zero && IsWindowVisible(card)) { sample.RawMs = clock.Elapsed.TotalMilliseconds; sample.Painted = true; break; }
                if (now > 5000.0) { sample.RawMs = clock.Elapsed.TotalMilliseconds; sample.TimedOut = true; break; }
            }
            if (blockedNow) blocked += clock.Elapsed.TotalMilliseconds - since;
            sample.BlockedMs = blocked;
            if (sample.Painted) { raw[report.Painted] = sample.RawMs; report.Painted++; } else report.Errors++;
            System.Threading.Thread.Sleep(150);
        }
        if (card != IntPtr.Zero) {
            report.CardTitle = Title(card);
            Rect rect;
            if (GetWindowRect(card, out rect)) { report.CardWidth = rect.Right - rect.Left; report.CardHeight = rect.Bottom - rect.Top; }
            if (IsWindowVisible(card)) report.PanelPixels = PanelScan(card, panel);
        }
        if (report.Painted > 0) {
            double[] ordered = new double[report.Painted];
            Array.Copy(raw, ordered, report.Painted);
            Array.Sort(ordered);
            report.P50 = ordered[(report.Painted - 1) / 2];
            report.Max = ordered[report.Painted - 1];
            for (int i = 0; i < report.Painted; i++) {
                ordered[i] = raw[i] - hoverDelayMs;
                if (ordered[i] < 0.0) ordered[i] = 0.0;
            }
            Array.Sort(ordered);
            report.OpenP50 = ordered[(report.Painted - 1) / 2];
            report.OpenMax = ordered[report.Painted - 1];
        }
        for (int i = 0; i < 60; i++) {
            if (card == IntPtr.Zero || !IsWindowVisible(card)) { MoveTo(awayX, awayY); MoveTo(iconX, iconY); System.Threading.Thread.Sleep(250); }
            Stopwatch trip = Stopwatch.StartNew();
            bool answered = Ping(main, 250);
            double elapsed = trip.Elapsed.TotalMilliseconds;
            if (!answered) elapsed = 250.0;
            if (elapsed > report.SmoothMaxMs) report.SmoothMaxMs = elapsed;
        }
        return report;
    }
}
'@
$geometry = & node (Join-Path (Get-Location) 'tools/usage-icon-geometry.js') | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $geometry) { throw 'Usage icon geometry unavailable from the app source' }
$usageRoot = Join-Path $env:APPDATA 'ZigShell'
New-Item -ItemType Directory -Force $usageRoot | Out-Null
Copy-Item (Join-Path (Get-Location) 'tools/fixtures/IGSH-908/usage-telemetry.json') (Join-Path $usageRoot 'usage-telemetry.json')
$usageCollector = [Threading.Mutex]::new($false, 'Local\MultipromptUsageTelemetry')
$cardClass = 'MultiPromptUsageCard'
$eventName = 'Local\MultipromptCardTiming-' + [guid]::NewGuid().ToString('N')
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $eventName)
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120, [int]$PollMs = 100) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $process -and $process.HasExited) { throw "App exited during $Name" }
        $value = & $Check
        if ($value) { return $value }
        Start-Sleep -Milliseconds $PollMs
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
$job = [VerifyJob]::new()
$process = $null
$result = [ordered]@{
    probe = 'usage-card-open'
    tag = $Tag
    status = 'failed'
    samples = @()
    painted = $null
    errors = $null
    openedP50Ms = $null
    openedMaxMs = $null
    rawP50Ms = $null
    rawMaxMs = $null
    blockedMaxMs = $null
    smoothMaxMs = $null
    panelPixels = $null
    cardTitle = $null
    cardWidth = $null
    cardHeight = $null
    hoverDelayMs = $HoverDelayMs
    scale = $null
    clientWidth = $null
    clientHeight = $null
    sha256 = $null
    exeVersion = $null
    error = $null
}
try {
    $result.sha256 = (Get-FileHash $exePath -Algorithm SHA256).Hash
    $bytes = [IO.File]::ReadAllBytes($exePath)
    $result.exeVersion = [regex]::Match([Text.Encoding]::ASCII.GetString($bytes), 'MPVERSION=([0-9][0-9.]*);').Groups[1].Value
    $bytes = $null
    if (-not $result.exeVersion) { throw 'Executable version marker missing' }
    $process = $job.Start($exePath, $root, "$evidencePath/stdout.log", "$evidencePath/stderr.log", "--single-window --no-window-restore --update-ready $eventName")
    if (-not $ready.WaitOne(45000)) { throw 'Released app did not become ready' }
    $main = [IntPtr]::Zero
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        if ($process.HasExited) { throw "Released app exited with $($process.ExitCode)" }
        $main = [CardSpeed]::Main([uint32]$process.Id)
        if ($main -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($main -eq [IntPtr]::Zero) { throw 'Released app did not show its main window' }
    Start-Sleep -Seconds 3
    [void](Wait-For 'app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$process.Id, $main) } 30 200)
    Start-Sleep -Milliseconds 300
    $client = [CardSpeed]::Client($main)
    $result.clientWidth = $client[0]
    $result.clientHeight = $client[1]
    if ($client[0] -le 0 -or $client[1] -le 0) { throw 'Main window has no client area' }
    $scale = [double]([CardSpeed]::Dpi($main)) / 96.0
    $result.scale = $scale
    $iconX = [int][Math]::Round($geometry.icon.centerX * $scale)
    $iconY = $client[1] - [int][Math]::Round($geometry.icon.centerYInset * $scale)
    $icon = [CardSpeed]::ScreenPoint($main, $iconX, $iconY)
    $away = [CardSpeed]::ScreenPoint($main, [int]($client[0] / 2), [int]($client[1] / 2))
    $hit = [CardSpeed]::HitClass($icon[0], $icon[1])
    Write-Host "icon screen $($icon[0]),$($icon[1]) hit class '$hit'"
    if ($hit -ne 'ZigShell') { throw "Usage icon is not under the pointer, hit class '$hit'" }
    $previous = [CardSpeed]::HoverDelay()
    [CardSpeed]::SetHoverDelay([uint32]$HoverDelayMs)
    $report = [CardSpeed]::Measure($main, $cardClass, $icon[0], $icon[1], $away[0], $away[1], $Samples, $HoverDelayMs, [int[]]$geometry.card.panel)
    [CardSpeed]::SetHoverDelay($previous)
    $rows = @()
    $blocked = 0.0
    foreach ($sample in $report.Samples) {
        $rows += [ordered]@{ rawMs = [Math]::Round($sample.RawMs, 2); painted = $sample.Painted; timedOut = $sample.TimedOut; blockedMs = [Math]::Round($sample.BlockedMs, 2) }
        if ($sample.BlockedMs -gt $blocked) { $blocked = $sample.BlockedMs }
    }
    $result.samples = $rows
    $result.painted = $report.Painted
    $result.errors = $report.Errors
    $result.openedP50Ms = [Math]::Round($report.OpenP50, 2)
    $result.openedMaxMs = [Math]::Round($report.OpenMax, 2)
    $result.rawP50Ms = [Math]::Round($report.P50, 2)
    $result.rawMaxMs = [Math]::Round($report.Max, 2)
    $result.blockedMaxMs = [Math]::Round($blocked, 2)
    $result.smoothMaxMs = [Math]::Round($report.SmoothMaxMs, 2)
    $result.panelPixels = $report.PanelPixels
    $result.cardTitle = $report.CardTitle
    $result.cardWidth = $report.CardWidth
    $result.cardHeight = $report.CardHeight
    $result.status = if ($report.Errors -eq 0 -and $report.Painted -ge 5) { 'measured' } else { 'failed' }
} catch {
    $result.error = $_.Exception.Message
    Write-Host $_.ScriptStackTrace
} finally {
    if ($null -ne $job) { try { [void]$job.Stop() } catch { Write-Host "job stop failed: $($_.Exception.Message)" }; $job.Dispose() }
    $ready.Dispose()
    $usageCollector.Dispose()
    if ($null -ne $process) { $process.Dispose() }
    $result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$evidencePath/open-timings.json"
}
exit ($(if ($result.status -eq 'measured') { 0 } else { 1 }))
