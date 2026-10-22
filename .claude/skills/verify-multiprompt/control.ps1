param(
    [Parameter(Mandatory=$true)][ValidateSet('appearance', 'sessions', 'workspaces', 'workspace-focus', 'inbox', 'command-palette', 'session-open', 'favorites-groups', 'browser-pane-stuck', 'browser-pane-locked', 'group-rail', 'pane-layout', 'chat-tables', 'safe-updates', 'chat-view', 'browser-emulation')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
switch ($Feature) {
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
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr Hwnd; public uint Id; public UIntPtr WParam; public IntPtr LParam; public uint Time; public Point Position; public uint Private; }
    [StructLayout(LayoutKind.Sequential)] public struct GuiThreadInfo { public uint Size, Flags; public IntPtr Active, Focus, Capture, MenuOwner, MoveSize, Caret; public Rect CaretRect; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Keyboard keyboard; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Union data; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool PeekMessage(out Message message, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll", SetLastError=true)] static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetFocus(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr count, StringBuilder text, uint flags, uint timeout, out UIntPtr result);
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
        StringBuilder text = new StringBuilder(512);
        UIntPtr length;
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
            int left = origin.X - frame.Left + S(8, dpi, scale);
            int railLeft = left + S(4, dpi, scale), railRight = left + S(7, dpi, scale);
            var rail = System.Drawing.Color.FromArgb(145, 149, 157);
            int top = -1;
            int searchTop = origin.Y - frame.Top + S(8, dpi, scale);
            for (int y = searchTop; y < searchTop + S(180, dpi, scale); y++) {
                if (Distance(image.GetPixel(railLeft, y), rail) <= 2) { top = y; break; }
            }
            if (top < 0) throw new InvalidOperationException("group-rail gray header rail not found");
            int rowHeight = S(38, dpi, scale), firstRow = top + 28;
            int rowTop = firstRow + selected * rowHeight, rowBottom = rowTop + rowHeight;
            int referenceX = origin.X - frame.Left + S(220, dpi, scale) - S(44, dpi, scale);
            var highlight = image.GetPixel(referenceX, (rowTop + rowBottom) / 2);
            if (highlight.B <= highlight.R + 10) throw new InvalidOperationException("group-rail expected a visible blue selected highlight");
            int headerPixels = 0, unselectedPixels = 0, selectedMismatch = 0, selectedRail = 0, strayPixels = 0;
            for (int x = railLeft; x < railRight; x++) {
                for (int y = top; y < firstRow; y++) if (Distance(image.GetPixel(x, y), rail) <= 2) headerPixels++;
                int otherTop = firstRow + (1 - selected) * rowHeight;
                for (int y = otherTop; y < otherTop + rowHeight; y++) if (Distance(image.GetPixel(x, y), rail) <= 2) unselectedPixels++;
                for (int y = rowTop + 3; y < rowBottom - 3; y++) {
                    var actual = image.GetPixel(x, y);
                    var expected = image.GetPixel(referenceX, y);
                    if (Distance(actual, expected) > 3) selectedMismatch++;
                    if (Distance(actual, rail) <= 2) selectedRail++;
                }
                for (int y = firstRow + 2 * rowHeight; y < firstRow + 3 * rowHeight; y++) {
                    if (Distance(image.GetPixel(x, y), rail) <= 2) strayPixels++;
                }
            }
            int width = railRight - railLeft;
            if (headerPixels != width * 28 || unselectedPixels != width * rowHeight) throw new InvalidOperationException("group-rail missing continuous gray header or unselected rail: " + headerPixels + "," + unselectedPixels);
            proof["selectedClear"] = selectedMismatch == 0 && selectedRail == 0;
            proof["strayClear"] = strayPixels == 0;
            proof["selectedMismatch"] = selectedMismatch;
            proof["selectedRailPixels"] = selectedRail;
            proof["strayPixels"] = strayPixels;
            proof["headerPixels"] = headerPixels;
            proof["unselectedPixels"] = unselectedPixels;
            proof["railX"] = new int[] { railLeft, railRight };
            proof["selectedRect"] = new int[] { railLeft, rowTop + 3, railRight, rowBottom - 3 };
            proof["belowGroupRect"] = new int[] { railLeft, firstRow + 2 * rowHeight, railRight, firstRow + 3 * rowHeight };
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
            Require(longestRail >= S(40, dpi, scale), "group-line-found", "longest vertical group-color run=" + longestRail);
            int railRight = railX + 1;
            while (railRight < sidebarLeft + S(40, dpi, scale) && Distance(pixel(railRight, (railTop + railBottom) / 2), railColor) <= 2) railRight++;
            int rowTop = railTop + S(28, dpi, scale), rowBottom = rowTop + S(38, dpi, scale);
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

function Remove-ScratchPath([string]$Path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
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

function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    do {
        if ($process.HasExited) { throw "App exited while waiting for $Description" }
        try { if (& $Condition) { return } } catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds 200
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

function Read-BrowserPane {
    $state = Read-Inbox
    if ($null -eq $state) { return $null }
    return @($state.shells | Where-Object { $_.sid -eq $script:browserShellId })[0]
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
    if ($pane.browser_window_id -ne 0) { throw 'Unexpected browser extension connection in the no-extension journey' }
    Save-Json $pane ("browser-pane-$Step.json")
    $result.checks += @{ name = "browser-pane-stuck $Step"; state = $pane.browser_state; connectionId = $pane.browser_connection_id }
    Write-Host "browser-pane-stuck $Step PASS"
    return $pane
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
    $focus = @{ foreground = [VerifyNative]::GetForegroundWindow().ToInt64() }
    try { $focus.native = [VerifyNative]::GetFocusedWindow($script:window).ToInt64() } catch { $focus.nativeError = $_.Exception.Message }
    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $focus.uia = @{ handle = $focused.Current.NativeWindowHandle; pid = $focused.Current.ProcessId; class = $focused.Current.ClassName }
    } catch { $focus.uiaError = $_.Exception.Message }
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
    $start = (Get-Content $log -Raw).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Wait-Until {
        $trace = (Get-Content $log -Raw).Substring($start)
        if ($trace -notmatch '\[palette\] ready chars=0 count=\d+ target=\d+') { return $false }
        Doctor
        Assert-Foreground
        [void][VerifyNative]::SetForegroundWindow($script:window)
        $trace -match '\[palette\] ready chars=0 count=\d+ target=\d+' -and [VerifyNative]::GetForegroundWindow() -eq $script:window -and [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
    } 'command palette initialized and owned frame focused' 20
    Type-Text $Query
    Wait-Until {
        (Get-Content $log -Raw).Substring($start) -match ('\[palette\] ready chars=' + $Query.Length + ' count=[1-9]\d* target=' + $Target + '(?:\r?\n|$)')
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

try {
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'IGSH_246')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    $env:USERPROFILE = Join-Path $scratch 'profile'
    $env:HOME = $env:USERPROFILE
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $job = New-Object VerifyJob
    $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'))
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -gt 0
    } 'owned main window and initialized CMD session' 60
    if ($Feature -in @('browser-pane-stuck', 'pane-layout', 'browser-pane-locked')) {
        $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
        if (-not (Test-Path -LiteralPath $edge)) { throw 'Browser setup requires installed Edge' }
        $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/EdgeUserData'
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
        $warmup = $warmupJob.Start($edge, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
        } 'isolated browser rendered setup page before the pane adoption deadline starts' 60
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
            Wait-Until { (Test-Path $log) -and (Get-Content $log -Raw) -match 'CHAT_TABLE rows=1 columns=2 .*source=box' } 'formatted table built from real console output'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'Chat View preference persisted for table tab'
            Snapshot 'before'
            $buildsBefore = @([regex]::Matches((Get-Content $log -Raw), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create another real CMD tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 -and (Read-Session).active_tab -ne $tableTab } 'new CMD tab active and saved'
            Snapshot 'away'
            $awayLogLength = (Get-Content $log -Raw).Length
            Press @(0x11, 0x10, 0x09) 'Ctrl+Shift+Tab: return to table Chat View'
            Wait-Until { (Read-Session).active_tab -eq $tableTab -and (Read-Session).tabs[$tableTab].cv } 'original Chat View tab active again'
            Wait-Until { $text = Get-Content $log -Raw; $text.Length -gt $awayLogLength -and $text.Substring($awayLogLength) -match '\[switch\] chat painted in' } 'returned Chat View painted'
            Snapshot 'after'
            $buildsAfter = @([regex]::Matches((Get-Content $log -Raw), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            if ($buildsAfter -ne $buildsBefore) { throw "Unchanged table rebuilt across tab switch: $buildsBefore -> $buildsAfter" }
            $result.checks += @{ name = 'console-table-switch-return'; tableTab = $tableTab; buildsBefore = $buildsBefore; buildsAfter = $buildsAfter; marker = (Get-Content (Join-Path $scratch 'table-ready.txt') -Raw).Trim(); chatViewSaved = $true }
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
                $listener = [regex]::Match((Get-Content $log -Raw), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
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
                $failure = [regex]::Match((Get-Content $log -Raw), ('ssh-reconnect disconnect id=' + $created.tab + ' reason=(process-exit-event|process-exit-poll|startup-console-missing) exit_code=(\d+) known=true'))
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
            Focus-Palette 'per tab' 6345
            Press @(0x0D) 'Enter: Chat View per tab'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and -not ($state.PSObject.Properties.Name -contains 'chat_view_mode')
            } 'per-session Chat View mode saved'
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
        }
        'group-rail' {
            Write-Host "group-rail verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            Select-Theme 'dark' 'group-rail-dark'
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
            Press @(0x11, 0x32) 'Ctrl+2: select the ungrouped original session'
            Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text $group.name
            Press @(0x0D) 'Enter: move first session into same group'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.tabs[0].group_id -eq $group.id -and $state.tabs[1].group_id -eq $group.id -and $state.active_tab -eq 0 } 'two real sessions saved in one group'
            $state = Read-Session
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
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
                $selectedClear = $selectedClear -and $proof['selectedClear']
                $strayClear = $strayClear -and $proof['strayClear']
                $result.checks += @{ name = $shot; pixels = $proof }
            }
            Snapshot 'after'
            if ($selectedClear) { Write-Host 'group-rail selected-clear PASS' } else { Write-Host 'group-rail selected-clear FAIL' }
            if ($strayClear) { Write-Host 'group-rail stray-clear PASS' } else { Write-Host 'group-rail stray-clear FAIL' }
            if (-not $selectedClear -or -not $strayClear) { throw 'group-rail pixel assertions failed' }
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
            $pane = Open-BrowserPane 'pane-layout-open'
            Press @(0x5B, 0x26) 'Win+Up: maximize main window'
            Wait-Until { [VerifyNative]::IsZoomed($script:window) } 'maximized main window'
            Press @(0x11, 0x31) 'Ctrl+1: return to the CMD console'
            Wait-WorkspaceSurface $initial.active_workspace 0 $false
            $console = [VerifyNative]::GetForegroundWindow()
            $browser = [VerifyNative]::PaneWindow($script:window)
            if ($browser -eq [IntPtr]::Zero) { throw 'No visible owned docked browser HWND' }
            $consoleElement = [System.Windows.Automation.AutomationElement]::FromHandle($console)
            if ($consoleElement.Current.IsOffscreen -or $consoleElement.Current.ClassName -ne 'ConsoleWindowClass' -or
                -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $initial.tabs[0].shell_id), [StringComparison]::Ordinal)) { throw 'UIA cannot see the owned CMD console' }
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
            if ($state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv) { throw 'Journey accidentally entered Chat View' }
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            Save-Json @{ frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64(); dpi = $dpi; scale = $scale; session = $state } 'pane-layout-rects.json'
            $proof = [PaneLayoutProof]::Check((Join-Path $Evidence 'pane-layout.png'), $frame, $client, $consoleRect, $browserRect, $dpi, $scale)
            Save-Json $proof 'pane-layout-pixels.json'
            $result.checks += @{ name = 'pane-layout'; assertions = @('console-uia-hwnd', 'ring-found', 'ring-top', 'ring-bottom', 'ring-left', 'ring-right', 'console-inside-ring', 'clean-gap', 'group-line-found', 'row-icon-found', 'group-line-clears-icon'); pixels = $proof }
            Snapshot 'after'
        }
        'browser-pane-locked' {
            Write-Host "browser-pane-locked verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $pane = Open-BrowserPane 'locked-open'
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
