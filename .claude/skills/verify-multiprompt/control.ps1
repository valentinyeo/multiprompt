param(
    [Parameter(Mandatory=$true)][ValidateSet('appearance', 'sessions', 'session-restore', 'workspaces', 'workspace-focus', 'inbox', 'command-palette', 'session-open', 'favorites-groups', 'browser-switch-speed', 'browser-pane-stuck', 'browser-pane-locked', 'group-rail', 'pane-layout', 'chat-tables', 'chat-code-font', 'safe-updates', 'chat-view', 'chat-view-everywhere', 'chat-focus', 'chat-delivery', 'browser-emulation', 'status-card', 'palette-order', 'browser-own-profile', 'remind-me')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
switch ($Feature) {
        'chat-delivery' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Chat delivery verification failed' }
            return
        }
        'safe-updates' {
            if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before update journey' }
            if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch before update journey' }
            & "$PSScriptRoot/../../../tools/update-release-journey.ps1" -Exe $Exe -Evidence $Evidence
            return
        }
}

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, WindowsBase, System.Drawing
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class VerifyNative {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo { public uint Size; public Rect Monitor, Work; public uint Flags; }
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr Hwnd; public uint Id; public UIntPtr WParam; public IntPtr LParam; public uint Time; public Point Position; public uint Private; }
    [StructLayout(LayoutKind.Sequential)] public struct GuiThreadInfo { public uint Size, Flags; public IntPtr Active, Focus, Capture, MenuOwner, MoveSize, Caret; public Rect CaretRect; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Keyboard keyboard; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Union data; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool PeekMessage(out Message message, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll", SetLastError=true)] static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetFocus(IntPtr hwnd);
    public static void BringToForeground(IntPtr hwnd) {
        uint pid;
        uint foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint currentThread = GetCurrentThreadId();
        uint targetPid;
        uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
        bool attached = foregroundThread != 0 && foregroundThread != currentThread && AttachThreadInput(currentThread, foregroundThread, true);
        bool attachedTarget = targetThread != 0 && targetThread != currentThread && targetThread != foregroundThread && AttachThreadInput(currentThread, targetThread, true);
        Key(0x12, 0, 0);
        try {
            AllowSetForegroundWindow(targetPid);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
        } finally {
            Key(0x12, 0, 2);
            if (attachedTarget) AttachThreadInput(currentThread, targetThread, false);
            if (attached) AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfoW(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr count, StringBuilder text, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr count, IntPtr text, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern short VkKeyScan(char character);
    [DllImport("dwmapi.dll")] public static extern int DwmFlush();
    static void Key(ushort key, ushort scan, uint flags) {
        Input input = new Input(); input.type = 1;
        input.data.keyboard = new Keyboard { key = key, scan = scan, flags = flags };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("SendInput failed");
    }
    public static void Chord(int[] keys) {
        Input[] inputs = new Input[keys.Length * 2];
        for (int i = 0; i < keys.Length; i++) {
            inputs[i].type = 1;
            inputs[i].data.keyboard = new Keyboard { key = (ushort)keys[i] };
            inputs[keys.Length + i].type = 1;
            inputs[keys.Length + i].data.keyboard = new Keyboard { key = (ushort)keys[keys.Length - i - 1], flags = 2 };
        }
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("SendInput chord failed");
        Thread.Sleep(250);
    }
    public static void Text(string text) {
        foreach (char c in text) {
            short mapping = VkKeyScan(c);
            if (mapping == -1 || (mapping & 0x600) != 0) throw new InvalidOperationException("Character requires an unsupported keyboard layout: " + c);
            bool shift = (mapping & 0x100) != 0;
            if (shift) { Key(0x10, 0, 0); Thread.Sleep(35); }
            ushort key = (ushort)(mapping & 0xff);
            Key(key, 0, 0); Thread.Sleep(35); Key(key, 0, 2);
            if (shift) Key(0x10, 0, 2);
            Thread.Sleep(30);
        }
        Thread.Sleep(250);
    }
    public static void OpenAndCloseBrowserPane() {
        var inputs = new List<Input>();
        Action<ushort, uint> key = (code, flags) => {
            Input input = new Input(); input.type = 1;
            input.data.keyboard = new Keyboard { key = code, flags = flags };
            inputs.Add(input);
        };
        foreach (string query in new string[] { "open browser", "close browser pane" }) {
            key(0x11, 0); key(0x4B, 0); key(0x4B, 2); key(0x11, 2);
            foreach (char c in query) {
                short mapping = VkKeyScan(c);
                if (mapping == -1 || (mapping & 0x700) != 0) throw new InvalidOperationException("Batch query requires an unshifted keyboard mapping: " + c);
                key((ushort)(mapping & 0xff), 0); key((ushort)(mapping & 0xff), 2);
            }
            key(0x0D, 0); key(0x0D, 2);
        }
        Input[] batch = inputs.ToArray();
        if (SendInput((uint)batch.Length, batch, Marshal.SizeOf(typeof(Input))) != (uint)batch.Length) throw new InvalidOperationException("SendInput batch failed");
    }
    delegate bool EnumWindow(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindow callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr hwnd, string name);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    public static Dictionary<string, object> WindowIdentity(IntPtr hwnd) {
        uint ownerPid;
        uint ownerThread = GetWindowThreadProcessId(hwnd, out ownerPid);
        return new Dictionary<string, object> {
            { "handle", hwnd.ToInt64() }, { "pid", ownerPid }, { "thread", ownerThread },
            { "class", Class(hwnd) }, { "title", Title(hwnd) },
            { "root", GetAncestor(hwnd, 2).ToInt64() },
            { "rootOwner", GetAncestor(hwnd, 3).ToInt64() },
            { "visible", IsWindowVisible(hwnd) }
        };
    }
    public static List<Dictionary<string, object>> DesktopWindows() {
        var windows = new List<Dictionary<string, object>>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            windows.Add(WindowIdentity(hwnd));
            return true;
        }, IntPtr.Zero);
        return windows;
    }
    public static bool PaneVisible(IntPtr owner) {
        Rect frame;
        if (!GetWindowRect(owner, out frame)) return false;
        bool visible = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            if (GetProp(hwnd, "ZigShellPaneOwner") != owner || !IsWindowVisible(hwnd)) return true;
            Rect pane;
            if (GetWindowRect(hwnd, out pane) && pane.Right > pane.Left && pane.Bottom > pane.Top &&
                pane.Left < frame.Right && pane.Right > frame.Left && pane.Top < frame.Bottom && pane.Bottom > frame.Top) visible = true;
            return true;
        }, IntPtr.Zero);
        return visible;
    }
    public static IntPtr PaneWindow(IntPtr owner) {
        IntPtr pane = IntPtr.Zero;
        int count = 0;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            if (GetProp(hwnd, "ZigShellPaneOwner") == owner && IsWindowVisible(hwnd)) { pane = hwnd; count++; }
            return true;
        }, IntPtr.Zero);
        if (count > 1) throw new InvalidOperationException("Multiple visible owned browser panes");
        return pane;
    }
    public static IntPtr DockedPaneWindow(IntPtr owner) {
        Rect frame;
        if (!GetWindowRect(owner, out frame)) throw new InvalidOperationException("Missing owned frame rectangle");
        IntPtr pane = IntPtr.Zero;
        int count = 0;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            Rect rect;
            if (GetProp(hwnd, "ZigShellPaneOwner") != owner || !IsWindowVisible(hwnd) || !GetWindowRect(hwnd, out rect)) return true;
            if (rect.Right <= rect.Left || rect.Bottom <= rect.Top || rect.Left >= frame.Right || rect.Right <= frame.Left || rect.Top >= frame.Bottom || rect.Bottom <= frame.Top) return true;
            pane = hwnd;
            count++;
            return true;
        }, IntPtr.Zero);
        if (count > 1) throw new InvalidOperationException("Multiple onscreen owned browser panes");
        return pane;
    }
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll", SetLastError=true)] static extern bool BitBlt(IntPtr target, int x, int y, int width, int height, IntPtr source, int sourceX, int sourceY, int operation);
    public static int[] ReadSwitchScreenPatch(Rect dock, bool layered) {
        using (var pixels = new System.Drawing.Bitmap(3, 3))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            IntPtr screen = GetDC(IntPtr.Zero);
            IntPtr target = graphics.GetHdc();
            try {
                int x = dock.Left + (dock.Right - dock.Left) / 2;
                int y = dock.Top + (dock.Bottom - dock.Top) * 3 / 4;
                if (!BitBlt(target, 0, 0, 3, 3, screen, x, y, 0x00CC0020 | (layered ? 0x40000000 : 0))) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            } finally { graphics.ReleaseHdc(target); ReleaseDC(IntPtr.Zero, screen); }
            var colors = new int[9];
            for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) colors[row * 3 + col] = pixels.GetPixel(col, row).ToArgb() & 0xFFFFFF;
            return colors;
        }
    }
    public static System.Diagnostics.Stopwatch BeginSessionSwitch() {
        Input[] inputs = new Input[4];
        for (int i = 0; i < inputs.Length; i++) inputs[i].type = 1;
        inputs[0].data.keyboard = new Keyboard { key = 0x11 };
        inputs[1].data.keyboard = new Keyboard { key = 0x09 };
        inputs[2].data.keyboard = new Keyboard { key = 0x09, flags = 2 };
        inputs[3].data.keyboard = new Keyboard { key = 0x11, flags = 2 };
        var timer = System.Diagnostics.Stopwatch.StartNew();
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("SendInput Ctrl+Tab failed");
        return timer;
    }
    public static bool SwitchReady(IntPtr owner, IntPtr console, string suffix, IntPtr browser, Rect dock, IntPtr composer, string draft) {
        if (composer != IntPtr.Zero) {
            if (GetForegroundWindow() != owner || GetAncestor(composer, 2) != owner || !IsWindowVisible(composer) ||
                GetFocusedWindow(owner) != composer || EditText(composer) != draft) return false;
        } else if (GetForegroundWindow() != console || GetAncestor(console, 2) != owner || !IsWindowVisible(console) ||
            Class(console) != "ConsoleWindowClass" || !Title(console).EndsWith(suffix, StringComparison.Ordinal)) return false;
        if (browser != IntPtr.Zero) {
            Rect actual;
            if (GetProp(browser, "ZigShellPaneOwner") != owner || !IsWindowVisible(browser) || !GetWindowRect(browser, out actual) ||
                actual.Left != dock.Left || actual.Top != dock.Top || actual.Right != dock.Right || actual.Bottom != dock.Bottom) return false;
        } else if (PaneVisible(owner)) return false;
        return true;
    }
    public static void RequireSwitchStart(IntPtr owner, IntPtr composer, IntPtr sourceConsole, string sourceSuffix, IntPtr sourceBrowser, Rect sourceDock, string sourceDraft, IntPtr targetConsole, string targetSuffix, IntPtr targetBrowser, Rect targetDock, string targetDraft) {
        if (sourceConsole == targetConsole || (sourceBrowser == targetBrowser && sourceBrowser != IntPtr.Zero) || sourceSuffix == targetSuffix || sourceDraft == targetDraft) throw new InvalidOperationException("Source and target sessions are not distinct");
        if (!SwitchReady(owner, sourceConsole, sourceSuffix, sourceBrowser, sourceDock, composer, sourceDraft)) throw new InvalidOperationException("Source session is not the visible foreground session before Ctrl+Tab");
        if (SwitchReady(owner, targetConsole, targetSuffix, targetBrowser, targetDock, composer, targetDraft)) throw new InvalidOperationException("Target session is already visible before Ctrl+Tab; this sample would not be a switch");
    }
    static bool PaintMatches(Rect dock, int rgb, System.Drawing.Bitmap pixels, System.Drawing.Graphics graphics) {
        if (dock.Right - dock.Left < 16 || dock.Bottom - dock.Top < 200) throw new InvalidOperationException("Browser content area is too small");
        int x = dock.Left + (dock.Right - dock.Left) / 2;
        int y = dock.Top + (dock.Bottom - dock.Top) * 3 / 4;
        graphics.CopyFromScreen(x, y, 0, 0, pixels.Size);
        for (int row = 0; row < pixels.Height; row++) {
            for (int col = 0; col < pixels.Width; col++) {
                var pixel = pixels.GetPixel(col, row);
                if (Math.Abs(pixel.R - ((rgb >> 16) & 255)) > 8 || Math.Abs(pixel.G - ((rgb >> 8) & 255)) > 8 || Math.Abs(pixel.B - (rgb & 255)) > 8) return false;
            }
        }
        return true;
    }
    public static bool PagePainted(Rect dock, int rgb) {
        using (var pixels = new System.Drawing.Bitmap(3, 3))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) return PaintMatches(dock, rgb, pixels, graphics);
    }
    public static double[] MeasureSessionSwitch(IntPtr owner, IntPtr console, string suffix, IntPtr browser, Rect dock, IntPtr composer, string draft, int rgb, string frozenMarker) {
        using (var pixels = new System.Drawing.Bitmap(3, 3))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            double visible = -1;
            double painted = -1;
            double awake = -1;
            bool frozen = !String.IsNullOrEmpty(frozenMarker);
            if (frozen && (!System.IO.File.Exists(frozenMarker) || System.IO.File.ReadAllText(frozenMarker).Trim() != "1")) throw new InvalidOperationException("Target freeze marker missing before input");
            var timer = BeginSessionSwitch();
            do {
                if (frozen && awake < 0 && !System.IO.File.Exists(frozenMarker)) awake = timer.Elapsed.TotalMilliseconds;
                if (SwitchReady(owner, console, suffix, browser, dock, composer, draft)) {
                    if (visible < 0) visible = timer.Elapsed.TotalMilliseconds;
                    if (painted < 0 && (browser == IntPtr.Zero || PaintMatches(dock, rgb, pixels, graphics))) painted = timer.Elapsed.TotalMilliseconds;
                    if (painted >= 0 && (!frozen || awake >= 0)) {
                        timer.Stop();
                        return new double[] { painted, visible, awake };
                    }
                }
                Thread.Sleep(1);
            } while (timer.ElapsedMilliseconds < 20000);
            throw new TimeoutException("Target session surface and browser paint did not become ready within 20 seconds; visible=" + visible + "; painted=" + painted + "; awake=" + awake + "; foreground=" + GetForegroundWindow());
        }
    }
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    static void MouseAt(int x, int y, uint flags) {
        int left = GetSystemMetrics(76), top = GetSystemMetrics(77);
        int width = GetSystemMetrics(78), height = GetSystemMetrics(79);
        if (width <= 1 || height <= 1 || x < left || x >= left + width || y < top || y >= top + height) throw new InvalidOperationException("Mouse target outside the desktop");
        Input input = new Input(); input.type = 0;
        input.data.mouse = new Mouse { x = (int)Math.Round((x - left) * 65535.0 / (width - 1)), y = (int)Math.Round((y - top) * 65535.0 / (height - 1)), flags = flags | 0xC001 };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Browser strip SendInput failed");
    }
    static void RequireBrowserStrip(IntPtr pane, IntPtr owner, Point point) {
        if (GetProp(pane, "ZigShellPaneOwner") != owner || GetAncestor(pane, 3) != owner ||
            GetForegroundWindow() != pane || GetAncestor(WindowFromPoint(point), 2) != pane) throw new InvalidOperationException("Refusing mouse input outside the focused owned browser strip");
    }
    public static void DragBrowserStrip(IntPtr pane, IntPtr owner, Point point) {
        RequireBrowserStrip(pane, owner, point);
        MouseAt(point.X, point.Y, 0);
        MouseAt(point.X, point.Y, 2);
        try {
            for (int step = 1; step <= 20; step++) {
                MouseAt(point.X - 300 * step / 20, point.Y + 200 * step / 20, 0);
                Thread.Sleep(20);
            }
        } finally { MouseAt(point.X - 300, point.Y + 200, 4); }
    }
    public static void DoubleClickBrowserStrip(IntPtr pane, IntPtr owner, Point point) {
        RequireBrowserStrip(pane, owner, point);
        MouseAt(point.X, point.Y, 0);
        foreach (uint flags in new uint[] { 2, 4, 2, 4 }) MouseAt(point.X, point.Y, flags);
    }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out Point point);
    public static void MoveMouseClient(IntPtr hwnd, int x, int y, bool requireOwned) {
        Point target = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref target)) throw new InvalidOperationException("Cannot map mouse target");
        if (requireOwned && WindowFromPoint(target) != hwnd) throw new InvalidOperationException("Mouse target is not in the owned window");
        Point start;
        if (!GetCursorPos(out start)) start = target;
        for (int step = 1; step <= 12; step++) {
            MouseAt(start.X + (target.X - start.X) * step / 12, start.Y + (target.Y - start.Y) * step / 12, 0);
            Thread.Sleep(15);
        }
    }
    public static void ClickClient(IntPtr hwnd, int x, int y) {
        Point point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Pill is not in the owned window");
        if (!SetCursorPos(point.X, point.Y)) throw new InvalidOperationException("Cannot position mouse on pill");
        foreach (uint flags in new uint[] { 2, 4 }) {
            Input input = new Input(); input.type = 0;
            input.data.mouse = new Mouse { flags = flags };
            if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Mouse SendInput failed");
            Thread.Sleep(35);
        }
    }
    public static void RightClickTranscript(IntPtr hwnd, uint pid, IntPtr owner, Point point) {
        uint actualPid;
        GetWindowThreadProcessId(hwnd, out actualPid);
        if (actualPid != pid || Class(hwnd) != "ZigShellChatTranscript" || GetAncestor(hwnd, 2) != owner ||
            GetForegroundWindow() != owner || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Message bubble is not in the foreground owned transcript");
        MouseAt(point.X, point.Y, 0);
        MouseAt(point.X, point.Y, 8);
        MouseAt(point.X, point.Y, 16);
    }
    public static Point MessageBubblePoint(IntPtr hwnd) {
        Rect rect;
        if (!GetWindowRect(hwnd, out rect)) throw new InvalidOperationException("Transcript rectangle unavailable");
        using (var pixels = new System.Drawing.Bitmap(rect.Right - rect.Left, rect.Bottom - rect.Top))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, pixels.Size);
            var bg = pixels.GetPixel(0, pixels.Height / 2);
            int shift = (2126 * bg.R + 7152 * bg.G + 722 * bg.B) / 10000 < 128 ? 53 : -26;
            var fill = System.Drawing.Color.FromArgb(Math.Max(0, Math.Min(255, bg.R + shift)), Math.Max(0, Math.Min(255, bg.G + shift)), Math.Max(0, Math.Min(255, bg.B + shift)));
            for (int y = pixels.Height - 2; y > 0; y--) {
                for (int x = pixels.Width - 2; x > 0; x--) {
                    if (pixels.GetPixel(x, y).ToArgb() == fill.ToArgb() && pixels.GetPixel(x - 1, y).ToArgb() == fill.ToArgb() &&
                        pixels.GetPixel(x, y - 1).ToArgb() == fill.ToArgb()) return new Point { X = rect.Left + x - 1, Y = rect.Top + y - 1 };
                }
            }
        }
        throw new InvalidOperationException("No painted user message bubble in transcript");
    }
    public static List<int[]> GreyButtonPixels(string image, IntPtr owner, int[] card, int[] stop, int[] send) {
        Rect frame;
        Point origin = new Point();
        if (!GetWindowRect(owner, out frame) || !ClientToScreen(owner, ref origin)) throw new InvalidOperationException("Composer screen origin unavailable");
        using (var pixels = new System.Drawing.Bitmap(image)) {
            int dx = origin.X - frame.Left, dy = origin.Y - frame.Top;
            var bg = pixels.GetPixel(dx + (card[0] + card[2]) / 2, dy + card[1] + (card[3] - card[1]) / 4);
            var samples = new List<int[]>();
            foreach (int[] rect in new int[][] { stop, send }) {
                if (rect == null) continue;
                int x = rect[0] + (rect[2] - rect[0]) / 4;
                int y = rect[1] + (rect[3] - rect[1]) / 4;
                Point screen = new Point { X = origin.X + x, Y = origin.Y + y };
                if (WindowFromPoint(screen) != owner) throw new InvalidOperationException("Button sample is not in the owned composer");
                var c = pixels.GetPixel(dx + x, dy + y);
                samples.Add(new int[] { x, y, c.R, c.G, c.B });
                if (Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)) > 12 || c.ToArgb() == bg.ToArgb())
                    throw new InvalidOperationException("Send or Stop background is not neutral grey distinct from composer: " + c);
            }
            return samples;
        }
    }
    public static void FocusOwnedWindow(IntPtr hwnd, uint pid, IntPtr owner) {
        uint actualPid;
        uint targetThread = GetWindowThreadProcessId(hwnd, out actualPid);
        if (hwnd == IntPtr.Zero || owner == IntPtr.Zero || pid == 0 || targetThread == 0 || actualPid != pid ||
            GetProp(hwnd, "ZigShellPaneOwner") != owner || GetAncestor(hwnd, 3) != owner) throw new InvalidOperationException("Browser focus ownership mismatch");
        Message message;
        PeekMessage(out message, IntPtr.Zero, 0, 0, 0);
        uint currentThread = GetCurrentThreadId();
        uint foregroundPid;
        uint foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), out foregroundPid);
        bool attachedForeground = false, attachedTarget = false;
        Key(0x12, 0, 0);
        try {
            if (foregroundThread != 0 && foregroundThread != currentThread) {
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            }
            if (targetThread != currentThread && targetThread != foregroundThread) {
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            }
            AllowSetForegroundWindow(pid);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
            SetFocus(hwnd);
        } finally {
            if (attachedTarget) AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground) AttachThreadInput(currentThread, foregroundThread, false);
            Key(0x12, 0, 2);
        }
        if (GetForegroundWindow() != hwnd || GetFocusedWindow(hwnd) == IntPtr.Zero) throw new InvalidOperationException("Owned browser did not receive foreground keyboard focus");
    }
    public static IntPtr GetFocusedWindow(IntPtr hwnd) {
        uint pid;
        uint thread = GetWindowThreadProcessId(hwnd, out pid);
        if (thread == 0) throw new InvalidOperationException("Cannot find the owned window thread");
        GuiThreadInfo info = new GuiThreadInfo();
        info.Size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo));
        if (!GetGUIThreadInfo(thread, ref info)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return info.Focus;
    }
    public static string EditText(IntPtr hwnd) {
        if (Class(hwnd) != "Edit") throw new InvalidOperationException("Expected the owned Edit control");
        UIntPtr length;
        if (SendMessageTimeout(hwnd, 0x000E, UIntPtr.Zero, IntPtr.Zero, 2, 1000, out length) == IntPtr.Zero) throw new InvalidOperationException("Cannot read Edit text length within timeout");
        StringBuilder text = new StringBuilder(checked((int)length.ToUInt64() + 2));
        if (SendMessageTimeout(hwnd, 0x000D, new UIntPtr((uint)text.Capacity), text, 2, 1000, out length) == IntPtr.Zero) throw new InvalidOperationException("Cannot read Edit text within timeout");
        if (length.ToUInt64() >= (ulong)(text.Capacity - 1)) throw new InvalidOperationException("Edit text may be truncated");
        return text.ToString();
    }
    public static string Title(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(512); GetWindowText(hwnd, text, text.Capacity); return text.ToString();
    }
    public static string Class(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString();
    }
}
public static class GroupRailProof {
    static int S(int value, uint dpi, int scale) { return (int)((long)value * dpi * scale / 9600); }
    static int Distance(System.Drawing.Color a, System.Drawing.Color b) {
        return Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B)));
    }
    public static Dictionary<string, object> Check(string path, VerifyNative.Rect frame, VerifyNative.Point origin, uint dpi, int scale, int selected) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int clientLeft = origin.X - frame.Left;
            int left = clientLeft + S(8, dpi, scale);
            int referenceX = clientLeft + S(220, dpi, scale) - S(44, dpi, scale);
            int scanRight = left + S(10, dpi, scale);
            int width = S(7, dpi, scale) - S(4, dpi, scale);
            var rail = System.Drawing.Color.FromArgb(145, 149, 157);
            var header = System.Drawing.Color.FromArgb(63, 64, 66);
            int top = -1;
            int searchTop = origin.Y - frame.Top + S(8, dpi, scale);
            for (int y = searchTop; y < searchTop + S(180, dpi, scale); y++) {
                if (Distance(image.GetPixel(referenceX, y), header) <= 2) { top = y; break; }
            }
            if (top < 0) throw new InvalidOperationException("group-rail gray header fill not found");
            int headerHeight = 28, rowHeight = S(38, dpi, scale);
            int firstRow = top + headerHeight;
            int secondHeader = firstRow + 2 * rowHeight;
            int secondRow = secondHeader + headerHeight;
            int groupBottom = secondRow + 2 * rowHeight;
            int rowTop = firstRow + selected * rowHeight, rowBottom = rowTop + rowHeight;
            var highlight = image.GetPixel(referenceX, (rowTop + rowBottom) / 2);
            if (highlight.B <= highlight.R + 10) throw new InvalidOperationException("group-rail expected a visible blue selected highlight");
            int headerPixels = 0, headerMismatch = 0, unselectedPixels = 0, selectedMismatch = 0, selectedRail = 0, strayPixels = 0;
            bool leftEdge = true, groupsSeparate = true;
            var railXs = new List<int>();
            var headerXs = new List<int>();
            for (int group = 0; group < 2; group++) {
                int headerTop = group == 0 ? top : secondHeader;
                int memberTop = headerTop + headerHeight;
                int headerLeft = -1;
                for (int x = clientLeft; x < scanRight; x++) {
                    if (Distance(image.GetPixel(x, headerTop + headerHeight / 2), header) <= 2) { headerLeft = x; break; }
                }
                if (headerLeft < 0 || Distance(image.GetPixel(referenceX, headerTop), header) > 2) throw new InvalidOperationException("group-rail adjacent header fill not found");
                int unselectedTop = memberTop + (group == 0 ? 1 - selected : 0) * rowHeight;
                int railLeft = -1, railRight = -1;
                for (int x = clientLeft; x < scanRight; x++) {
                    if (Distance(image.GetPixel(x, unselectedTop + rowHeight / 2), rail) <= 2) {
                        if (railLeft < 0) railLeft = x;
                        railRight = x + 1;
                    }
                }
                if (railLeft < 0 || railRight - railLeft != width) throw new InvalidOperationException("group-rail missing full-width gray unselected rail");
                leftEdge = leftEdge && railLeft == headerLeft;
                railXs.Add(railLeft);
                headerXs.Add(headerLeft);
                for (int x = railLeft; x < railRight; x++) {
                    for (int y = memberTop; y < memberTop + 2 * rowHeight; y++) {
                        if (group == 0 && y >= rowTop && y < rowBottom) continue;
                        if (Distance(image.GetPixel(x, y), rail) <= 2) unselectedPixels++;
                        else throw new InvalidOperationException("group-rail missing continuous gray unselected rail");
                    }
                }
                for (int x = clientLeft; x < scanRight; x++) {
                    for (int y = headerTop; y < memberTop; y++) {
                        var actual = image.GetPixel(x, y);
                        var expected = image.GetPixel(referenceX, y);
                        bool railPixel = Distance(actual, rail) <= 2 && Distance(actual, expected) > 3;
                        if (railPixel) headerPixels++;
                        if (x >= headerLeft && Distance(actual, expected) > 3) headerMismatch++;
                        if (group == 1 && railPixel) groupsSeparate = false;
                    }
                }
            }
            for (int x = left + S(4, dpi, scale); x < left + S(7, dpi, scale); x++) {
                for (int y = rowTop + 3; y < rowBottom - 3; y++) {
                    if (Distance(image.GetPixel(x, y), image.GetPixel(referenceX, y)) > 3) selectedMismatch++;
                }
            }
            for (int x = clientLeft; x < scanRight; x++) {
                for (int y = rowTop; y < rowBottom; y++) {
                    if (Distance(image.GetPixel(x, y), rail) <= 2) selectedRail++;
                }
                for (int y = groupBottom; y < groupBottom + 24 + 2 * rowHeight; y++) {
                    if (Distance(image.GetPixel(x, y), rail) <= 2) strayPixels++;
                }
            }
            for (int x = railXs[1]; x < railXs[1] + width; x++) {
                if (Distance(image.GetPixel(x, secondRow - 1), header) > 3 || Distance(image.GetPixel(x, secondRow), rail) > 2) groupsSeparate = false;
                if (Distance(image.GetPixel(x, groupBottom - 1), rail) > 2 || Distance(image.GetPixel(x, groupBottom), rail) <= 2) groupsSeparate = false;
            }
            proof["leftEdge"] = leftEdge;
            proof["headerClear"] = headerPixels == 0 && headerMismatch == 0;
            proof["groupsSeparate"] = groupsSeparate;
            proof["selectedClear"] = selectedMismatch == 0 && selectedRail == 0;
            proof["strayClear"] = strayPixels == 0;
            proof["selectedMismatch"] = selectedMismatch;
            proof["selectedRailPixels"] = selectedRail;
            proof["strayPixels"] = strayPixels;
            proof["headerPixels"] = headerPixels;
            proof["headerMismatch"] = headerMismatch;
            proof["unselectedPixels"] = unselectedPixels;
            proof["railX"] = railXs.ToArray();
            proof["headerX"] = headerXs.ToArray();
            proof["headerTops"] = new int[] { top, secondHeader };
            proof["selectedRect"] = new int[] { left, rowTop, scanRight, rowBottom };
            proof["belowGroupRect"] = new int[] { left, groupBottom, scanRight, groupBottom + 24 + 2 * rowHeight };
            proof["highlightColor"] = new int[] { highlight.R, highlight.G, highlight.B };
        }
        return proof;
    }
}
public static class PaneLayoutProof {
    static int S(int value, uint dpi, int scale) { return (int)((long)value * dpi * scale / 9600); }
    static void Require(bool ok, string step, string detail) {
        if (!ok) throw new InvalidOperationException("pane-layout " + step + " FAIL: " + detail);
        Console.WriteLine("pane-layout " + step + " PASS");
    }
    static int Distance(System.Drawing.Color a, System.Drawing.Color b) {
        return Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B)));
    }
    public static Dictionary<string, object> Check(string path, VerifyNative.Rect frame, VerifyNative.Rect client,
        VerifyNative.Rect console, VerifyNative.Rect browser, uint dpi, int scale) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int ox = frame.Left, oy = frame.Top;
            Func<int, int, System.Drawing.Color> pixel = (x, y) => image.GetPixel(x - ox, y - oy);
            int gap = S(8, dpi, scale), pad = S(6, dpi, scale), border = S(1, dpi, scale);
            int sidebarLeft = client.Left + gap;
            int sidebarRight = client.Left + S(220, dpi, scale) - gap / 2;
            int left = sidebarRight + gap + pad, right = browser.Left - gap - pad;
            int top = client.Top + gap + pad, bottom = client.Bottom - gap - pad;
            int radius = S(8, dpi, scale), tolerance = Math.Max(1, border);
            var histogram = new Dictionary<int, int>();
            for (int y = top - tolerance; y <= top + tolerance; y++) {
                for (int x = left + radius; x < right - radius; x++) {
                    var color = pixel(x, y);
                    if (Math.Abs(color.R - color.G) > 2 || Math.Abs(color.G - color.B) > 2 || color.R < 40 || color.R > 100) continue;
                    int key = color.ToArgb();
                    histogram[key] = histogram.ContainsKey(key) ? histogram[key] + 1 : 1;
                }
            }
            int best = 0, ringKey = 0;
            foreach (var entry in histogram) if (entry.Value > best) { best = entry.Value; ringKey = entry.Key; }
            Require(best >= (right - left - 2 * radius) * 0.9, "ring-found", "No long dark-theme focus-color stroke at the console slot top");
            var ring = System.Drawing.Color.FromArgb(ringKey);
            proof["ringColor"] = new int[] { ring.R, ring.G, ring.B };
            proof["ringRect"] = new int[] { left, top, right, bottom };
            foreach (string side in new string[] { "top", "bottom", "left", "right" }) {
                bool horizontal = side == "top" || side == "bottom";
                int start = (horizontal ? left : top) + radius;
                int end = (horizontal ? right : bottom) - radius;
                int fixedAt = side == "top" ? top : side == "bottom" ? bottom : side == "left" ? left : right;
                int missing = 0, longest = 0, run = 0;
                for (int along = start; along < end; along++) {
                    bool found = false;
                    for (int across = fixedAt - tolerance; across <= fixedAt + tolerance; across++) {
                        if (Distance(pixel(horizontal ? along : across, horizontal ? across : along), ring) <= 3) found = true;
                    }
                    if (found) run = 0; else { missing++; run++; longest = Math.Max(longest, run); }
                }
                proof[side + "MissingPixels"] = missing;
                Require(missing == 0, "ring-" + side, "missing=" + missing + " longestGap=" + longest);
            }
            Require(console.Left >= left + border && console.Right <= right - border && console.Top >= top + border && console.Bottom <= bottom - border,
                "console-inside-ring", "HWND=" + console.Left + "," + console.Top + "," + console.Right + "," + console.Bottom);
            int gapLeft = browser.Left - gap, middleX = gapLeft + gap / 2;
            int middleY = (client.Top + client.Bottom) / 2;
            var divider = System.Drawing.Color.FromArgb(60, 60, 60);
            int forbidden = 0, gripPixels = 0;
            for (int x = gapLeft; x < browser.Left; x++) {
                for (int y = client.Top; y < client.Bottom; y++) {
                    var color = pixel(x, y);
                    bool line = Distance(color, ring) <= 3 || Distance(color, System.Drawing.Color.FromArgb(95, 95, 95)) <= 3 || Distance(color, divider) <= 3;
                    if (!line) continue;
                    bool grip = x >= middleX && x < middleX + border && y >= middleY - S(16, dpi, scale) && y < middleY + S(16, dpi, scale);
                    if (grip && Distance(color, divider) <= 3) gripPixels++; else forbidden++;
                }
            }
            proof["gapRect"] = new int[] { gapLeft, client.Top, browser.Left, client.Bottom };
            proof["gripPixels"] = gripPixels;
            Require(forbidden == 0 && gapLeft > right + border, "clean-gap", "forbidden ring/divider pixels=" + forbidden);
            var railColor = System.Drawing.Color.FromArgb(145, 149, 157);
            int railX = -1, railTop = -1, railBottom = -1, longestRail = 0;
            for (int x = sidebarLeft; x < sidebarLeft + S(36, dpi, scale); x++) {
                int run = 0;
                for (int y = client.Top + S(20, dpi, scale); y < client.Top + S(220, dpi, scale); y++) {
                    if (Distance(pixel(x, y), railColor) <= 2) run++; else run = 0;
                    if (run > longestRail) { longestRail = run; railX = x; railBottom = y + 1; railTop = y + 1 - run; }
                }
            }
            Require(longestRail == S(38, dpi, scale) && railX == sidebarLeft, "group-line-found", "expected a left-aligned member-only rail, longest vertical group-color run=" + longestRail);
            int railRight = railX + 1;
            while (railRight < sidebarLeft + S(40, dpi, scale) && Distance(pixel(railRight, (railTop + railBottom) / 2), railColor) <= 2) railRight++;
            int rowTop = railTop, rowBottom = railBottom;
            var rowBackground = pixel(sidebarRight - S(45, dpi, scale), (rowTop + rowBottom) / 2);
            var cardBackground = pixel(sidebarLeft + S(2, dpi, scale), (rowTop + rowBottom) / 2);
            var sidebarBackground = pixel(sidebarRight - S(45, dpi, scale), railBottom + S(2, dpi, scale));
            string backgroundColors = " rowBackground=" + rowBackground + " cardBackground=" + cardBackground + " sidebarBackground=" + sidebarBackground;
            var railPixelColor = pixel(railX, (rowTop + rowBottom) / 2);
            var firstIconColor = System.Drawing.Color.Empty;
            int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1, iconPixels = 0;
            for (int x = railRight; x < sidebarLeft + S(34, dpi, scale); x++) {
                for (int y = rowTop + S(4, dpi, scale); y < rowBottom - S(4, dpi, scale); y++) {
                    var color = pixel(x, y);
                    if (Distance(color, rowBackground) <= 16 || Distance(color, cardBackground) <= 16 || Distance(color, sidebarBackground) <= 16) continue;
                    if (x < minX) firstIconColor = color;
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y); iconPixels++;
                }
            }
            Require(iconPixels >= S(16, dpi, scale) && maxY - minY >= S(8, dpi, scale), "row-icon-found", "No visible CMD icon pixels in the first grouped row" + backgroundColors);
            proof["railRect"] = new int[] { railX, railTop, railRight, railBottom };
            proof["iconPixelBounds"] = new int[] { minX, minY, maxX + 1, maxY + 1 };
            proof["iconPixels"] = iconPixels;
            Require(railRight + S(4, dpi, scale) <= minX, "group-line-clears-icon", "railRight=" + railRight + " iconLeft=" + minX + " railColor=" + railPixelColor + " firstIconColor=" + firstIconColor + backgroundColors);
        }
        return proof;
    }
}
public static class CodeFontProof {
    static double Luminance(System.Drawing.Color c) { return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B; }
    public static Dictionary<string, object> Bar(string path, int left, int top, int right, int bottom, int cells) {
        using (var image = new System.Drawing.Bitmap(path)) {
            left = Math.Max(0, left); top = Math.Max(0, top);
            right = Math.Min(right, image.Width); bottom = Math.Min(bottom, image.Height);
            int width = right - left, height = bottom - top;
            if (width < 8 || height < 8) throw new InvalidOperationException("IGSH-678 transcript area too small to measure");
            double background = Luminance(image.GetPixel(left + 2, top + 2));
            var contrast = new double[width * height];
            double strongest = 0;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    double value = Math.Abs(Luminance(image.GetPixel(left + x, top + y)) - background);
                    contrast[y * width + x] = value;
                    if (value > strongest) strongest = value;
                }
            }
            double threshold = strongest * 0.5;
            int bestStart = -1, bestEnd = -1, bestTop = -1, bestRows = 0;
            int stackStart = -1, stackEnd = -1, stackTop = -1, stackRows = 0;
            for (int y = 0; y < height; y++) {
                int runStart = -1, runEnd = -1, current = -1;
                for (int x = 0; x <= width; x++) {
                    bool ink = x < width && contrast[y * width + x] >= threshold;
                    if (ink && current < 0) current = x;
                    if (!ink && current >= 0) {
                        if (x - current > runEnd - runStart) { runStart = current; runEnd = x; }
                        current = -1;
                    }
                }
                bool bar = runEnd - runStart >= cells * 4;
                if (bar && stackRows > 0 && Math.Abs(runStart - stackStart) <= 2 && Math.Abs(runEnd - stackEnd) <= 2) {
                    stackRows++;
                } else if (bar) {
                    stackStart = runStart; stackEnd = runEnd; stackTop = y; stackRows = 1;
                } else {
                    stackRows = 0;
                }
                if (stackRows > bestRows) { bestStart = stackStart; bestEnd = stackEnd; bestTop = stackTop; bestRows = stackRows; }
            }
            if (bestRows < 4) throw new InvalidOperationException("IGSH-678 code block bar of " + cells + " full-block cells not found in Chat View");
            var proof = new Dictionary<string, object>();
            proof["left"] = left + bestStart;
            proof["right"] = left + bestEnd;
            proof["top"] = top + bestTop;
            proof["rows"] = bestRows;
            proof["width"] = bestEnd - bestStart;
            proof["background"] = background;
            proof["threshold"] = threshold;
            return proof;
        }
    }
    public static Dictionary<string, object> Edges(string path, int left, int top, int right, int bottom) {
        using (var image = new System.Drawing.Bitmap(path)) {
            left = Math.Max(0, left); top = Math.Max(0, top);
            right = Math.Min(right, image.Width); bottom = Math.Min(bottom, image.Height);
            double low = double.MaxValue, high = double.MinValue;
            for (int y = top; y < bottom; y++) for (int x = left; x < right; x++) {
                double value = Luminance(image.GetPixel(x, y));
                low = Math.Min(low, value); high = Math.Max(high, value);
            }
            int edges = 0, jumps = 0, ink = 0, partial = 0;
            double span = Math.Max(1, high - low);
            for (int y = top; y < bottom; y++) {
                double previous = -1;
                for (int x = left; x < right; x++) {
                    double t = Math.Abs(Luminance(image.GetPixel(x, y)) - low) / span;
                    if (t > 0.1) { ink++; if (t < 0.9) partial++; }
                    if (previous >= 0) {
                        double lo = Math.Min(previous, t), hi = Math.Max(previous, t);
                        if (lo <= 0.1 && hi > 0.1) { edges++; if (hi >= 0.9) jumps++; }
                    }
                    previous = t;
                }
            }
            var proof = new Dictionary<string, object>();
            proof["edges"] = edges;
            proof["hardEdges"] = jumps;
            proof["hardEdgeFraction"] = edges == 0 ? 1.0 : (double)jumps / edges;
            proof["inkPixels"] = ink;
            proof["partialPixels"] = partial;
            return proof;
        }
    }
    public static void Crop(string path, string output, int left, int top, int right, int bottom, int scale) {
        using (var image = new System.Drawing.Bitmap(path)) {
            left = Math.Max(0, left); top = Math.Max(0, top);
            right = Math.Min(right, image.Width); bottom = Math.Min(bottom, image.Height);
            using (var crop = new System.Drawing.Bitmap((right - left) * scale, (bottom - top) * scale)) {
                using (var graphics = System.Drawing.Graphics.FromImage(crop)) {
                    graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
                    graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
                    graphics.DrawImage(image, new System.Drawing.Rectangle(0, 0, crop.Width, crop.Height), new System.Drawing.Rectangle(left, top, right - left, bottom - top), System.Drawing.GraphicsUnit.Pixel);
                }
                crop.Save(output, System.Drawing.Imaging.ImageFormat.Png);
            }
        }
    }
}
public sealed class VerifyJob : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes { public int Length; public IntPtr Descriptor; public int Inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct StartupInfo {
        public int Size; public string Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
        public ushort Show, ReservedSize; public IntPtr ReservedBytes, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process, Thread; public uint Pid, Tid; }
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long ProcessTime, JobTime; public uint Flags; public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcessLimit; public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic; public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Accounting {
        public long UserTime, KernelTime, PeriodUserTime, PeriodKernelTime;
        public uint PageFaults, TotalProcesses, ActiveProcesses, TerminatedProcesses;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimits limits, int size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int kind, out Accounting info, int size, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app, StringBuilder command, IntPtr processAttributes, IntPtr threadAttributes, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInfo process);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFile(string path, uint access, uint share, ref SecurityAttributes attributes, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr job;
    bool started;
    static void Check(bool success) {
        if (!success) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
    public VerifyJob() {
        job = CreateJobObject(IntPtr.Zero, null);
        Check(job != IntPtr.Zero);
        try {
            ExtendedLimits limits = new ExtendedLimits();
            limits.Basic.Flags = 0x2000;
            Check(SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(ExtendedLimits))));
        } catch { Dispose(); throw; }
    }
    static IntPtr OpenLog(string path, uint access, uint disposition) {
        SecurityAttributes attributes = new SecurityAttributes();
        attributes.Length = Marshal.SizeOf(typeof(SecurityAttributes)); attributes.Inherit = 1;
        IntPtr handle = CreateFile(path, access, 3, ref attributes, disposition, 0x80, IntPtr.Zero);
        Check(handle != new IntPtr(-1));
        return handle;
    }
    public System.Diagnostics.Process Start(string exe, string directory, string stdout, string stderr) {
        return Start(exe, directory, stdout, stderr, "--single-window --no-window-restore");
    }
    public System.Diagnostics.Process Start(string exe, string directory, string stdout, string stderr, string arguments) {
        if (started || job == IntPtr.Zero) throw new InvalidOperationException("Job is not available for launch");
        IntPtr output = IntPtr.Zero, error = IntPtr.Zero, input = IntPtr.Zero;
        ProcessInfo native = new ProcessInfo();
        System.Diagnostics.Process process = null;
        try {
            output = OpenLog(stdout, 0x40000000, 2); error = OpenLog(stderr, 0x40000000, 2);
            input = OpenLog("NUL", 0x80000000, 3);
            StartupInfo startup = new StartupInfo();
            startup.Size = Marshal.SizeOf(typeof(StartupInfo)); startup.Flags = 0x100;
            startup.Input = input; startup.Output = output; startup.Error = error;
            Check(CreateProcess(exe, new StringBuilder("\"" + exe + "\" " + arguments), IntPtr.Zero, IntPtr.Zero, true, 4, IntPtr.Zero, directory, ref startup, out native));
            Check(AssignProcessToJobObject(job, native.Process));
            process = System.Diagnostics.Process.GetProcessById((int)native.Pid);
            IntPtr handle = process.Handle;
            Check(ResumeThread(native.Thread) != uint.MaxValue);
            started = true;
            return process;
        } catch {
            if (native.Process != IntPtr.Zero) {
                Check(TerminateProcess(native.Process, 1));
                if (WaitForSingleObject(native.Process, 10000) != 0) throw new TimeoutException("Suspended launch did not stop");
            }
            if (process != null) process.Dispose();
            throw;
        } finally {
            if (native.Thread != IntPtr.Zero) CloseHandle(native.Thread);
            if (native.Process != IntPtr.Zero) CloseHandle(native.Process);
            if (input != IntPtr.Zero) CloseHandle(input);
            if (output != IntPtr.Zero) CloseHandle(output);
            if (error != IntPtr.Zero) CloseHandle(error);
        }
    }
    public bool Contains(System.Diagnostics.Process process) {
        bool result;
        Check(IsProcessInJob(process.Handle, job, out result));
        return result;
    }
    public Accounting ReadAccounting() {
        Accounting info;
        Check(QueryInformationJobObject(job, 1, out info, Marshal.SizeOf(typeof(Accounting)), IntPtr.Zero));
        return info;
    }
    public Accounting Stop() {
        Check(TerminateJobObject(job, 1));
        System.Diagnostics.Stopwatch timer = System.Diagnostics.Stopwatch.StartNew();
        for (;;) {
            Accounting info = ReadAccounting();
            if (info.ActiveProcesses == 0) return info;
            if (timer.ElapsedMilliseconds >= 10000) throw new TimeoutException("Owned process tree did not stop");
            Thread.Sleep(100);
        }
    }
    public void Dispose() {
        if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
    }
}
'@

switch ($Feature) {
        'browser-emulation' {
            $Evidence = [IO.Path]::GetFullPath($Evidence)
            New-Item -ItemType Directory -Force $Evidence | Out-Null
            $browserJob = New-Object VerifyJob
            $driver = $null
            try {
                $node = (Get-Command node.exe -ErrorAction Stop).Source
                $scriptPath = (Resolve-Path '.claude/skills/verify-multiprompt/browser-emulation.mjs').Path
                $driver = $browserJob.Start($node, $pwd.Path, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), ('"' + $scriptPath + '"'))
                if (-not $driver.WaitForExit(600000)) { throw 'Browser verification timed out' }
                if ($driver.ExitCode -ne 0) { throw ('Browser verification failed: ' + (Get-Content (Join-Path $Evidence 'stderr.log') -Raw)) }
            } finally {
                try {
                    $beforeStop = $browserJob.ReadAccounting()
                    $stopped = $browserJob.Stop()
                    @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'process-tree.json')
                } finally {
                    if ($null -ne $driver) { $driver.Dispose() }
                    $browserJob.Dispose()
                }
            }
            Write-Output 'VERIFIED browser-emulation with real native CLI and zero active job processes'
            return
        }
}

$Evidence = [IO.Path]::GetFullPath($Evidence)
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('multiprompt-verify-' + [guid]::NewGuid().ToString('N'))
$process = $null
$job = $null
$warmupJob = $null
$warmup = $null
$switchNativeRegistry = $null
$script:window = [IntPtr]::Zero
$script:actions = New-Object System.Collections.ArrayList
$script:scratchLinks = @()
$result = [ordered]@{ feature = $Feature; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; checks = @(); offlineLogin = $true; cleanup = 'pending' }
$original = @{}

function Save-Json($Value, [string]$Name) {
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}

function Record([string]$Action) {
    [void]$script:actions.Add(@{ time = [DateTime]::UtcNow.ToString('o'); action = $Action; title = [VerifyNative]::Title($script:window) })
    Save-Json @($script:actions.ToArray()) 'actions.json'
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
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    do {
        if ($null -ne $process -and $process.HasExited) { throw "App exited while waiting for $Description" }
        try { if (& $Condition) { return } } catch { $lastError = $_.Exception.Message }
        if ($Tight) { [Threading.Thread]::Sleep(1) } else { Start-Sleep -Milliseconds $PollMilliseconds }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Missing precondition or resulting state: $Description. $lastError"
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

function Wait-ChatViews([bool[]]$Views, [int]$Active, [string]$Step) {
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state -or @($state.tabs).Count -ne 3 -or $state.active_tab -ne $Active) { return $false }
        if ($state.PSObject.Properties['chat_view_mode']) { throw 'Global forcing mode was saved again' }
        for ($i = 0; $i -lt 3; $i++) {
            $on = $state.tabs[$i].PSObject.Properties['cv'] -and $state.tabs[$i].cv -eq $true
            if ($on -ne $Views[$i]) { return $false }
        }
        $state.tabs[2].PSObject.Properties['chat_view_lock'] -and $state.tabs[2].chat_view_lock -ceq 'shell'
    } "app-written views and shell lock: $Step"
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
    if ($Feature -ne 'browser-switch-speed' -and $pane.browser_window_id -ne 0) { throw 'Unexpected browser extension connection in the no-extension journey' }
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
    $proof = @{ step = $Step; launches = $launches; monitor = $info.Monitor; mainHwnd = $script:window.ToInt64(); paneHwnd = $browser.ToInt64(); panePid = $browserPid; mainDpi = $mainDpi; paneDpi = $paneDpi }
    Save-Json $proof ("browser-pane-locked-launch-$Step.json")
    if ($launches.Count -eq 0 -or $browserPid -notin @($launches | ForEach-Object { $_.pid })) { throw 'No isolated browser launch command line for the owned pane' }
    if (@($launches | Where-Object { -not $_.parsed -or -not $_.inside }).Count -ne 0) { throw 'Browser launch point is outside the owner monitor' }
    if ($mainDpi -eq 0 -or $paneDpi -ne $mainDpi) { throw "Pane DPI $paneDpi differs from owner DPI $mainDpi" }
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
    $process.Refresh()
    if ($process.HasExited -or $script:window -eq [IntPtr]::Zero) { throw 'Doctor: owned app window missing' }
    [uint32]$owner = 0
    [void][VerifyNative]::GetWindowThreadProcessId($script:window, [ref]$owner)
    if ($owner -ne $process.Id -or [VerifyNative]::Class($script:window) -ne 'ZigShell') { throw 'Doctor: window ownership mismatch' }
    if ($process.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    $title = [VerifyNative]::Title($script:window)
    if ($title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw "Doctor: wrong version in $title" }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    if ($element.Current.ProcessId -ne $process.Id -or $element.Current.IsOffscreen) { throw 'Doctor: UI Automation cannot see owned window' }
    $state = Read-Inbox
    if ($null -eq $state -or @($state.shells).Count -lt 1) { throw 'Doctor: no usable initial shell published' }
    Save-Json @{ pid = $process.Id; hwnd = $script:window.ToInt64(); title = $title; class = $element.Current.ClassName; version = $ExpectedVersion; sha256 = $ExpectedHash; shellCount = @($state.shells).Count; data = $scratch } 'doctor.json'
}

function Snapshot([string]$Name) {
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
    if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -ne $script:window) { throw 'Refusing input: owned app is not foreground' }
}

function Press([int[]]$Keys, [string]$Label) {
    Doctor
    Wait-Until {
        [void][VerifyNative]::SetForegroundWindow($script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
    } 'owned app foreground for keyboard input'
    Assert-Foreground
    Record $Label
    [VerifyNative]::Chord($Keys)
}

function Type-Text([string]$Text) {
    Doctor
    Assert-Foreground
    Record ('Type ' + $Text)
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

function Focus-Palette([string]$Query, [int]$Target) {
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $start = ((Get-Content $log -Raw) -join '').Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
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

function Palette([string]$Query) {
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
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

function Restart-SessionRestore([string]$Stage, [bool]$Crash, [bool]$Updater = $false) {
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
    $match = [regex]::Match($line, '(?:^|\s)--user-data-dir=(?:"([^"]+)"|(\S+))')
    if (-not $match.Success) { throw 'Docked pane browser has no user data directory' }
    $dir = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
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

function Open-WorkspaceBrowser([string]$Step) {
    Palette 'open browser'
    Press @(0x0D) ('Enter: Open Browser Pane for ' + $Step)
    Wait-Until {
        $pane = Read-BrowserPane
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero
    } "browser-own-profile ${Step}: docked pane connected" 60
    $pane = Read-BrowserPane
    $browser = [VerifyNative]::DockedPaneWindow($script:window)
    if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Docked pane is not owned by the app window' }
    $proof = Get-PaneUserDataDir $browser
    Save-Json @{ pane = $pane; browser = $proof } ("browser-own-profile-$Step.json")
    Focus-BrowserPaneOwner $Step $pane.browser_connection_id
    return $proof
}

function Select-Theme([string]$Theme, [string]$ActionShot) {
    Palette 'themes'
    Press @(0x0D) 'Enter: Themes...'
    Type-Text $Theme
    Snapshot $ActionShot
    Press @(0x0D) ('Enter: choose ' + $Theme)
    $path = Join-Path $scratch 'roaming/ZigShell/theme-mode.txt'
    Wait-Until { (Test-Path $path) -and (Get-Content $path -Raw).Trim() -eq $Theme } "app-written theme-mode.txt equals $Theme"
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
    $x = $offsetX + [int][Math]::Round(14 * $scale)
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
            if ([Math]::Max([Math]::Abs($pixel.R - $fill.R), [Math]::Max([Math]::Abs($pixel.G - $fill.G), [Math]::Abs($pixel.B - $fill.B))) -gt 8) { break }
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

function Wait-ChatFocus([string]$Class, [string]$Step) {
    Wait-Until {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $focused.Current.ProcessId -eq $process.Id -and $focused.Current.ClassName -ceq $Class -and
            -not $focused.Current.IsOffscreen -and $focused.Current.NativeWindowHandle -ne 0 -and
            [VerifyNative]::GetAncestor([IntPtr]$focused.Current.NativeWindowHandle, 2) -eq $script:window
    } ("owned focused $Class`: $Step")
    Snapshot $Step
}

function Assert-ChatTyping([string]$Text, [string]$Step) {
    Wait-ChatFocus 'Edit' ($Step + '-focused')
    $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
    $handle = [IntPtr]$composer.Current.NativeWindowHandle
    if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::Class($handle) -cne 'Edit' -or
        [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Expected the owned composer Edit before reading text' }
    if ([VerifyNative]::EditText($handle) -cne '') { throw 'Expected an empty composer before typing proof' }
    Type-Text $Text
    Wait-Until { [VerifyNative]::EditText($handle) -ceq $Text } ("WM_GETTEXT typing landed: $Step")
    Wait-ChatFocus 'Edit' $Step
    if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -ne $handle) { throw 'Typing focus left the original composer Edit' }
    Save-Json @{ WM_GETTEXT = [VerifyNative]::EditText($handle); handle = $composer.Current.NativeWindowHandle; pid = $composer.Current.ProcessId } ($Step + '.text.json')
}

try {
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'IGSH_246')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    if ($Feature -in @('browser-switch-speed', 'browser-own-profile')) {
        $chrome = & node (Join-Path $PSScriptRoot 'browser-switch-chrome.mjs')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $chrome)) { throw 'Pinned Chrome for Testing executable unavailable' }
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    $env:USERPROFILE = Join-Path $scratch 'profile'
    $env:HOME = $env:USERPROFILE
    if ($Feature -in @('browser-switch-speed', 'browser-own-profile')) {
        $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        New-Item -ItemType Directory -Force (Split-Path $extension) | Out-Null
        Copy-Item (Join-Path $PSScriptRoot '../../../extension') $extension -Recurse
        $manifestPath = Join-Path $extension 'manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $publicKey = 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDQp16XVv5KtjSlsEqMuPshm2xYXIvCx5DIAvNpHvxVpg2xJylPEsBoMC3pNeqqz9qG3g9MHQx7X08ItIevQXaOEWBrX7ZVHHXzoQBnlQ/LZbcSkpFucyNItAURMUCGg8XpwuAXi+rFcMkBcib6IpHklkAk97Kxc3NTevJ8TNSUewIDAQAB'
        $manifest | Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $manifestPath
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = $sha.ComputeHash([Convert]::FromBase64String($publicKey)) } finally { $sha.Dispose() }
        $extensionId = -join ($digest[0..15] | ForEach-Object { [char](97 + ($_ -shr 4)); [char](97 + ($_ -band 15)) })
        $nativeManifest = Join-Path $scratch 'native-host.json'
        @{ name = 'com.zigshell.bridge'; description = 'Synthetic switch timing bridge'; path = (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'); type = 'stdio'; allowed_origins = @("chrome-extension://$extensionId/") } | ConvertTo-Json | Set-Content -Encoding UTF8 $nativeManifest
        $registry = 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.zigshell.bridge'
        if (Test-Path $registry) { throw 'Switch timing requires an unregistered disposable native host' }
        $switchNativeRegistry = $registry
        New-Item -Path $registry -Force | Out-Null
        Set-Item -Path $registry -Value $nativeManifest
        $edge = $chrome
        $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData'
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config | Out-Null
        [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $chrome)
        [IO.File]::WriteAllText((Join-Path $config 'browser-engine.txt'), 'chrome')
        Save-Json @{ extensionId = $extensionId; version = $manifest.version; installed = $true; executable = $chrome; configuration = 'chrome-exe.txt + browser-engine.txt' } 'switch-extension.json'
    }
    $paletteUsageFixture = Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-612/palette-usage.tsv'
    if ($Feature -eq 'palette-order') {
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config | Out-Null
        Copy-Item $paletteUsageFixture (Join-Path $config 'palette-usage.tsv')
    }
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $job = New-Object VerifyJob
    if ($Feature -eq 'session-restore') {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } elseif ($Feature -eq 'browser-own-profile') {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } else {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'))
    }
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -gt 0
    } 'owned main window and initialized CMD session' 60
    if ($Feature -in @('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed')) {
        if ($Feature -ne 'browser-switch-speed') {
            $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
            $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/EdgeUserData'
        }
        if (-not (Test-Path -LiteralPath $edge)) { throw 'Browser setup requires the configured browser executable' }
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
        if ($Feature -eq 'browser-switch-speed') { $arguments += ' --load-extension="' + $extension + '" --disable-extensions-except="' + $extension + '" --silent-debugger-extension-api' }
        $warmup = $warmupJob.Start($edge, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
        } 'isolated browser rendered setup page before the pane adoption deadline starts' 60
        if ($Feature -eq 'browser-switch-speed') { Wait-SwitchNativeHost }
        [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
        Save-Json @{ pid = $warmup.Id; ready = $true; timeoutSeconds = 60 } 'browser-setup.json'
    }
    if ($Feature -eq 'appearance') {
        Doctor
        $maximized = [VerifyNative]::IsZoomed($script:window)
        Save-Json @{ hwnd = $script:window.ToInt64(); maximized = $maximized } 'startup-maximized.json'
        if (-not $maximized) { throw 'IGSH-587: main window did not start maximized' }
        $result.checks += @{ name = 'startup-maximized'; maximized = $maximized }
        Snapshot 'startup-maximized'
    }
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'foreground main window'
    Doctor
    Record 'Launch complete; read-only Doctor passed'
    Snapshot 'before'
    switch ($Feature) {
        'palette-order' {
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $usage = @(Get-Content $paletteUsageFixture | Where-Object { $_ } | ForEach-Object { $fields = $_ -split "`t"; [pscustomobject]@{ id = [string]$fields[0]; count = [int]$fields[1]; last = [uint64]$fields[2] } })
            $expected = @($usage | Sort-Object @{ Expression = 'count'; Descending = $true }, @{ Expression = 'last'; Descending = $true } | Select-Object -First 10 | ForEach-Object { $_.id })
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x4B) 'Ctrl+K: open empty command palette with seeded usage history'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
            } 'empty palette ready'
            Snapshot 'action'
            $trace = ((Get-Content $log -Raw) -join '').Substring($start)
            $ready = [regex]::Matches($trace, '\[palette\] ready chars=0 count=(\d+) target=(\d+)')
            $selected = $ready[$ready.Count - 1].Groups[2].Value
            if ($selected -ne $expected[0]) { throw "palette-order: selected row $selected, expected most used command $($expected[0])" }
            $rows = [regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)')
            if ($rows.Count -eq 0) { throw 'palette-order: no empty palette rows trace' }
            $ids = @($rows[$rows.Count - 1].Groups[1].Value -split ' ')
            if ($ids[0] -ne 'h0') { throw "palette-order: first row $($ids[0]), expected Most used header" }
            $band = @($ids[1..10])
            if (($band -join ' ') -ne ($expected -join ' ')) { throw "palette-order: Most used rows $($band -join ' '), expected $($expected -join ' ')" }
            if ($ids[11] -notmatch '^h[1-8]$') { throw "palette-order: row after Most used is $($ids[11]), expected a group header" }
            $headers = @($ids | Where-Object { $_ -match '^h\d$' })
            if (@($headers | Select-Object -Unique).Count -ne $headers.Count) { throw "palette-order: repeated group header in $($ids -join ' ')" }
            $rare = @($usage | Sort-Object count | Select-Object -First 1)[0].id
            if ($band -contains $rare) { throw "palette-order: rarely used command $rare entered Most used" }
            Save-Json @{ ids = $ids; expected = $expected; selected = $selected } 'palette-order-rows.json'
            Press @(0x1B) 'Esc: close empty palette'
            $queries = @(
                @{ text = 'chat view per tab'; id = 0 },
                @{ text = 'copy session diagnostics'; id = 6247 },
                @{ text = 'copy shell diagnostics'; id = 6247 },
                @{ text = 'rename workspace'; id = 7000 },
                @{ text = 'mobile latency mode'; id = 8000 },
                @{ text = 'restore disconnected workspace sessions'; id = 6295 },
                @{ text = 'auto-suspend idle panes'; id = 6240 },
                @{ text = 'use agent or terminal session name'; id = 6248 },
                @{ text = 'insert agent instructions'; id = 6237 }
            )
            $found = @()
            foreach ($query in $queries) {
                $start = ((Get-Content $log -Raw) -join '').Length
                Press @(0x11, 0x4B) ('Ctrl+K: open palette for ' + $query.text)
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                    [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
                } ('empty palette ready for ' + $query.text)
                Type-Text $query.text
                if ($query.id -eq 0) {
                    Wait-Until {
                        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] ready chars=' + $query.text.Length + ' count=0 target=0(?:\r?\n|$)')
                    } 'removed per-tab command has zero palette rows'
                    Snapshot 'removed-absent'
                } else {
                    Wait-Until {
                        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] rows chars=' + $query.text.Length + ' count=[1-9]\d* ids=(?:\S+ )*' + $query.id + '(?: |\r?\n|$)')
                    } ("palette-order: '" + $query.text + "' lists command " + $query.id)
                    $found += @{ query = $query.text; id = $query.id }
                }
                if ($query.text -eq 'copy session diagnostics') { Snapshot 'renamed' }
                Press @(0x1B) ('Esc: close palette for ' + $query.text)
            }
            $result.checks += @{ name = 'palette-order'; mostUsed = $expected; selected = $selected; headers = $headers; removedRowCount = 0; renamedFound = $found; entry = 'Ctrl+K' }
            Snapshot 'after'
        }
        'chat-view-everywhere' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'Local CMD sessions exercise view preferences and persistence, not agent delivery or remote tmux creation' }
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist initial session through UI Size: Reset'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 } 'one initial saved CMD session'
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep creation order for Ctrl+1/2/3'
            Wait-Until {
                $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                if (-not (Test-Path $path)) { return $false }
                $launch = Get-Content $path -Raw | ConvertFrom-Json
                $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
            } 'manual tab order saved before creating sessions'
            for ($count = 2; $count -le 3; $count++) {
                Focus-Palette 'new cmd' 2000
                Snapshot ("new-session-$count-action")
                Press @(0x0D) 'Enter: New CMD Shell'
                Wait-Until { $state = Read-Session; @($state.tabs).Count -eq $count -and $state.active_tab -eq $count - 1 } "user-created CMD session $count"
            }
            Snapshot 'sessions-created'
            Focus-Palette 'always shell view for this session' 6465
            Snapshot 'lock-action'
            Press @(0x0D) 'Enter: Always shell view for this session on session 3'
            Wait-ChatViews @($false, $false, $false) 2 'locked-shell'
            Focus-Palette 'chat view on everywhere' 6346
            Snapshot 'action'
            Press @(0x0D) 'Enter: Chat View on everywhere once'
            Wait-ChatViews @($true, $true, $false) 2 'on-everywhere'
            Press @(0x11, 0x31) 'Ctrl+1: show session 1 in Chat View'
            Wait-ChatViews @($true, $true, $false) 0 'session-1-chat'
            Press @(0x12, 0x43) 'Alt+C: session 1 back to shell'
            Wait-ChatViews @($false, $true, $false) 0 'session-1-toggled'
            Press @(0x11, 0x32) 'Ctrl+2: show session 2 in Chat View'
            Wait-ChatViews @($false, $true, $false) 1 'session-2-chat'
            Press @(0x11, 0x31) 'Ctrl+1: return to session 1 without forcing Chat View'
            Wait-ChatViews @($false, $true, $false) 0 'toggle-sticks'
            Focus-Palette 'chat view off everywhere' 6347
            Snapshot 'off-action'
            Press @(0x0D) 'Enter: Chat View off everywhere once'
            Wait-ChatViews @($false, $false, $false) 0 'off-everywhere'
            Press @(0x11, 0x33) 'Ctrl+3: shell-locked session stays in shell'
            Wait-ChatViews @($false, $false, $false) 2 'locked-after-off'
            Restart-ChatView 3
            Save-Json (Read-Session) 'restart-before-input.session.json'
            Press @(0x11, 0x31) 'Ctrl+1: restored first session'
            Wait-ChatViews @($false, $false, $false) 0 'restart-session-1'
            Press @(0x11, 0x32) 'Ctrl+2: restored second session'
            Wait-ChatViews @($false, $false, $false) 1 'restart-session-2'
            Press @(0x11, 0x33) 'Ctrl+3: restored shell lock'
            Wait-ChatViews @($false, $false, $false) 2 'restart-session-3'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Focus-Palette 'chat view on everywhere' 6346
            Press @(0x1B) 'Esc: close known positive palette query'
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x4B) 'Ctrl+K: reopen empty command palette'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
            } 'empty palette ready for removed-command query'
            Type-Text 'chat view per tab'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=17 count=0 target=0(?:\r?\n|$)'
            } 'removed per-tab command has zero palette rows'
            Snapshot 'per-tab-absent'
            Press @(0x1B) 'Esc: close empty palette'
            Wait-ChatViews @($false, $false, $false) 2 'after'
            $result.checks += @{ name = 'chat-view-everywhere-once'; unlockedOn = @(0, 1); skippedShellLock = 2; laterToggleSticks = $true; offEverywhere = $true; restartViewsAndLock = $true; removedPerTabRowCount = 0; entry = 'Ctrl+K, Ctrl+1/2/3 and Alt+C' }
        }
        'chat-focus' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'Offline CMD session proves typing focus, not agent delivery' }
            Press @(0x12, 0x43) 'Alt+C: enable Chat View for the isolated CMD session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].cv -and
                    -not ($state.tabs[0].PSObject.Properties['bon'] -and $state.tabs[0].bon)
            } 'one saved Chat View session without a browser pane'
            Wait-ChatFocus 'Edit' 'chat-enabled'
            Restart-ChatView 1
            Assert-ChatTyping 'abc' 'restart-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select restart draft'
            Press @(0x08) 'Backspace: clear restart draft'
            Press @(0x11, 0x46) 'Ctrl+F: open Chat Find'
            Wait-ChatFocus 'ZigShellChatTranscript' 'find-open'
            Snapshot 'action'
            Press @(0x12, 0x51) 'Alt+Q: close Find and restore typing without a pane'
            Assert-ChatTyping 'abc' 'find-alt-q-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select recovered draft'
            Press @(0x08) 'Backspace: clear recovered draft'
            Press @(0x1B) 'Esc: dismiss any remaining Find'
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
            $transcript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
            if ($null -eq $transcript -or $transcript.Current.ProcessId -ne $process.Id -or $transcript.Current.IsOffscreen) { throw 'Owned transcript is not visible for mouse input' }
            $handle = [IntPtr]$transcript.Current.NativeWindowHandle
            if ($handle -eq [IntPtr]::Zero -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Transcript is not in the owned app window' }
            $rect = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetClientRect($handle, [ref]$rect) -or $rect.Right -le 0 -or $rect.Bottom -le 0) { throw 'Owned transcript rectangle unavailable' }
            Doctor
            Assert-Foreground
            Record 'Click the ownership-checked transcript rectangle using real mouse input'
            [VerifyNative]::ClickClient($handle, [int]($rect.Right / 2), [int]($rect.Bottom / 2))
            Snapshot 'transcript-clicked'
            Press @(0x12, 0x51) 'Alt+Q: return from transcript to composer without a pane'
            Assert-ChatTyping 'abc' 'transcript-alt-q-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select final draft'
            Press @(0x08) 'Backspace: clear final draft'
            Press @(0x11, 0x46) 'Ctrl+F: reopen Find for the Alt+M alias'
            Wait-ChatFocus 'ZigShellChatTranscript' 'alias-find-open'
            Press @(0x12, 0x4D) 'Alt+M: close Find and restore typing without a pane'
            Assert-ChatTyping 'abc' 'find-alt-m-typing'
            Snapshot 'after'
            $result.checks += @{ name = 'chat-focus'; restartTyping = $true; findAltQTyping = $true; transcriptAltQTyping = $true; findAltMTyping = $true; panePresent = $false; entry = 'Alt+C, Ctrl+F, Alt+Q, mouse and Alt+M' }
        }
        'appearance' {
            Select-Theme 'dark' 'baseline-dark-action'
            Snapshot 'before'
            Select-Theme 'light' 'action'
            Snapshot 'after'
            $dark = Sidebar-Luminance 'before'
            $light = Sidebar-Luminance 'after'
            if ($light -lt $dark + 60) { throw "Visible sidebar did not become light: $dark -> $light" }
            $result.checks += @{ name = 'dark-to-light'; darkLuminance = $dark; lightLuminance = $light; savedTheme = 'light' }
        }
        'chat-tables' {
            $command = 'powershell -nop -c "''250c 2500 252c 2500 2510'',''2502 0041 2502 0042 2502'',''251c 2500 253c 2500 2524'',''2502 0031 2502 0032 2502'',''2514 2500 2534 2500 2518''|ForEach-Object{-join($_.Split('' '')|ForEach-Object{[char][Convert]::ToInt32($_,16)})}"'
            $command += ' && echo table-ready>"' + (Join-Path $scratch 'table-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print table and persist console completion marker in CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'table-ready.txt') } 'real console table command completed'
            Press @(0x12, 0x43) 'Alt+C: open formatted Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_tab -ge 0 -and $state.active_tab -lt @($state.tabs).Count } 'saved initial table tab'
            $tableTab = (Read-Session).active_tab
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Test-Path $log) -and ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE rows=1 columns=2 .*source=box' } 'formatted table built from real console output'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'Chat View preference persisted for table tab'
            Snapshot 'before'
            $buildsBefore = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create another real CMD tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 -and (Read-Session).active_tab -ne $tableTab } 'new CMD tab active and saved'
            Snapshot 'away'
            $awayLogLength = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x10, 0x09) 'Ctrl+Shift+Tab: return to table Chat View'
            Wait-Until { (Read-Session).active_tab -eq $tableTab -and (Read-Session).tabs[$tableTab].cv } 'original Chat View tab active again'
            Wait-Until { $text = (Get-Content $log -Raw) -join ''; $text.Length -gt $awayLogLength -and $text.Substring($awayLogLength) -match '\[switch\] chat painted in' } 'returned Chat View painted'
            Snapshot 'after'
            $buildsAfter = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            if ($buildsAfter -ne $buildsBefore) { throw "Unchanged table rebuilt across tab switch: $buildsBefore -> $buildsAfter" }
            $result.checks += @{ name = 'console-table-switch-return'; tableTab = $tableTab; buildsBefore = $buildsBefore; buildsAfter = $buildsAfter; marker = (Get-Content (Join-Path $scratch 'table-ready.txt') -Raw).Trim(); chatViewSaved = $true }
        }
        'chat-code-font' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'A real CMD prints a fenced code block that Chat View formats from console text; diff previews only come from an agent transcript, so their rows are proven by the branch painter image' }
            $cells = 40
            $sizeCheck = @{ name = 'IGSH-678 code cell size'; passed = $false; cells = $cells }
            $faceCheck = @{ name = 'IGSH-678 code font face and size'; passed = $false }
            $edgeCheck = @{ name = 'IGSH-678 code edges'; passed = $false }
            $painterCheck = @{ name = 'IGSH-678 diff rows smooth on green and red'; passed = $false }
            $result.checks += $sizeCheck
            $result.checks += $faceCheck
            $result.checks += $edgeCheck
            $result.checks += $painterCheck
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist default UI size before Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial tab before Chat View'
            $baseline = Read-Session
            if ($baseline.PSObject.Properties['ui_scale'] -and $baseline.ui_scale -ne 100) { throw 'Chat code font baseline UI size is not 100' }
            Save-Json $baseline 'session-before.json'
            $defaultSource = Get-Content (Join-Path $PSScriptRoot '../../../src/app_state.zig') -Raw
            if ($defaultSource -notmatch 'CHAT_FONT_DEFAULT_PT: i32 = (\d+);') { throw 'Default Chat View text size not found in source' }
            $chatPt = if ($baseline.PSObject.Properties['chat_font_pt']) { [int]$baseline.chat_font_pt } else { [int]$Matches[1] }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            if ($dpi -eq 0) { throw 'Main window DPI unavailable' }
            $expectedEm = [int][Math]::Floor([Math]::Max(8, $chatPt - 3) * 100 * $dpi / 9600)
            $previousEm = [int][Math]::Floor([Math]::Max(8, $chatPt - 1) * 100 * $dpi / 9600)
            $bodyEm = [int][Math]::Floor($chatPt * 100 * $dpi / 9600)
            $expectedAdvance = [int][Math]::Floor($expectedEm * 600 / 1000 + 0.5)
            $previousAdvance = [int][Math]::Floor($previousEm * 600 / 1000 + 0.5)
            $sizeCheck.chatPt = $chatPt
            $sizeCheck.dpi = $dpi
            $sizeCheck.expectedEm = $expectedEm
            $sizeCheck.previousEm = $previousEm
            $sizeCheck.bodyEm = $bodyEm
            $sizeCheck.expectedAdvance = $expectedAdvance
            $sizeCheck.previousAdvance = $previousAdvance
            $command = 'powershell -nop -c "''Body text for the code size check'';([string][char]96)*3;''a''+([string][char]0x2588)*' + $cells + ';''let answer = 42;'';([string][char]96)*3"'
            $command += ' && echo code-ready>"' + (Join-Path $scratch 'code-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print a fenced code block in the real CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'code-ready.txt') } 'real console code block command completed'
            Snapshot 'action'
            Press @(0x12, 0x43) 'Alt+C: open Chat View on the code block'
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View enabled in app-written session'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                $script:transcript = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
                $script:transcript.Count -eq 1
            } 'visible native Chat View transcript control'
            Save-Json (Read-Session) 'session-opened.json'
            $frame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Window rectangle unavailable' }
            $bounds = $script:transcript[0].Current.BoundingRectangle
            $area = @{ left = [int]$bounds.Left - $frame.Left; top = [int]$bounds.Top - $frame.Top; right = [int]$bounds.Right - $frame.Left; bottom = [int]$bounds.Bottom - $frame.Top }
            Wait-Until {
                Snapshot 'after'
                $script:codeBar = [CodeFontProof]::Bar((Join-Path $Evidence 'after.png'), $area.left, $area.top, $area.right, $area.bottom, $cells)
                $true
            } 'IGSH-678 fenced code block painted and measurable in Chat View' 20 1000
            $bar = $script:codeBar
            $measuredAdvance = $bar.width / $cells
            $sizeCheck.bar = $bar
            $sizeCheck.measuredAdvance = $measuredAdvance
            $cropTop = $bar.top - 3 * $expectedEm
            $cropBottom = $bar.top + 3 * $expectedEm
            $cropRight = $bar.right + 16
            [CodeFontProof]::Crop((Join-Path $Evidence 'after.png'), (Join-Path $Evidence 'code-crop-4x.png'), ($bar.left - 16), $cropTop, $cropRight, $cropBottom, 4)
            $textTop = $bar.top + $bar.rows + 1
            $edges = [CodeFontProof]::Edges((Join-Path $Evidence 'after.png'), $bar.left, $textTop, ($bar.left + 16 * $previousAdvance), ($textTop + [int](1.6 * $previousEm)))
            $edgeCheck.crop = 'code-crop-4x.png'
            $edgeCheck.textRow = @{ left = $bar.left; top = $textTop; right = $bar.left + 16 * $previousAdvance; bottom = $textTop + [int](1.6 * $previousEm) }
            $edgeCheck.measurement = $edges
            $edgeCheck.passed = $edges.partialPixels -gt 0 -and $edges.inkPixels -gt 0
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logText = if (Test-Path $log) { (Get-Content $log -Raw) -join '' } else { '' }
            $codeLines = @([regex]::Matches($logText, '\[chatcode\] face=(.+?) em=(\d+) advance=(\d+) body_em=(\d+) pt=(\d+)'))
            $faceCheck.logLines = $codeLines.Count
            if ($codeLines.Count -gt 0) {
                $last = $codeLines[$codeLines.Count - 1].Groups
                $faceCheck.face = $last[1].Value
                $faceCheck.em = [int]$last[2].Value
                $faceCheck.advance = [int]$last[3].Value
                $faceCheck.bodyEm = [int]$last[4].Value
                $faceCheck.chatPt = [int]$last[5].Value
            }
            $faceCheck.expectedFace = 'Nordwand Mono MP SemiBold'
            $faceCheck.expectedEm = $expectedEm
            $faceCheck.previousEm = $previousEm
            $proofPath = Join-Path $Evidence 'chat-code-proof-summary.json'
            if ($env:RELEASE_TAG) {
                $painterCheck.skipped = 'Release executables are verified live only; the painter image is built from branch source'
            } elseif (Test-Path $proofPath) {
                $painter = Get-Content $proofPath -Raw | ConvertFrom-Json
                $painterCheck.summary = $painter
                $painterCheck.passed = $painter.passed -eq $true
            } else {
                $painterCheck.error = 'Branch painter proof summary missing'
            }
            if ([Math]::Abs($bar.width - $cells * $expectedAdvance) -gt 3) {
                $sizeCheck.error = "Code cells measure $measuredAdvance px; expected $expectedAdvance px for $expectedEm px Nordwand Mono (previous size $previousEm px draws $previousAdvance px cells)"
                throw ('IGSH-678 code size: ' + $sizeCheck.error)
            }
            $sizeCheck.passed = $true
            if ($codeLines.Count -eq 0) {
                $faceCheck.error = 'The app logged no selected Chat View code font'
                throw ('IGSH-678 code font: ' + $faceCheck.error)
            }
            if ($faceCheck.face -cne $faceCheck.expectedFace -or $faceCheck.em -ne $expectedEm -or $faceCheck.em -ne $previousEm - 2 -or $faceCheck.em -ge $faceCheck.bodyEm -or $faceCheck.advance -ne $expectedAdvance) {
                $faceCheck.error = "Selected $($faceCheck.face) at $($faceCheck.em) px with $($faceCheck.advance) px cells and $($faceCheck.bodyEm) px body text"
                throw ('IGSH-678 code font: ' + $faceCheck.error)
            }
            $faceCheck.passed = $true
            if (-not $edgeCheck.passed) { throw 'IGSH-678 code edges: no antialiased code pixels in the Chat View crop' }
            if (-not $env:RELEASE_TAG -and -not $painterCheck.passed) { throw 'IGSH-678 diff rows: branch painter proof did not pass' }
        }
        'sessions' {
            $before = @( (Read-Session).tabs ).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New CMD shell'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $before + 1 } 'new CMD tab saved'
            Press @(0x71) 'F2: rename active tab'
            Press @(0x11, 0x41) 'Ctrl+A: replace tab name'
            Type-Text 'Verification session'
            Press @(0x0D) 'Enter: save tab name'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -eq 'Verification session' }).Count -eq 1 } 'renamed tab persisted'
            $marker = Join-Path $scratch 'user-created.txt'
            Type-Text ('echo verified-from-real-cmd>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute shell command'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq 'verified-from-real-cmd' } 'real console command wrote file'
            $result.checks += @{ name = 'create-rename-execute'; tabsBefore = $before; tabsAfter = @((Read-Session).tabs).Count; marker = (Get-Content $marker -Raw).Trim() }
            Snapshot 'after'
        }
        'session-restore' {
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'initial restore finished before keyboard creation' 60
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep creation order before grouping restore sessions'
            $before = (Read-Session).workspace_count
            Press @(0x11, 0x4E) 'Ctrl+N: create a different workspace with its first CMD session'
            Wait-Until { $script:createdSession = Read-Session; $null -ne $script:createdSession -and $script:createdSession.workspace_count -eq $before + 1 } 'new workspace persisted'
            $workspace = $script:createdSession.active_workspace
            $workspaceId = $script:createdSession.workspaces[$workspace].wid
            if ($workspace -eq 0 -or [string]::IsNullOrWhiteSpace($workspaceId)) { throw 'Expected a distinct named workspace identity' }
            $names = @('Restore first', 'Restore middle', 'Restore last')
            for ($i = 0; $i -lt $names.Count; $i++) {
                if ($i -gt 0) {
                    $tabsBefore = @((Read-Session).tabs).Count
                    Focus-Palette 'new cmd' 2000
                    Press @(0x0D) 'Enter: New CMD shell for restore'
                    Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 } 'new local CMD session saved'
                }
                Press @(0x71) 'F2: name the restore session'
                Press @(0x11, 0x41) 'Ctrl+A: replace restore session name'
                Type-Text $names[$i]
                Press @(0x0D) 'Enter: save restore session name'
                Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq $names[$i] -and $_.kind -ceq 'cmd' }).Count -eq 1 } 'unique local CMD name persisted'
                if ($i -lt 2) {
                    Focus-Palette 'move to group' 6301
                    Press @(0x0D) 'Enter: Move to Group submenu for the active restore session'
                    $groupQuery = if ($i -eq 0) { 'new group' } else { 'Group 1' }
                    $groupTarget = if ($i -eq 0) { 6303 } else { 6320 }
                    Type-Text $groupQuery
                    Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match ('\[palette\] ready chars=' + $groupQuery.Length + ' count=[1-9]\d* target=' + $groupTarget + '(?:\r?\n|$)') } 'group submenu query selects the existing UI action'
                    Press @(0x0D) 'Enter: assign the active restore session to its home sidebar group'
                    Wait-Until {
                        $saved = Read-Session
                        $saved.PSObject.Properties['groups'] -and @($saved.groups).Count -eq 1 -and $saved.groups[0].name -ceq 'Group 1' -and
                            @($saved.tabs | Where-Object { $_.name -ceq $names[$i] -and $_.PSObject.Properties['group_id'] -and $_.group_id -eq $saved.groups[0].id }).Count -eq 1
                    } 'home group membership persisted through real palette input'
                }
                if ($i -ne 1) {
                    Press @(0x12, 0x53) 'Alt+S: favorite the reorder companion session'
                    Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq $names[$i] -and $_.favorite -eq $true }).Count -eq 1 } 'reorder companion favorite persisted'
                }
            }
            $tabs = @((Read-Session).tabs)
            $middleIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
            if ($middleIndex -lt 0) { throw 'Middle session missing from saved tabs' }
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the middle session by name'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId
            Press @(0x12, 0x53) 'Alt+S: favorite the middle restore session'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'middle favorite persisted'
            Press @(0x12, 0x31) 'Alt+1: open the Starred workspace'
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the favorite in Starred'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Snapshot 'action'
            Press @(0x12, 0x32) 'Alt+2: open workspace A before updater restart'
            Wait-Until {
                $state = Read-Inbox
                $saved = Read-Session
                $null -ne $state -and $null -ne $saved -and $state.active_workspace -eq 0 -and
                    $saved.active_workspace -eq 0 -and $state.starred_view -eq $false -and $saved.starred_view -eq $false
            } 'workspace A active before updater Starred selection'
            Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A before updater restart'
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the workspace B favorite by name before updater restart'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Prepare-SessionRestoreGroupOrder 'update-restart'
            Snapshot 'update-restart-action'
            Restart-SessionRestore 'update-restart' $false $true
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.workspace -eq $workspace -and $_.favorite -eq $true }).Count -eq 1 } 'updater favorite retains its original home and favorite flag'
            Save-Json (Read-Inbox) 'update-restart-after.inbox.json'
            Save-Json (Read-Session) 'update-restart-after.session.json'
            Snapshot 'update-restart-after'
            $result.checks += @{ name = 'update-restart-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view; shellId = (Read-Inbox).active_shell_id }
            Prepare-SessionRestoreGroupOrder 'normal-close'
            Snapshot 'action'
            Restart-SessionRestore 'normal-close' $false
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'favorite retained after Starred restore'
            Save-Json (Read-Inbox) 'normal-close-after.inbox.json'
            Save-Json (Read-Session) 'normal-close-after.session.json'
            Snapshot 'normal-close-after'
            $result.checks += @{ name = 'normal-close-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; shellId = (Read-Inbox).active_shell_id }
            $result.checks += @{ name = 'starred-view-selection'; session = 'Restore middle'; starred_view = (Read-Inbox).starred_view }
            Wait-Until {
                Doctor
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'normal-close hook-ready owned foreground before workspace input'
            Press @([byte]0x12, [byte](0x32 + $workspace)) 'Alt+workspace digit: return to the favorite home workspace'
            Wait-Until {
                $state = Read-Inbox
                $null -ne $state -and $state.active_workspace -eq $workspace -and $state.starred_view -eq $false
            } 'favorite home workspace active outside Starred before palette input'
            $tabs = @((Read-Session).tabs)
            $middleIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
            if ($middleIndex -lt 0) { throw 'Favorite session missing after normal close' }
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the same favorite in its home workspace'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false
            Snapshot 'favorite-home-action'
            Restart-SessionRestore 'favorite-home-kill' $true
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'same session remains a favorite at home after kill'
            Save-Json (Read-Inbox) 'favorite-home-kill-after.inbox.json'
            Save-Json (Read-Session) 'favorite-home-kill-after.session.json'
            Snapshot 'favorite-home-kill-after'
            $result.checks += @{ name = 'favorite-home-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view }
            $tabs = @((Read-Session).tabs)
            $firstIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore first') { $firstIndex = $i } }
            if ($firstIndex -lt 0) { throw 'First session missing from saved tabs' }
            Wait-Until {
                Doctor
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'favorite-home-kill hook-ready owned foreground before palette input'
            Focus-Palette 'Restore first' $firstIndex
            Press @(0x0D) 'Enter: select a different named session before the kill'
            Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId
            Snapshot 'kill-action'
            Restart-SessionRestore 'process-kill' $true
            Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId
            Save-Json (Read-Inbox) 'process-kill-after.inbox.json'
            Save-Json (Read-Session) 'process-kill-after.session.json'
            $result.checks += @{ name = 'process-kill-selection'; session = 'Restore first'; workspace = $workspace; workspaceId = $workspaceId; shellId = (Read-Inbox).active_shell_id }
            foreach ($stage in @('favorite-cross-workspace-close', 'favorite-cross-workspace-kill')) {
                Wait-Until {
                    Doctor
                    [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
                } "$stage hook-ready owned foreground before workspace input"
                Press @(0x12, 0x32) 'Alt+2: open workspace A, not the favorite home workspace B'
                Wait-Until {
                    $state = Read-Inbox
                    $saved = Read-Session
                    $null -ne $state -and $null -ne $saved -and $state.active_workspace -eq 0 -and
                        $saved.active_workspace -eq 0 -and $state.starred_view -eq $false -and $saved.starred_view -eq $false
                } 'workspace A active before opening Starred from outside the favorite home'
                Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A'
                $tabs = @((Read-Session).tabs)
                $middleIndex = -1
                for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
                if ($middleIndex -lt 0) { throw 'Cross-workspace favorite missing from saved tabs' }
                Focus-Palette 'Restore middle' $middleIndex
                Press @(0x0D) 'Enter: select the workspace B favorite by name in Starred'
                Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
                Prepare-SessionRestoreGroupOrder $stage
                Restart-SessionRestore $stage ($stage -eq 'favorite-cross-workspace-kill')
                Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
                Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.workspace -eq $workspace -and $_.favorite -eq $true }).Count -eq 1 } 'cross-workspace favorite retains its original home and favorite flag'
                Save-Json (Read-Inbox) ($stage + '-after.inbox.json')
                Save-Json (Read-Session) ($stage + '-after.session.json')
                Snapshot ($stage + '-after')
            }
            $result.checks += @{ name = 'favorite-cross-workspace-selection'; session = 'Restore middle'; openedFromWorkspace = 0; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view }
            $requiredChecks = @('normal-close-selection', 'starred-view-selection', 'favorite-home-selection', 'process-kill-selection', 'favorite-cross-workspace-selection', 'update-restart-selection')
            foreach ($check in $requiredChecks) {
                if (@($result.checks | Where-Object { $_.name -ceq $check }).Count -ne 1) { throw "Required session restore check missing or duplicated: $check" }
            }
            if ($result.checks.Count -ne $requiredChecks.Count) { throw 'All selection and workspace-view restore checks are required' }
            Snapshot 'after'
        }
        'workspaces' {
            $before = (Read-Session).workspace_count
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create workspace'
            Wait-Until { (Read-Session).workspace_count -eq $before + 1 } 'workspace and CMD tab persisted'
            Snapshot 'created'
            $created = (Read-Session).active_workspace
            Press @(0x12, 0x32) 'Alt+2: return to first stored workspace'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'first workspace active'
            Press @(0x12, 0x27) 'Alt+Right: cycle to new workspace'
            Wait-Until { (Read-Session).active_workspace -eq $created } 'new workspace active again'
            $result.checks += @{ name = 'create-switch-return'; workspacesBefore = $before; workspacesAfter = (Read-Session).workspace_count; activeWorkspace = $created; title = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        }
        'favorites-groups' {
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.single_window -and $state.active_workspace -eq 0 -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -ceq 'cmd' } 'initial CMD session saved in first workspace'
            $initial = Read-Session
            $tabIndex = $initial.active_tab
            if ($tabIndex -ne 0 -or ($initial.tabs[$tabIndex].PSObject.Properties['favorite'] -and $initial.tabs[$tabIndex].favorite)) { throw 'Favorites journey requires the fresh unstarred CMD session' }
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            Press @(0x12, 0x53) 'Alt+S: favorite initial CMD session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$tabIndex].favorite -eq $true } 'favorite true saved in session.json'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu in home workspace'
            Type-Text 'new group'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New home group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and $newGroups[0].id -gt 0 -and $state.tabs[$tabIndex].group_id -eq $newGroups[0].id
            } 'new home group H persisted on original tab'
            $homeState = Read-Session
            $homeGroupId = $homeState.tabs[$tabIndex].group_id
            $homeGroupIds = @($homeState.groups | ForEach-Object { $_.id })
            Press @(0x1B) 'Escape: finish home group inline rename without changing its name'
            Press @(0x12, 0x31) 'Alt+1: Starred workspace'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu in Starred workspace'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New Favorites group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.tabs[$tabIndex].PSObject.Properties['starred_group_id']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $homeGroupIds })
                $newGroups.Count -eq 1 -and $newGroups[0].id -gt 0 -and $newGroups[0].id -ne $homeGroupId -and $state.tabs[$tabIndex].group_id -eq $homeGroupId -and $state.tabs[$tabIndex].starred_group_id -eq $newGroups[0].id
            } 'independent Favorites group F saved while home group stays H'
            $starred = Read-Session
            $favoritesGroupId = $starred.tabs[$tabIndex].starred_group_id
            Save-Json $starred 'session-starred-grouped.json'
            Press @(0x1B) 'Escape: finish Favorites group inline rename without changing its name'
            Snapshot 'starred-grouped'
            Press @(0x12, 0x32) 'Alt+2: return to home workspace'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.active_workspace -eq 0 -and $state.active_tab -eq $tabIndex -and $state.tabs[$tabIndex].group_id -eq $homeGroupId -and $state.tabs[$tabIndex].starred_group_id -eq $favoritesGroupId -and $state.tabs[$tabIndex].favorite -eq $true
            } 'home return retains H and independent Favorites F'
            Save-Json (Read-Session) 'session-home-returned.json'
            Snapshot 'after'
            $result.checks += @{ name = 'favorites-groups-independent'; group_id = $homeGroupId; starred_group_id = $favoritesGroupId; tab = $tabIndex }
        }
        'session-open' {
            $result.sshBoundary = @{ verified = $false; expected = 'No remote credentials or tmux server are supplied; only background tab creation and idempotency are verified'; observed = 'pending'; tabRemoved = $null }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            if (@($initial.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' }).Count -ne 0) { throw 'verify-1 already exists before the journey' }
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            $groupCount = $initialGroupIds.Count
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Snapshot 'group-action'
            Press @(0x0D) 'Enter: New group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($newGroups[0].name) -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'user-created group name and original tab membership saved'
            $baseline = Read-Session
            $group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $result.groupSetup = @{ name = $group.name; id = $group.id; customNameExercised = $false; reason = 'Palette creation does not reliably focus an inline rename editor; using the default name read from session.json' }
            Record ('Use persisted group ' + $group.name + '; custom name path not exercised')
            $workspaceBefore = $baseline.active_workspace
            $activeTabBefore = $baseline.active_tab
            $activeBefore = $baseline.tabs[$activeTabBefore]
            if ($activeBefore.group_id -ne $group.id) { throw 'New group does not contain the original active tab' }
            $titleBefore = [VerifyNative]::Title($script:window)
            $foregroundBefore = [VerifyNative]::GetForegroundWindow()
            $foregroundTitleBefore = [VerifyNative]::Title($foregroundBefore)
            Save-Json $baseline 'session-before.json'
            Snapshot 'before'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
            $workspaceName = $baseline.workspaces[$workspaceBefore].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($workspaceBefore + 1) }
            $workspaces = @($listed.workspaces | Where-Object { $_.id -eq $workspaceBefore -and $_.name -ceq $workspaceName -and $_.active -eq $true })
            if ($workspaces.Count -ne 1) { throw 'workspace-list did not report the saved active workspace' }
            $listedGroups = @($workspaces[0].groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name })
            if ($listedGroups.Count -ne 1) { throw 'workspace-list did not report the user-created group' }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
            $hostName = $listed.hosts[0]
            $openArgs = @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $hostName, '--tmux', 'verify-1', '--name', 'Verify 1')
            $assertSaved = {
                $state = Read-Session
                if ($null -eq $state) { throw 'session.json is not readable' }
                $tabs = @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' })
                if ($tabs.Count -ne 1 -or @($state.tabs).Count -ne @($baseline.tabs).Count + 1) { throw 'Expected exactly one new verify-1 tab' }
                $tab = $tabs[0]
                $tabWorkspace = 0
                if ($tab.PSObject.Properties['workspace']) { $tabWorkspace = $tab.workspace }
                if ($tab.kind -cne 'tmux' -or $tab.name -cne 'Verify 1' -or $tab.group_id -ne $group.id -or $tabWorkspace -ne $workspaceBefore) { throw 'Saved tmux tab title, group or workspace mismatch' }
                if (@($state.groups).Count -ne $groupCount + 1 -or @($state.groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name }).Count -ne 1) { throw 'Saved group changed' }
                if ($state.active_workspace -ne $workspaceBefore -or $state.active_tab -ne $activeTabBefore -or $state.tabs[$activeTabBefore].name -cne $activeBefore.name -or $state.tabs[$activeTabBefore].kind -cne $activeBefore.kind) { throw 'Background request changed the active workspace or active tab' }
                if ([VerifyNative]::GetForegroundWindow() -ne $foregroundBefore -or [VerifyNative]::Title($foregroundBefore) -cne $foregroundTitleBefore -or [VerifyNative]::Title($script:window) -cne $titleBefore) { throw 'Background request changed foreground window or title' }
                $script:sessionOpenSaved = $state
                return $true
            }
            Snapshot 'action'
            $created = Invoke-Zsb $openArgs $script:zsbPort 'session-open-created'
            if ($created.created -ne $true -or $created.tab -le 0) { throw 'session-open did not reply ok/created with a tab ID' }
            Wait-Until $assertSaved 'exact saved background tab and unchanged selection after creation'
            Save-Json $script:sessionOpenSaved 'session-created.json'
            $repeated = Invoke-Zsb $openArgs $script:zsbPort 'session-open-repeated'
            if ($repeated.existing -ne $true -or $repeated.tab -ne $created.tab -or $repeated.workspace -cne $workspaceName) { throw 'Repeated session-open was not an existing:true no-op for the same tab and workspace' }
            Wait-Until $assertSaved 'repeat no-op with exactly one saved tab and unchanged selection'
            Save-Json $script:sessionOpenSaved 'session-repeated.json'
            $script:sshFailure = $null
            Wait-Until {
                $failure = [regex]::Match(((Get-Content $log -Raw) -join ''), ('ssh-reconnect disconnect id=' + $created.tab + ' reason=(process-exit-event|process-exit-poll|startup-console-missing) exit_code=(\d+) known=true'))
                if (-not $failure.Success -or [uint64]$failure.Groups[2].Value -in @(0, 259)) { return $false }
                $script:sshFailure = @{ reason = $failure.Groups[1].Value; exitCode = [uint64]$failure.Groups[2].Value; logLine = $failure.Value }
                return $true
            } 'observed failed SSH attach for the created tab' 60
            $result.sshBoundary.observed = $script:sshFailure
            Wait-Until $assertSaved 'failed SSH tab preserved in saved state with unchanged active tab and foreground'
            $result.sshBoundary.tabRemoved = $false
            Save-Json $script:sessionOpenSaved 'session-after.json'
            $result.checks += @{ name = 'session-open-background-idempotent'; workspace = $workspaceName; group = $group.name; groupId = $group.id; host = $hostName; port = $script:zsbPort; created = $created; repeated = $repeated; tmux = 'verify-1'; title = 'Verify 1'; matchingTabs = 1; tabsBefore = @($baseline.tabs).Count; tabsAfter = @($script:sessionOpenSaved.tabs).Count; activeWorkspaceBefore = $workspaceBefore; activeWorkspaceAfter = $script:sessionOpenSaved.active_workspace; activeTabBefore = $activeTabBefore; activeTabAfter = $script:sessionOpenSaved.active_tab; foregroundBefore = $foregroundBefore.ToInt64(); foregroundAfter = [VerifyNative]::GetForegroundWindow().ToInt64(); windowTitleBefore = $titleBefore; windowTitleAfter = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        }
        'workspace-focus' {
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'initial CMD session saved' 60
            $initial = Read-Session
            if ($initial.active_workspace -ne 0 -or $initial.workspace_count -ne 1) { throw 'Expected one initial stored workspace' }
            $initialTab = $initial.active_tab
            Wait-WorkspaceSurface 0 $initialTab $false
            if ($initial.hide_pills) {
                Focus-Palette 'workspace switcher' 6213
                Press @(0x0D) 'Enter: show workspace switcher'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills -and -not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -and -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)
            } 'workspace switcher shown and saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            Snapshot 'pills-ready'
            Focus-Palette 'clear always view for this session' 6466
            Press @(0x0D) 'Enter: clear Always view for the test session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and -not $state.PSObject.Properties['chat_view_mode'] -and -not $state.tabs[$initialTab].PSObject.Properties['chat_view_lock']
            } 'unlocked per-session Chat View saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            $tab = (Read-Session).tabs[$initialTab]
            if (-not ($tab.PSObject.Properties.Name -contains 'cv' -and $tab.cv)) {
                Press @(0x12, 0x43) 'Alt+C: enable Chat View for the test session'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv
            } 'test session Chat View enabled'
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
            Wait-Until {
                $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                $null -ne $candidate -and $candidate.Current.ProcessId -eq $process.Id -and -not $candidate.Current.IsOffscreen -and $candidate.Current.NativeWindowHandle -ne 0
            } 'owned Chat View typing box visible' 30
            $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
            $composerHandle = $composer.Current.NativeWindowHandle
            if ([VerifyNative]::GetAncestor([IntPtr]$composerHandle, 2) -ne $script:window) { throw 'Chat View typing box is not in the owned window' }
            Record 'Setup: foreground owned Chat View before focus regression'
            [void][VerifyNative]::ShowWindow($script:window, 9)
            [void][VerifyNative]::SetForegroundWindow($script:window)
            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'foreground Chat View frame'
            Wait-Until {
                $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
                $focused.Current.ProcessId -eq $process.Id -and $focused.Current.NativeWindowHandle -eq $composerHandle
            } 'owned Chat View typing box focused'
            Type-Text 'before-'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq 'before-'
            } 'initial text landed in Chat View typing box'
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create second workspace'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.workspace_count -eq $initial.workspace_count + 1 -and $state.active_workspace -eq 1 -and $state.active_tab -ne $initialTab -and $state.tabs[$state.active_tab].workspace -eq 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'second workspace and distinct CMD session saved'
            $second = (Read-Session).active_workspace
            $secondTab = (Read-Session).active_tab
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x32) 'Alt+2: return to first workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Press @(0x12, 0x27) 'Alt+Right: leave Chat View workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to Chat View workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text 'workspace-focus-chat'
            $expectedText = 'before-workspace-focus-chat'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq $expectedText
            } 'text landed in Chat View typing box without a click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            if ($focused.Current.NativeWindowHandle -ne $composerHandle) { throw 'Chat View typing box did not retain keyboard focus' }
            $chatState = Read-Session
            if ($chatState.active_tab -ne $initialTab -or $chatState.workspaces[0].focus -ne 'chat') { throw 'Chat focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-chat'; text = $expectedText; composer = $composerHandle; activeTab = $chatState.active_tab; savedFocus = $chatState.workspaces[0].focus }
            Write-Output 'workspace-focus chat PASS'
            Snapshot 'chat-returned'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text '-pill'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq ($expectedText + '-pill')
            } 'pill return restored Chat View input without a composer click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            $pillState = Read-Session
            if ($focused.Current.NativeWindowHandle -ne $composerHandle -or $pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'chat') { throw 'Pill return lost Chat View focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-chat-pill'; text = ($expectedText + '-pill'); composer = $composerHandle; activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus chat pill PASS'
            Press @(0x12, 0x43) 'Alt+C: switch to shell console'
            Wait-WorkspaceSurface 0 $initialTab $false
            $pillMarker = Join-Path $scratch 'workspace-focus-shell-pill.txt'
            if (Test-Path $pillMarker) { throw 'Pill shell marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell-pill'
            Wait-ConsoleText 'echo workspace-focus-shell-pill'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            if ((Read-Session).workspaces[0].focus -ne 'shell') { throw 'Pill mouse-down did not capture the newly selected shell surface' }
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $pillMarker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell-pill>"' + $pillMarker + '"')
            Press @(0x0D) 'Enter: execute in pill-restored shell without a console click'
            Wait-Until { (Test-Path $pillMarker) -and (Get-Content $pillMarker -Raw).Trim() -ceq 'workspace-focus-shell-pill' } 'pill-restored console executed typed command'
            $pillState = Read-Session
            if ($pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'shell') { throw 'Pill return lost shell focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-shell-pill'; marker = (Get-Content $pillMarker -Raw).Trim(); activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus shell pill PASS'
            Wait-WorkspaceSurface 0 $initialTab $false
            $marker = Join-Path $scratch 'workspace-focus-shell.txt'
            if (Test-Path $marker) { throw 'Shell focus marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell'
            Wait-ConsoleText 'echo workspace-focus-shell'
            Press @(0x12, 0x27) 'Alt+Right: leave shell workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to shell workspace'
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $marker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute in restored shell without a click'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -ceq 'workspace-focus-shell' } 'restored console executed the typed command'
            $shellState = Read-Session
            if ($shellState.active_tab -ne $initialTab -or $shellState.workspaces[0].focus -ne 'shell') { throw 'Shell focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-shell'; marker = (Get-Content $marker -Raw).Trim(); activeTab = $shellState.active_tab; savedFocus = $shellState.workspaces[0].focus }
            Write-Output 'workspace-focus shell PASS'
            Snapshot 'after'
        }
        'chat-view' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'The fresh offline CMD has no signed-in agent or received conversation; the separate native painter proof uses a synthetic envelope without seeding app state' }
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist default UI size before Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial tab before Chat View'
            $baseline = Read-Session
            if ($baseline.PSObject.Properties['ui_scale'] -and $baseline.ui_scale -ne 100) { throw 'Chat View baseline UI size is not 100' }
            Save-Json $baseline 'session-before.json'
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View enabled in app-written session'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count -eq 1
            } 'visible native Chat View transcript control'
            Save-Json (Read-Session) 'session-opened.json'
            Snapshot 'action'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before closing'
            Press @(0x12, 0x43) 'Alt+C: close Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                -not $state.tabs[$state.active_tab].PSObject.Properties['cv'] -or $state.tabs[$state.active_tab].cv -eq $false
            } 'Chat View disabled in app-written session'
            Save-Json (Read-Session) 'session-closed.json'
            Snapshot 'closed'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before reopening'
            Press @(0x12, 0x43) 'Alt+C: reopen Chat View'
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View re-enabled in app-written session'
            $after = Read-Session
            if ($after.active_tab -ne $baseline.active_tab -or @($after.tabs).Count -ne @($baseline.tabs).Count) { throw 'Chat View changed the selected tab or tab count' }
            Save-Json $after 'session-after.json'
            Snapshot 'after'
            $result.checks += @{ name = 'chat-view-open-close-reopen'; activeTab = $after.active_tab; tabCount = @($after.tabs).Count; savedChatView = $after.tabs[$after.active_tab].cv; entry = 'Alt+C' }
            $menuCheck = @{ name = 'message-menu'; passed = $false; reason = 'not reached' }
            $greyCheck = @{ name = 'grey-buttons'; passed = $false; reason = 'not reached' }
            $result.checks += $menuCheck
            $result.checks += $greyCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $localAgent = Join-Path (Split-Path $Exe) 'claude.exe'
            if (-not (Test-Path $localAgent)) { throw 'Local Claude console stand-in is missing' }
            $typedCheck = @{ name = 'local-route-typed'; passed = $false; entry = 'Chat View Enter'; receivedBytes = $null; queued = $false }
            $suggestionCheck = @{ name = 'local-route-suggestion'; passed = $false; entry = 'Chat View Enter'; received = '' }
            $result.checks += $typedCheck
            $result.checks += $suggestionCheck
            $outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
            $typedPrefix = Join-Path $scratch 'local-route-typed'
            $typedMessage = 'local route typed must stay queued'
            try {
                foreach ($mode in @('typed', 'suggestion')) {
                    $beforeLocal = Read-Session
                    Palette 'new cmd'
                    Press @(0x0D) 'Enter: create local console for direct-route check'
                    Wait-Until {
                        $state = Read-Session
                        @($state.tabs).Count -eq @($beforeLocal.tabs).Count + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
                    } 'new local CMD session saved'
                    $localState = Read-Session
                    $localTab = $localState.active_tab
                    if ($localState.tabs[$localTab].PSObject.Properties['cv'] -and $localState.tabs[$localTab].cv) {
                        Press @(0x12, 0x43) 'Alt+C: show new local console'
                    }
                    Wait-WorkspaceSurface $localState.active_workspace $localTab $false
                    $prefix = Join-Path $scratch ('local-route-' + $mode)
                    Type-Text ('"' + $localAgent + '" ' + $mode + ' "' + $prefix + '"')
                    Press @(0x0D) 'Enter: launch console-backed Claude stand-in'
                    Wait-Until {
                        if (-not (Test-Path ($prefix + '-ready.json'))) { return $false }
                        $script:localReady = Get-Content ($prefix + '-ready.json') -Raw | ConvertFrom-Json
                        $script:localReady.chars.Count -eq 32 -and $script:localReady.attributes.Count -eq 32
                    } 'stand-in rendered prompt and recorded console attributes'
                    $ready = $script:localReady
                    if ($ready.chars[0] -ne 0x276F -or $ready.chars[1] -ne 32) { throw 'Stand-in did not render the Claude prompt glyph and separator' }
                    if ($mode -eq 'suggestion' -and (($ready.attributes[2] -band 0x4000) -eq 0 -or ($ready.attributes[3] -band 0xF) -ne 8)) { throw 'Real console did not retain the suggestion cursor and gray foreground' }
                    Wait-Until {
                        $inbox = Read-Inbox
                        @($inbox.shells | Where-Object { $_.sid -eq $localState.tabs[$localTab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
                    } 'local claude.exe detected as Claude for the direct input route' -Seconds 45
                    Press @(0x12, 0x43) 'Alt+C: open local agent Chat View'
                    Wait-Until {
                        $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                        $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                        $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                        $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle
                    } 'owned local Chat View composer focused'
                    $message = if ($mode -eq 'typed') { $typedMessage } else { 'local route suggestion delivered' }
                    Type-Text $message
                    Press @(0x0D) 'Enter: send through normal Chat View outbox'
                    if ($mode -eq 'typed') {
                        Wait-Until {
                            if (-not (Test-Path $outboxPath)) { return $false }
                            $outbox = Get-Content $outboxPath -Raw | ConvertFrom-Json
                            @($outbox.queues.messages | Where-Object { $_.t -ceq $typedMessage -and $_.s -eq 0 -and $_.x -eq 0 }).Count -eq 1
                        } 'typed prompt keeps the Chat View message queued without starting a write'
                        $typedCheck.console = $ready
                        Snapshot 'local-route-typed'
                    } else {
                        $suggestionCheck.console = $ready
                        Wait-Until {
                            $stdin = [IO.File]::Open($prefix + '-stdin.bin', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                            try {
                                $buffer = New-Object IO.MemoryStream
                                try {
                                    $stdin.CopyTo($buffer)
                                    $receivedBytes = $buffer.ToArray()
                                } finally { $buffer.Dispose() }
                            } finally { $stdin.Dispose() }
                            $received = [Text.Encoding]::ASCII.GetString($receivedBytes)
                            $suggestionCheck.received = $received
                            $received.Contains($message) -and $received.Contains("`r")
                        } 'local suggestion prompt receives the Chat View message and Enter on stdin'
                        $suggestionCheck.passed = $true
                        Snapshot 'local-route-suggestion'
                        try {
                            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                            $transcripts = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $process.Id })
                            if ($transcripts.Count -ne 1) { throw 'Expected exactly one visible owned transcript for the message menu' }
                            $transcript = [IntPtr]$transcripts[0].Current.NativeWindowHandle
                            Wait-Until {
                                $script:messagePoint = [VerifyNative]::MessageBubblePoint($transcript)
                                $true
                            } 'painted message bubble after suggestion delivery'
                            $menuLinesBefore = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' }).Count
                            Doctor
                            Record 'Real SendInput right-click inside the owned transcript message bubble'
                            [VerifyNative]::RightClickTranscript($transcript, $process.Id, $script:window, $script:messagePoint)
                            Wait-Until {
                                $lines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' })
                                $lines.Count -gt $menuLinesBefore
                            } 'app logged the opened message menu'
                            $menuLines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' })
                            if ($menuLines.Count -ne $menuLinesBefore + 1 -or $menuLines[-1] -cnotmatch '\[chat\] message menu items=Reply,Copy$') { throw ('Unexpected message menu: ' + $menuLines[-1]) }
                            $menuCheck.items = 'Reply,Copy'
                            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'owned native message popup visible'
                            Snapshot 'message-menu'
                            Press @(0x1B) 'Esc: dismiss message menu'
                            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'no visible owned native popup after Esc'
                            $menuCheck.passed = $true
                            $menuCheck.reason = ''
                        } catch {
                            $menuCheck.reason = $_.Exception.Message
                            throw
                        }
                    }
                }
            } finally {
                if ($typedCheck.ContainsKey('console')) {
                    $typedCheck.receivedBytes = (Get-Item ($typedPrefix + '-stdin.bin')).Length
                    $outbox = Get-Content $outboxPath -Raw | ConvertFrom-Json
                    $typedCheck.queued = @($outbox.queues.messages | Where-Object { $_.t -ceq $typedMessage -and $_.s -eq 0 -and $_.x -eq 0 }).Count -eq 1
                    $typedCheck.passed = $typedCheck.receivedBytes -eq 0 -and $typedCheck.queued
                    if (-not $typedCheck.passed) { throw 'Chat View overwrote a local typed draft or stopped keeping its message queued' }
                }
            }
            $stopCheck = @{ name = 'stop-in-box'; passed = $false; entry = 'Chat View working composer'; reason = 'not reached' }
            $result.checks += $stopCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $stopPrefix = Join-Path $scratch 'local-route-working'
            $readStopFrame = {
                $frame = @{ card = $null; size = 0; send = $null; stop = $null; anyStop = $null }
                if (-not (Test-Path $debugLog)) { return $frame }
                foreach ($line in @((Get-Content $debugLog -Raw) -split "`r?`n")) {
                    if ($line -match '\[chat\] composer card (-?\d+),(-?\d+),(-?\d+),(-?\d+) size=(\d+)') {
                        $frame.card = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                        $frame.size = [int]$Matches[5]
                        $frame.send = $null
                        $frame.stop = $null
                    } elseif ($line -match '\[chat\] send rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame.send = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                    } elseif ($line -match '\[chat\] stop rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame.stop = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                        $frame.anyStop = $frame.stop
                    }
                }
                return $frame
            }
            $insideCard = { param($rect, $card) $rect[0] -ge $card[0] -and $rect[1] -ge $card[1] -and $rect[2] -le $card[2] -and $rect[3] -le $card[3] }
            try {
                $beforeStop = Read-Session
                Palette 'new cmd'
                Press @(0x0D) 'Enter: create local console for the in-box Stop check'
                Wait-Until {
                    $state = Read-Session
                    @($state.tabs).Count -eq @($beforeStop.tabs).Count + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
                } 'new local CMD session saved for the in-box Stop check'
                $stopState = Read-Session
                $stopTab = $stopState.active_tab
                if ($stopState.tabs[$stopTab].PSObject.Properties['cv'] -and $stopState.tabs[$stopTab].cv) {
                    Press @(0x12, 0x43) 'Alt+C: show new working console'
                }
                Wait-WorkspaceSurface $stopState.active_workspace $stopTab $false
                Type-Text ('"' + $localAgent + '" working "' + $stopPrefix + '"')
                Press @(0x0D) 'Enter: launch working Claude stand-in'
                Wait-Until {
                    if (-not (Test-Path ($stopPrefix + '-ready.json'))) { return $false }
                    $script:stopReady = Get-Content ($stopPrefix + '-ready.json') -Raw | ConvertFrom-Json
                    $script:stopReady.chars.Count -eq 32
                } 'working stand-in rendered its status line and empty prompt'
                if ($script:stopReady.chars[0] -ne 0x276F -or $script:stopReady.chars[1] -ne 32) { throw 'Working stand-in did not render the Claude prompt glyph and separator' }
                Wait-Until {
                    $inbox = Read-Inbox
                    @($inbox.shells | Where-Object { $_.sid -eq $stopState.tabs[$stopTab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
                } 'working claude.exe detected as Claude' -Seconds 45
                Press @(0x12, 0x43) 'Alt+C: open working agent Chat View'
                Wait-Until {
                    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                    $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                    $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle
                } 'owned working Chat View composer focused'
                Wait-Until { $null -ne (& $readStopFrame).anyStop } 'app painted a Stop control for the working agent' -Seconds 45
                $empty = & $readStopFrame
                $stopCheck.empty = $empty
                if ($null -eq $empty.card) { throw ('No composer card logged; Stop rect ' + ($empty.anyStop -join ',') + ' is not inside the message box') }
                if ($null -eq $empty.stop) { throw 'Latest composer frame has no Stop while the agent is working' }
                $stopW = $empty.stop[2] - $empty.stop[0]
                $stopH = $empty.stop[3] - $empty.stop[1]
                if ($empty.size -le 0 -or $stopW -ne $empty.size -or $stopH -ne $empty.size) { throw ('Stop rect is ' + $stopW + 'x' + $stopH + ', expected the ' + $empty.size + ' px send size') }
                if (-not (& $insideCard $empty.stop $empty.card)) { throw ('Stop rect ' + ($empty.stop -join ',') + ' is outside composer card ' + ($empty.card -join ',')) }
                if ($null -ne $empty.send) { throw ('Send rect ' + ($empty.send -join ',') + ' is drawn while the composer is empty and the agent is working') }
                Type-Text 'x'
                Wait-Until { $typed = & $readStopFrame; $null -ne $typed.card -and $null -ne $typed.send -and $null -ne $typed.stop } 'Send and Stop both drawn after typing while working'
                $typed = & $readStopFrame
                $stopCheck.typed = $typed
                if (($typed.stop[2] - $typed.stop[0]) -ne $typed.size -or ($typed.stop[3] - $typed.stop[1]) -ne $typed.size) { throw 'Stop changed size after typing' }
                if ($typed.send[2] -gt $typed.stop[0]) { throw ('Send rect ' + ($typed.send -join ',') + ' is not left of Stop rect ' + ($typed.stop -join ',')) }
                if (-not (& $insideCard $typed.send $typed.card) -or -not (& $insideCard $typed.stop $typed.card)) { throw 'Send or Stop is outside the composer card after typing' }
                Snapshot 'stop-in-box'
                Snapshot 'grey-buttons'
                Press @(0x1B) 'Esc: stop the working agent from the composer'
                Wait-Until {
                    $stdin = [IO.File]::Open($stopPrefix + '-stdin.bin', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                    try {
                        $buffer = New-Object IO.MemoryStream
                        try {
                            $stdin.CopyTo($buffer)
                            $stopBytes = $buffer.ToArray()
                        } finally { $buffer.Dispose() }
                    } finally { $stdin.Dispose() }
                    $stopCheck.receivedBytes = $stopBytes.Length
                    $stopBytes -contains [byte]0x1B
                } 'Esc reached the working stand-in stdin'
                $stopCheck.passed = $true
                $stopCheck.reason = ''
            } catch {
                $stopCheck.reason = $_.Exception.Message
                throw
            }
            try {
                $greyCheck.typed = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'grey-buttons.png'), $script:window, $typed.card, $typed.stop, $typed.send)
                $greyCheck.passed = $true
                $greyCheck.reason = ''
            } catch {
                $greyCheck.reason = $_.Exception.Message
                throw
            }
        }
        'inbox' {
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split'
            Snapshot 'action'
            $prior = (Read-Inbox).shells[0].att
            Press @(0x55) 'u: toggle selected Inbox session unread'
            Wait-Until { (Read-Inbox).shells[0].att -ne $prior } 'published attention state toggled'
            Snapshot 'after'
            $result.checks += @{ name = 'inbox-toggle-read'; attentionBefore = $prior; attentionAfter = (Read-Inbox).shells[0].att; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox closed'
            Snapshot 'returned'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create a second CMD session to mute'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 } 'second CMD session saved and selected'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells).Count -eq 2 } 'both sessions published to the Inbox'
            $sid = (Read-Session).tabs[1].shell_id
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 1 } 'current session listed before muting'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.active_tab -ge 0 -and $state.tabs[$state.active_tab].shell_id -eq $sid } 'published session is the active saved tab'
            $baseline = Read-Session
            Palette 'mute tab'
            Press @(0x0D) 'Enter: mute the current tab'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.active_tab -eq $baseline.active_tab -and
                    $state.tabs[$state.active_tab].shell_id -eq $sid -and
                    $state.tabs[$state.active_tab].PSObject.Properties['muted'] -and $state.tabs[$state.active_tab].muted -eq $true
            } 'active tab saved as muted'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 0 } 'muted session absent from published Inbox'
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox with the session muted'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'muted Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split with the session muted'
            Snapshot 'muted'
            $result.checks += @{ name = 'inbox-muted-hidden'; sid = $sid; listed = $false; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox with the session muted'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'muted Inbox closed'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq @($baseline.tabs).Count -and
                    @($state.tabs | Where-Object { $_.shell_id -eq $sid }).Count -eq 1
            } 'muted session still exists with unchanged tab count'
            Snapshot 'muted-returned'
            Palette 'unmute tab'
            Press @(0x0D) 'Enter: unmute the current tab'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 1 } 'unmuted session listed in published Inbox'
            $result.checks += @{ name = 'inbox-unmuted-listed'; sid = $sid; listed = $true }
        }
        'remind-me' {
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $presetBase = [int][regex]::Match((Get-Content (Join-Path $PSScriptRoot '../../../src/app_state.zig') -Raw), 'SEARCH_REMIND_PRESET_OFFSET: usize = (\d+);').Groups[1].Value
            if ($presetBase -le 0) { throw 'remind-me: SEARCH_REMIND_PRESET_OFFSET not found' }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            $groupCount = $initialGroupIds.Count
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($newGroups[0].name) -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'user-created group saved with the initial session'
            $baseline = Read-Session
            $group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
            $workspaceName = $baseline.workspaces[$baseline.active_workspace].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($baseline.active_workspace + 1) }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'remind-me: workspace-list reported no usable host name' }
            $created = Invoke-Zsb @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $listed.hosts[0], '--tmux', 'verify-1', '--name', 'Verify 1') $script:zsbPort 'session-open-created'
            if ($created.created -ne $true) { throw 'remind-me: session-open did not create the tmux tab' }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' }).Count -eq 1 } 'tmux tab verify-1 saved'
            Press @(0x11, 0x32) 'Ctrl+2: focus the tmux session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$state.active_tab].PSObject.Properties['tmux_session'] -and $state.tabs[$state.active_tab].tmux_session -ceq 'verify-1' } 'tmux session is the active tab'
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x48) 'Ctrl+H: open Remind Me presets'
            $expectedIds = @(0..4 + 6..12 | ForEach-Object { [string]($presetBase + $_) })
            Wait-Until {
                $trace = ((Get-Content $log -Raw) -join '').Substring($start)
                $rows = [regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)')
                if ($rows.Count -eq 0) { return $false }
                $ids = @($rows[$rows.Count - 1].Groups[1].Value -split ' ')
                @($expectedIds | Where-Object { $_ -notin $ids }).Count -eq 0
            } 'Remind Me preset rows published after Ctrl+H'
            Snapshot 'action'
            $trace = ((Get-Content $log -Raw) -join '').Substring($start)
            $pickerRows = @([regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)'))
            $pickerIds = @($pickerRows[$pickerRows.Count - 1].Groups[1].Value -split ' ')
            $stateAfter = Read-Session
            if ($stateAfter.tabs[$stateAfter.active_tab].tmux_session -cne 'verify-1' -or @($stateAfter.tabs).Count -ne @($baseline.tabs).Count + 1) { throw 'remind-me: a session was hidden or changed' }
            Snapshot 'after'
            $result.checks += @{ name = 'remind-me-ctrl-h'; entry = 'Ctrl+H'; presetBase = $presetBase; pickerRowIds = $pickerIds; sessionsBefore = @($baseline.tabs).Count; sessionsAfter = @($stateAfter.tabs).Count }
        }
        'group-rail' {
            Write-Host "group-rail verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            Select-Theme 'dark' 'group-rail-dark'
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep stable manual sidebar order'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.active_workspace -eq 0 -and $state.tabs[0].kind -eq 'cmd' } 'one initial CMD session'
            Press @(0x71) 'F2: rename first session'
            Press @(0x11, 0x41) 'Ctrl+A: replace first session name'
            Type-Text 'Rail A'
            Press @(0x0D) 'Enter: save first session name'
            Wait-Until { (Read-Session).tabs[0].name -eq 'Rail A' } 'short synthetic first name saved'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create second CMD session'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 } 'second CMD session saved and selected'
            Press @(0x71) 'F2: rename second session'
            Press @(0x11, 0x41) 'Ctrl+A: replace second session name'
            Type-Text 'Rail B'
            Press @(0x0D) 'Enter: save second session name'
            Wait-Until { (Read-Session).tabs[1].name -eq 'Rail B' } 'short synthetic second name saved'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create group for second session'
            Wait-Until { $state = Read-Session; $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[1].group_id -eq $state.groups[0].id } 'second session in new saved group'
            Press @(0x1B) 'Esc: finish default group name'
            $group = (Read-Session).groups[0]
            Press @(0x11, 0x31) 'Ctrl+1: select the original session in manual order'
            Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text $group.name
            Press @(0x0D) 'Enter: move first session into same group'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.tabs[0].group_id -eq $group.id -and $state.tabs[1].group_id -eq $group.id -and $state.active_tab -eq 0 } 'two real sessions saved in one group'
            foreach ($index in @(2, 3, 4, 5)) {
                Palette 'new cmd'
                Press @(0x0D) ('Enter: create CMD session ' + ($index + 1))
                Wait-Until { $state = Read-Session; @($state.tabs).Count -eq ($index + 1) -and $state.active_tab -eq $index } 'new CMD session saved and selected'
                Press @(0x71) 'F2: rename session'
                Press @(0x11, 0x41) 'Ctrl+A: replace session name'
                $name = 'Rail ' + [char](65 + $index)
                Type-Text $name
                Press @(0x0D) 'Enter: save short session name'
                Wait-Until { (Read-Session).tabs[$index].name -eq $name } 'short synthetic session name saved'
            }
            Press @(0x11, 0x33) 'Ctrl+3: select third session for second group'
            Wait-Until { (Read-Session).active_tab -eq 2 } 'third session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: create adjacent second group'
            Wait-Until { $state = Read-Session; @($state.groups).Count -eq 2 -and $state.tabs[2].group_id -eq $state.groups[1].id } 'third session in second saved group'
            Press @(0x1B) 'Esc: finish second default group name'
            $secondGroup = (Read-Session).groups[1]
            Press @(0x11, 0x34) 'Ctrl+4: select fourth session'
            Wait-Until { (Read-Session).active_tab -eq 3 } 'fourth session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text $secondGroup.name
            Press @(0x0D) 'Enter: move fourth session into second group'
            Wait-Until {
                $state = Read-Session
                @($state.tabs).Count -eq 6 -and @($state.groups).Count -eq 2 -and
                    $state.tabs[0].group_id -eq $group.id -and $state.tabs[1].group_id -eq $group.id -and
                    $state.tabs[2].group_id -eq $secondGroup.id -and $state.tabs[3].group_id -eq $secondGroup.id -and
                    (-not $state.tabs[4].PSObject.Properties['group_id'] -or $state.tabs[4].group_id -eq 0) -and
                    (-not $state.tabs[5].PSObject.Properties['group_id'] -or $state.tabs[5].group_id -eq 0)
            } 'two adjacent two-member groups followed by two ungrouped sessions'
            $state = Read-Session
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $leftEdge = $true
            $headerClear = $true
            $groupsSeparate = $true
            $selectedClear = $true
            $strayClear = $true
            foreach ($selected in @(0, 1)) {
                Press @(0x11, (0x31 + $selected)) ('Ctrl+' + ($selected + 1) + ': select grouped session')
                Wait-Until { (Read-Session).active_tab -eq $selected } 'grouped selection persisted'
                $shot = 'group-rail-selected-' + $selected
                Snapshot $shot
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'group-rail native geometry unavailable' }
                $proof = [GroupRailProof]::Check((Join-Path $Evidence ($shot + '.png')), $frame, $origin, $dpi, $scale, $selected)
                Save-Json @{ pixels = $proof; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; session = Read-Session; tag = $env:RELEASE_TAG; version = $ExpectedVersion } ($shot + '.json')
                $leftEdge = $leftEdge -and $proof['leftEdge']
                $headerClear = $headerClear -and $proof['headerClear']
                $groupsSeparate = $groupsSeparate -and $proof['groupsSeparate']
                $selectedClear = $selectedClear -and $proof['selectedClear']
                $strayClear = $strayClear -and $proof['strayClear']
                $result.checks += @{ name = $shot; pixels = $proof }
            }
            Snapshot 'after'
            if ($leftEdge) { Write-Host 'group-rail left-edge PASS' } else { Write-Host 'group-rail left-edge FAIL' }
            if ($headerClear) { Write-Host 'group-rail header-clear PASS' } else { Write-Host 'group-rail header-clear FAIL' }
            if ($groupsSeparate) { Write-Host 'group-rail groups-separate PASS' } else { Write-Host 'group-rail groups-separate FAIL' }
            if ($selectedClear) { Write-Host 'group-rail selected-clear PASS' } else { Write-Host 'group-rail selected-clear FAIL' }
            if ($strayClear) { Write-Host 'group-rail stray-clear PASS' } else { Write-Host 'group-rail stray-clear FAIL' }
            if (-not $leftEdge -or -not $headerClear -or -not $groupsSeparate -or -not $selectedClear -or -not $strayClear) { throw 'group-rail pixel assertions failed' }
        }
        'pane-layout' {
            Select-Theme 'dark' 'pane-layout-dark'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one real CMD session'
            $initial = Read-Session
            if ($initial.tabs[0].PSObject.Properties['cv'] -and $initial.tabs[0].cv) { throw 'pane-layout requires the console, not Chat View' }
            $script:browserShellId = (Read-Inbox).shells[0].sid
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New group containing CMD'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[0].group_id -eq $state.groups[0].id
            } 'CMD membership in the user-created gray group'
            Press @(0x1B) 'Esc: leave inline group rename using the saved default name'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create ungrouped foreground console'
            Wait-Until {
                $state = Read-Session
                @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'cmd' -and
                    (-not $state.tabs[1].PSObject.Properties['group_id'] -or $state.tabs[1].group_id -eq 0)
            } 'second CMD selected while grouped rail stays fully visible'
            $consoleTab = (Read-Session).active_tab
            $consoleShellId = (Read-Session).tabs[$consoleTab].shell_id
            $script:browserShellId = $consoleShellId
            $pane = Open-BrowserPane 'pane-layout-open'
            Press @(0x5B, 0x26) 'Win+Up: maximize main window'
            Wait-Until { [VerifyNative]::IsZoomed($script:window) } 'maximized main window'
            Press @(0x11, 0x32) 'Ctrl+2: return to the ungrouped CMD console'
            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
            $console = [VerifyNative]::GetForegroundWindow()
            $browser = [VerifyNative]::PaneWindow($script:window)
            if ($browser -eq [IntPtr]::Zero) { throw 'No visible owned docked browser HWND' }
            $consoleElement = [System.Windows.Automation.AutomationElement]::FromHandle($console)
            if ($consoleElement.Current.IsOffscreen -or $consoleElement.Current.ClassName -ne 'ConsoleWindowClass' -or
                -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $consoleShellId), [StringComparison]::Ordinal)) { throw 'UIA cannot see the owned CMD console' }
            Snapshot 'action'
            Snapshot 'pane-layout'
            $frame = New-Object VerifyNative+Rect
            $client = New-Object VerifyNative+Rect
            $consoleRect = New-Object VerifyNative+Rect
            $browserRect = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout HWND rectangles unavailable' }
            $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
            $uiaRect = $consoleElement.Current.BoundingRectangle
            if ([Math]::Abs($uiaRect.Left - $consoleRect.Left) -gt 1 -or [Math]::Abs($uiaRect.Top - $consoleRect.Top) -gt 1 -or
                [Math]::Abs($uiaRect.Right - $consoleRect.Right) -gt 1 -or [Math]::Abs($uiaRect.Bottom - $consoleRect.Bottom) -gt 1) { throw 'Console UIA and HWND bounds disagree' }
            Write-Host 'pane-layout console-uia-hwnd PASS'
            $state = Read-Session
            if ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv) { throw 'Journey accidentally entered Chat View' }
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            Save-Json @{ frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64(); dpi = $dpi; scale = $scale; session = $state } 'pane-layout-rects.json'
            $proof = [PaneLayoutProof]::Check((Join-Path $Evidence 'pane-layout.png'), $frame, $client, $consoleRect, $browserRect, $dpi, $scale)
            Save-Json $proof 'pane-layout-pixels.json'
            $result.checks += @{ name = 'pane-layout'; assertions = @('console-uia-hwnd', 'ring-found', 'ring-top', 'ring-bottom', 'ring-left', 'ring-right', 'console-inside-ring', 'clean-gap', 'group-line-found', 'row-icon-found', 'group-line-clears-icon'); pixels = $proof }
            Snapshot 'after'
        }
        'browser-switch-speed' {
            $modes = @('browser_off', 'browser_on', 'frozen_browser_on', 'chat_browser_off', 'chat_browser_on', 'chat_frozen_browser_on')
            $timings = [ordered]@{ steps = @{} }
            $traces = @{}
            foreach ($mode in $modes) {
                $sampleCount = if ($mode.Contains('frozen_')) { 5 } else { 20 }
                $timings[$mode] = @{ samples_ms = @($null) * $sampleCount; median_ms = $null; window_visible_ms = @($null) * $sampleCount; window_visible_median_ms = $null }
                $timings.steps[$mode] = $null
                $traces[$mode] = @()
            }
            $traceLines = New-Object System.Collections.ArrayList
            $frozenSwitches = New-Object System.Collections.ArrayList
            $frozenLogStart = $null
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $colors = @('#db2855', '#26b8d4')
            $rgb = @(0xDB2855, 0x26B8D4)
            $drafts = @('switch-paint-0', 'switch-paint-1')
            $composerHandle = [IntPtr]::Zero
            $gapCase = @{ name = 'switch-gap'; status = 'failed'; detail = 'Switch measurement did not complete'; phase = 'initial-console' }
            $result.checks += $gapCase
            try {
                Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one initial CMD for switch timing'
                $initial = Read-Session
                Wait-WorkspaceSurface $initial.active_workspace 0 $false
                $gapCase.phase = 'idle-close-fixture'
                Focus-Palette 'browser auto suspend' 6240
                Press @(0x0D) 'Enter: disable timed browser closing while measuring fresh tier-two freezes'
                Wait-Until { $state = Read-Session; $state.PSObject.Properties['browser_suspend_min'] -and $state.browser_suspend_min -eq 0 } 'app saved idle browser closing disabled; automatic freezing remains enabled'
                Save-Json (Read-Session) 'switch-idle-close-fixture.json'
                $gapCase.phase = 'group-setup'
                Focus-Palette 'move to group' 6301
                Press @(0x0D) 'Enter: Move to Group submenu'
                Type-Text 'new group'
                Press @(0x0D) 'Enter: New group containing timing CMD'
                Wait-Until {
                    $state = Read-Session
                    $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[0].group_id -eq $state.groups[0].id
                } 'timing CMD membership in the user-created group'
                Press @(0x1B) 'Esc: leave inline group rename using the saved default name'
                $gapCase.phase = 'second-console'
                Palette 'new cmd'
                Press @(0x0D) 'Enter: create second CMD for Ctrl+Tab timing'
                Wait-Until {
                    $state = Read-Session
                    @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'cmd' -and
                        (-not $state.tabs[1].PSObject.Properties['group_id'] -or $state.tabs[1].group_id -eq 0)
                } 'second ungrouped timing CMD saved and selected'
                $consoleTab = (Read-Session).active_tab
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                $state = Read-Session
                $consoles = @{}
                $browsers = @{}
                $docks = @{}
                $shellIds = @($state.tabs[0].shell_id, $state.tabs[1].shell_id)
                foreach ($tab in @(0, 1)) {
                    $gapCase.phase = "console-identification-$tab"
                    Press @(0x11, (0x31 + $tab)) ('Ctrl+' + ($tab + 1) + ': identify timing console')
                    Wait-WorkspaceSurface $initial.active_workspace $tab $false
                    $consoles[$tab] = [VerifyNative]::GetForegroundWindow()
                    $browsers[$tab] = [IntPtr]::Zero
                    $docks[$tab] = New-Object VerifyNative+Rect
                }
                $gapCase.phase = 'browser-off-baseline'
                if (@((Read-Inbox).shells | Where-Object { $_.browser_state -ne 'closed' }).Count -ne 0) { throw 'Browser-off baseline already has a pane' }
                $warmupStopped = $warmupJob.Stop()
                Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                $warmupJob.Dispose()
                $warmupJob = $null
                foreach ($mode in $modes) {
                    $chat = $mode.StartsWith('chat_')
                    $browserOn = $mode.EndsWith('browser_on')
                    $frozen = $mode.Contains('frozen_')
                    $sampleCount = $timings[$mode].samples_ms.Count
                    if ($mode -eq 'chat_browser_off') {
                        $gapCase.phase = 'chat-setup'
                        Focus-Palette 'clear always view for this session' 6466
                        Press @(0x0D) 'Enter: clear Always view for the switch test session'
                        Wait-Until { -not (Read-Session).PSObject.Properties['chat_view_mode'] } 'per-session Chat View mode saved'
                        foreach ($tab in @(0, 1)) {
                            Press @(0x11, (0x31 + $tab)) 'Select session to enable Chat View'
                            Wait-WorkspaceSurface $initial.active_workspace $tab $false
                            $script:browserShellId = $shellIds[$tab]
                            Press-CloseBrowserPane 'Alt+A: close browser pane for Chat View baseline'
                            $null = Assert-BrowserPane 'closed' ('chat-baseline-' + $tab)
                            $browsers[$tab] = [IntPtr]::Zero
                            Press @(0x12, 0x43) 'Alt+C: enable Chat View for this session'
                            Wait-Until { (Read-Session).tabs[$tab].cv } 'Chat View saved for this session'
                            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                            Wait-Until {
                                $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                                $null -ne $candidate -and $candidate.Current.ProcessId -eq $process.Id -and -not $candidate.Current.IsOffscreen
                            } 'owned Chat View composer visible'
                            $composerHandle = [IntPtr]($root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition).Current.NativeWindowHandle)
                            Wait-WorkspaceSurface $initial.active_workspace $tab $true ($composerHandle.ToInt32())
                            Type-Text $drafts[$tab]
                            Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq $drafts[$tab] } 'distinct unsent synthetic session draft'
                        }
                    }
                    if ($browserOn -and -not $frozen) {
                        foreach ($tab in @(0, 1)) {
                            $gapCase.phase = "$mode-setup-$tab"
                            Press @(0x11, (0x31 + $tab)) ('Ctrl+' + ($tab + 1) + ': open this session browser')
                            Wait-WorkspaceSurface $initial.active_workspace $tab $chat ($composerHandle.ToInt32())
                            $script:browserShellId = $shellIds[$tab]
                            $pane = Open-BrowserPane ($mode + '-' + $tab)
                            Wait-SwitchNativeHost
                            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero } 'connected timing browser with app-published CDP binding in its session' 30
                            $browser = [VerifyNative]::DockedPaneWindow($script:window)
                            $dock = New-Object VerifyNative+Rect
                            if (-not [VerifyNative]::GetWindowRect($browser, [ref]$dock)) { throw 'Timing browser dock rectangle unavailable' }
                            Palette 'jump browser'
                            Press @(0x0D) 'Enter: focus the session browser through the palette'
                            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $browser } 'target browser foreground for real address-bar navigation'
                            Doctor
                            if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or [VerifyNative]::DockedPaneWindow($script:window) -ne $browser) { throw 'Navigation browser ownership changed' }
                            [uint32]$browserPid = 0
                            [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
                            Record 'Focus verified session browser HWND before address-bar input'
                            [VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Ctrl+L' }
                            Record 'Ctrl+L: navigate through the native browser address bar'
                            [VerifyNative]::Chord(@(0x11, 0x4C))
                            $browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
                            $omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
                            Wait-Until {
                                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                                    [System.Windows.Automation.Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement) -and
                                    [VerifyNative]::GetForegroundWindow() -eq $browser
                            } 'verified pane native address bar has keyboard focus'
                            $pageTitle = 'Switch paint ' + $tab
                            $html = '<title>' + $pageTitle + '</title><style>html,body{margin:0;width:100%;height:100%;background:' + $colors[$tab] + '}</style>'
                            $pageUrl = 'data:text/html,' + [Uri]::EscapeDataString($html)
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost address-bar focus' }
                            [VerifyNative]::Text($pageUrl)
                            Wait-Until {
                                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                                    $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value -ceq $pageUrl -and
                                    [VerifyNative]::GetForegroundWindow() -eq $browser
                            } 'complete color URL is in the focused pane address bar'
                            if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or [VerifyNative]::DockedPaneWindow($script:window) -ne $browser) { throw 'Navigation browser ownership changed before Enter' }
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before navigation' }
                            Record 'Enter: show the synthetic full-viewport session color'
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until {
                                [VerifyNative]::DockedPaneWindow($script:window) -eq $browser -and
                                    [VerifyNative]::Title($browser).StartsWith($pageTitle + ' ', [StringComparison]::Ordinal) -and
                                    [VerifyNative]::PagePainted($dock, $rgb[$tab])
                            } 'active pane tab is the color page and target session color visibly painted below the browser toolbar' -Tight
                            $browsers[$tab] = $browser
                            $docks[$tab] = $dock
                        }
                        if ($browsers[0] -eq $browsers[1]) { throw 'Timing sessions do not have distinct browser HWNDs' }
                        $identities = foreach ($tab in @(0, 1)) {
                            @{ tab = $tab; shellId = $shellIds[$tab]; consoleHwnd = $consoles[$tab].ToInt64(); browserHwnd = $browsers[$tab].ToInt64(); dock = $docks[$tab]; color = $colors[$tab] }
                        }
                        Save-Json @($identities) ("$mode-window-identities.json")
                    }
                    if ($frozen) {
                        foreach ($tab in @(1, 0)) {
                            $gapCase.phase = "$mode-reset-$tab"
                            Press @(0x11, (0x31 + $tab)) 'Select session to verify its freeze marker is cleared before fresh sampling'
                            Wait-WorkspaceSurface $initial.active_workspace $tab $chat ($composerHandle.ToInt32())
                            Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$tab]) } 'active browser freeze marker cleared'
                        }
                        Wait-Until {
                            $panes = @((Read-Inbox).shells | Where-Object { $_.sid -in $shellIds -and $_.browser_state -eq 'connected' -and $_.browser_window_id -gt 0 })
                            $panes.Count -eq 2
                        } 'both timing browsers have app-published CDP window bindings' 30
                    }
                    $gapCase.phase = "$mode-start"
                    Press @(0x11, 0x31) 'Ctrl+1: start timing from first session'
                    Wait-WorkspaceSurface $initial.active_workspace 0 $chat ($composerHandle.ToInt32())
                    if ($browserOn) { Wait-Until { [VerifyNative]::PagePainted($docks[0], $rgb[0]) } 'first session color before measurement' -Tight }
                    Snapshot $(if ($mode -eq 'browser_off') { 'before' } elseif ($mode -eq 'browser_on') { 'action' } else { $mode + '-action' })
                    for ($sample = 0; $sample -lt $sampleCount; $sample++) {
                        $gapCase.phase = "$mode-sample-$sample"
                        $target = ($sample + 1) % 2
                        Doctor
                        if ($frozen) {
                            $frozenLogStart = ((Get-Content $log -Raw) -join '').Length
                            $freeze = @{ mode = $mode; sample = $sample; target = $target; shellId = $shellIds[$target]; marker = "panehib-zss-$($shellIds[$target]).flag"; status = 'waiting'; wait_ms = $null; marker_cleared = $false; window_visible_ms = $null; wake_flag_cleared_ms = $null; target_color_painted_ms = $null; log_start = $frozenLogStart; log_end = $null }
                            [void]$frozenSwitches.Add($freeze)
                            if ($false -ne (Read-BrowserFrozen $shellIds[$target])) { throw 'Target already frozen; expected a fresh freeze after its last activation' }
                            $parked = [Diagnostics.Stopwatch]::StartNew()
                            Wait-Until {
                                $state = Read-Session
                                $null -ne $state -and $state.active_tab -eq (1 - $target) -and $state.tabs[$target].shell_id -eq $shellIds[$target] -and
                                    ($true -eq (Read-BrowserFrozen $shellIds[$target]))
                            } "fresh app-published freeze marker for parked target $target" 150
                            $freeze.wait_ms = $parked.Elapsed.TotalMilliseconds
                            $freeze.status = 'frozen'
                            $freeze.observed_utc = [DateTime]::UtcNow.ToString('o')
                            $bridgePath = Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'
                            $freezeWindow = @((Read-Inbox).shells | Where-Object { $_.sid -eq $shellIds[$target] })[0].browser_window_id
                            Wait-Until {
                                $workers = @(Get-CimInstance Win32_Process -Filter "Name = 'zigshell-bridge.exe'" | Where-Object {
                                    $_.ExecutablePath -ceq $bridgePath -and $_.CommandLine -match ('--window\s+' + $freezeWindow + '\s+cdp\s+Page\.setWebLifecycleState\s+') -and $_.CommandLine.Contains('frozen')
                                })
                                $workers.Count -eq 0
                            } 'app freeze helper exited before timed input; dispatch-only markers cannot race wake'
                            $freeze.worker_finished_utc = [DateTime]::UtcNow.ToString('o')
                            Doctor
                            Assert-Foreground
                        }
                        $source = 1 - $target
                        [VerifyNative]::RequireSwitchStart($script:window, $composerHandle, $consoles[$source], ('ZigShell-' + $shellIds[$source]), $browsers[$source], $docks[$source], $drafts[$source], $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $drafts[$target])
                        Record ("Ctrl+Tab timing $mode sample=$sample target=$target shellId=" + $shellIds[$target])
                        $logStart = ((Get-Content $log -Raw) -join '').Length
                        $frozenMarker = if ($frozen) { Join-Path $scratch ("roaming/ZigShell/panehib-zss-$($shellIds[$target]).flag") } else { $null }
                        $measurement = [VerifyNative]::MeasureSessionSwitch($script:window, $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $composerHandle, $drafts[$target], $rgb[$target], $frozenMarker)
                        $timings[$mode].samples_ms[$sample] = $measurement[0]
                        $timings[$mode].window_visible_ms[$sample] = $measurement[1]
                        if ($frozen) {
                            $freeze.window_visible_ms = $measurement[1]
                            $freeze.wake_flag_cleared_ms = $measurement[2]
                            $freeze.target_color_painted_ms = $measurement[0]
                        }
                        Wait-WorkspaceSurface $initial.active_workspace $target $chat ($composerHandle.ToInt32())
                        $pattern = 'switch-timing: to=(\d+) total_us=\d+[^\r\n]*'
                        $debugAfter = (Get-Content $log -Raw) -join ''
                        $traceMatches = @()
                        if ($debugAfter.Length -ge $logStart) { $traceMatches = [regex]::Matches($debugAfter.Substring($logStart), $pattern) }
                        Save-Json @{ mode = $mode; sample = $sample; start = $logStart; end = $debugAfter.Length; complete = $debugAfter.Length -ge $logStart } ("$mode-$sample-log-range.json")
                        if ($traceMatches.Count -ne 1 -or [int]$traceMatches[0].Groups[1].Value -ne $target) { throw "Sample was not exactly one app switch to session $target; switch-timing lines in its log range: $($traceMatches.Count)" }
                        $line = $traceMatches[0].Value
                        [void]$traceLines.Add($line)
                        $steps = @{}
                        foreach ($field in [regex]::Matches($line, '(\w+_us)=(\d+)')) { $steps[$field.Groups[1].Value] = [double]$field.Groups[2].Value }
                        $traces[$mode] += $steps
                        if ($frozen) {
                            $frozenText = $debugAfter.Substring($freeze.log_start)
                            $idPattern = 'shell=' + $shellIds[$target] + ' '
                            if ($frozenText -notmatch ('(?s)browser freeze confirmed: ' + $idPattern + '.*hook: Ctrl\+Tab shift=0 -> NEXT_TAB.*browser wake sent: ' + $idPattern + '.*switchToShell: ' + (1 - $target) + ' -> ' + $target + ' ')) { throw "Frozen target $target was not frozen before Ctrl+Tab and woken by it in the app log" }
                            Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$target]) } 'target freeze marker removed by app wake'
                            $freeze.marker_cleared = $true
                            $freeze.status = 'painted-and-awake'
                            $freeze.log_end = ((Get-Content $log -Raw) -join '').Length
                        }
                    }
                    if ($mode -eq 'browser_on') {
                        $offMedian = Get-SwitchMedian $timings.browser_off.samples_ms
                        $onMedian = Get-SwitchMedian $timings.browser_on.samples_ms
                        if ($onMedian - $offMedian -gt 50) {
                            $gapCase.phase = 'switch-gap'
                            $gapCase.detail = "browser_on minus browser_off = $($onMedian - $offMedian) ms; required <= 50 ms"
                            throw $gapCase.detail
                        }
                    }
                }
                foreach ($mode in $modes) { $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms }
                $gapCase.phase = 'switch-gap'
                $gaps = foreach ($pair in @(@('browser_off', 'browser_on'), @('chat_browser_off', 'chat_browser_on'), @('browser_off', 'frozen_browser_on'), @('chat_browser_off', 'chat_frozen_browser_on'))) {
                    $gap = $timings[$pair[1]].median_ms - $timings[$pair[0]].median_ms
                    @{ off = $pair[0]; on = $pair[1]; gap_ms = $gap }
                }
                $gapCase.detail = ($gaps | ForEach-Object { "$($_.on) minus $($_.off) = $($_.gap_ms) ms; required <= 50 ms" }) -join '; '
                foreach ($pair in $gaps) { if ($pair.gap_ms -gt 50) { throw $gapCase.detail } }
                $gapCase.phase = 'after-snapshot'
                Snapshot 'after'
                $gapCase.status = 'passed'
            } catch {
                $gapCase.detail = $gapCase.phase + ': ' + $_.Exception.Message
                throw
            } finally {
                foreach ($mode in $modes) {
                    $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms
                    $timings[$mode].window_visible_median_ms = Get-SwitchMedian $timings[$mode].window_visible_ms
                    if ($traces[$mode].Count -eq $timings[$mode].samples_ms.Count -and @($traces[$mode] | Where-Object { $null -eq $_ }).Count -eq 0) {
                        $timings.steps[$mode] = @{}
                        foreach ($step in $traces[$mode][0].Keys) {
                            $values = @($traces[$mode] | ForEach-Object { $_[$step] })
                            $timings.steps[$mode][$step] = Get-SwitchMedian $values
                        }
                    }
                }
                Save-Json (Read-Inbox) 'switch-final-inbox.json'
                Save-Json (Read-Session) 'switch-final-session.json'
                Save-Json $timings 'switch-timings.json'
                Save-Json $traces 'switch-traces.json'
                if ($null -ne $frozenLogStart -and (Test-Path $log)) {
                    $debug = (Get-Content $log -Raw) -join ''
                    foreach ($freeze in $frozenSwitches) {
                        $end = if ($null -eq $freeze.log_end) { $debug.Length } else { $freeze.log_end }
                        $lines = if ($freeze.log_start -le $end -and $end -le $debug.Length) { $debug.Substring($freeze.log_start, $end - $freeze.log_start) } else { $debug }
                        $lines | Set-Content -Encoding UTF8 (Join-Path $Evidence ("{0}-{1}-debug.log" -f $freeze.mode, $freeze.sample))
                    }
                }
                Save-Json @($frozenSwitches.ToArray()) 'frozen-switches.json'
                if ($gapCase.status -ne 'passed' -and $gapCase.phase -like '*sample-*') {
                    try {
                        Save-Json @{ expected = $rgb[$target]; normal = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $false)); layered = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $true)); dock = $docks[$target] } 'switch-failure-screen-patch.json'
                        $diagnosticPane = @((Read-Inbox).shells | Where-Object { $_.sid -eq $shellIds[$target] })[0]
                        $expression = 'JSON.stringify({url:location.href,visibility:document.visibilityState,focused:document.hasFocus(),html:document.documentElement.outerHTML,rect:document.documentElement.getBoundingClientRect().toJSON(),bodyRect:document.body.getBoundingClientRect().toJSON(),htmlBg:getComputedStyle(document.documentElement).backgroundColor,bodyBg:getComputedStyle(document.body).backgroundColor})'
                        $probes = @(
                            @{ name = 'tabs'; method = $null; params = $null },
                            @{ name = 'dom'; method = 'Runtime.evaluate'; params = @{ expression = $expression; returnByValue = $true } },
                            @{ name = 'capture'; method = 'Page.captureScreenshot'; params = @{ format = 'png' } }
                        )
                        $probeResults = @()
                        foreach ($probe in $probes) {
                            $arguments = '--window ' + $diagnosticPane.browser_window_id
                            if ($null -eq $probe.method) { $arguments += ' tabs' } else {
                                $params = $probe.params | ConvertTo-Json -Compress
                                $arguments += ' cdp ' + $probe.method + ' "' + $params.Replace('"', '\"') + '"'
                            }
                            $prefix = Join-Path $Evidence ('switch-failure-' + $probe.name)
                            $probeJob = New-Object VerifyJob
                            $probeProcess = $null
                            try {
                                $probeProcess = $probeJob.Start((Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'), $scratch, ($prefix + '.stdout.json'), ($prefix + '.stderr.log'), $arguments)
                                $exited = $probeProcess.WaitForExit(30000)
                            } finally {
                                try { $probeStopped = $probeJob.Stop() } finally {
                                    if ($null -ne $probeProcess) { $probeProcess.Dispose() }
                                    $probeJob.Dispose()
                                }
                            }
                            $probeResults += @{ name = $probe.name; exited = $exited; windowId = $diagnosticPane.browser_window_id; activeAfterStop = $probeStopped.ActiveProcesses }
                            if (-not $exited) { break }
                        }
                        Save-Json $probeResults 'switch-failure-browser-diagnostics.json'
                    } catch { Save-Json @{ error = $_.Exception.Message } 'switch-failure-browser-diagnostics.json' }
                }
                $traceLines | Set-Content -Encoding UTF8 (Join-Path $Evidence 'switch-timing-debug.log')
            }
        }
        'browser-pane-locked' {
            Write-Host "browser-pane-locked verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if ($null -ne $warmupJob -and $warmupJob.ReadAccounting().ActiveProcesses -gt 0) {
                $warmupStopped = $warmupJob.Stop()
                Save-Json $warmupStopped 'browser-pane-locked-warmup-initial-stopped.json'
            }
            $pane = Open-BrowserPane 'locked-open'
            $initialLaunch = Assert-BrowserLaunchOnOwnMonitor 'initial'
            Doctor
            Record 'Close owned app normally and relaunch with its saved browser pane'
            if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)) { throw 'Owned app did not close normally for relaunch' }
            $relaunchStopped = $job.Stop()
            Save-Json $relaunchStopped 'browser-pane-locked-relaunch-stopped.json'
            if ($null -ne $warmupJob -and $warmupJob.ReadAccounting().ActiveProcesses -gt 0) {
                $warmupStopped = $warmupJob.Stop()
                Save-Json $warmupStopped 'browser-pane-locked-warmup-restored-stopped.json'
            }
            $job.Dispose()
            $job = New-Object VerifyJob
            $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'relaunch.stdout.log'), (Join-Path $Evidence 'relaunch.stderr.log'))
            $script:window = [IntPtr]::Zero
            Wait-Until {
                $process.Refresh()
                $script:window = $process.MainWindowHandle
                $script:window -ne [IntPtr]::Zero
            } 'relaunch main window ready for Shortcuts' 60 20
            if (-not [VerifyNative]::PostMessage($script:window, 0x8035, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Could not open Shortcuts before the restored browser launch' }
            $overlayPostedAt = [DateTime]::UtcNow
            $monitor = [VerifyNative]::MonitorFromWindow($script:window, 1)
            $info = New-Object VerifyNative+MonitorInfo
            $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
            if (-not [VerifyNative]::GetMonitorInfoW($monitor, [ref]$info)) { throw 'Owner monitor rectangle unavailable' }
            $profile = (Join-Path $env:LOCALAPPDATA 'ZigShell') -replace '\\', '/'
            $profileArgument = '(?:^|\s)--user-data-dir="?' + [regex]::Escape($profile) + '/(?:ChromeUserData|EdgeUserData)"?(?=\s|$)'
            Wait-Until {
                $script:overlayLaunches = @(Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe' OR Name = 'msedge.exe'" | Where-Object {
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
                $script:overlayLaunches.Count -gt 0
            } 'positioned isolated browser launched while Shortcuts is open' 60
            $launchObservedAt = [DateTime]::UtcNow
            $overlayLaunch = @{ launches = $script:overlayLaunches; monitor = $info.Monitor; mainHwnd = $script:window.ToInt64(); overlayPostedAt = $overlayPostedAt; launchObservedAt = $launchObservedAt; overlayAtLaunch = $overlayPostedAt -lt $launchObservedAt }
            Save-Json $overlayLaunch 'browser-pane-locked-launch-restored-overlay.json'
            if (-not $overlayLaunch.overlayAtLaunch) { throw 'Shortcuts was not posted before the restored launch appeared' }
            if (@($overlayLaunch.launches | Where-Object { -not $_.parsed -or -not $_.inside }).Count -ne 0) { throw 'Browser launch point is outside the owner monitor while Shortcuts is open' }
            if (-not [VerifyNative]::PostMessage($script:window, 0x8036, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Could not close Shortcuts after the restored browser launch' }
            Wait-Until {
                [VerifyNative]::PaneVisible($script:window) -and
                    $null -ne (Read-Inbox) -and @((Read-Inbox).shells).Count -gt 0
            } 'startup restored the owned browser pane without an open command' 60
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $restoredLaunch = Assert-BrowserLaunchOnOwnMonitor 'restored'
            if (@($restoredLaunch.launches | Where-Object { $_.pid -in @($initialLaunch.launches | ForEach-Object { $_.pid }) }).Count -ne 0) { throw 'Relaunch reused an initial browser process instead of launching at startup' }
            $result.checks += @{ name = 'browser-pane-locked launch-on-own-monitor'; initial = $initialLaunch; restored = $restoredLaunch; restoredOverlay = $overlayLaunch }
            Write-Host 'browser-pane-locked launch-on-own-monitor PASS'
            $browser = [VerifyNative]::PaneWindow($script:window)
            if ($browser -eq [IntPtr]::Zero) { throw 'No visible owned docked browser HWND' }
            $dockRect = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($browser, [ref]$dockRect) -or [VerifyNative]::IsZoomed($browser)) { throw 'Initial browser dock rect unavailable or zoomed' }
            Save-Json @{ hwnd = $browser.ToInt64(); rect = $dockRect; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'browser-pane-locked-dock.json'
            Focus-LockedBrowser $browser
            $strip = Get-LockedBrowserStrip $browser $dockRect
            Snapshot 'action'
            Doctor
            Record 'Real SendInput drag: empty browser top strip 300px left and 200px down'
            [VerifyNative]::DragBrowserStrip($browser, $script:window, $strip)
            Assert-LockedBrowserRect $browser $dockRect 'drag-blocked'
            Snapshot 'drag-blocked'
            Focus-LockedBrowser $browser
            Doctor
            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Win+Up' }
            Record 'Real SendInput Win+Up with the docked browser focused'
            [VerifyNative]::Chord(@(0x5B, 0x26))
            Assert-LockedBrowserRect $browser $dockRect 'win-up-blocked'
            Focus-LockedBrowser $browser
            $strip = Get-LockedBrowserStrip $browser $dockRect
            Doctor
            Record 'Real SendInput double-click on the same empty browser top strip'
            [VerifyNative]::DoubleClickBrowserStrip($browser, $script:window, $strip)
            Assert-LockedBrowserRect $browser $dockRect 'maximize-blocked'
            Snapshot 'after'
        }
        'browser-pane-stuck' {
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if (Test-Path (Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension/manifest.json')) { throw 'Expected no browser extension in the isolated profile' }
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved for the initial session'
            $first = Open-BrowserPane 'initial-open'
            Snapshot 'action'
            Press @(0x12, 0x41) 'Alt+A: close browser pane'
            $closed = Assert-BrowserPane 'closed' 'shortcut-close'
            $second = Open-BrowserPane 'reopen-after-shortcut' $first.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'palette-close-all'
            if (@((Read-Inbox).shells | Where-Object { $_.browser_state -ne 'closed' }).Count -ne 0) { throw 'Close All left a browser pane open' }
            Doctor
            Assert-Foreground
            Record 'reopen-after-close-all: batch palette open then close before adoption timers'
            [VerifyNative]::OpenAndCloseBrowserPane()
            $closed = Assert-BrowserPane 'closed' 'palette-close-pane'
            $fourth = Open-BrowserPane 'reopen-after-close-pane' $second.browser_connection_id
            if ($fourth.browser_connection_id -le $second.browser_connection_id + 1) { throw 'Palette batch did not open and cancel an intermediate connection' }
            Assert-ConnectedPaneStaysVisible $fourth.browser_connection_id
            Press @(0x12, 0x10, 0x41) 'Alt+Shift+A: toggle working browser pane closed'
            $shiftToggleCooldown = [Diagnostics.Stopwatch]::StartNew()
            $closed = Assert-BrowserPane 'closed' 'shift-a-toggle'
            Wait-Until { $shiftToggleCooldown.ElapsedMilliseconds -ge 1600 } 'browser shortcut debounce elapsed' 5
            Press @(0x12, 0x10, 0x42) 'Alt+Shift+B: toggle browser pane open'
            $fifth = Assert-BrowserPane 'open' 'shift-b-toggle' $fourth.browser_connection_id
            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'final-close'
            Snapshot 'after'
        }
        'browser-own-profile' {
            if ((Get-OwnProfileToken 'ws-own-test') -cne 'own-adee37bbc9fa6013ec24ccfd') { throw 'Journey token derivation differs from the app test vector' }
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'initial restore finished before keyboard input' 60
            $sharedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData')).TrimEnd('\')
            $ownBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'ZigShell/BrowserWorkspaces')).TrimEnd('\')
            $optIn = Join-Path $env:APPDATA 'ZigShell/browser-own-profile.txt'
            if ((Test-Path -LiteralPath $ownBase) -or (Test-Path -LiteralPath $optIn)) { throw 'Own browser profile state existed before the journey' }
            $warmupJob = New-Object VerifyJob
            $arguments = '--user-data-dir="' + $sharedRoot + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --load-extension="' + $extension + '" --disable-extensions-except="' + $extension + '" --silent-debugger-extension-api --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
            $warmup = $warmupJob.Start($chrome, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
            Wait-Until {
                $warmup.Refresh()
                if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
                $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
            } 'shared browser profile rendered setup page' 60
            Wait-SwitchNativeHost
            [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
            $warmupStopped = $warmupJob.Stop()
            Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
            $warmupJob.Dispose()
            $warmupJob = $null
            Wait-Until {
                [void][VerifyNative]::SetForegroundWindow($script:window)
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'main window foreground after shared browser setup'
            $script:browserShellId = (Read-Inbox).active_shell_id
            $sharedProof = Open-WorkspaceBrowser 'shared'
            if ($sharedProof.userDataDir -ine $sharedRoot) { throw 'Workspace without opt-in left the shared browser profile' }
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'shared pane bound through the shared native host' 60
            $sharedBefore = Get-SharedProfileListing $sharedRoot
            $coreBefore = Get-SharedProfileCore $sharedRoot
            if ('Default' -notin $coreBefore -or 'Local State' -notin $coreBefore) { throw 'Shared browser profile was not warmed' }
            $before = (Read-Session).workspace_count
            Press @(0x11, 0x4E) 'Ctrl+N: create the workspace that gets its own browser profile'
            Wait-Until { $script:ownSession = Read-Session; $null -ne $script:ownSession -and $script:ownSession.workspace_count -eq $before + 1 -and $script:ownSession.active_workspace -ne 0 } 'new workspace persisted'
            $ownWorkspace = $script:ownSession.active_workspace
            $ownWorkspaceId = $script:ownSession.workspaces[$ownWorkspace].wid
            if ([string]::IsNullOrWhiteSpace($ownWorkspaceId) -or $ownWorkspaceId -ceq $script:ownSession.workspaces[0].wid) { throw 'Expected a distinct workspace identity' }
            $ownToken = Get-OwnProfileToken $ownWorkspaceId
            $ownRoot = [IO.Path]::GetFullPath((Join-Path $ownBase ('chrome/' + $ownToken))).TrimEnd('\')
            if (Test-Path -LiteralPath $ownBase) { throw 'Own browser profile folder appeared before opt-in' }
            Record 'Opt the new workspace into its own browser profile with browser-own-profile.txt'
            [IO.File]::WriteAllText($optIn, $ownWorkspaceId + "`n")
            Wait-Until {
                $state = Read-Inbox
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $selected.Count -eq 1 -and $selected[0].ws -eq $ownWorkspace
            } 'new workspace CMD selected'
            $script:browserShellId = (Read-Inbox).active_shell_id
            Snapshot 'action'
            $ownProof = Open-WorkspaceBrowser 'opted-in'
            if ($ownProof.userDataDir -ine $ownRoot) { throw ('Opted-in workspace has no own browser profile: ' + $ownProof.userDataDir) }
            if ($ownProof.pid -eq $sharedProof.pid) { throw 'Opted-in pane reused the shared browser process' }
            Wait-OwnProfilePipe $ownToken 'opted-in'
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'opted-in pane bound through its own native host' 60
            if ($null -eq (Get-Process -Id $sharedProof.pid -ErrorAction SilentlyContinue)) { throw 'Shared browser closed when the opted-in pane opened' }
            $sharedAfter = Get-SharedProfileListing $sharedRoot
            $coreAfter = Get-SharedProfileCore $sharedRoot
            $missing = @($coreBefore | Where-Object { $_ -notin $coreAfter })
            $foreign = @($sharedAfter | Where-Object { $_ -match '(?i)own-[0-9a-f]{24}|BrowserWorkspaces|workspace-owner' })
            if ($missing.Count -ne 0 -or $foreign.Count -ne 0) { throw ('Shared browser profile changed: missing ' + ($missing -join ', ') + '; foreign ' + ($foreign -join ', ')) }
            $engines = @(Get-ChildItem -LiteralPath $ownBase -Force | ForEach-Object { $_.Name })
            $leaves = @(Get-ChildItem -LiteralPath (Join-Path $ownBase 'chrome') -Force | ForEach-Object { $_.Name })
            if ($engines.Count -ne 1 -or $engines[0] -cne 'chrome' -or $leaves.Count -ne 1 -or $leaves[0] -cne $ownToken) { throw 'Own browser profile folder is not exactly one own-<hash> leaf' }
            Restart-SessionRestore 'own-profile-restart' $false
            Wait-Until {
                $state = Read-Inbox
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $selected.Count -eq 1 -and $selected[0].ws -eq $ownWorkspace
            } 'restored selection is the opted-in workspace'
            $script:browserShellId = (Read-Inbox).active_shell_id
            Wait-Until {
                $pane = Read-BrowserPane
                $null -ne $pane -and $pane.browser_state -eq 'connected' -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero
            } 'restored opted-in pane docked without an open command' 90
            $restoredProof = Get-PaneUserDataDir ([VerifyNative]::DockedPaneWindow($script:window))
            if ($restoredProof.userDataDir -ine $ownRoot) { throw ('Restored opted-in workspace lost its own browser profile: ' + $restoredProof.userDataDir) }
            Wait-OwnProfilePipe $ownToken 'restored'
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'restored opted-in pane bound through its own native host' 60
            Save-Json @{ token = $ownToken; workspaceId = $ownWorkspaceId; ownRoot = $ownRoot; sharedRoot = $sharedRoot; shared = $sharedProof; opted = $ownProof; restored = $restoredProof; sharedBefore = $sharedBefore; sharedAfter = $sharedAfter; coreBefore = $coreBefore; coreAfter = $coreAfter } 'browser-own-profile.json'
            $result.checks += @{ name = 'browser-own-profile shared'; userDataDir = $sharedProof.userDataDir }
            $result.checks += @{ name = 'browser-own-profile opted-in'; userDataDir = $ownProof.userDataDir; token = $ownToken }
            $result.checks += @{ name = 'browser-own-profile shared-untouched'; entries = $sharedAfter.Count }
            $result.checks += @{ name = 'browser-own-profile restored'; userDataDir = $restoredProof.userDataDir }
            Snapshot 'after'
        }
        'status-card' {
            $client = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client)) { throw 'status-card client rectangle unavailable' }
            $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
            Doctor
            Assert-Foreground
            Record 'Mouse: move away from the sidebar status card'
            [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
            $statusFile = Join-Path $scratch 'roaming/ZigShell/sidebar-status-card.txt'
            $pages = @()
            $heights = @()
            foreach ($page in 0..2) {
                if ($page -gt 0) {
                    Press @(0x11, 0x10, 0x47) ('Ctrl+Shift+G: status card page ' + ($page + 1))
                    Wait-Until { (Test-Path -LiteralPath $statusFile) -and ([IO.File]::ReadAllText($statusFile).Trim() -eq [string]$page) } ('status card page ' + ($page + 1) + ' saved by the app')
                    Start-Sleep -Milliseconds 500
                }
                $shot = 'status-card-' + ($page + 1)
                Snapshot $shot
                $measure = Measure-StatusCard $shot
                $measure.page = $page + 1
                $pages += $measure
                $heights += $measure.height
            }
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages }
            Save-Json $result.statusCard 'status-card.json'
            Snapshot 'action'
            Doctor
            Assert-Foreground
            Record 'Mouse: hover the sidebar status card'
            [VerifyNative]::MoveMouseClient($script:window, [int][Math]::Round(60 * $scale), $client.Bottom - [int][Math]::Round(14 * $scale), $true)
            Start-Sleep -Milliseconds 600
            Snapshot 'hover'
            Record 'Mouse: leave the sidebar status card'
            [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
            Start-Sleep -Milliseconds 300
            Snapshot 'after'
            foreach ($height in $heights) {
                if ($height -gt 30 -or $height -lt 20) { throw ('status-card: card height ' + $height + ' outside 20..30; heights ' + ($heights -join ', ')) }
            }
            $result.checks += @{ name = 'status-card'; heights = $heights; entry = 'Ctrl+Shift+G'; hover = 'hover.png' }
        }
        'command-palette' {
            Palette 'interface'
            Snapshot 'action'
            Press @(0x0D) 'Enter: UI Size: Increase'
            Wait-Until { (Read-Session).ui_scale -eq 110 } 'UI scale saved as 110'
            Snapshot 'after'
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: UI Size: Reset'
            Wait-Until { $state = Read-Session; -not ($state.PSObject.Properties.Name -contains 'ui_scale') -or $state.ui_scale -eq 100 } 'UI scale reset to default'
            Snapshot 'reset'
            $result.checks += @{ name = 'palette-increase-reset'; increasedScale = 110; resetScale = 100 }
            Palette 'restart to update'
            Snapshot 'update-command'
            $image = New-Object Drawing.Bitmap((Join-Path $Evidence 'update-command.png'))
            $selectedTextPixels = 0
            try {
                $top = $image.Height
                $bottom = 0
                for ($y = [int]($image.Height * 0.2); $y -lt [int]($image.Height * 0.8); $y++) {
                    $pixel = $image.GetPixel([int]($image.Width / 2), $y)
                    if ($pixel.R -lt 50 -and $pixel.G -gt 70 -and $pixel.G -lt 160 -and $pixel.B -gt 150) {
                        $top = [Math]::Min($top, $y)
                        $bottom = [Math]::Max($bottom, $y)
                    }
                }
                for ($y = $top; $y -le $bottom; $y++) {
                    for ($x = [int]($image.Width * 0.3); $x -lt [int]($image.Width * 0.7); $x++) {
                        $pixel = $image.GetPixel($x, $y)
                        if ($pixel.R -gt 180 -and $pixel.G -gt 180 -and $pixel.B -gt 180) { $selectedTextPixels++ }
                    }
                }
                if ($selectedTextPixels -lt 40) { throw 'Update command row is blank or unreadable' }
            } finally { $image.Dispose() }
            Press @(0x0D) 'Enter: Restart to update with no update ready'
            Doctor
            Snapshot 'update-idle'
            $result.checks += @{ name = 'update-command-without-ready-keeps-session'; pid = $process.Id; scale = 100; selectedTextPixels = $selectedTextPixels }
        }
    }
    Doctor
    $result.status = 'passed'
} catch {
    $result.error = $_.Exception.Message
    if ($script:window -ne [IntPtr]::Zero) {
        try { Snapshot 'failure' } catch { $result.captureError = $_.Exception.Message }
    }
} finally {
    try {
        try {
            if ($null -ne $process -and -not $process.HasExited) {
                Record 'Cleanup: close owned app before stopping its job-owned process tree'
                [void]$process.CloseMainWindow()
                [void]$process.WaitForExit(10000)
            }
        } finally {
            try {
                if ($null -ne $job) {
                    $beforeStop = $job.ReadAccounting()
                    $stopped = $job.Stop()
                    Save-Json @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } 'process-tree.json'
                    Record 'Cleanup: owned process tree stopped; job active process count is zero'
                }
                if ($null -ne $warmupJob) {
                    $warmupStopped = $warmupJob.Stop()
                    Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                }
            } finally {
                if ($null -ne $switchNativeRegistry) {
                    Remove-Item -LiteralPath $switchNativeRegistry -Recurse -Force
                    $switchNativeRegistry = $null
                }
                if (Test-Path $scratch) {
                    Prepare-ScratchEvidence $scratch
                    $data = Join-Path $Evidence 'data'
                    New-Item -ItemType Directory -Force $data | Out-Null
                    $deadline = [DateTime]::UtcNow.AddSeconds(20)
                    while ($true) {
                        try { Copy-Item (Join-Path $scratch '*') $data -Recurse -Force; break } catch {
                            if ([DateTime]::UtcNow -ge $deadline) { throw }
                            Start-Sleep -Milliseconds 200
                        }
                    }
                }
            }
        }
        Remove-ScratchPath $scratch
        $result.cleanup = 'owned process tree stopped; scratch copied to evidence/data then removed'
        $result.scratchRemoved = -not (Test-Path $scratch)
        if (-not $result.scratchRemoved) { throw 'Scratch directory still exists' }
        Write-Output $result.cleanup
        if ($result.status -eq 'passed') {
            foreach ($name in @('before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json')) {
                if (-not (Test-Path (Join-Path $Evidence $name))) { throw "Evidence lost during cleanup: $name" }
            }
        }
    } catch {
        $result.status = 'failed'
        $result.cleanup = $_.Exception.Message
    }
    if ($null -ne $warmup) { $warmup.Dispose() }
    if ($null -ne $warmupJob) { $warmupJob.Dispose() }
    if ($null -ne $job) { $job.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    Save-Json $result 'result.json'
}
if ($result.status -ne 'passed') { throw ('Verification failed: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
Write-Output "VERIFIED $Feature with real input and retained evidence"
