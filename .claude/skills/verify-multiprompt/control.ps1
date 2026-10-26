param(
    [Parameter(Mandatory=$true)][ValidateSet('appearance', 'app-icon', 'sessions', 'session-restore', 'tmux-binding', 'workspaces', 'workspace-focus', 'inbox', 'command-palette', 'session-open', 'favorites-groups', 'chat-first-paint', 'chat-send-latency', 'browser-switch-speed', 'chat-switch-speed', 'browser-pane-stuck', 'browser-pane-locked', 'browser-corners', 'group-rail', 'pane-layout', 'title-bar', 'window-controls', 'chat-tables', 'chat-code-font', 'chat-working', 'chat-composer-text', 'chat-skill-pill', 'chat-options', 'composer-buttons', 'chat-dictation', 'safe-updates', 'chat-view', 'chat-view-everywhere', 'chat-focus', 'chat-delivery', 'chat-messages-only', 'chat-full-history', 'browser-emulation', 'status-card', 'palette-order', 'browser-own-profile', 'remind-me', 'tab-names', 'session-tabs', 'relaunch-saved-sessions')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
switch ($Feature) {
        'app-icon' {
            & "$PSScriptRoot/../../../tools/verify-app-icon/drive.ps1" -Exe $Exe -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            return
        }
        'chat-full-history' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Feature $Feature -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Full-session history verification failed' }
            return
        }
        'chat-messages-only' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Feature $Feature -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Messages-only verification failed' }
            return
        }
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

Write-Host 'Launch: loading native verification helpers'
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
    [DllImport("user32.dll", SetLastError=true)] static extern bool SystemParametersInfo(uint action, uint parameter, IntPtr value, uint flags);
    public static bool FontSmoothing() {
        IntPtr value = Marshal.AllocHGlobal(4);
        try {
            if (!SystemParametersInfo(0x004A, 0, value, 0)) throw new System.ComponentModel.Win32Exception();
            return Marshal.ReadInt32(value) != 0;
        } finally { Marshal.FreeHGlobal(value); }
    }
    public static void FontSmoothing(bool enabled) {
        if (!SystemParametersInfo(0x004B, enabled ? 1u : 0u, IntPtr.Zero, 0)) throw new System.ComponentModel.Win32Exception();
        if (FontSmoothing() != enabled) throw new InvalidOperationException("Font smoothing setting did not change");
    }
    public static int[] ComposerRow(IntPtr hwnd, int length, int em) {
        Point origin = new Point();
        if (!ClientToScreen(hwnd, ref origin)) throw new InvalidOperationException("Missing composer client origin");
        UIntPtr first, last;
        if (SendMessageTimeout(hwnd, 0x00D6, UIntPtr.Zero, IntPtr.Zero, 2, 2000, out first) == IntPtr.Zero ||
            SendMessageTimeout(hwnd, 0x00D6, new UIntPtr((uint)(length - 5)), IntPtr.Zero, 2, 2000, out last) == IntPtr.Zero) throw new InvalidOperationException("Missing composer character positions");
        int x = (short)(first.ToUInt64() & 0xffff), y = (short)((first.ToUInt64() >> 16) & 0xffff);
        int right = (short)(last.ToUInt64() & 0xffff), lastY = (short)((last.ToUInt64() >> 16) & 0xffff);
        if (lastY != y || right <= x) throw new InvalidOperationException("Composer sentence did not fit one row");
        return new int[] { origin.X + x, origin.Y + y, origin.X + right, origin.Y + y + (int)Math.Ceiling(em * 1.6) };
    }
    public static void Bmp(string input, string output) {
        using (var image = new System.Drawing.Bitmap(input))
        using (var bitmap = image.Clone(new System.Drawing.Rectangle(0, 0, image.Width, image.Height), System.Drawing.Imaging.PixelFormat.Format32bppRgb)) bitmap.Save(output, System.Drawing.Imaging.ImageFormat.Bmp);
    }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(uint pid);
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
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("shcore.dll")] public static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint x, out uint y);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromRect(ref Rect rect, uint flags);
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
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("dwmapi.dll")] public static extern int DwmFlush();
    static void Key(ushort key, ushort scan, uint flags) {
        Input input = new Input(); input.type = 1;
        input.data.keyboard = new Keyboard { key = key, scan = scan, flags = flags };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("SendInput failed");
    }
    public static void KeyDown(int key) { Key((ushort)key, 0, 0); }
    public static void KeyUp(int key) { Key((ushort)key, 0, 2); }
    public static bool IsDown(int key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }
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
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    public static List<IntPtr> OwnedPaneWindows(IntPtr owner) {
        var panes = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            if (GetProp(hwnd, "ZigShellPaneOwner") == owner) panes.Add(hwnd);
            return true;
        }, IntPtr.Zero);
        return panes;
    }
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
            Rect rect;
            if (GetProp(hwnd, "ZigShellPaneOwner") == owner && IsWindowVisible(hwnd) &&
                GetWindowRect(hwnd, out rect) && MonitorFromRect(ref rect, 0) != IntPtr.Zero) { pane = hwnd; count++; }
            return true;
        }, IntPtr.Zero);
        if (count > 1) throw new InvalidOperationException("Multiple visible owned browser panes");
        return pane;
    }
    static Thread probeThread;
    static volatile bool probeRun;
    static double probeMax;
    static readonly object probeLock = new object();
    public static void StartHangProbe(IntPtr owner) {
        probeRun = true;
        probeThread = new Thread(() => {
            var timer = new System.Diagnostics.Stopwatch();
            while (probeRun) {
                UIntPtr result;
                timer.Restart();
                SendMessageTimeout(owner, 0, UIntPtr.Zero, IntPtr.Zero, 2, 5000, out result);
                double elapsed = timer.Elapsed.TotalMilliseconds;
                lock (probeLock) { if (elapsed > probeMax) probeMax = elapsed; }
                Thread.Sleep(2);
            }
        });
        probeThread.IsBackground = true;
        probeThread.Start();
    }
    public static void ResetHangProbe() { lock (probeLock) { probeMax = 0; } }
    public static double HangProbeMax() { lock (probeLock) { return probeMax; } }
    public static void StopHangProbe() { probeRun = false; if (probeThread != null) probeThread.Join(6000); }
    public static double[] SwitchToSession(int digit, string log, long offset, string needle, int settleMs) {
        Input[] inputs = new Input[4];
        for (int i = 0; i < inputs.Length; i++) inputs[i].type = 1;
        inputs[0].data.keyboard = new Keyboard { key = 0x11 };
        inputs[1].data.keyboard = new Keyboard { key = (ushort)(0x31 + digit) };
        inputs[2].data.keyboard = new Keyboard { key = (ushort)(0x31 + digit), flags = 2 };
        inputs[3].data.keyboard = new Keyboard { key = 0x11, flags = 2 };
        ResetHangProbe();
        var timer = System.Diagnostics.Stopwatch.StartNew();
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("SendInput Ctrl+digit failed");
        double shown = -1;
        long position = offset;
        string carry = "";
        while (timer.ElapsedMilliseconds < settleMs) {
            if (shown < 0) {
                using (var stream = new System.IO.FileStream(log, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.ReadWrite | System.IO.FileShare.Delete)) {
                    if (stream.Length > position) {
                        stream.Seek(position, System.IO.SeekOrigin.Begin);
                        var bytes = new byte[stream.Length - position];
                        int read = stream.Read(bytes, 0, bytes.Length);
                        position += read;
                        carry += Encoding.UTF8.GetString(bytes, 0, read);
                        if (carry.Contains(needle)) shown = timer.Elapsed.TotalMilliseconds;
                        if (carry.Length > 4096) carry = carry.Substring(carry.Length - 4096);
                    }
                }
            }
            Thread.Sleep(1);
        }
        return new double[] { shown, HangProbeMax() };
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
    public static Dictionary<string, object> ComposerTypingFrames(IntPtr owner, IntPtr composer, string text, Rect crop, string directory) {
        if (GetAncestor(composer, 2) != owner || GetForegroundWindow() != owner || GetFocusedWindow(owner) != composer || EditText(composer) != "") throw new InvalidOperationException("Typing burst requires the owned empty focused composer");
        Text(text.Substring(0, 12));
        var frames = new List<System.Drawing.Bitmap>();
        var times = new List<double>();
        var ready = new ManualResetEvent(false);
        var stop = new ManualResetEvent(false);
        Exception captureError = null;
        var timer = System.Diagnostics.Stopwatch.StartNew();
        var sampler = new Thread(delegate() {
            try {
                int width = crop.Right - crop.Left, height = crop.Bottom - crop.Top;
                if (width <= 0 || height <= 0 || width > 1000 || height > 100) throw new InvalidOperationException("Typing crop is not a small composer row");
                using (var bitmap = new System.Drawing.Bitmap(width, height, System.Drawing.Imaging.PixelFormat.Format32bppRgb))
                using (var graphics = System.Drawing.Graphics.FromImage(bitmap)) {
                    IntPtr screen = GetDC(IntPtr.Zero);
                    try {
                        ready.Set();
                        bool finalFrame = false;
                        while (true) {
                            if (GetForegroundWindow() != owner) throw new InvalidOperationException("Foreground left owned app during typing burst");
                            IntPtr target = graphics.GetHdc();
                            try {
                                if (!BitBlt(target, 0, 0, width, height, screen, crop.Left, crop.Top, 0x00CC0020)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
                            } finally { graphics.ReleaseHdc(target); }
                            times.Add(timer.Elapsed.TotalMilliseconds);
                            frames.Add(bitmap.Clone(new System.Drawing.Rectangle(0, 0, width, height), System.Drawing.Imaging.PixelFormat.Format32bppRgb));
                            if (frames.Count >= 4096) throw new InvalidOperationException("Typing burst exceeded frame limit");
                            if (finalFrame) break;
                            finalFrame = stop.WaitOne(2);
                        }
                    } finally { ReleaseDC(IntPtr.Zero, screen); }
                }
            } catch (Exception error) { captureError = error; ready.Set(); }
        });
        try {
            double typingStart = 0, typingEnd = 0;
            try {
                sampler.Start();
                if (!ready.WaitOne(5000)) throw new InvalidOperationException("Typing sampler did not start");
                typingStart = timer.Elapsed.TotalMilliseconds;
                Text(text.Substring(12));
                typingEnd = timer.Elapsed.TotalMilliseconds;
            } finally { stop.Set(); sampler.Join(); ready.Dispose(); stop.Dispose(); }
            if (captureError != null) throw new InvalidOperationException("Typing capture failed", captureError);
            if (GetFocusedWindow(owner) != composer || EditText(composer) != text) throw new InvalidOperationException("Typing burst lost the composer or sentence");
            for (int index = 0; index < frames.Count; index++) frames[index].Save(System.IO.Path.Combine(directory, "composer-typing-" + index.ToString("D4") + ".bmp"), System.Drawing.Imaging.ImageFormat.Bmp);
            return new Dictionary<string, object> { { "timesMs", times.ToArray() }, { "typingStartMs", typingStart }, { "typingEndMs", typingEnd }, { "capture", "screen BitBlt SRCCOPY; 2ms sampling; no forced repaint or DwmFlush" } };
        } finally { foreach (var frame in frames) frame.Dispose(); }
    }

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
    public static void RequireSwitchStart(IntPtr owner, IntPtr composer, IntPtr sourceConsole, string sourceSuffix, IntPtr sourceBrowser, Rect sourceDock, string sourceDraft, IntPtr targetConsole, string targetSuffix, IntPtr targetBrowser, Rect targetDock, string targetDraft, int sourceRgb, int targetRgb, int[] sourcePatch, int[] targetPatch) {
        if (sourceConsole == targetConsole || (sourceBrowser == targetBrowser && sourceBrowser != IntPtr.Zero) || sourceSuffix == targetSuffix || sourceDraft == targetDraft) throw new InvalidOperationException("Source and target sessions are not distinct");
        if (!SwitchReady(owner, sourceConsole, sourceSuffix, sourceBrowser, sourceDock, composer, sourceDraft)) throw new InvalidOperationException("Source session is not the visible foreground session before Ctrl+Tab");
        if (SwitchReady(owner, targetConsole, targetSuffix, targetBrowser, targetDock, composer, targetDraft)) throw new InvalidOperationException("Target session is already visible before Ctrl+Tab; this sample would not be a switch");
        if (!PagePainted(sourceDock, sourceRgb, sourcePatch)) throw new InvalidOperationException("Source session color is not on screen before Ctrl+Tab");
        if (PagePainted(targetDock, targetRgb, targetPatch)) throw new InvalidOperationException("Target session color is already on screen before Ctrl+Tab; this sample would not be a switch");
    }
    static void ReadPatch(int x, int y, System.Drawing.Bitmap pixels, System.Drawing.Graphics graphics) {
        IntPtr screen = GetDC(IntPtr.Zero);
        IntPtr target = graphics.GetHdc();
        try {
            if (!BitBlt(target, 0, 0, pixels.Width, pixels.Height, screen, x, y, 0x00CC0020)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        } finally { graphics.ReleaseHdc(target); ReleaseDC(IntPtr.Zero, screen); }
    }
    static bool PatchMatches(int x, int y, int[] colors, int offset, System.Drawing.Bitmap pixels, System.Drawing.Graphics graphics) {
        ReadPatch(x, y, pixels, graphics);
        for (int row = 0; row < pixels.Height; row++) {
            for (int col = 0; col < pixels.Width; col++) {
                var pixel = pixels.GetPixel(col, row);
                int want = colors[offset + row * pixels.Width + col];
                if (Math.Abs(pixel.R - ((want >> 16) & 255)) > 8 || Math.Abs(pixel.G - ((want >> 8) & 255)) > 8 || Math.Abs(pixel.B - (want & 255)) > 8) return false;
            }
        }
        return true;
    }
    static bool PaintMatches(Rect dock, int rgb, System.Drawing.Bitmap pixels, System.Drawing.Graphics graphics) {
        if (dock.Right - dock.Left < 16 || dock.Bottom - dock.Top < 200) throw new InvalidOperationException("Paint area is too small");
        int x = dock.Left + (dock.Right - dock.Left) / 2;
        int y = dock.Top + (dock.Bottom - dock.Top) * 3 / 4;
        var colors = new int[pixels.Width * pixels.Height];
        for (int index = 0; index < colors.Length; index++) colors[index] = rgb;
        return PatchMatches(x, y, colors, 0, pixels, graphics);
    }
    static bool Painted(Rect dock, int rgb, int[] patch, System.Drawing.Bitmap pixels, System.Drawing.Graphics graphics) {
        if (patch != null) return PatchMatches(patch[0], patch[1], patch, 2, pixels, graphics);
        return PaintMatches(dock, rgb, pixels, graphics);
    }
    public static bool PagePainted(Rect dock, int rgb, int[] patch) {
        using (var pixels = new System.Drawing.Bitmap(3, 3))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) return Painted(dock, rgb, patch, pixels, graphics);
    }
    public static bool PagePainted(Rect dock, int rgb) { return PagePainted(dock, rgb, null); }
    public static int SolidPatch(Rect area) {
        if (area.Right - area.Left < 16 || area.Bottom - area.Top < 200) throw new InvalidOperationException("Paint area is too small");
        using (var pixels = new System.Drawing.Bitmap(3, 3))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            ReadPatch(area.Left + (area.Right - area.Left) / 2, area.Top + (area.Bottom - area.Top) * 3 / 4, pixels, graphics);
            var first = pixels.GetPixel(0, 0);
            for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) {
                var pixel = pixels.GetPixel(col, row);
                if (Math.Abs(pixel.R - first.R) > 8 || Math.Abs(pixel.G - first.G) > 8 || Math.Abs(pixel.B - first.B) > 8) return -1;
            }
            return (first.R << 16) | (first.G << 8) | first.B;
        }
    }
    public static int[] CaptureComposerStart(IntPtr composer) {
        Point origin = new Point();
        if (!ClientToScreen(composer, ref origin)) throw new InvalidOperationException("Missing composer client origin");
        UIntPtr first;
        if (SendMessageTimeout(composer, 0x00D6, UIntPtr.Zero, IntPtr.Zero, 2, 2000, out first) == IntPtr.Zero) throw new InvalidOperationException("Missing composer first character position");
        int x = origin.X + (short)(first.ToUInt64() & 0xffff), y = origin.Y + (short)((first.ToUInt64() >> 16) & 0xffff);
        int[] previous = null;
        var stable = System.Diagnostics.Stopwatch.StartNew();
        while (stable.ElapsedMilliseconds < 5000) {
            var region = new int[2 + 16 * 16];
            region[0] = x; region[1] = y;
            using (var pixels = new System.Drawing.Bitmap(16, 16))
            using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
                ReadPatch(x, y, pixels, graphics);
                for (int row = 0; row < 16; row++) for (int col = 0; col < 16; col++) region[2 + row * 16 + col] = pixels.GetPixel(col, row).ToArgb() & 0xFFFFFF;
            }
            if (previous != null && System.Linq.Enumerable.SequenceEqual(previous, region)) return region;
            previous = region;
            Thread.Sleep(60);
        }
        throw new TimeoutException("Composer first character did not paint stably");
    }
    static int ChannelGap(int a, int b) {
        return Math.Max(Math.Abs(((a >> 16) & 255) - ((b >> 16) & 255)), Math.Max(Math.Abs(((a >> 8) & 255) - ((b >> 8) & 255)), Math.Abs((a & 255) - (b & 255))));
    }
    public static int[][] CalibratePatches(int[] regionA, int[] regionB) {
        if (regionA[0] != regionB[0] || regionA[1] != regionB[1]) throw new InvalidOperationException("Composer first character moved between sessions");
        int bestScore = 0, bestX = -1, bestY = -1;
        for (int oy = 0; oy <= 13; oy++) for (int ox = 0; ox <= 13; ox++) {
            int score = 0;
            for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) {
                int index = 2 + (oy + row) * 16 + ox + col;
                int gap = ChannelGap(regionA[index], regionB[index]);
                if (gap > 40) score += gap;
            }
            if (score > bestScore) { bestScore = score; bestX = ox; bestY = oy; }
        }
        if (bestX < 0) throw new InvalidOperationException("Composer first characters of the two sessions are indistinguishable on screen");
        var result = new int[2][];
        var sources = new int[][] { regionA, regionB };
        for (int which = 0; which < 2; which++) {
            result[which] = new int[11];
            result[which][0] = regionA[0] + bestX;
            result[which][1] = regionA[1] + bestY;
            for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) result[which][2 + row * 3 + col] = sources[which][2 + (bestY + row) * 16 + bestX + col];
        }
        if (PatchesDiffer(result[0], result[1]) == false) throw new InvalidOperationException("Composer calibration patches match each other within tolerance");
        return result;
    }
    static bool PatchesDiffer(int[] a, int[] b) {
        for (int index = 2; index < 11; index++) if (ChannelGap(a[index], b[index]) > 8) return true;
        return false;
    }
    public static double[] MeasureSessionSwitch(IntPtr owner, IntPtr console, string suffix, IntPtr browser, Rect dock, IntPtr composer, string draft, int rgb, string frozenMarker, int[] patch) {
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
                    if (painted < 0 && Painted(dock, rgb, patch, pixels, graphics)) painted = timer.Elapsed.TotalMilliseconds;
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
    public static void ClickBrowserContent(IntPtr pane, IntPtr owner) {
        Rect rect;
        if (!GetClientRect(pane, out rect)) throw new InvalidOperationException("Browser client rectangle unavailable");
        Point point = new Point { X = rect.Right / 2, Y = rect.Bottom / 2 };
        if (!ClientToScreen(pane, ref point)) throw new InvalidOperationException("Browser screen rectangle unavailable");
        RequireBrowserStrip(pane, owner, point);
        MouseAt(point.X, point.Y, 0);
        MouseAt(point.X, point.Y, 2);
        MouseAt(point.X, point.Y, 4);
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
    static System.Drawing.Color QueuedColor(System.Drawing.Color bg, System.Drawing.Color fill) {
        return System.Drawing.Color.FromArgb((bg.R * 128 + 128) / 256 + (fill.R * 127 + 128) / 256,
            (bg.G * 128 + 128) / 256 + (fill.G * 127 + 128) / 256,
            (bg.B * 128 + 128) / 256 + (fill.B * 127 + 128) / 256);
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
            if (bg.R == 0x10 && bg.G == 0x10 && bg.B == 0x10) fill = System.Drawing.Color.FromArgb(0x3A, 0x3A, 0x3A);
            var queuedFill = QueuedColor(bg, fill);
            for (int y = pixels.Height - 2; y > 0; y--) {
                for (int x = pixels.Width - 2; x > 0; x--) {
                    int color = pixels.GetPixel(x, y).ToArgb();
                    if ((color == fill.ToArgb() || color == queuedFill.ToArgb()) && pixels.GetPixel(x - 1, y).ToArgb() == color &&
                        pixels.GetPixel(x, y - 1).ToArgb() == color) return new Point { X = rect.Left + x - 1, Y = rect.Top + y - 1 };
                }
            }
        }
        throw new InvalidOperationException("No painted user message bubble in transcript");
    }
    [DllImport("user32.dll")] static extern int GetWindowRgn(IntPtr hwnd, IntPtr region);
    [DllImport("gdi32.dll")] static extern IntPtr CreateRectRgn(int left, int top, int right, int bottom);
    [DllImport("gdi32.dll")] static extern bool PtInRegion(IntPtr region, int x, int y);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr handle);
    public static Dictionary<string, object> MenuLook(IntPtr menu) {
        Rect rect, client;
        if (!GetWindowRect(menu, out rect) || !GetClientRect(menu, out client)) throw new InvalidOperationException("Menu rectangle unavailable");
        int width = rect.Right - rect.Left, height = rect.Bottom - rect.Top;
        int side = Math.Max(0, (width - (client.Right - client.Left)) / 2);
        IntPtr region = CreateRectRgn(0, 0, 0, 0);
        try {
            bool clipped = GetWindowRgn(menu, region) > 0;
            Func<int, int, bool> shown = (x, y) => !clipped || PtInRegion(region, x, y);
            using (var pixels = new System.Drawing.Bitmap(width, height))
            using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
                graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, pixels.Size);
                Func<int, int, string> hex = (x, y) => (pixels.GetPixel(x, y).ToArgb() & 0xFFFFFF).ToString("X6");
                return new Dictionary<string, object> {
                    { "width", width }, { "height", height }, { "clipped", clipped }, { "side", side },
                    { "fill", hex(width / 2, height - 6) },
                    { "cornerShown", shown(0, 0) && hex(0, 0) == hex(0, height / 2) },
                    { "corner", hex(0, 0) }, { "corner2", hex(2, 2) }, { "outerLeft", hex(0, height / 2) },
                    { "leftEdge", hex(side, height / 2) }, { "rightEdge", hex(width - 1 - side, height / 2) }
                };
            }
        } finally { DeleteObject(region); }
    }
    public static Point[] SelectTranscriptText(IntPtr hwnd, uint pid, IntPtr owner) {
        Point bubble = MessageBubblePoint(hwnd);
        Rect rect;
        if (!GetWindowRect(hwnd, out rect)) throw new InvalidOperationException("Transcript rectangle unavailable");
        Point start, end;
        using (var pixels = new System.Drawing.Bitmap(rect.Right - rect.Left, rect.Bottom - rect.Top))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, pixels.Size);
            int bx = bubble.X - rect.Left, by = bubble.Y - rect.Top;
            var seed = pixels.GetPixel(bx, by);
            var seen = new bool[pixels.Width, pixels.Height];
            var pending = new Queue<Point>();
            pending.Enqueue(new Point { X = bx, Y = by });
            seen[bx, by] = true;
            int left = bx, right = bx, top = by, bottom = by;
            int[] dx = { -1, 1, 0, 0 }, dy = { 0, 0, -1, 1 };
            while (pending.Count > 0) {
                Point p = pending.Dequeue();
                left = Math.Min(left, p.X); right = Math.Max(right, p.X);
                top = Math.Min(top, p.Y); bottom = Math.Max(bottom, p.Y);
                for (int i = 0; i < 4; i++) {
                    int x = p.X + dx[i], y = p.Y + dy[i];
                    if (x < 0 || y < 0 || x >= pixels.Width || y >= pixels.Height || seen[x, y]) continue;
                    seen[x, y] = true;
                    var near = pixels.GetPixel(x, y);
                    if (Math.Max(Math.Abs(near.R - seed.R), Math.Max(Math.Abs(near.G - seed.G), Math.Abs(near.B - seed.B))) <= 10) pending.Enqueue(new Point { X = x, Y = y });
                }
            }
            int inset = Math.Max(4, Math.Min(right - left, bottom - top) / 5);
            int glyphLeft = right, glyphRight = left, glyphTop = -1, glyphBottom = -1;
            var background = seed;
            for (int y = top + inset; y <= bottom - inset; y++) {
                bool ink = false;
                for (int x = left + inset; x <= right - inset; x++) {
                    var c = pixels.GetPixel(x, y);
                    if (Math.Max(Math.Abs(c.R - background.R), Math.Max(Math.Abs(c.G - background.G), Math.Abs(c.B - background.B))) < 40) continue;
                    ink = true;
                    glyphLeft = Math.Min(glyphLeft, x); glyphRight = Math.Max(glyphRight, x);
                }
                if (ink) {
                    if (glyphTop < 0) glyphTop = y;
                    glyphBottom = y;
                } else if (glyphTop >= 0) break;
            }
            if (glyphTop < 0 || glyphRight - glyphLeft < 24) throw new InvalidOperationException("No partial text span in the owned user bubble");
            int lineY = rect.Top + (glyphTop + glyphBottom) / 2;
            start = new Point { X = rect.Left + glyphLeft + 2, Y = lineY };
            end = new Point { X = start.X + (glyphRight - glyphLeft) / 3, Y = lineY };
        }
        uint actualPid;
        GetWindowThreadProcessId(hwnd, out actualPid);
        if (actualPid != pid || Class(hwnd) != "ZigShellChatTranscript" || GetAncestor(hwnd, 2) != owner ||
            GetForegroundWindow() != owner || WindowFromPoint(start) != hwnd || WindowFromPoint(end) != hwnd)
            throw new InvalidOperationException("Selection is not in the foreground owned transcript");
        MouseAt(start.X, start.Y, 0);
        MouseAt(start.X, start.Y, 2);
        try {
            for (int step = 1; step <= 12; step++) {
                Point p = new Point { X = start.X + (end.X - start.X) * step / 12, Y = start.Y };
                if (WindowFromPoint(p) != hwnd) throw new InvalidOperationException("Selection drag left the owned transcript");
                MouseAt(p.X, p.Y, 0);
                Thread.Sleep(20);
            }
        } finally { MouseAt(end.X, end.Y, 4); }
        return new Point[] { start, end };
    }
    public static int TranscriptSelectionPixels(IntPtr hwnd, Point[] points) {
        if (points.Length != 2 || points[1].X <= points[0].X || points[0].Y != points[1].Y ||
            WindowFromPoint(points[0]) != hwnd || WindowFromPoint(points[1]) != hwnd)
            throw new InvalidOperationException("Selection evidence is not inside the owned transcript");
        int pad = Math.Max(8, (int)GetDpiForWindow(hwnd) / 6);
        Rect rect;
        if (!GetWindowRect(hwnd, out rect)) throw new InvalidOperationException("Transcript rectangle unavailable");
        System.Drawing.Color bg;
        using (var backdrop = new System.Drawing.Bitmap(1, 1))
        using (var graphics = System.Drawing.Graphics.FromImage(backdrop)) {
            graphics.CopyFromScreen(rect.Left, rect.Top + (rect.Bottom - rect.Top) / 2, 0, 0, backdrop.Size);
            bg = backdrop.GetPixel(0, 0);
        }
        var queuedColors = new HashSet<int>();
        foreach (var fill in new System.Drawing.Color[] { System.Drawing.Color.FromArgb(56, 78, 112), System.Drawing.Color.FromArgb(183, 206, 240), System.Drawing.Color.FromArgb(52, 68, 96) }) queuedColors.Add(QueuedColor(bg, fill).ToArgb());
        using (var pixels = new System.Drawing.Bitmap(points[1].X - points[0].X, pad * 2 + 1))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            DwmFlush();
            graphics.CopyFromScreen(points[0].X, points[0].Y - pad, 0, 0, pixels.Size);
            int count = 0;
            for (int y = 0; y < pixels.Height; y++) {
                for (int x = 0; x < pixels.Width; x++) {
                    var c = pixels.GetPixel(x, y);
                    if ((c.R == 56 && c.G == 78 && c.B == 112) || (c.R == 183 && c.G == 206 && c.B == 240) ||
                        (c.R == 52 && c.G == 68 && c.B == 96)) count++;
                    else if (queuedColors.Contains(c.ToArgb())) count++;
                }
            }
            return count;
        }
    }
    public static int[] DictationMicPixels(IntPtr owner, int[] rect, bool active, string output) {
        Point origin = new Point();
        if (!ClientToScreen(owner, ref origin)) throw new InvalidOperationException("Missing microphone origin");
        Point center = new Point { X = origin.X + (rect[0] + rect[2]) / 2, Y = origin.Y + (rect[1] + rect[3]) / 2 };
        if (WindowFromPoint(center) != owner) throw new InvalidOperationException("Microphone is not in the owned frame");
        using (var pixels = new System.Drawing.Bitmap(rect[2] - rect[0], rect[3] - rect[1])) {
            using (var graphics = System.Drawing.Graphics.FromImage(pixels)) graphics.CopyFromScreen(origin.X + rect[0], origin.Y + rect[1], 0, 0, pixels.Size);
            pixels.Save(output, System.Drawing.Imaging.ImageFormat.Png);
            int fill = 0, ink = 0;
            for (int y = 0; y < pixels.Height; y++) for (int x = 0; x < pixels.Width; x++) {
                var c = pixels.GetPixel(x, y);
                if (c.R == 63 && c.G == 83 && c.B == 113) fill++;
                int r = active ? 80 : 137, g = active ? 150 : 146, b = active ? 255 : 164;
                if (Math.Abs(c.R - r) <= 15 && Math.Abs(c.G - g) <= 15 && Math.Abs(c.B - b) <= 15) ink++;
            }
            return new int[] { fill, ink, pixels.Width * pixels.Height };
        }
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
    public static int RegionDiff(string before, string after, IntPtr owner, int left, int top, int right, int bottom) {
        Rect frame;
        Point origin = new Point();
        if (!GetWindowRect(owner, out frame) || !ClientToScreen(owner, ref origin)) throw new InvalidOperationException("Region screen origin unavailable");
        int dx = origin.X - frame.Left, dy = origin.Y - frame.Top, differing = 0;
        using (var a = new System.Drawing.Bitmap(before))
        using (var b = new System.Drawing.Bitmap(after)) {
            for (int y = Math.Max(0, top); y < bottom; y++) {
                for (int x = Math.Max(0, left); x < right; x++) {
                    if (a.GetPixel(dx + x, dy + y).ToArgb() != b.GetPixel(dx + x, dy + y).ToArgb()) differing++;
                }
            }
        }
        return differing;
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
    static bool TextPixel(System.Drawing.Color color) { return color.R > 210 && color.G > 210 && color.B > 210; }
    static int TextLeft(System.Drawing.Bitmap image, int left, int right, int top, int height) {
        for (int x = left; x < right; x++)
            for (int y = top; y < top + height; y++)
                if (TextPixel(image.GetPixel(x, y))) return x;
        return -1;
    }
    public static Dictionary<string, object> Check(string path, VerifyNative.Rect frame, VerifyNative.Point origin, uint dpi, int scale, bool hidePills, bool collapsed) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int clientLeft = origin.X - frame.Left;
            int left = clientLeft + S(8, dpi, scale);
            int right = clientLeft + S(220, dpi, scale) - S(8, dpi, scale) / 2;
            int top = origin.Y - frame.Top + S(8, dpi, scale) + (hidePills ? 0 : 34);
            int headerHeight = 28, rowHeight = S(38, dpi, scale);
            int secondHeader = top + headerHeight + (collapsed ? 0 : 2 * rowHeight);
            int groupBottom = secondHeader + headerHeight + 2 * rowHeight;
            var background = image.GetPixel(clientLeft + S(2, dpi, scale), top);
            var muted = System.Drawing.Color.FromArgb(98, 102, 109);
            var rail = System.Drawing.Color.FromArgb(145, 149, 157);
            int fillMismatch = 0, railPixels = 0, brightHeaderPixels = 0, largestPrefixGap = 0;
            var nameXs = new List<int>();
            var sessionXs = new List<int>();
            bool flushLeft = true;
            for (int group = 0; group < 2; group++) {
                int headerTop = group == 0 ? top : secondHeader;
                foreach (int y in new int[] { headerTop, headerTop + headerHeight - 1 })
                    for (int x = clientLeft; x < clientLeft + S(220, dpi, scale) - 1; x++)
                        if (Distance(image.GetPixel(x, y), background) > 3) fillMismatch++;
                int nameLeft = -1;
                var headerBackground = image.GetPixel(right - S(8, dpi, scale), headerTop + headerHeight / 2);
                int blankColumns = 0;
                bool seenInk = false;
                for (int x = left; x < right - S(8, dpi, scale); x++) {
                    bool columnInk = false;
                    for (int y = headerTop + 1; y < headerTop + headerHeight - 1; y++) {
                        var pixel = image.GetPixel(x, y);
                        if (Distance(pixel, headerBackground) > 18) columnInk = true;
                        if (TextPixel(pixel)) brightHeaderPixels++;
                        if (Distance(pixel, muted) <= 16 && Distance(pixel, headerBackground) > 18 && nameLeft < 0) nameLeft = x;
                    }
                    if (columnInk) {
                        if (seenInk) largestPrefixGap = Math.Max(largestPrefixGap, blankColumns);
                        seenInk = true;
                        blankColumns = 0;
                    } else if (seenInk) blankColumns++;
                }
                int memberTop = headerTop + headerHeight;
                int sessionLeft = -1;
                if (group != 0 || !collapsed) {
                    int textStart = left + S(12, dpi, scale) + S(16, dpi, scale) + S(8, dpi, scale);
                    sessionLeft = TextLeft(image, textStart, right - S(44, dpi, scale), memberTop, rowHeight);
                    int normalizedSessionLeft = sessionLeft - S(16, dpi, scale) - S(8, dpi, scale);
                    flushLeft = flushLeft && sessionLeft >= 0 && nameLeft >= 0 && Math.Abs(nameLeft - normalizedSessionLeft) <= Math.Max(3, S(3, dpi, scale));
                    for (int y = memberTop; y < memberTop + 2 * rowHeight; y++)
                        for (int x = clientLeft; x < left + S(10, dpi, scale); x++)
                            if (Distance(image.GetPixel(x, y), rail) <= 2) railPixels++;
                } else {
                    flushLeft = flushLeft && nameLeft >= 0 && Math.Abs(nameLeft - (left + S(12, dpi, scale))) <= Math.Max(3, S(3, dpi, scale));
                }
                nameXs.Add(nameLeft);
                sessionXs.Add(sessionLeft);
            }
            proof["noFill"] = fillMismatch == 0;
            proof["noRail"] = railPixels == 0;
            proof["flushLeft"] = flushLeft && brightHeaderPixels == 0 && largestPrefixGap < S(8, dpi, scale);
            proof["fillMismatch"] = fillMismatch;
            proof["railPixels"] = railPixels;
            proof["brightHeaderPixels"] = brightHeaderPixels;
            proof["largestPrefixGap"] = largestPrefixGap;
            proof["nameX"] = nameXs.ToArray();
            proof["sessionTextX"] = sessionXs.ToArray();
            proof["sessionIconInset"] = S(16, dpi, scale) + S(8, dpi, scale);
            proof["headerTops"] = new int[] { top, secondHeader };
            proof["headerHeight"] = headerHeight;
            proof["rowHeight"] = rowHeight;
            proof["sidebarRect"] = new int[] { clientLeft, top, clientLeft + S(220, dpi, scale) - 1, groupBottom };
            proof["railSearchX"] = new int[] { clientLeft, left + S(10, dpi, scale) };
            proof["background"] = new int[] { background.R, background.G, background.B };
        }
        return proof;
    }
    public static Dictionary<string, object> Labels(string path, VerifyNative.Rect frame, VerifyNative.Point origin, uint dpi, int scale, int sectionTop, int headlineX, int rowHeight) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int clientLeft = origin.X - frame.Left;
            int right = clientLeft + S(220, dpi, scale) - S(8, dpi, scale);
            int sectionHeight = 24, buttonHeight = 32;
            var muted = System.Drawing.Color.FromArgb(98, 102, 109);
            var sectionBackground = image.GetPixel(right, sectionTop + sectionHeight / 2);
            int firstInk = -1, inkPixels = 0, mutedPixels = 0, topInk = int.MaxValue, inkColumns = 0;
            var columnTops = new List<int>();
            var columnXs = new List<int>();
            for (int x = clientLeft + S(4, dpi, scale); x < right - S(8, dpi, scale); x++) {
                int columnTop = -1;
                for (int y = sectionTop + 1; y < sectionTop + sectionHeight - 1; y++) {
                    var pixel = image.GetPixel(x, y);
                    if (Distance(pixel, sectionBackground) <= 30) continue;
                    inkPixels++;
                    if (Distance(pixel, muted) <= 16) mutedPixels++;
                    if (columnTop < 0) columnTop = y;
                }
                if (columnTop >= 0) {
                    if (firstInk < 0) firstInk = x;
                    inkColumns++;
                    columnTops.Add(columnTop);
                    columnXs.Add(x);
                }
            }
            int capColumns = 0;
            int textColumns = 0;
            for (int i = 0; i < columnTops.Count; i++)
                if (columnXs[i] >= headlineX - 3) topInk = Math.Min(topInk, columnTops[i]);
            for (int i = 0; i < columnTops.Count; i++) {
                if (columnXs[i] < headlineX - 3) continue;
                textColumns++;
                if (columnTops[i] <= topInk + 1) capColumns++;
            }
            double capRatio = textColumns == 0 ? 1.0 : (double)capColumns / textColumns;
            bool present = inkPixels >= 15;
            bool noArrow = present && Math.Abs(firstInk - headlineX) <= Math.Max(3, S(3, dpi, scale));
            bool mixedCase = present && capRatio < 0.5;
            bool mutedInk = mutedPixels >= 8;
            int buttonTop = sectionTop + sectionHeight + 2 * rowHeight + 4;
            var buttonBackground = image.GetPixel(right, buttonTop + buttonHeight / 2);
            int minX = int.MaxValue, maxX = -1, minY = int.MaxValue, maxY = -1, buttonInk = 0;
            for (int y = buttonTop; y < buttonTop + buttonHeight; y++) {
                for (int x = clientLeft + S(2, dpi, scale); x < clientLeft + S(220, dpi, scale) - S(2, dpi, scale); x++) {
                    if (Distance(image.GetPixel(x, y), buttonBackground) <= 30) continue;
                    buttonInk++;
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x);
                    minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
                }
            }
            bool plusOnly = buttonInk >= 4 && maxX - minX + 1 <= S(24, dpi, scale) && maxY - minY + 1 <= S(24, dpi, scale);
            proof["labelPresent"] = present;
            proof["noArrow"] = noArrow;
            proof["mixedCase"] = mixedCase;
            proof["mutedInk"] = mutedInk;
            proof["sameStyle"] = present && mixedCase && mutedInk && noArrow;
            proof["plusOnly"] = plusOnly;
            proof["labelFirstInkX"] = firstInk;
            proof["headlineX"] = headlineX;
            proof["capRatio"] = capRatio;
            proof["labelInkPixels"] = inkPixels;
            proof["labelMutedPixels"] = mutedPixels;
            proof["labelRect"] = new int[] { clientLeft, sectionTop, right, sectionTop + sectionHeight };
            proof["buttonRect"] = new int[] { clientLeft, buttonTop, clientLeft + S(220, dpi, scale), buttonTop + buttonHeight };
            proof["buttonInkBox"] = buttonInk == 0 ? new int[0] : new int[] { minX, minY, maxX, maxY };
            proof["buttonInkPixels"] = buttonInk;
        }
        return proof;
    }
    static bool SameRow(System.Drawing.Bitmap baseline, System.Drawing.Bitmap image, int x, int firstY, int secondY, int width, int height) {
        int ink = 0, changed = 0;
        for (int dx = 0; dx < width; dx++) {
            for (int dy = 0; dy < height; dy++) {
                var original = baseline.GetPixel(x + dx, firstY + dy);
                var actual = image.GetPixel(x + dx, secondY + dy);
                if (original.R > 210 && original.G > 210 && original.B > 210) ink++;
                if (Math.Abs(original.R - actual.R) > 48 || Math.Abs(original.G - actual.G) > 48 || Math.Abs(original.B - actual.B) > 48) changed++;
            }
        }
        return ink > 5 && changed <= 4;
    }
    public static Dictionary<string, object> Toggle(string before, string hidden, string after, int textX, int firstRow, int rowHeight, int scanTop, int scanBottom, uint dpi, int scale) {
        var proof = new Dictionary<string, object>();
        using (var baseline = new System.Drawing.Bitmap(before))
        using (var collapsed = new System.Drawing.Bitmap(hidden))
        using (var restored = new System.Drawing.Bitmap(after)) {
            int hiddenMatches = 0, restoredMatches = 0;
            for (int member = 0; member < 2; member++) {
                int memberTop = firstRow + member * rowHeight;
                for (int y = scanTop; y <= scanBottom - rowHeight; y++)
                    if (SameRow(baseline, collapsed, textX, memberTop, y, S(90, dpi, scale), rowHeight)) hiddenMatches++;
                if (SameRow(baseline, restored, textX, memberTop, memberTop, S(90, dpi, scale), rowHeight)) restoredMatches++;
            }
            proof["hiddenMemberMatches"] = hiddenMatches;
            proof["restoredMemberMatches"] = restoredMatches;
            proof["membersDisappearAndReturn"] = hiddenMatches == 0 && restoredMatches == 2;
            proof["textRect"] = new int[] { textX, firstRow, textX + S(90, dpi, scale), firstRow + 2 * rowHeight };
            proof["scanY"] = new int[] { scanTop, scanBottom };
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
    public static Dictionary<string, object> FocusMargins(string inputPath, string browserPath, VerifyNative.Rect frame,
        VerifyNative.Rect client, VerifyNative.Rect console, VerifyNative.Rect browser, uint dpi, int scale) {
        int gap = S(8, dpi, scale), inset = S(10, dpi, scale), margin = S(2, dpi, scale);
        int browserLeft = browser.Left - inset;
        int primaryLeft = client.Left + S(220, dpi, scale) + gap / 2;
        int mismatches = 0, samples = 0;
        var first = new List<int[]>();
        Func<int, int, bool> inContent = (x, y) =>
            (x >= console.Left - margin && x < console.Right + margin && y >= console.Top - margin && y < console.Bottom + margin) ||
            (x >= browser.Left - margin && x < browser.Right + margin && y >= browser.Top - margin && y < browser.Bottom + margin);
        using (var input = new System.Drawing.Bitmap(inputPath))
        using (var page = new System.Drawing.Bitmap(browserPath)) {
            if (input.Width != page.Width || input.Height != page.Height) throw new InvalidOperationException("Focus screenshot dimensions changed");
            foreach (var slot in new int[][] {
                new int[] { primaryLeft, client.Top + gap, browserLeft - gap, client.Bottom - gap },
                new int[] { browserLeft, client.Top + gap, client.Right - gap, client.Bottom - gap }
            }) {
                if (slot[2] - slot[0] <= 2 * inset || slot[3] - slot[1] <= 2 * inset) throw new InvalidOperationException("Invalid focus slot geometry");
                for (int y = slot[1]; y < slot[3]; y++) {
                    for (int x = slot[0]; x < slot[2]; x++) {
                        int edge = Math.Min(Math.Min(x - slot[0], slot[2] - 1 - x), Math.Min(y - slot[1], slot[3] - 1 - y));
                        if (edge >= inset || inContent(x, y)) continue;
                        int px = x - frame.Left, py = y - frame.Top;
                        samples++;
                        int inputArgb = input.GetPixel(px, py).ToArgb(), pageArgb = page.GetPixel(px, py).ToArgb();
                        if (inputArgb == pageArgb) continue;
                        mismatches++;
                        if (first.Count < 32) first.Add(new int[] { x, y, inputArgb, pageArgb });
                    }
                }
            }
        }
        return new Dictionary<string, object> { { "samples", samples }, { "mismatches", mismatches }, { "firstMismatches", first } };
    }
    public static List<Dictionary<string, object>> Masks(uint appPid) {
        var masks = new List<Dictionary<string, object>>();
        foreach (var window in VerifyNative.DesktopWindows()) {
            if ((string)window["class"] != "ZigShellBrowserEdgeMask" || (uint)window["pid"] != appPid || !(bool)window["visible"]) continue;
            VerifyNative.Rect rect;
            if (!VerifyNative.GetWindowRect(new IntPtr((long)window["handle"]), out rect) || rect.Right <= rect.Left || rect.Bottom <= rect.Top) continue;
            window["rect"] = new int[] { rect.Left, rect.Top, rect.Right, rect.Bottom };
            masks.Add(window);
        }
        return masks;
    }
    public static Dictionary<string, object> MeasureMasks(string path, string theme, VerifyNative.Rect frame, VerifyNative.Rect client,
        VerifyNative.Rect browser, Dictionary<string, object>[] masks, uint dpi, int scale) {
        var proof = new Dictionary<string, object>();
        int[] selected = null, raw = null;
        long handle = 0;
        int candidates = 0, bleed = Math.Max(1, S(4, dpi, scale));
        foreach (var mask in masks) {
            var rect = (int[])mask["rect"];
            int left = Math.Max(rect[0], browser.Left), top = Math.Max(rect[1], browser.Top);
            int right = Math.Min(rect[2], browser.Right), bottom = Math.Min(rect[3], browser.Bottom);
            int width = right - left, height = bottom - top;
            if (top != browser.Top || right != browser.Right || rect[0] < browser.Left || rect[1] < browser.Top - bleed || rect[2] > browser.Right + bleed ||
                rect[3] > browser.Bottom || width < S(100, dpi, scale) || width > S(180, dpi, scale) || height < S(24, dpi, scale) || height > S(40, dpi, scale)) continue;
            selected = new int[] { left, top, right, bottom }; raw = rect; handle = (long)mask["handle"]; candidates++;
        }
        Require(candidates == 1, "mask-top-right-" + theme, "Expected one frame-side controls mask, found " + candidates);
        int y = selected[1] + Math.Max(1, S(12, dpi, scale));
        int maskX = (selected[0] + selected[2]) / 2, referenceX = selected[0] - Math.Max(1, S(4, dpi, scale));
        int appX = client.Left + S(180, dpi, scale), appY = client.Top + S(200, dpi, scale);
        foreach (var mask in masks) {
            var rect = (int[])mask["rect"];
            if (referenceX >= rect[0] && referenceX < rect[2] && y >= rect[1] && y < rect[3])
                throw new InvalidOperationException("pane-layout mask-reference-" + theme + " FAIL: reference is covered by a mask");
        }
        Require(referenceX > browser.Left && y > browser.Top && y < selected[3] && y < browser.Top + S(24, dpi, scale),
            "mask-reference-" + theme, "Reference must be inside Chrome's frame above page content");
        using (var image = new System.Drawing.Bitmap(path)) {
            Func<int, int, System.Drawing.Color> pixel = (x, py) => image.GetPixel(x - frame.Left, py - frame.Top);
            var color = pixel(maskX, y);
            var reference = pixel(referenceX, y);
            var app = pixel(appX, appY);
            proof["maskHwnd"] = handle; proof["maskRect"] = raw; proof["maskInsideBrowserRect"] = selected;
            proof["browserRect"] = new int[] { browser.Left, browser.Top, browser.Right, browser.Bottom };
            proof["screenshotRect"] = new int[] { frame.Left, frame.Top, frame.Right, frame.Bottom };
            proof["maskPoint"] = new int[] { maskX, y }; proof["referencePoint"] = new int[] { referenceX, y }; proof["appPoint"] = new int[] { appX, appY };
            proof["maskColor"] = new int[] { color.R, color.G, color.B };
            proof["referenceColor"] = new int[] { reference.R, reference.G, reference.B };
            proof["appColor"] = new int[] { app.R, app.G, app.B };
            proof["channelDeltas"] = new int[] { Math.Abs(color.R - reference.R), Math.Abs(color.G - reference.G), Math.Abs(color.B - reference.B) };
            proof["chromeDelta"] = Distance(color, reference); proof["appDelta"] = Distance(color, app);
            proof["tolerance"] = 10; proof["nearBlackThreshold"] = 32;
        }
        return proof;
    }
    public static void CheckMasks(Dictionary<string, object> proof, string theme) {
        var color = (int[])proof["maskColor"];
        var reference = (int[])proof["referenceColor"];
        var app = (int[])proof["appColor"];
        int tolerance = (int)proof["tolerance"], black = (int)proof["nearBlackThreshold"];
        bool referenceBlack = reference[0] <= black && reference[1] <= black && reference[2] <= black;
        bool maskBlack = color[0] <= black && color[1] <= black && color[2] <= black;
        Require(referenceBlack || !maskBlack, "mask-not-black-" + theme, "Near-black mask over non-black Chrome frame");
        Require((int)proof["chromeDelta"] <= tolerance, "mask-chrome-" + theme,
            "mask=" + string.Join(",", color) + " Chrome=" + string.Join(",", reference) + " delta=" + proof["chromeDelta"]);
        if (theme == "dark" || theme == "amoled") {
            Require(reference[0] >= 160 && reference[1] >= 160 && reference[2] >= 160 && app[0] <= 80 && app[1] <= 80 && app[2] <= 80 &&
                (int)proof["appDelta"] > tolerance && (int)proof["chromeDelta"] < (int)proof["appDelta"],
                "mask-follows-chrome-" + theme, "Need a light Chrome frame, dark app surface and a mask matching Chrome rather than the app");
        }
    }
    public static Dictionary<string, object> Check(string path, VerifyNative.Rect frame, VerifyNative.Rect client,
        VerifyNative.Rect console, VerifyNative.Rect browser, uint dpi, int scale, bool hidePills) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int ox = frame.Left, oy = frame.Top;
            Func<int, int, System.Drawing.Color> pixel = (x, y) => image.GetPixel(x - ox, y - oy);
            int gap = S(8, dpi, scale), pad = S(6, dpi, scale), border = S(1, dpi, scale);
            int sidebarLeft = client.Left + gap;
            int sidebarRight = client.Left + S(220, dpi, scale) - gap / 2;
            int left = sidebarRight + gap, right = browser.Left - S(10, dpi, scale) - gap;
            int top = client.Top + gap, bottom = client.Bottom - gap;
            Require(console.Left >= left && console.Right <= right && console.Top >= top && console.Bottom <= bottom,
                "console-inside-inset", "HWND=" + console.Left + "," + console.Top + "," + console.Right + "," + console.Bottom);
            int browserLeft = browser.Left - S(10, dpi, scale);
            int gapLeft = browserLeft - gap, middleX = gapLeft + gap / 2;
            int middleY = (client.Top + client.Bottom) / 2;
            var divider = System.Drawing.Color.FromArgb(60, 60, 60);
            int forbidden = 0, gripPixels = 0;
            for (int x = gapLeft; x < browserLeft; x++) {
                for (int y = client.Top; y < client.Bottom; y++) {
                    var color = pixel(x, y);
                    bool line = Distance(color, System.Drawing.Color.FromArgb(95, 95, 95)) <= 3 || Distance(color, divider) <= 3;
                    if (!line) continue;
                    bool grip = x >= middleX && x < middleX + border && y >= middleY - S(16, dpi, scale) && y < middleY + S(16, dpi, scale);
                    if (grip && Distance(color, divider) <= 3) gripPixels++; else forbidden++;
                }
            }
            proof["gapRect"] = new int[] { gapLeft, client.Top, browserLeft, client.Bottom };
            proof["gripPixels"] = gripPixels;
            Require(forbidden == 0 && gapLeft >= right, "clean-gap", "forbidden ring/divider pixels=" + forbidden);
            int rowTop = client.Top + gap + (hidePills ? 0 : 34) + 28;
            int rowBottom = rowTop + S(38, dpi, scale);
            var railColor = System.Drawing.Color.FromArgb(145, 149, 157);
            int railPixels = 0;
            for (int x = sidebarLeft; x < sidebarLeft + S(10, dpi, scale); x++)
                for (int y = rowTop; y < rowBottom; y++)
                    if (Distance(pixel(x, y), railColor) <= 2) railPixels++;
            Require(railPixels == 0, "group-line-absent", "unexpected group rail pixels=" + railPixels);
            var rowBackground = pixel(sidebarRight - S(45, dpi, scale), (rowTop + rowBottom) / 2);
            var cardBackground = pixel(sidebarLeft + S(2, dpi, scale), (rowTop + rowBottom) / 2);
            var sidebarBackground = pixel(sidebarRight - S(45, dpi, scale), rowBottom + S(2, dpi, scale));
            string backgroundColors = " rowBackground=" + rowBackground + " cardBackground=" + cardBackground + " sidebarBackground=" + sidebarBackground;
            var firstIconColor = System.Drawing.Color.Empty;
            int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1, iconPixels = 0;
            for (int x = sidebarLeft; x < sidebarLeft + S(34, dpi, scale); x++) {
                for (int y = rowTop + S(4, dpi, scale); y < rowBottom - S(4, dpi, scale); y++) {
                    var color = pixel(x, y);
                    if (Distance(color, rowBackground) <= 16 || Distance(color, cardBackground) <= 16 || Distance(color, sidebarBackground) <= 16) continue;
                    if (x < minX) firstIconColor = color;
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y); iconPixels++;
                }
            }
            Require(iconPixels >= S(16, dpi, scale) && maxY - minY >= S(8, dpi, scale), "row-icon-found", "No visible CMD icon pixels in the first grouped row" + backgroundColors);
            proof["railPixels"] = railPixels;
            proof["memberRect"] = new int[] { sidebarLeft, rowTop, sidebarRight, rowBottom };
            proof["iconPixelBounds"] = new int[] { minX, minY, maxX + 1, maxY + 1 };
            proof["iconPixels"] = iconPixels;
            Require(sidebarLeft + S(12, dpi, scale) <= minX, "group-content-inset", "contentLeft=" + sidebarLeft + " iconLeft=" + minX + " firstIconColor=" + firstIconColor + backgroundColors);
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
$switchExtensionRoot = $null
$script:pinnedNotifyListeners = @()
$script:uploadReceiver = $null
$script:uploadReceiverDir = $null
$script:window = [IntPtr]::Zero
$script:actions = New-Object System.Collections.ArrayList
$script:scratchLinks = @()
$result = [ordered]@{ feature = $Feature; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; checks = @(); offlineLogin = $true; cleanup = 'pending' }
$original = @{}
$originalFontSmoothing = $null

function Save-Json($Value, [string]$Name) {
    Write-Host "Evidence: serialize $Name"
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}

function Record([string]$Action) {
    Write-Host $Action
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
    if ($title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw "Doctor: wrong version in $title" }
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
    Assert-Foreground
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
try {
    if ($Feature -in @('title-bar', 'window-controls')) {
        Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'title-bar-native.cs')
        [CaptionProof]::SetDpi([int]$env:CAPTION_DPI)
    }
    if ($Feature -eq 'chat-composer-text') {
        $originalFontSmoothing = [VerifyNative]::FontSmoothing()
        [VerifyNative]::FontSmoothing($false)
    }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'IGSH_246', 'MULTIPROMPT_DICTATION_FIXTURE')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {
        $chrome = & node (Join-Path $PSScriptRoot 'browser-switch-chrome.mjs')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $chrome)) { throw 'Pinned Chrome for Testing executable unavailable' }
    }
    if ($Feature -eq 'title-bar') {
        $chrome = & node (Join-Path $PSScriptRoot 'browser-switch-chrome.mjs')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $chrome)) { throw 'Pinned caption browser executable unavailable' }
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    if ($Feature -ne 'browser-own-profile') { $env:USERPROFILE = Join-Path $scratch 'profile' }
    $env:HOME = Join-Path $scratch 'profile'
    if ($Feature -eq 'status-card') {
        $usageCollector = [Threading.Mutex]::new($false, 'Local\MultipromptUsageTelemetryLaunch')
        $usageRoot = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $usageRoot | Out-Null
        Copy-Item (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-908/usage-telemetry.json') (Join-Path $usageRoot 'usage-telemetry.json')
    }
    if ($Feature -eq 'chat-skill-pill') {
        $skillRoot = Join-Path $env:USERPROFILE '.claude/skills/pill-proof'
        New-Item -ItemType Directory -Force $skillRoot | Out-Null
        [IO.File]::WriteAllText((Join-Path $skillRoot 'SKILL.md'), "---`nname: pill-proof`ndescription: isolated skill color proof`n---`nReply with the given text.")
    }
    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {
        $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        $extensionRoot = [IO.Path]::GetFullPath((Split-Path $extension))
        $extensionRootExisted = Test-Path -LiteralPath $extensionRoot
        if (-not $extensionRootExisted) {
            New-Item -ItemType Directory -Path $extensionRoot | Out-Null
            $switchExtensionRoot = (Resolve-Path -LiteralPath $extensionRoot).Path
        }
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
    if ($Feature -eq 'title-bar') {
        $edge = $chrome
        $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData'
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config, (Join-Path $profile 'Default') | Out-Null
        [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $chrome)
        [IO.File]::WriteAllText((Join-Path $config 'browser-engine.txt'), 'chrome')
        $scheme = if ($env:CAPTION_BROWSER_THEME -eq 'light') { 1 } else { 2 }
        @{ browser = @{ theme = @{ color_scheme = $scheme } } } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $profile 'Default/Preferences')
    }
    $paletteUsageFixture = Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-612/palette-usage.tsv'
    if ($Feature -eq 'palette-order') {
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config | Out-Null
        Copy-Item $paletteUsageFixture (Join-Path $config 'palette-usage.tsv')
    }
    $env:MULTIPROMPT_DICTATION_FIXTURE = $null
    if ($Feature -eq 'chat-dictation') {
        $fixture = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-812')).Path
        $audioHash = (Get-FileHash (Join-Path $fixture 'goforward.pcm') -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($audioHash -cne 'f15c60ec54059d8b66e410d0064945a0b0a04ea56e1ddca1958e493c0cf70e71') { throw 'Recorded dictation PCM checksum mismatch' }
        $env:MULTIPROMPT_DICTATION_FIXTURE = $fixture
        $result.dictationBoundary = @{ audio = 'recorded CMUSphinx goforward.pcm'; sha256 = $audioHash; provider = 'offline provider-format response replay, not live Deepgram recognition'; microphoneHardware = $false }
    }
    if ($Feature -eq 'browser-own-profile') {
        for ($port = 19548; $port -le 19559; $port++) {
            $pinned = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
            $pinned.Start()
            $script:pinnedNotifyListeners += $pinned
        }
        $script:uploadReceiverDir = Join-Path $Evidence 'upload-receiver'
        New-Item -ItemType Directory -Force $script:uploadReceiverDir | Out-Null
        $receiverPortFile = Join-Path $script:uploadReceiverDir 'port.txt'
        $script:uploadReceiver = Start-Process -FilePath node -ArgumentList @((Join-Path $PSScriptRoot '../../../tools/screenshot-upload-receiver.mjs'), $receiverPortFile, $script:uploadReceiverDir, 'verify-only-upload-secret') -PassThru -WindowStyle Hidden
        Wait-Until { Test-Path -LiteralPath $receiverPortFile -PathType Leaf } 'local upload receiver listening' 30
        $uploadConfigDir = Join-Path $env:LOCALAPPDATA 'screencast2-go'
        New-Item -ItemType Directory -Force $uploadConfigDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $uploadConfigDir 'config.toml'), "api_base_url = `"http://127.0.0.1:$((Get-Content -LiteralPath $receiverPortFile -Raw).Trim())`"`nupload_secret = `"verify-only-upload-secret`"`n")
        New-Item -ItemType File -Force (Join-Path $script:uploadReceiverDir 'uploads.jsonl') | Out-Null
    }
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    if ($Feature -eq 'tmux-binding') {
        $bindingState = Join-Path $scratch 'binding-state'
        New-Item -ItemType Directory -Force $bindingState, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $bindingDocument = @{ name = 'tmux-binding'; binding = $true; bindingStatus = $true; generation = '1700:123:$7'; mode = 'busy'; suggestion = ''; sessions = @('workspace') }
        [IO.File]::WriteAllText((Join-Path $bindingState 'state.json'), ($bindingDocument | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
        $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
        $env:MP_VERIFY_BOUNDARY = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/boundary.py')).Path
        $env:MP_VERIFY_STATE = $bindingState
        $env:PATH = (Split-Path $Exe) + ';' + $env:PATH
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
        $bindingSeed = @{ active_tab = 0; single_window = $true; tabs = @(@{ kind = 'vps2'; name = 'workspace'; manual = $true; pid = 0 }) }
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), ($bindingSeed | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
        Save-Json $bindingSeed 'seed-session.json'
        $result.seedBoundary = 'One saved bare SSH tab with no terminal binding. Only SSH is replaced by an owned console showing an existing named terminal session. The real app resolves its public pane-info request, adopts, saves and restores its binding; command receipts prove five exact reattachments and no session creation. No live server, credentials or real Claude are used.'
    }
    if ($Feature -eq 'chat-switch-speed') {
        $remoteState = Join-Path $scratch 'remote-state'
        New-Item -ItemType Directory -Force -Path $remoteState, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $remoteNames = @(1..5 | ForEach-Object { "verify-agent-$_" })
        $remotePanes = [ordered]@{}
        $remoteSids = [ordered]@{}
        for ($i = 0; $i -lt $remoteNames.Count; $i++) {
            $remotePanes[$remoteNames[$i]] = 4300 + $i
            $remoteSids[$remoteNames[$i]] = ('a1b2c3d4-0927-4000-8000-0000000009{0:D2}' -f $i)
        }
        $remoteDocument = [ordered]@{ name = 'chat-switch-speed'; fake = $true; mode = 'idle'; suggestion = 'Try asking about the next step'; sessions = $remoteNames; panes = $remotePanes; sids = $remoteSids; home = (Join-Path $scratch 'profile'); procRoot = ([IO.Path]::GetPathRoot($scratch) + 'proc') }
        [IO.File]::WriteAllText((Join-Path $remoteState 'state.json'), (ConvertTo-Json -InputObject $remoteDocument -Depth 6), (New-Object Text.UTF8Encoding($false)))
        $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
        $env:MP_VERIFY_BOUNDARY = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/boundary.py')).Path
        $env:MP_VERIFY_STATE = $remoteState
        $env:PATH = (Split-Path $Exe) + ';' + $env:PATH
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
        & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 400
        if ($LASTEXITCODE -ne 0) { throw 'Remote transcript seeding failed' }
        $remoteTabs = @($remoteNames | ForEach-Object { @{ kind = 'tmux'; name = ('Remote ' + $_); manual = $true; tmux_host = 0; tmux_session = $_; cv = $false; pid = 0 } })
        $remoteSeedJson = ConvertTo-Json -InputObject @{ active_tab = 0; single_window = $false; chat_active = $false; tabs = $remoteTabs } -Depth 6
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), $remoteSeedJson, (New-Object Text.UTF8Encoding($false)))
        Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Evidence 'seed-session.json') -Value $remoteSeedJson
        $result.seedBoundary = 'The harness writes the saved-tab file once before the first launch: five tmux tabs on a stand-in SSH host, each backed by a seeded Claude transcript of 400 question and answer rounds with tool calls, code blocks and tables. Only SSH is replaced; transcript reading, caching, layout and switching run in the real app.'
    }
    if ($Feature -eq 'tab-names') {
        $seedFolder = Join-Path $scratch 'GitHub'
        New-Item -ItemType Directory -Force -Path $seedFolder, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $seedNames = @('Mini Boss CEO', 'HT Product Lead', 'inne Chief of Staff')
        $seedTabs = @()
        for ($i = 0; $i -lt $seedNames.Count; $i++) { $seedTabs += @{ kind = 'cmd'; name = $seedNames[$i]; cwd = $seedFolder; shell_id = ($i + 1) } }
        $seedJson = ConvertTo-Json -InputObject @{ active_tab = 0; single_window = $true; tabs = $seedTabs } -Depth 6
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), $seedJson, (New-Object Text.UTF8Encoding($false)))
        Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Evidence 'seed-session.json') -Value $seedJson
        $result.seedBoundary = 'The harness writes the saved-tab file once before the first launch: three CMD tabs with names that carry no manual or semantic flag, all in one folder named GitHub. Nothing else is seeded and the app is never edited or driven through a setter.'
    }
    $job = New-Object VerifyJob
    if ($Feature -eq 'session-restore') {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } elseif ($Feature -in @('browser-own-profile', 'tab-names')) {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } elseif ($Feature -eq 'relaunch-saved-sessions') {
        $relaunchSeed = New-RelaunchSeed
        New-Item -ItemType Directory -Force (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), (ConvertTo-Json -InputObject $relaunchSeed.document -Depth 8), (New-Object Text.UTF8Encoding $false))
        Save-Json $relaunchSeed.document 'seed-session.json'
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
    if ($Feature -in @('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed', 'chat-switch-speed', 'chat-first-paint', 'browser-corners', 'window-controls')) {
        if ($Feature -notin @('browser-switch-speed', 'chat-switch-speed')) {
            $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
            $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/EdgeUserData'
        }
        if (-not (Test-Path -LiteralPath $edge)) { throw 'Browser setup requires the configured browser executable' }
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
        if ($Feature -in @('browser-switch-speed', 'chat-switch-speed')) { $arguments += ' --load-extension="' + $extension + '" --disable-extensions-except="' + $extension + '" --silent-debugger-extension-api' }
        $warmup = $warmupJob.Start($edge, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
        } 'isolated browser rendered setup page before the pane adoption deadline starts' 60
        if ($Feature -in @('browser-switch-speed', 'chat-switch-speed')) { Wait-SwitchNativeHost }
        [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
        Save-Json @{ pid = $warmup.Id; ready = $true; timeoutSeconds = 60 } 'browser-setup.json'
    }
    if ($Feature -eq 'title-bar') {
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt caption browser ready</title>"'
        if ($env:CAPTION_BROWSER_THEME -eq 'dark') { $arguments += ' --force-dark-mode' }
        $warmup = $warmupJob.Start($chrome, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Caption browser setup exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt caption browser ready'
        } 'isolated browser rendered the requested caption theme' 60
        [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
        Save-Json @{ pid = $warmup.Id; executable = $chrome; browserTheme = $env:CAPTION_BROWSER_THEME; dpi = [int]$env:CAPTION_DPI } 'caption-browser-setup.json'
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
    Write-Host "Drive: $Feature"
    $driveFeature = $Feature
    switch ($Feature) {
        'composer-buttons' { $driveFeature = 'chat-view' }
    }
    switch ($driveFeature) {
        'chat-working' {
            . (Join-Path $PSScriptRoot 'chat-working.ps1')
        }
        'title-bar' {
            . (Join-Path $PSScriptRoot 'title-bar.ps1')
        }
        'window-controls' {
            . (Join-Path $PSScriptRoot 'window-controls.ps1')
        }
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
            Focus-Palette 'pin to top' 6293
            Snapshot 'pin-action'
            Press @(0x0D) 'Enter: Pin to Top on session 3'
            Wait-ChatViews @($false, $false, $false) 2 'pinned-shell'
            Press @(0x11, 0x57) 'Ctrl+W: refuse closing the pinned session'
            Wait-ChatViews @($false, $false, $false) 2 'pinned-close-refused'
            Press @(0x12, 0x43) 'Alt+C: pinned session can enter Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-ChatViews @($false, $false, $true) 2 'pinned-toggle-chat'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before pinned shell toggle'
            Press @(0x12, 0x43) 'Alt+C: pinned session can return to shell'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-ChatViews @($false, $false, $false) 2 'pinned-toggle-shell'
            Focus-Palette 'chat view on everywhere' 6346
            Snapshot 'action'
            Press @(0x0D) 'Enter: Chat View on everywhere once'
            Wait-ChatViews @($true, $true, $true) 2 'on-everywhere'
            Press @(0x11, 0x31) 'Ctrl+1: show session 1 in Chat View'
            Wait-ChatViews @($true, $true, $true) 0 'session-1-chat'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before session 1 toggle'
            Press @(0x12, 0x43) 'Alt+C: session 1 back to shell'
            Wait-ChatViews @($false, $true, $true) 0 'session-1-toggled'
            Press @(0x11, 0x32) 'Ctrl+2: show session 2 in Chat View'
            Wait-ChatViews @($false, $true, $true) 1 'session-2-chat'
            Press @(0x11, 0x31) 'Ctrl+1: return to session 1 without forcing Chat View'
            Wait-ChatViews @($false, $true, $true) 0 'toggle-sticks'
            Focus-Palette 'chat view off everywhere' 6347
            Snapshot 'off-action'
            Press @(0x0D) 'Enter: Chat View off everywhere once'
            Wait-ChatViews @($false, $false, $false) 0 'off-everywhere'
            Press @(0x11, 0x33) 'Ctrl+3: pinned session follows Off Everywhere'
            Wait-ChatViews @($false, $false, $false) 2 'pinned-after-off'
            Focus-Palette 'unpin from top' 6293
            Press @(0x0D) 'Enter: unpin before normal app close for restart'
            Wait-ChatViews @($false, $false, $false) 2 'unpinned-before-restart' $false
            Restart-ChatView 3
            Save-Json (Read-Session) 'restart-before-input.session.json'
            Press @(0x11, 0x31) 'Ctrl+1: restored first session'
            Wait-ChatViews @($false, $false, $false) 0 'restart-session-1' $false
            Press @(0x11, 0x32) 'Ctrl+2: restored second session'
            Wait-ChatViews @($false, $false, $false) 1 'restart-session-2' $false
            Press @(0x11, 0x33) 'Ctrl+3: restored third session'
            Wait-ChatViews @($false, $false, $false) 2 'restart-session-3' $false
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            foreach ($query in @('chat view per tab', 'lock session', 'always chat view for this session', 'always shell view for this session', 'clear always view for this session')) {
                Focus-Palette 'chat view on everywhere' 6346
                Press @(0x1B) 'Esc: close known positive palette query'
                $start = ((Get-Content $log -Raw) -join '').Length
                Press @(0x11, 0x4B) 'Ctrl+K: reopen empty command palette'
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                    [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
                } 'empty palette ready for removed-command query'
                Type-Text $query
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match ("\[palette\] ready chars=" + $query.Length + " count=0 target=0(?:\r?\n|$)")
                } "removed command has zero palette rows: $query"
                Snapshot ('absent-' + $query.Replace(' ', '-'))
                Press @(0x1B) 'Esc: close empty palette'
            }
            Wait-ChatViews @($false, $false, $false) 2 'after' $false
            $result.checks += @{ name = 'chat-view-everywhere-once'; allOn = @(0, 1, 2); pinnedToggleWorks = $true; pinnedCloseRefused = $true; laterToggleSticks = $true; offEverywhere = $true; restartViews = $true; removedCommands = 5; entry = 'Ctrl+K, Ctrl+W, Ctrl+1/2/3 and Alt+C' }
        }
        'chat-send-latency' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'A PowerShell console titled claude with an idle prompt stands in for a local coding agent; it proves how fast the sent message is drawn, not agent delivery' }
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $agentScript = Join-Path $scratch 'latency-agent.ps1'
            [IO.File]::WriteAllLines($agentScript, [string[]]@("function prompt { [string][char]0x276F + ' ' }", "`$Host.UI.RawUI.WindowTitle = 'claude agent'"))
            Type-Text ('powershell -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "' + $agentScript + '"')
            Press @(0x0D) 'Enter: start the stand-in coding agent prompt'
            Wait-Until {
                $foreground = [VerifyNative]::GetForegroundWindow()
                if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window -or [VerifyNative]::Class($foreground) -ne 'ConsoleWindowClass') { return $false }
                $console = [System.Windows.Automation.AutomationElement]::FromHandle($foreground)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
                $document = $console.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
                if ($null -eq $document) { return $false }
                $pattern = $document.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
                $consoleText = $pattern.DocumentRange.GetText(-1) -replace '[\r\n]', ''
                $consoleText.TrimEnd().EndsWith([string][char]0x276F, [StringComparison]::Ordinal)
            } 'stand-in coding agent prompt is visible in the console' 60
            Snapshot 'agent-prompt'
            Press @(0x12, 0x43) 'Alt+C: enable Chat View for the isolated CMD session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].cv -and
                    -not ($state.tabs[0].PSObject.Properties['bon'] -and $state.tabs[0].bon)
            } 'one saved Chat View session without a browser pane'
            Wait-ChatFocus 'Edit' 'send-latency-ready'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $handle = [IntPtr]$composer.Current.NativeWindowHandle
            if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::Class($handle) -cne 'Edit' -or
                [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Expected the owned composer Edit before the send loop' }
            $pattern = 'send-latency id=(\d+) enqueue_us=(\d+) painted_us=(\d+)'
            $samples = @()
            for ($n = 1; $n -le 20; $n++) {
                $text = "latency probe $n"
                $logText = Read-SharedText $log; $before = ([regex]::Matches($logText, $pattern)).Count
                Type-Text $text
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $text } "send $n typed"
                if ($n -eq 1) { Snapshot 'action' }
                Press @(0x0D) "Enter: send message $n"
                Wait-Until { $current = Read-SharedText $log; ([regex]::Matches($current, $pattern)).Count -gt $before } "send $n bubble painted" 10 50
                Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } "send $n composer cleared" 10 50
                Start-Sleep -Milliseconds 1500
            }
            $finalText = Read-SharedText $log; $timed = [regex]::Matches($finalText, $pattern)
            $samples = @($timed | ForEach-Object { @{ id = [uint64]$_.Groups[1].Value; enqueueMs = [math]::Round([int64]$_.Groups[2].Value / 1000.0, 2); paintedMs = [math]::Round([int64]$_.Groups[3].Value / 1000.0, 2) } })
            if ($samples.Count -ne 20) { throw "chat-send-latency: expected 20 timed sends, found $($samples.Count)" }
            $painted = @($samples | ForEach-Object { $_.paintedMs } | Sort-Object)
            $summary = @{ budgetMs = 100; count = $samples.Count; medianMs = $painted[10]; maxMs = $painted[-1]; samples = $samples }
            Save-Json $summary 'chat-send-latency.json'
            Snapshot 'after'
            $late = @($samples | Where-Object { $_.paintedMs -gt 100 })
            $result.checks += @{ name = 'chat-send-latency'; budgetMs = 100; count = $samples.Count; medianMs = $summary.medianMs; maxMs = $summary.maxMs; over = $late.Count }
            if ($late.Count -gt 0) { throw "chat-send-latency: $($late.Count) of 20 sends took longer than 100 ms to draw the message, worst $($summary.maxMs) ms" }
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
            $reader = Sidebar-Dominant 'before'
            foreach ($channel in @($reader.r, $reader.g, $reader.b)) {
                if ([Math]::Abs($channel - 0x10) -gt 4) { throw "IGSH-1016 dark sidebar is not the Android reader background 101010: $($reader.r),$($reader.g),$($reader.b)" }
            }
            $result.checks += @{ name = 'IGSH-1016-reader-sidebar'; sidebarRgb = "$($reader.r),$($reader.g),$($reader.b)"; expected = '16,16,16' }
            $result.checks += @{ name = 'dark-to-light'; darkLuminance = $dark; lightLuminance = $light; savedTheme = 'light' }
        }
        'chat-dictation' {
            Select-Theme 'dark' 'dictation-dark'
            Press @(0x12, 0x43) 'Alt+C: open Chat View for dictation'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv
            } 'isolated CMD session saved in Chat View'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                $script:composerElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                $null -ne $script:composerElement -and -not $script:composerElement.Current.IsOffscreen
            } 'owned visible composer after Alt+C'
            $handle = [IntPtr]$script:composerElement.Current.NativeWindowHandle
            if ($script:composerElement.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Composer is not owned by this app' }
            [VerifyNative]::BringToForeground($script:window)
            Record 'Click the owned composer to recover typing focus from the hidden console'
            [VerifyNative]::ClickClient($handle, 8, 8)
            Wait-ChatFocus 'Edit' 'dictation-composer'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $handle = [IntPtr]$composer.Current.NativeWindowHandle
            if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Dictation requires the owned composer' }
            $mic = Get-DictationMic $handle
            Assert-DictationMic $mic $false 'dictation-idle'
            $micLive = @(($mic[0] - 84), $mic[1], $mic[2], $mic[3])
            if (($mic[2] - $mic[0]) -ne ($mic[3] - $mic[1])) { throw 'IGSH-887 the idle microphone must be a round button' }
            Snapshot 'before'
            $auditPath = Join-Path $scratch 'roaming/ZigShell/dictation-audit.log'
            $iteration = 0
            foreach ($stop in @('enter', 'ctrl-d', 'mic-click')) {
                if ([VerifyNative]::EditText($handle) -cne '') { throw 'Dictation case must start with an empty message box' }
                Press @(0x11, 0x44) 'Ctrl+D: start composer dictation'
                $iteration++
                if ($env:VERIFY_DICTATION_STALL -eq '1') {
                    Wait-Until { $false } 'deliberately stalled recorded PCM capture precondition' -Seconds 1 -PollMilliseconds 20
                }
                Wait-Until {
                    (Test-Path $auditPath) -and @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
                } 'recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
                Assert-DictationMic $micLive $true ($stop + '-listening')
                if ($stop -ceq 'enter') {
                    $pillTimer = @(($micLive[0] + 26), $micLive[1], ($micLive[0] + 64), $micLive[3])
                    $pillWave = @(($micLive[0] + 68), ($micLive[1] + 6), ($micLive[2] - 16), ($micLive[3] - 6))
                    WindowShot 'recording-0'
                    $script:pillShot = 0
                    $script:timerDiff = 0
                    $script:waveDiff = 0
                    Wait-Until {
                        $script:pillShot++
                        WindowShot ('recording-' + $script:pillShot)
                        $first = Join-Path $Evidence 'recording-0.png'
                        $later = Join-Path $Evidence ('recording-' + $script:pillShot + '.png')
                        $script:timerDiff = [VerifyNative]::RegionDiff($first, $later, $script:window, $pillTimer[0], $pillTimer[1], $pillTimer[2], $pillTimer[3])
                        $script:waveDiff = [VerifyNative]::RegionDiff($first, $later, $script:window, $pillWave[0], $pillWave[1], $pillWave[2], $pillWave[3])
                        $script:timerDiff -gt 20 -and $script:waveDiff -gt 20
                    } 'IGSH-887 the recording pill timer counts up and the wave moves' -Seconds 6 -PollMilliseconds 250
                    Copy-Item (Join-Path $Evidence ('recording-' + $script:pillShot + '.png')) (Join-Path $Evidence 'recording-pill.png')
                    $result.micPill = @{ passed = $true; timerDiffPixels = $script:timerDiff; waveDiffPixels = $script:waveDiff; pillRect = $micLive }
                }
                $typed = 'typing-' + $stop
                Type-Text $typed
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $typed } 'IGSH-812 typing is accepted while listening' -Seconds 1 -PollMilliseconds 10
                if ([VerifyNative]::GetFocusedWindow($script:window) -ne $handle) { throw 'Dictation stole native composer typing focus' }
                Assert-DictationMic $micLive $true ($stop + '-typed-listening')
                Snapshot ($stop + '-listening')
                if ($stop -ceq 'enter') { Snapshot 'action' }
                Doctor
                Assert-Foreground
                Record ('Stop dictation with ' + $stop)
                $immediate = [Diagnostics.Stopwatch]::StartNew()
                switch ($stop) {
                    'enter' { [VerifyNative]::Chord(@(0x0D)) }
                    'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }
                    'mic-click' { [VerifyNative]::ClickClient($script:window, [int](($mic[0] + $mic[2]) / 2), [int](($mic[1] + $mic[3]) / 2)) }
                }
                $expected = $typed + ' Go forward ten meters.'
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'IGSH-812 transcript appears immediately without another input' -Seconds 1 -PollMilliseconds 10
                $elapsed = $immediate.ElapsedMilliseconds
                if ($elapsed -gt 1000) { throw "IGSH-812 transcript was not immediate: $elapsed ms" }
                Save-Json @{ WM_GETTEXT = [VerifyNative]::EditText($handle); expected = $expected; elapsedMilliseconds = $elapsed; handle = $handle.ToInt64(); pid = $process.Id } ($stop + '.text.json')
                Assert-DictationMic $mic $false ($stop + '-stopped')
                $audit = @((Read-DictationAudit $auditPath))
                foreach ($stage in @('audio-bytes\t89160', 'fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                    if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne $iteration) { throw "IGSH-812 missing production transcription stage $stage" }
                }
                Snapshot ($stop + '-delivered')
                $result.checks += @{ name = ('dictation-' + $stop); passed = $true; typedWhileListening = $typed; WM_GETTEXT = [VerifyNative]::EditText($handle); elapsedMilliseconds = $elapsed; activeMicPixels = $true; idleMicPixels = $true }
                if ($stop -cne 'mic-click') {
                    Press @(0x11, 0x41) 'Ctrl+A: select the verified dictation draft'
                    Press @(0x08) 'Backspace: clear the draft through normal keyboard input'
                    Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'composer cleared for next independent stop case'
                }
            }
            if ($result.checks.Count -ne 3) { throw 'IGSH-812 requires all three dictation stop cases' }
            $draft = [VerifyNative]::EditText($handle)
            Press @(0x11, 0x44) 'Ctrl+D: start dictation over the existing draft'
            $iteration++
            Wait-Until {
                @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 cancellation recording reached the real capture worker' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $micLive $true 'escape-listening'
            Type-Text ' keep this'
            $draft += ' keep this'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq $draft } 'IGSH-846 draft includes typing during recording'
            Press @(0x1B, 0x1B) 'Escape with a repeated keydown: discard the recording once'
            Wait-Until {
                $audit = @((Read-DictationAudit $auditPath))
                @($audit | Where-Object { $_ -match '\tcancel\t0$' }).Count -eq 1 -and
                    @($audit | Where-Object { $_ -match '\taudio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 cancellation stopped the capture worker' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $mic $false 'escape-cancelled'
            if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 Escape changed the existing draft' }
            Snapshot 'escape-cancelled'
            $result.checks += @{ name = 'dictation-escape'; passed = $true; WM_GETTEXT = $draft; idleMicPixels = $true }
            $delivered = $iteration - 1
            Press @(0x11, 0x44) 'Ctrl+D: restart dictation after cancellation'
            $iteration++
            Wait-Until {
                @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 a new recording starts after cancellation' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $micLive $true 'escape-restarted'
            if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 cancelled transcript arrived late' }
            $audit = @((Read-DictationAudit $auditPath))
            foreach ($stage in @('fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne $delivered) { throw "IGSH-846 cancelled recording reached transcription or delivery: $stage" }
            }
            Press @(0x0D) 'Enter: transcribe only the restarted recording'
            $expected = $draft + ' Go forward ten meters.'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'IGSH-846 restarted recording delivers exactly once' -Seconds 1 -PollMilliseconds 10
            Assert-DictationMic $mic $false 'escape-restart-stopped'
            $audit = @((Read-DictationAudit $auditPath))
            foreach ($stage in @('fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne ($delivered + 1)) { throw "IGSH-846 restarted recording did not deliver exactly once: $stage" }
            }
            Save-Json @{ preservedDraft = $draft; WM_GETTEXT = [VerifyNative]::EditText($handle); audit = $audit } 'escape-restart.text.json'
            $result.checks += @{ name = 'dictation-escape-restart'; passed = $true; WM_GETTEXT = [VerifyNative]::EditText($handle); idleMicPixels = $true }
            Press @(0x11, 0x41) 'Ctrl+A: select the restarted dictation draft before the send cases'
            Press @(0x08) 'Backspace: clear the draft before the send cases'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'IGSH-965 composer empty before the send cases'
            $send = Get-DictationSend $mic
            Save-Json @{ mic = $mic; send = $send } 'send-geometry.json'
            $deliveries = @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\ttarget-chat-composer\t22$' }).Count
            foreach ($way in @('send-click', 'ctrl-enter')) {
                $outbox = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
                [VerifyNative]::BringToForeground($script:window)
                Record 'Click the owned composer to recover typing focus from the hidden console'
                [VerifyNative]::ClickClient($handle, 8, 8)
                Wait-ChatFocus 'Edit' ($way + '-composer')
                Press @(0x11, 0x44) 'Ctrl+D: start composer dictation for the send case'
                $iteration++
                Wait-Until {
                    @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
                } 'IGSH-965 recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
                Assert-DictationMic $micLive $true ($way + '-listening')
                $typed = 'typing-' + $way
                Type-Text $typed
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $typed } 'IGSH-965 typing is accepted while listening' -Seconds 1 -PollMilliseconds 10
                Snapshot ($way + '-listening')
                Record ('Send once with ' + $way + ' while dictating')
                $immediate = [Diagnostics.Stopwatch]::StartNew()
                switch ($way) {
                    'send-click' { [VerifyNative]::ClickClient($script:window, [int](($send[0] + $send[2]) / 2), [int](($send[1] + $send[3]) / 2)) }
                    'ctrl-enter' { [VerifyNative]::Chord(@(0x11, 0x0D)) }
                }
                Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'IGSH-965 one press ended dictation and sent the typed and spoken words' -Seconds 3 -PollMilliseconds 20
                $elapsed = $immediate.ElapsedMilliseconds
                Snapshot ($way + '-sent-box')
                $expected = $typed + ' Go forward ten meters.'
                Wait-Until {
                    (Test-Path $outbox) -and @((Get-Content $outbox -Raw | ConvertFrom-Json).queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $expected }).Count -eq 1
                } 'IGSH-965 the sent message holds the typed and spoken words exactly once' -Seconds 5 -PollMilliseconds 50
                Assert-DictationMic $mic $false ($way + '-stopped')
                $audit = @((Read-DictationAudit $auditPath))
                $deliveries++
                if (@($audit | Where-Object { $_ -match '\ttarget-chat-composer\t22$' }).Count -ne $deliveries) { throw 'IGSH-965 spoken words did not reach the message box before sending' }
                Snapshot ($way + '-sent')
                $result.checks += @{ name = ('dictation-' + $way); passed = $true; delivered = $expected; elapsedMilliseconds = $elapsed; sendRect = $send; micRect = $mic }
            }
            Snapshot 'after'
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
        'chat-skill-pill' {
            . (Join-Path $PSScriptRoot 'chat-skill-pill.ps1')
        }
        'chat-options' {
            . (Join-Path $PSScriptRoot 'chat-options.ps1')
        }
        'chat-composer-text' {
            $composerCheck = @{ name = 'IGSH-731 composer edges'; passed = $false; fontSmoothing = [VerifyNative]::FontSmoothing() }
            $result.checks += $composerCheck
            $typingCheck = @{ name = 'IGSH-760 typing frames steady'; passed = $false }
            $result.checks += $typingCheck
            $stripCheck = @{ name = 'IGSH-805 composer has no unpainted strip'; passed = $false }
            $result.checks += $stripCheck
            Select-Theme 'dark' 'composer-dark'
            Snapshot 'before'
            Press @(0x12, 0x43) 'Alt+C: open Chat View for the composer'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                $script:composerElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                $null -ne $script:composerElement -and -not $script:composerElement.Current.IsOffscreen
            } 'owned visible composer after Alt+C'
            $handle = [IntPtr]$script:composerElement.Current.NativeWindowHandle
            if ($script:composerElement.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Composer is not owned by this app' }
            [VerifyNative]::BringToForeground($script:window)
            Record 'Click the owned composer to recover typing focus from the hidden console'
            [VerifyNative]::ClickClient($handle, 8, 8)
            Wait-ChatFocus 'Edit' 'composer-open'
            $sentence = 'The message box should look as smooth as the chat text.'
            Assert-ChatTyping $sentence 'composer-typed'
            Snapshot 'action'
            Snapshot 'after'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $state = Read-Session
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $em = [int][Math]::Floor(16 * $dpi / 96)
            $row = [VerifyNative]::ComposerRow([IntPtr]$composer.Current.NativeWindowHandle, $sentence.Length, $em)
            $frame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Composer frame unavailable' }
            $rect = @{ left = $row[0] - $frame.Left; top = $row[1] - $frame.Top; right = $row[2] - $frame.Left; bottom = $row[3] - $frame.Top }
            $client = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetClientRect($handle, [ref]$client) -or -not [VerifyNative]::ClientToScreen($handle, [ref]$origin)) { throw 'Composer client rectangle unavailable' }
            $clientRect = @{ left = $origin.X + $client.Left - $frame.Left; top = $origin.Y + $client.Top - $frame.Top; right = $origin.X + $client.Right - $frame.Left; bottom = $origin.Y + $client.Bottom - $frame.Top }
            Save-Json @{ rect = $rect; clientRect = $clientRect; fontSmoothing = [VerifyNative]::FontSmoothing(); text = $sentence; dpi = $dpi } 'composer-live.json'
            [VerifyNative]::Bmp((Join-Path $Evidence 'after.png'), (Join-Path $Evidence 'composer-live.bmp'))
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence --strip
            $stripExit = $LASTEXITCODE
            $stripSummary = Get-Content (Join-Path $Evidence 'composer-strip-summary.json') -Raw | ConvertFrom-Json
            foreach ($property in $stripSummary.PSObject.Properties) { $stripCheck[$property.Name] = $property.Value }
            if ($stripExit -ne 0 -or -not $stripCheck.passed) { throw 'IGSH-805 composer has no unpainted strip: full client contains a contrasting horizontal run' }
            $prefixRow = [VerifyNative]::ComposerRow($handle, 12, $em)
            $composerFrame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($handle, [ref]$composerFrame)) { throw 'Composer typing rectangle unavailable' }
            $typingCrop = New-Object VerifyNative+Rect
            $typingCrop.Left = $composerFrame.Left - 1
            $typingCrop.Top = $composerFrame.Top - 1
            $typingCrop.Right = [Math]::Min($composerFrame.Right - 1, $row[2] + 5 * $em)
            $typingCrop.Bottom = [Math]::Min($composerFrame.Bottom, $row[3] + 2)
            $inkRect = @{ left = [Math]::Max($prefixRow[0], $typingCrop.Left) - $typingCrop.Left; top = [Math]::Max($prefixRow[1], $typingCrop.Top) - $typingCrop.Top; right = [Math]::Min($prefixRow[2], $typingCrop.Right) - $typingCrop.Left; bottom = [Math]::Min($prefixRow[3], $typingCrop.Bottom) - $typingCrop.Top }
            $rowRect = @{ left = [Math]::Max($row[0], $typingCrop.Left) - $typingCrop.Left; top = [Math]::Max($row[1], $typingCrop.Top) - $typingCrop.Top; right = [Math]::Min($row[2], $typingCrop.Right) - $typingCrop.Left; bottom = [Math]::Min($row[3], $typingCrop.Bottom) - $typingCrop.Top }
            Press @(0x11, 0x41) 'Ctrl+A: select settled sentence before typing burst'
            Press @(0x08) 'Backspace: empty owned composer before typing burst'
            Assert-ChatTyping $sentence 'composer-typing-burst' {
                Doctor
                Assert-Foreground
                Record ('Type with concurrent composer-row BitBlt: ' + $sentence)
                $burst = [VerifyNative]::ComposerTypingFrames($script:window, $handle, $sentence, $typingCrop, $Evidence)
                $burst['inkRect'] = $inkRect
                $burst['rowRect'] = $rowRect
                Save-Json $burst 'composer-typing.json'
            }
            Snapshot 'composer-typing-after'
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence --typing
            $typingSummary = Get-Content (Join-Path $Evidence 'composer-typing-summary.json') -Raw | ConvertFrom-Json
            foreach ($property in $typingSummary.PSObject.Properties) { $typingCheck[$property.Name] = $property.Value }
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence
            $summary = Get-Content (Join-Path $Evidence 'composer-live-summary.json') -Raw | ConvertFrom-Json
            $composerCheck.measurement = $summary.measurement
            $composerCheck.passed = $summary.passed -eq $true
            $composerCheck.threshold = $summary.threshold
            if (-not $typingCheck.passed) { throw 'IGSH-760 typing frames steady: transient ink loss, changed background/border, or insufficient typing frames' }
            if (-not $composerCheck.passed) { throw 'IGSH-731 composer edges: hard-edge fraction must be below 0.18 with system font smoothing OFF' }
            if (-not $env:RELEASE_TAG) {
                $native = Get-Content (Join-Path $Evidence 'composer-native-summary.json') -Raw | ConvertFrom-Json
                $result.checks += @{ name = 'IGSH-731 composer native scale and DPI'; passed = $native.passed; checks = $native.checks }
                if (-not $native.passed) { throw 'IGSH-731 composer native painter proof failed' }
            }
            Add-Type -AssemblyName System.Windows.Forms
            $pasteCheck = @{ name = 'IGSH-895 exact composer paste'; passed = $false; cases = @() }
            $result.checks += $pasteCheck
            foreach ($trailing in @('', "`r`n")) {
                Press @(0x11, 0x41) 'Ctrl+A: select the owned draft'
                Press @(0x08) 'Backspace: clear before the paste check'
                $prefix = 'I cannot send '
                $pasted = 'screenshots https://example.invalid/image.png' + $trailing
                Assert-ChatTyping $prefix 'paste-prefix'
                [System.Windows.Forms.Clipboard]::SetText($pasted)
                Press @(0x11, 0x56) 'Ctrl+V: paste clipboard text at the caret'
                $expected = $prefix + $pasted
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'paste contains exactly typed plus clipboard text'
                $pasteCheck.cases += @{ clipboard = $pasted; expected = $expected; actual = [VerifyNative]::EditText($handle) }
                Snapshot ('paste-' + $trailing.Length)
            }
            $pasteCheck.passed = $true
            Save-Json $pasteCheck 'composer-paste.json'
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
        'tab-names' {
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'seeded restore finished' 60
            $expected = @($seedNames)
            function Assert-TabNamesHold([string]$Stage, [string[]]$Expected) {
                $settle = [Diagnostics.Stopwatch]::StartNew()
                $samples = 0
                while ($settle.Elapsed.TotalSeconds -lt 45) {
                    if ($samples % 8 -eq 0) { Doctor }
                    $saved = Read-Session
                    $state = Read-Inbox
                    if ($null -ne $saved -and $null -ne $state -and @($saved.tabs).Count -gt 0) {
                        $savedNames = @($saved.tabs | ForEach-Object { $_.name })
                        $shownNames = @($state.shells | ForEach-Object { $_.name })
                        $drift = (@($savedNames).Count -ne $Expected.Count) -or (($savedNames -join '|') -cne ($Expected -join '|')) -or (@($Expected | Where-Object { $shownNames -ccontains $_ }).Count -ne $Expected.Count)
                        if ($drift) {
                            Snapshot ($Stage + '-drift')
                            Save-Json @{ expected = $Expected; saved = $savedNames; shown = $shownNames; seconds = $settle.Elapsed.TotalSeconds } ($Stage + '-drift.json')
                            throw ('Tab names or order changed after ' + $Stage + ': expected [' + ($Expected -join ', ') + '], saved [' + ($savedNames -join ', ') + '], shown [' + ($shownNames -join ', ') + ']')
                        }
                        $samples++
                    }
                    Start-Sleep -Milliseconds 250
                }
                if ($samples -lt 40) { throw "Too few state samples after ${Stage}: $samples" }
                Doctor
                Save-Json (Read-Inbox) ($Stage + '-after.inbox.json')
                Save-Json (Read-Session) ($Stage + '-after.session.json')
                Snapshot ($Stage + '-after')
                $script:holdSamples = $samples
            }
            Assert-TabNamesHold 'names-launch' $expected
            $result.checks += @{ name = 'names-launch'; names = $expected; samples = $script:holdSamples; settledSeconds = 45 }
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep the seeded order'
            Wait-Until {
                $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                if (-not (Test-Path $path)) { return $false }
                $launch = Get-Content $path -Raw | ConvertFrom-Json
                $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
            } 'manual tab order saved before reordering'
            Focus-Palette $seedNames[2] 2
            Press @(0x0D) 'Enter: select the last seeded tab by name'
            Wait-Until { $saved = Read-Session; $null -ne $saved -and $saved.active_tab -eq 2 -and $saved.tabs[2].name -ceq $seedNames[2] } 'last seeded tab selected'
            Press @(0x11, 0x10, 0x26) 'Ctrl+Shift+Up: move the last tab above the middle one'
            $custom = @($seedNames[0], $seedNames[2], $seedNames[1])
            Wait-Until { (@((Read-Session).tabs | ForEach-Object { $_.name }) -join '|') -ceq ($custom -join '|') } 'custom tab order persisted' 30
            Snapshot 'action'
            $stages = @(@('names-restart-1', $false), @('names-restart-2', $true), @('names-restart-3', $false))
            foreach ($stage in $stages) {
                Restart-SessionRestore $stage[0] $stage[1]
                $before = Get-Content -Raw -LiteralPath (Join-Path $Evidence ($stage[0] + '-before.session.json')) | ConvertFrom-Json
                $expectedNow = @($before.tabs | ForEach-Object { $_.name })
                if (($expectedNow -join '|') -cne ($custom -join '|')) { throw "Saved names before $($stage[0]) are not the seeded names in the custom order: $($expectedNow -join ', ')" }
                if (@($before.tabs | Where-Object { $_.PSObject.Properties['manual'] -and $_.manual }).Count -ne 0) { throw "A seeded name became manual before $($stage[0])" }
                Assert-TabNamesHold $stage[0] $custom
                $result.checks += @{ name = $stage[0]; names = $custom; samples = $script:holdSamples; settledSeconds = 45; crash = $stage[1] }
            }
            $result.checks += @{ name = 'tab-names-order-survive-restarts'; restarts = 3 }
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
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Press @(0x0D) 'Enter: New CMD shell so the Inbox keeps one unmuted session'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $tabsBefore + 1 -and $state.active_tab -ne $tabIndex } 'second unmuted CMD tab saved and active'
            Press @(0x12, 0x31) 'Alt+1: Favorites with the starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and $state.starred_view -and $state.active_tab -eq $tabIndex } 'starred session selected in Favorites'
            Palette 'mute tab'
            Press @(0x0D) 'Enter: Mute Tab on the starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$tabIndex].PSObject.Properties['muted'] -and $state.tabs[$tabIndex].muted -eq $true } 'muted true saved on the starred session'
            Press @(0x12, 0x32) 'Alt+2: leave Favorites before reopening it'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and -not $state.starred_view } 'home workspace before reopening Favorites'
            Press @(0x12, 0x31) 'Alt+1: reopen Favorites with the muted starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and $state.starred_view -and $state.active_tab -eq $tabIndex -and $state.tabs[$tabIndex].starred_group_id -eq $favoritesGroupId -and $state.tabs[$tabIndex].muted -eq $true } 'muted starred session still listed and selected in Favorites group F'
            Save-Json (Read-Session) 'session-starred-muted.json'
            Snapshot 'starred-muted'
            $result.checks += @{ name = 'favorites-keeps-muted-starred'; starred_group_id = $favoritesGroupId; tab = $tabIndex; muted = $true }
            $expectedTabs = @((Read-Session).tabs).Count
            $listeners = @()
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logStart = (Read-SharedText $log).Length
            Doctor
            Record 'Close only the owned app before occupying notification ports'
            if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)) { throw 'Favorites app refused normal close' }
            $stopped = $job.Stop()
            Save-Json $stopped 'favorites-before-restart-process-tree.json'
            if ($stopped.ActiveProcesses -ne 0) { throw 'Favorites restart left owned descendants' }
            $job.Dispose()
            try {
                $portSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../../src/notify_ports.zig'))
                $firstPort = [regex]::Match($portSource, 'pub const FIRST_PORT: u16 = (\d+);')
                $portCount = [regex]::Match($portSource, 'pub const PORT_COUNT: usize = (\d+);')
                if (-not $firstPort.Success -or -not $portCount.Success) { throw 'Notification port range missing' }
                for ($offset = 0; $offset -lt [int]$portCount.Groups[1].Value; $offset++) {
                    $port = [int]$firstPort.Groups[1].Value + $offset
                    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
                    $listener.Start()
                    $listeners += $listener
                }
                Record 'All notification ports occupied by owned fixture sockets'
                $script:job = New-Object VerifyJob
                $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'favorites-restart-stdout.log'), (Join-Path $Evidence 'favorites-restart-stderr.log'), '--single-window')
                $script:window = [IntPtr]::Zero
                Wait-Until {
                    $process.Refresh()
                    $script:window = $process.MainWindowHandle
                    $state = Read-Inbox
                    $trace = (Read-SharedText $log).Substring($logStart)
                    $script:window -ne [IntPtr]::Zero -and $null -ne $state -and
                        $state.hwnd -eq $script:window.ToInt64().ToString() -and
                        $trace -match 'no free notify port' -and $trace -match 'launch step=browser'
                } 'IGSH-890 sessions finish restoring despite occupied notification ports' 60
                [void][VerifyNative]::ShowWindow($script:window, 9)
                [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
                Wait-Until { [VerifyNative]::BringToForeground($script:window); [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'Favorites restarted owned foreground'
                Doctor
                foreach ($round in 1..4) {
                    Press @(0x12, 0x32) 'Alt+2: home during repeated Favorites refresh'
                    Wait-Until { $state = Read-Session; $null -ne $state -and -not $state.starred_view -and @($state.tabs).Count -eq $expectedTabs } 'home retains exactly the original sessions'
                    Press @(0x12, 0x31) 'Alt+1: Favorites during repeated refresh'
                    Wait-Until {
                        $state = Read-Session
                        $null -ne $state -and $state.starred_view -and @($state.tabs).Count -eq $expectedTabs -and
                            $state.tabs[$state.active_tab].favorite -and $state.tabs[$state.active_tab].starred_group_id -eq $favoritesGroupId
                    } 'Favorites has one selected original grouped session'
                    $published = (Get-Item (Join-Path $scratch 'roaming/ZigShell/inbox-default.json')).LastWriteTimeUtc
                    Wait-Until { (Get-Item (Join-Path $scratch 'roaming/ZigShell/inbox-default.json')).LastWriteTimeUtc -gt $published } 'fresh Inbox refresh does not append sessions'
                    $state = Read-Session
                    if (@($state.tabs).Count -ne $expectedTabs -or @($state.tabs | Where-Object { -not $_.PSObject.Properties['pid'] -or $_.pid -eq 0 }).Count -ne 0) { throw 'Favorites refresh retained cached ghosts or duplicated sessions' }
                    Save-Json $state ("favorites-refresh-$round.json")
                }
                Restart-SessionRestore 'favorites-second-restart' $false
                Press @(0x12, 0x31) 'Alt+1: verify Favorites after another occupied-port relaunch'
                Wait-Until { $state = Read-Session; $null -ne $state -and $state.starred_view -and @($state.tabs).Count -eq $expectedTabs -and $state.tabs[$state.active_tab].starred_group_id -eq $favoritesGroupId } 'second restart keeps one grouped favorite without growth'
                Save-Json (Read-Session) 'favorites-no-duplicates.json'
                Snapshot 'favorites-no-duplicates'
                $result.checks += @{ name = 'IGSH-890 favorites-refresh-restart'; tabs = $expectedTabs; refreshes = 4; restarts = 2; occupiedPorts = $listeners.Count; starred_group_id = $favoritesGroupId }
            } finally {
                foreach ($listener in $listeners) { $listener.Stop() }
            }
        }
        'tmux-binding' { . (Join-Path $PSScriptRoot 'tmux-binding.ps1') }
        'relaunch-saved-sessions' {
            $script:relaunchListeners = $null
            $openPorts = {
                if ($null -eq $script:relaunchListeners) {
                    $script:relaunchListeners = Open-NotifyPortListeners
                    Record "All $(@($script:relaunchListeners).Count) notification ports occupied by owned fixture sockets"
                }
            }
            try {
                $launches = @()
                $launchLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
                Wait-Until {
                    $trace = Read-SharedText $launchLog
                    $trace -match 'launch step=browser' -and $trace -match 'installHook: KEYBOARD_LL installed'
                } 'launch-1 restore finished and keyboard hook installed' 60
                $first = Assert-RelaunchSessions 'launch-1' $relaunchSeed
                if ($first.selected -cne $relaunchSeed.selected -or -not $first.starred_view) { throw "launch-1 did not restore the saved selection $($relaunchSeed.selected) in Starred, got $($first.selected)" }
                $launches += $first
                Snapshot 'launch-1'
                foreach ($launch in 2, 3) {
                    Press @(0x12, 0x32) 'Alt+2: home before quitting'
                    Wait-Until { $state = Read-Inbox; $null -ne $state -and -not $state.starred_view } 'home view before quitting'
                    [void](Assert-RelaunchSessions "home-before-launch-$launch" $relaunchSeed)
                    Press @(0x12, 0x31) 'Alt+1: Starred before quitting'
                    Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.starred_view } 'Starred view before quitting'
                    $starred = Assert-RelaunchSessions "starred-before-launch-$launch" $relaunchSeed
                    Snapshot 'action'
                    Restart-SessionRestore "relaunch-$launch" $false $false $openPorts
                    $after = Assert-RelaunchSessions "launch-$launch" $relaunchSeed
                    if ($after.selected -cne $starred.selected) { throw "launch-$launch selected chat changed from $($starred.selected) to $($after.selected)" }
                    if (-not $after.starred_view) { throw "launch-$launch lost the Starred view" }
                    Snapshot "launch-$launch"
                    $launches += $after
                }
                Snapshot 'after'
                Save-Json $launches 'relaunch-launches.json'
                $result.checks += @{ name = 'relaunch-saved-sessions'; launches = 3; sessions = $relaunchSeed.live.Count; ghostsSeeded = $relaunchSeed.ghosts; groups = $relaunchSeed.groups.Count; occupiedPorts = @($script:relaunchListeners).Count }
            } finally {
                if ($null -ne $script:relaunchListeners) { foreach ($listener in $script:relaunchListeners) { $listener.Stop() } }
            }
        }
        'session-open' {
            $result.sshBoundary = @{ verified = $false; expected = 'No remote credentials or tmux server are supplied; background tab creation, idempotency and failed connection status are verified'; observed = 'pending'; tabRemoved = $null }
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
            $status = Invoke-Zsb @('session-status', '--tab', [string]$created.tab) $script:zsbPort 'session-status-failed'
            if ($status.tab -ne $created.tab -or $status.state -cne 'disconnected' -or -not $status.PSObject.Properties['exit_code'] -or $status.exit_code -ne $script:sshFailure.exitCode) { throw 'session-status did not report disconnected with the logged SSH exit code' }
            $result.checks += @{ name = 'session-status-failed-attach'; tab = $created.tab; status = $status; loggedExitCode = $script:sshFailure.exitCode }
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
            Focus-Palette 'chat view off everywhere' 6347
            Press @(0x0D) 'Enter: reset Chat View to shell for the test session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and -not $state.PSObject.Properties['chat_view_mode'] -and -not $state.tabs[$initialTab].PSObject.Properties['chat_view_lock'] -and
                    -not ($state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv)
            } 'shell baseline without removed Chat View state saved'
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
            $greyCheck = @{ name = 'grey-buttons'; passed = $false; reason = 'not reached' }
            $result.checks += $greyCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $localAgent = Join-Path (Split-Path $Exe) 'claude.exe'
            if (-not (Test-Path $localAgent)) { throw 'Local Claude console stand-in is missing' }
            if ($Feature -eq 'chat-view') {
                $menuCheck = @{ name = 'message-menu'; passed = $false; reason = 'not reached' }
                $selectionCheck = @{ name = 'selection-enter-reply'; ticket = 'IGSH-717'; passed = $false; reason = 'not reached' }
                $result.checks += $selectionCheck
                $result.checks += $menuCheck
                $typedCheck = @{ name = 'local-route-typed'; passed = $false; entry = 'Chat View Enter'; receivedBytes = $null; queued = $false }
                $suggestionCheck = @{ name = 'local-route-suggestion'; passed = $false; entry = 'Chat View Ctrl+Enter'; received = '' }
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
                        if ($mode -eq 'suggestion') {
                            Record 'Shift+Enter: insert a newline without sending'
                            Assert-Foreground
                            $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                            if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Newline proof lost the owned composer' }
                            [VerifyNative]::KeyDown(0x10)
                            try {
                                [VerifyNative]::Chord(@(0x0D))
                                Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq ($message + "`r`n") } 'Shift+Enter keeps the complete draft and adds one newline'
                            } finally { [VerifyNative]::KeyUp(0x10) }
                            if ((Get-Item ($prefix + '-stdin.bin')).Length -ne 0) { throw 'Shift+Enter sent the draft' }
                            Snapshot 'ctrl-enter-newline'
                            Press @(0x08) 'Backspace: remove the newline before sending'
                            Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq $message } 'original message restored after newline proof'
                            Press @(0x11, 0x0D) 'Ctrl+Enter: send through normal Chat View outbox'
                        } else {
                            Press @(0x0D) 'Enter: send through normal Chat View outbox'
                        }
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
                            $wireMessage = ([string][char]27) + '[200~' + $message + ([string][char]27) + '[201~' + "`r"
                            $suggestionCheck.expected = $wireMessage
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
                                $received -ceq $wireMessage
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
                                $menuWindow = @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible })[0]
                                $menuLook = [VerifyNative]::MenuLook([IntPtr]::new([int64]$menuWindow.handle))
                                $menuCheck.look = $menuLook
                                Snapshot 'message-menu'
                                if ($menuLook.cornerShown) { throw 'IGSH-892: message menu corner is still drawn, so the menu is square' }
                                if ($menuLook.leftEdge -ne $menuLook.fill -or $menuLook.rightEdge -ne $menuLook.fill) { throw ('IGSH-892: message menu has a border: edges ' + $menuLook.leftEdge + ' and ' + $menuLook.rightEdge + ' differ from fill ' + $menuLook.fill) }
                                Press @(0x1B) 'Esc: dismiss message menu'
                                Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'no visible owned native popup after Esc'
                                $menuCheck.passed = $true
                                $menuCheck.reason = ''
                            } catch {
                                $menuCheck.reason = $_.Exception.Message
                                throw
                            }
                            try {
                                $quoteLinesBefore = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' }).Count
                                $stdinBytesBeforeReply = (Get-Item ($prefix + '-stdin.bin')).Length
                                Doctor
                                Record 'IGSH-717: genuine SendInput drag over only part of the owned user bubble text'
                                $selectionCheck.points = @([VerifyNative]::SelectTranscriptText($transcript, $process.Id, $script:window))
                                Snapshot 'selection-enter-reply-selected'
                                Wait-Until {
                                    $selectionCheck.selectionPixels = [VerifyNative]::TranscriptSelectionPixels($transcript, $selectionCheck.points)
                                    $selectionCheck.selectionPixels -ge ($selectionCheck.points[1].X - $selectionCheck.points[0].X)
                                } 'IGSH-717 drag paints a visible transcript selection before Enter'
                                Press @(0x0D) 'IGSH-717: Enter quotes the transcript selection instead of sending'
                                Wait-Until {
                                    @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' }).Count -gt $quoteLinesBefore
                                } 'IGSH-717 Enter creates a reply quote'
                                $quoteLines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' })
                                if ($quoteLines.Count -ne $quoteLinesBefore + 1 -or $quoteLines[-1] -cnotmatch '\[chat\] reply quote chars=(\d+)$') { throw 'Expected exactly one observable quote after selection Enter' }
                                $quoteChars = [int]$Matches[1]
                                if ($quoteChars -le 0 -or $quoteChars -ge $message.Length) { throw 'Enter did not quote only a nonempty part of the message' }
                                Wait-Until {
                                    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                                    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                                    $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                                    $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle -and [VerifyNative]::EditText([IntPtr]$composer.Current.NativeWindowHandle) -ceq ''
                                } 'IGSH-717 quote leaves the empty composer focused'
                                Snapshot 'selection-enter-reply'
                                if ((Get-Item ($prefix + '-stdin.bin')).Length -ne $stdinBytesBeforeReply) { throw 'Selection Enter sent input instead of only quoting' }
                                $selectionCheck.quoteChars = $quoteChars
                                $selectionCheck.messageChars = $message.Length
                                $selectionCheck.passed = $true
                                $selectionCheck.reason = ''
                                Press @(0x1B) 'Esc: cancel the selection reply quote'
                            } catch {
                                $selectionCheck.reason = $_.Exception.Message
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
            }
            $stopCheck = @{ name = 'stop-in-box'; passed = $false; entry = 'Chat View working composer'; reason = 'not reached' }
            $result.checks += $stopCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $stopPrefix = Join-Path $scratch 'local-route-working'
            $readStopFrame = {
                $frame = @{ card = $null; size = 0; send = $null; stop = $null; attach = $null; mic = $null; anyStop = $null }
                if (-not (Test-Path $debugLog)) { return $frame }
                foreach ($line in @((Get-Content $debugLog -Raw) -split "`r?`n")) {
                    if ($line -match '\[chat\] composer card (-?\d+),(-?\d+),(-?\d+),(-?\d+) size=(\d+)') {
                        $frame.card = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                        $frame.size = [int]$Matches[5]
                        $frame.send = $null
                        $frame.stop = $null
                        $frame.attach = $null
                        $frame.mic = $null
                    } elseif ($line -match '\[chat\] (attach|mic) rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame[$Matches[1]] = @([int]$Matches[2], [int]$Matches[3], [int]$Matches[4], [int]$Matches[5])
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
                $stopClock = [Diagnostics.Stopwatch]::StartNew()
                $stopCheck.paintAttempts = 0
                Wait-Until {
                    $stopCheck.paintAttempts++
                    Snapshot 'stop-in-box'
                    try {
                        $stopCheck.stopPixels = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'stop-in-box.png'), $script:window, $empty.card, $empty.stop, $null)
                        $true
                    } catch {
                        $stopCheck.stopPixelsReason = $_.Exception.Message
                        $false
                    }
                } 'stop-in-box screenshot paints the grey Stop disc in the logged Stop slot' -Seconds 10
                $stopCheck.paintedAfterMs = [int]$stopClock.ElapsedMilliseconds
                Snapshot 'composer-working-empty'
                $stopCheck.workingEmptyPixels = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'composer-working-empty.png'), $script:window, $empty.card, $empty.stop, $null)
                $stopSize = $empty.stop[2] - $empty.stop[0]
                [VerifyNative]::MoveMouseClient($script:window, [int](($empty.stop[0] + $empty.stop[2]) / 2), [int](($empty.stop[1] + $empty.stop[3]) / 2), $true)
                Wait-Until {
                    Snapshot 'stop-hover'
                    [VerifyNative]::RegionDiff((Join-Path $Evidence 'composer-working-empty.png'), (Join-Path $Evidence 'stop-hover.png'), $script:window, $empty.stop[0] + [int]($stopSize / 4), $empty.stop[1] + [int]($stopSize / 4), $empty.stop[0] + [int]($stopSize / 2), $empty.stop[1] + [int]($stopSize / 2)) -gt 0
                } 'pointer over Stop repaints the hovered button' -Seconds 10
                $stopCheck.hoverLabelDiffPixels = [VerifyNative]::RegionDiff((Join-Path $Evidence 'composer-working-empty.png'), (Join-Path $Evidence 'stop-hover.png'), $script:window, $empty.stop[2] - 4 * $stopSize, $empty.card[1] - [int]($stopSize / 2), $empty.stop[2], $empty.card[1] - 1)
                if ($stopCheck.hoverLabelDiffPixels -gt 4) { throw ('Stop button hover shows a label above the message box: ' + $stopCheck.hoverLabelDiffPixels + ' pixels changed') }
                [VerifyNative]::MoveMouseClient($script:window, [int]($empty.card[0] + ($empty.card[2] - $empty.card[0]) / 2), $empty.card[1] - 3 * $stopSize, $false)
                Type-Text 'x'
                Wait-Until { $typed = & $readStopFrame; $null -ne $typed.card -and $null -ne $typed.send -and $null -eq $typed.stop } 'Send replaces Stop after typing while working'
                $typed = & $readStopFrame
                $stopCheck.typed = $typed
                if (($typed.send[2] - $typed.send[0]) -ne $typed.size -or ($typed.send[3] - $typed.send[1]) -ne $typed.size) { throw 'Send changed size after typing' }
                if (-not (& $insideCard $typed.send $typed.card)) { throw 'Send is outside the composer card after typing' }
                if (($typed.send -join ',') -ne ($empty.stop -join ',')) { throw ('Send rect ' + ($typed.send -join ',') + ' is not in the slot Stop used: ' + ($empty.stop -join ',')) }
                Snapshot 'composer-working-text'
                Snapshot 'grey-buttons'
                $buttonsCheck = @{ name = 'round-bottom-composer-buttons'; passed = $false; frames = @() }
                $result.checks += $buttonsCheck
                foreach ($lines in @(1, 6)) {
                    if ($lines -eq 6) {
                        for ($line = 2; $line -le 6; $line++) {
                            Press-ShiftEnter 'Shift+Enter: grow the owned draft without sending'
                            Type-Text ('Draft line ' + $line)
                        }
                    }
                    Wait-Until {
                        $frame = & $readStopFrame
                        $null -ne $frame.mic -and $null -ne $frame.attach -and $null -ne $frame.send -and $null -eq $frame.stop -and
                        ($lines -eq 1 -or $frame.card[1] -lt $typed.card[1] - 2 * $frame.size)
                    } 'all three composer buttons painted at the requested draft height'
                    $frame = & $readStopFrame
                    foreach ($name in @('attach', 'mic', 'send')) {
                        $rect = $frame[$name]
                        if ($rect[3] -ne $frame.send[3] -or $rect[1] -ne $frame.send[1] -or
                            ($rect[2] - $rect[0]) -ne $frame.size -or ($rect[3] - $rect[1]) -ne $frame.size) {
                            throw ('Composer button is not equally sized and bottom-aligned: ' + $name)
                        }
                    }
                    $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                    if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Multiline proof lost the owned composer' }
                    $draft = [VerifyNative]::EditText($composerHandle)
                    if (@($draft -split "`r?`n").Count -ne $lines) { throw 'Owned composer does not contain the requested number of draft lines' }
                    Snapshot ('composer-' + $lines + '-line')
                    $buttonsCheck.frames += @{ lines = $lines; layout = $frame; draft = $draft }
                }
                $buttonsCheck.passed = $true
                Press @(0x11, 0x41) 'Ctrl+A: select the multiline proof draft'
                Press @(0x08) 'Backspace: restore the earlier single-line proof state'
                Type-Text 'x'
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
                $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Send click proof lost the owned composer' }
                $sendFrame = & $readStopFrame
                if ($null -eq $sendFrame.send -or $null -ne $sendFrame.stop) { throw 'Send is not the only action button before the click' }
                if ([VerifyNative]::EditText($composerHandle).Length -eq 0) { throw 'Composer draft is empty before the Send click' }
                [VerifyNative]::ClickClient($script:window, [int](($sendFrame.send[0] + $sendFrame.send[2]) / 2), [int](($sendFrame.send[1] + $sendFrame.send[3]) / 2))
                Wait-Until { [VerifyNative]::EditText($composerHandle).Length -eq 0 } 'clicking Send took the draft out of the composer'
                $stopCheck.sendClicked = $true
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
        'session-tabs' {
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: first group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'first user-created group saved'
            $groupA = @((Read-Session).groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-start'
            $baseline = Read-Session
            $workspaceName = $baseline.workspaces[$baseline.active_workspace].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($baseline.active_workspace + 1) }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
            $hostName = $listed.hosts[0]
            $tabIds = @{}
            foreach ($n in 1, 2, 3, 4) {
                $opened = Invoke-Zsb @('session-open', '--workspace', $workspaceName, '--group', $groupA.name, '--host', $hostName, '--tmux', "verify-$n", '--name', "Verify $n") $script:zsbPort "session-open-$n"
                if ($opened.created -ne $true -or $opened.tab -le 0) { throw "session-open did not create verify-$n" }
                $tabIds[$n] = [int]$opened.tab
            }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -cmatch '^verify-[1-4]$' }).Count -eq 4 } 'four tmux tabs saved'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: second group'
            $knownGroupIds = @($initialGroupIds) + @($groupA.id)
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                @($state.groups | Where-Object { $_.id -notin $knownGroupIds }).Count -eq 1
            } 'second user-created group saved'
            $groupB = @((Read-Session).groups | Where-Object { $_.id -notin $knownGroupIds })[0]
            if ($groupB.name -ceq $groupA.name) { throw 'Both groups have the same name' }
            $before = Read-Session
            $activeTabBefore = $before.active_tab
            $activeWorkspaceBefore = $before.active_workspace
            $activeNameBefore = $before.tabs[$activeTabBefore].name
            $titleBefore = [VerifyNative]::Title($script:window)
            $foregroundBefore = [VerifyNative]::GetForegroundWindow()
            $foregroundTitleBefore = [VerifyNative]::Title($foregroundBefore)
            $listedBefore = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-before'
            Save-Json $before 'session-tabs-before.session.json'
            Snapshot 'before'
            $assertQuiet = {
                param([string]$Step)
                $state = Read-Session
                if ($null -eq $state) { throw "session.json is not readable after $Step" }
                if ($state.active_workspace -ne $activeWorkspaceBefore -or $state.active_tab -ne $activeTabBefore -or $state.tabs[$state.active_tab].name -cne $activeNameBefore) { throw "$Step changed the active workspace or active tab" }
                if ([VerifyNative]::GetForegroundWindow() -ne $foregroundBefore -or [VerifyNative]::Title($foregroundBefore) -cne $foregroundTitleBefore -or [VerifyNative]::Title($script:window) -cne $titleBefore) { throw "$Step changed foreground window or title" }
            }
            $expectRefused = {
                param([string[]]$ZsbArgs, [string]$Code, [string]$Name)
                $refused = $false
                try { [void](Invoke-Zsb $ZsbArgs $script:zsbPort $Name) } catch { $refused = $_.Exception.Message.Contains('"error":"' + $Code + '"') }
                if (-not $refused) { throw "$Name was not refused with $Code" }
            }
            Snapshot 'action'
            $renamed = Invoke-Zsb @('session-rename', '--tab', [string]$tabIds[1], '--name', 'Renamed One') $script:zsbPort 'session-rename'
            if ($renamed.renamed -ne $true -or $renamed.tab -ne $tabIds[1]) { throw 'session-rename did not reply renamed for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' -and $_.name -ceq 'Renamed One' }).Count -eq 1 } 'renamed tab saved with its session unchanged'
            & $assertQuiet 'session-rename'
            $rebound = Invoke-Zsb @('session-rebind', '--tab', [string]$tabIds[2], '--tmux', 'verify-9') $script:zsbPort 'session-rebind'
            if ($rebound.rebound -ne $true -or $rebound.tab -ne $tabIds[2] -or $rebound.state -cnotin @('connecting', 'connected', 'disconnected')) { throw 'session-rebind did not reply rebound with a state' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-9' -and $_.name -ceq 'Verify 2' -and $_.group_id -eq $groupA.id }).Count -eq 1 -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-2' }).Count -eq 0 } 'rebound tab saved on the new session with its title and group'
            & $assertQuiet 'session-rebind'
            $status = Invoke-Zsb @('session-status', '--tab', [string]$tabIds[2]) $script:zsbPort 'session-status-rebound'
            if ($status.tab -ne $tabIds[2]) { throw 'session-status lost the rebound tab' }
            & $expectRefused @('session-rebind', '--tab', [string]$tabIds[3], '--tmux', 'verify-9') 'duplicate_session' 'session-rebind-duplicate'
            $moved = Invoke-Zsb @('session-move', '--tab', [string]$tabIds[3], '--group', $groupB.name) $script:zsbPort 'session-move'
            if ($moved.moved -ne $true -or $moved.tab -ne $tabIds[3]) { throw 'session-move did not reply moved for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-3' -and $_.group_id -eq $groupB.id }).Count -eq 1 } 'moved tab saved in the second group'
            & $assertQuiet 'session-move'
            $closed = Invoke-Zsb @('session-close', '--tab', [string]$tabIds[4]) $script:zsbPort 'session-close'
            if ($closed.closed -ne $true -or $closed.tab -ne $tabIds[4]) { throw 'session-close did not reply closed for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-4' }).Count -eq 0 -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -cmatch '^verify-' }).Count -eq 3 } 'closed tab removed from the saved layout'
            & $assertQuiet 'session-close'
            $activeListed = $null
            $afterList = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-after'
            foreach ($workspace in @($afterList.workspaces)) {
                foreach ($tab in @($workspace.tabs) + @($workspace.groups | ForEach-Object { @($_.tabs) })) { if ($tab.active -eq $true) { $activeListed = $tab } }
            }
            if ($null -eq $activeListed) { throw 'workspace-list reported no active tab' }
            & $expectRefused @('session-close', '--tab', [string]$activeListed.id) 'active_tab' 'session-close-active'
            & $expectRefused @('session-move', '--tab', [string]$activeListed.id, '--ungrouped') 'active_tab' 'session-move-active'
            & $expectRefused @('session-rebind', '--tab', [string]$activeListed.id, '--tmux', 'verify-8') 'active_tab' 'session-rebind-active'
            & $expectRefused @('session-close', '--tab', '2000000000') 'unknown_tab' 'session-close-unknown'
            & $assertQuiet 'refused commands'
            $layout = {
                param($state)
                $groupNames = @{}
                foreach ($g in @($state.groups)) { $groupNames[[int]$g.id] = $g.name }
                @($state.tabs | ForEach-Object {
                    $tabGroup = ''
                    if ($_.PSObject.Properties['group_id'] -and $_.group_id -and $groupNames.ContainsKey([int]$_.group_id)) { $tabGroup = $groupNames[[int]$_.group_id] }
                    $tabSession = ''
                    if ($_.PSObject.Properties['tmux_session']) { $tabSession = $_.tmux_session }
                    $tabWorkspace = 0
                    if ($_.PSObject.Properties['workspace']) { $tabWorkspace = $_.workspace }
                    '{0}|{1}|{2}|{3}' -f $_.name, $tabSession, $tabGroup, $tabWorkspace
                }) -join "`n"
            }
            $expectedLayout = & $layout (Read-Session)
            $expectedActive = (Read-Session).tabs[(Read-Session).active_tab].name
            Save-Json (Read-Session) 'session-tabs-layout.session.json'
            Save-Json $afterList 'session-tabs-layout.workspace-list.json'
            Snapshot 'after'
            Restart-SessionRestore 'tabs-restart' $false
            Wait-Until { $state = Read-Session; $null -ne $state -and (& $layout $state) -ceq $expectedLayout } 'saved layout survives the restart exactly' 60
            Save-Json (Read-Session) 'session-tabs-restarted.session.json'
            Snapshot 'restarted'
            $result.checks += @{ name = 'session-tabs-cli-repair'; tabIds = @($tabIds[1], $tabIds[2], $tabIds[3], $tabIds[4]); groupA = $groupA.name; groupB = $groupB.name; layout = $expectedLayout; activeTab = $expectedActive; listedStateBefore = @($listedBefore.workspaces).Count; foregroundBefore = $foregroundBefore.ToInt64(); windowTitle = $titleBefore; restart = $true }
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
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $noFill = $true
            $noRail = $true
            $flushLeft = $true
            foreach ($selected in @(0, 1)) {
                Press @(0x11, (0x31 + $selected)) ('Ctrl+' + ($selected + 1) + ': select grouped session')
                Wait-Until { (Read-Session).active_tab -eq $selected } 'grouped selection persisted'
                $shot = 'group-rail-selected-' + $selected
                Snapshot $shot
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'group-rail native geometry unavailable' }
                $proof = [GroupRailProof]::Check((Join-Path $Evidence ($shot + '.png')), $frame, $origin, $dpi, $scale, $hidePills, $false)
                Save-Json @{ pixels = $proof; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; session = Read-Session; tag = $env:RELEASE_TAG; version = $ExpectedVersion } ($shot + '.json')
                $noFill = $noFill -and $proof['noFill']
                $noRail = $noRail -and $proof['noRail']
                $flushLeft = $flushLeft -and $proof['flushLeft']
                $result.checks += @{ name = $shot; pixels = $proof }
            }
            if ($noFill) { Write-Host 'sidebar-headline no-fill PASS' } else { Write-Host 'sidebar-headline no-fill FAIL' }
            if ($noRail) { Write-Host 'sidebar-headline no-rail PASS' } else { Write-Host 'sidebar-headline no-rail FAIL' }
            if ($flushLeft) { Write-Host 'sidebar-headline flush-left PASS' } else { Write-Host 'sidebar-headline flush-left FAIL' }
            $labels = [GroupRailProof]::Labels((Join-Path $Evidence 'group-rail-selected-1.png'), $frame, $origin, $dpi, $scale, [int]$proof['sidebarRect'][3], [int]$proof['nameX'][0], [int]$proof['rowHeight'])
            Save-Json @{ labels = $labels; pixels = $proof; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-labels.json'
            $result.checks += @{ name = 'sidebar-label-parity'; pixels = $labels }
            $sameStyle = [bool]$labels['sameStyle']
            $noArrow = [bool]$labels['noArrow']
            $plusOnly = [bool]$labels['plusOnly']
            if ($sameStyle) { Write-Host 'sidebar-label same-style PASS' } else { Write-Host 'sidebar-label same-style FAIL' }
            if ($noArrow) { Write-Host 'sidebar-label no-arrow PASS' } else { Write-Host 'sidebar-label no-arrow FAIL' }
            if ($plusOnly) { Write-Host 'sidebar-newtab plus-only PASS' } else { Write-Host 'sidebar-newtab plus-only FAIL' }
            $clickToggle = $false
            try {
                $beforeToggle = Read-Session
                $membership = ($beforeToggle.tabs | ForEach-Object { $g = 0; if ($_.PSObject.Properties['group_id']) { $g = $_.group_id }; [string]$_.shell_id + ':' + [string]$g }) -join ','
                $clickX = [int]$proof['nameX'][0] + 4 + $frame.Left - $origin.X
                if ($proof['nameX'][0] -lt 0) { $clickX = [int]([long]20 * $dpi * $scale / 9600) }
                $clickY = [int]$proof['headerTops'][0] + 14 + $frame.Top - $origin.Y
                Doctor
                Record 'Click the first group headline to hide its member sessions'
                [VerifyNative]::ClickClient($script:window, $clickX, $clickY)
                Wait-Until {
                    $state = Read-Session
                    $savedGroup = @($state.groups | Where-Object { $_.id -eq $group.id })
                    $savedGroup.Count -eq 1 -and $savedGroup[0].PSObject.Properties['collapsed'] -and $savedGroup[0].collapsed
                } 'headline click persisted the existing group collapsed memory'
                Snapshot 'group-rail-collapsed'
                $hidden = [GroupRailProof]::Check((Join-Path $Evidence 'group-rail-collapsed.png'), $frame, $origin, $dpi, $scale, $hidePills, $true)
                Save-Json @{ pixels = $hidden; session = Read-Session; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-collapsed.json'
                Doctor
                Record 'Click the same headline to restore its member sessions'
                Start-Sleep -Milliseconds 700
                [VerifyNative]::ClickClient($script:window, ($clickX + 24), $clickY)
                Wait-Until {
                    $state = Read-Session
                    $savedGroup = @($state.groups | Where-Object { $_.id -eq $group.id })
                    $savedGroup.Count -eq 1 -and (-not $savedGroup[0].PSObject.Properties['collapsed'] -or -not $savedGroup[0].collapsed)
                } 'headline click persisted expanded group memory'
                Snapshot 'group-rail-restored'
                $restored = [GroupRailProof]::Check((Join-Path $Evidence 'group-rail-restored.png'), $frame, $origin, $dpi, $scale, $hidePills, $false)
                $firstRow = [int]$proof['headerTops'][0] + [int]$proof['headerHeight']
                $scanBottom = [int]$proof['sidebarRect'][3] + 24 + 2 * [int]$proof['rowHeight']
                $toggle = [GroupRailProof]::Toggle((Join-Path $Evidence 'group-rail-selected-1.png'), (Join-Path $Evidence 'group-rail-collapsed.png'), (Join-Path $Evidence 'group-rail-restored.png'), [int]$proof['sessionTextX'][0], $firstRow, [int]$proof['rowHeight'], [int]$proof['headerTops'][0], $scanBottom, $dpi, $scale)
                $state = Read-Session
                $afterMembership = ($state.tabs | ForEach-Object { $g = 0; if ($_.PSObject.Properties['group_id']) { $g = $_.group_id }; [string]$_.shell_id + ':' + [string]$g }) -join ','
                $clickToggle = $toggle['membersDisappearAndReturn'] -and $membership -ceq $afterMembership -and @($state.tabs).Count -eq 6 -and @($state.groups).Count -eq 2
                Save-Json @{ pixels = $restored; toggle = $toggle; clickToggle = $clickToggle; before = $beforeToggle; session = $state; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-restored.json'
                $result.checks += @{ name = 'sidebar-headline-click-toggle'; passed = $clickToggle; pixels = $toggle }
            } catch {
                Write-Host 'sidebar-headline click-toggle FAIL'
                throw
            }
            Snapshot 'after'
            if ($clickToggle) { Write-Host 'sidebar-headline click-toggle PASS' } else { Write-Host 'sidebar-headline click-toggle FAIL' }
            if (-not $noFill -or -not $noRail -or -not $flushLeft -or -not $clickToggle -or -not $sameStyle -or -not $noArrow -or -not $plusOnly) { throw 'sidebar-headline assertions failed' }
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
            } 'second CMD selected while grouped member stays fully visible'
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
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $focusProofs = @()
            [uint32]$browserPid = 0
            [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
            Record 'Ctrl+L: load a local keyboard probe through the owned browser address bar'
            [VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Ctrl+L' }
            Assert-Foreground
            [VerifyNative]::Chord(@(0x11, 0x4C))
            $browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
            $omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
            Wait-Until {
                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                    [System.Windows.Automation.Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement) -and
                    [VerifyNative]::GetForegroundWindow() -eq $browser
            } 'verified pane native address bar has keyboard focus'
            $probeHtml = '<title>IGSH807 keys 0 </title><script>let n=0;addEventListener("keydown",e=>{if(e.key==="j"){e.preventDefault();document.title="IGSH807 keys "+(++n)+" "}})</script>'
            Assert-Foreground
            [VerifyNative]::Text(('data:text/html,' + [Uri]::EscapeDataString($probeHtml)))
            Assert-Foreground
            [VerifyNative]::Chord(@(0x0D))
            Wait-Until { [VerifyNative]::Title($browser).StartsWith('IGSH807 keys 0 ', [StringComparison]::Ordinal) } 'local keyboard probe loaded'
            foreach ($theme in @('dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system')) {
                $query = if ($theme -eq 'edgegray') { 'edge grey' } else { $theme }
                Select-Theme $query ("focus-$theme-theme") $theme
                Press @(0x11, 0x32) 'Ctrl+2: start focus journey on the owned console'
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                foreach ($view in @('shell', 'chat')) {
                    if ($view -eq 'chat') {
                        $chatFocused = $false
                        for ($attempt = 1; $attempt -le 3 -and -not $chatFocused; $attempt++) {
                            $chatState = Read-Session
                            $inChat = $chatState.tabs[$consoleTab].PSObject.Properties['cv'] -and $chatState.tabs[$consoleTab].cv
                            if (-not $inChat) { Press @(0x12, 0x43) 'Alt+C: enter Chat View without changing Alt+Q behavior' }
                            try { Wait-ChatFocus 'Edit' ("focus-$theme-chat-start"); $chatFocused = $true }
                            catch { Record ('Chat View composer attempt ' + $attempt + ' for ' + $theme + ' returned: ' + $_) }
                        }
                        if (-not $chatFocused) { throw ('Chat View composer never took focus in theme ' + $theme) }
                    }
                    foreach ($cycle in @(1, 2)) {
                        $step = "focus-$theme-$view-$cycle"
                        if ($view -eq 'chat') {
                            Assert-ChatTyping "draft-$theme-$cycle" ($step + '-input')
                            $composer = [IntPtr][System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle
                            $draft = [VerifyNative]::EditText($composer)
                        } else {
                            $marker = Join-Path $scratch ($step + '.txt')
                            if (Test-Path $marker) { throw 'Focus marker already exists before shell input' }
                            $command = 'echo ' + $step + '>"' + $marker + '"'
                            Type-Text $command
                            Wait-ConsoleText $command
                            Doctor
                            Record 'Enter: execute focus marker in the Alt+Q-selected shell'
                            Assert-Foreground
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -ceq $step } 'shell focus marker content'
                        }
                        Snapshot ($step + '-input')
                        Doctor
                        Record 'Alt+Q: switch from input to browser without foreground repair'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x12, 0x51))
                        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $browser -and [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -eq $script:window } 'Alt+Q selected the owned browser'
                        Doctor
                        if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Refusing browser probe outside the Alt+Q-selected pane' }
                        $probeTitle = [VerifyNative]::Title($browser)
                        if ($probeTitle -notmatch '^IGSH807 keys (\d+) ') { throw ('Browser probe page is not loaded: ' + $probeTitle) }
                        [int]$pageKeys = [int]$Matches[1] + 1
                        Record 'j: prove keyboard input reaches browser content'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x4A))
                        Wait-Until { [VerifyNative]::Title($browser).StartsWith(('IGSH807 keys ' + $pageKeys + ' '), [StringComparison]::Ordinal) } 'browser page received the exact next key'
                        if ($view -eq 'chat' -and [VerifyNative]::EditText($composer) -cne $draft) { throw 'Browser input changed the chat draft' }
                        Snapshot ($step + '-browser')
                        Doctor
                        Record 'Alt+Q: return to input without foreground repair'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x12, 0x51))
                        if ($view -eq 'chat') {
                            Wait-ChatFocus 'Edit' ($step + '-returned')
                            if ([VerifyNative]::EditText($composer) -cne $draft) { throw 'Alt+Q lost the chat draft' }
                            Type-Text '-returned'
                            Wait-Until { [VerifyNative]::EditText($composer) -ceq ($draft + '-returned') } 'typing reaches the returned composer'
                        } else {
                            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                            $returnMarker = Join-Path $scratch ($step + '-returned.txt')
                            if (Test-Path $returnMarker) { throw 'Return marker already exists' }
                            $command = 'echo returned>"' + $returnMarker + '"'
                            Type-Text $command
                            Wait-ConsoleText $command
                            Doctor
                            Record 'Enter: execute in returned shell without focus repair'
                            Assert-Foreground
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until { (Test-Path $returnMarker) -and (Get-Content $returnMarker -Raw).Trim() -ceq 'returned' } 'returned shell received input'
                        }
                        Snapshot ($step + '-returned')
                        $pixels = [PaneLayoutProof]::FocusMargins((Join-Path $Evidence ($step + '-input.png')), (Join-Path $Evidence ($step + '-browser.png')), $frame, $client, $consoleRect, $browserRect, $dpi, $scale)
                        Save-Json $pixels ($step + '-pixels.json')
                        $focusProofs += @{ theme = $theme; view = $view; cycle = $cycle; pageKeys = $pageKeys; pixels = $pixels }
                        if ($view -eq 'chat') {
                            Doctor
                            Record 'Clear the unsent draft in the still-focused composer'
                            $cleared = $false
                            for ($attempt = 1; $attempt -le 4 -and -not $cleared; $attempt++) {
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x11, 0x41))
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x2E))
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x08))
                                try { Wait-Until { [VerifyNative]::EditText($composer) -ceq '' } 'empty composer for next cycle' 4; $cleared = $true } catch { Record ('Composer clear attempt ' + $attempt + ' left: ' + [VerifyNative]::EditText($composer)) }
                            }
                            if (-not $cleared) { throw ('Composer not empty before next cycle: ' + [VerifyNative]::EditText($composer)) }
                        }
                    }
                }
                $restored = $false
                for ($attempt = 1; $attempt -le 3 -and -not $restored; $attempt++) {
                    $restoreState = Read-Session
                    $stillChat = $restoreState.tabs[$consoleTab].PSObject.Properties['cv'] -and $restoreState.tabs[$consoleTab].cv
                    if ($stillChat) { Press @(0x12, 0x43) 'Alt+C: restore shell view for the next theme' }
                    try { Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false; $restored = $true }
                    catch { Record ('Shell view restore attempt ' + $attempt + ' returned: ' + $_) }
                }
                if (-not $restored) { throw 'Shell view never returned after Chat View' }
            }
            Save-Json $focusProofs 'focus-ring-proof.json'
            $result.checks += @{ name = 'IGSH-807 focus-input'; proofs = $focusProofs }
            if (@($focusProofs | Where-Object { $_.pixels.mismatches -ne 0 }).Count -ne 0) { throw 'IGSH-807 focus ring pixels differ from the unfocused surface' }
            Select-Theme 'dark' 'pane-layout-final-dark'
            Press @(0x11, 0x32) 'Ctrl+2: restore console for layout evidence'
            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
            if ([VerifyNative]::GetForegroundWindow() -ne $console -or [VerifyNative]::PaneWindow($script:window) -ne $browser -or
                [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or -not [VerifyNative]::IsZoomed($script:window)) { throw 'pane-layout lost original maximized console/browser HWNDs' }
            $frame = New-Object VerifyNative+Rect
            $client = New-Object VerifyNative+Rect
            $consoleRect = New-Object VerifyNative+Rect
            $browserRect = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout fresh HWND rectangles unavailable' }
            $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
            $state = Read-Session
            if ($state.tabs[$consoleTab].shell_id -ne $consoleShellId -or ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv)) { throw 'pane-layout original shell view changed' }
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $consoleElement = [System.Windows.Automation.AutomationElement]::FromHandle($console)
            $uiaRect = $consoleElement.Current.BoundingRectangle
            if ($consoleElement.Current.IsOffscreen -or $consoleElement.Current.ClassName -ne 'ConsoleWindowClass' -or
                -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $consoleShellId), [StringComparison]::Ordinal) -or
                [Math]::Abs($uiaRect.Left - $consoleRect.Left) -gt 1 -or [Math]::Abs($uiaRect.Top - $consoleRect.Top) -gt 1 -or
                [Math]::Abs($uiaRect.Right - $consoleRect.Right) -gt 1 -or [Math]::Abs($uiaRect.Bottom - $consoleRect.Bottom) -gt 1) { throw 'Fresh console UIA and HWND identity/bounds disagree' }
            Save-Json @{ frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64(); dpi = $dpi; scale = $scale; session = $state } 'pane-layout-rects.json'
            Snapshot 'pane-layout'
            $proof = [PaneLayoutProof]::Check((Join-Path $Evidence 'pane-layout.png'), $frame, $client, $consoleRect, $browserRect, $dpi, $scale, $hidePills)
            Save-Json $proof 'pane-layout-pixels.json'
            $maskColors = [ordered]@{ themes = [ordered]@{}; dpi = $dpi; scale = $scale }
            foreach ($theme in @('dark', 'light', 'amoled')) {
                Select-Theme $theme ("pane-layout-mask-$theme-action")
                Wait-Until { [PaneLayoutProof]::Masks([uint32]$process.Id).Count -eq 10 } ("ten visible owned browser masks for $theme") 10
                Write-Host "pane-layout mask-windows-$theme PASS"
                $paintReady = [DateTime]::UtcNow.AddMilliseconds(1000)
                Wait-Until { [DateTime]::UtcNow -ge $paintReady } ("theme repaint settled for $theme") 3
                Press @(0x11, 0x32) 'Ctrl+2: restore original console before mask geometry'
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                if ([VerifyNative]::GetForegroundWindow() -ne $console -or [VerifyNative]::PaneWindow($script:window) -ne $browser -or
                    [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or -not [VerifyNative]::IsZoomed($script:window)) { throw 'pane-layout lost original maximized console/browser HWNDs' }
                $frame = New-Object VerifyNative+Rect
                $client = New-Object VerifyNative+Rect
                $consoleRect = New-Object VerifyNative+Rect
                $browserRect = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                    -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                    -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout fresh HWND rectangles unavailable' }
                $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
                $state = Read-Session
                if ($state.tabs[$consoleTab].shell_id -ne $consoleShellId -or ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv)) { throw 'pane-layout original shell view changed' }
                $scale = 100
                if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
                $dpi = [VerifyNative]::GetDpiForWindow($script:window)
                $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
                $masks = [PaneLayoutProof]::Masks([uint32]$process.Id)
                $maskColors.themes[$theme] = @{ masks = $masks; screenshot = "pane-layout-mask-$theme.png"; frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; dpi = $dpi; scale = $scale; hidePills = $hidePills; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64() }
                Save-Json $maskColors 'pane-layout-mask-colours.json'
                if ($masks.Count -ne 10) { throw "pane-layout mask-windows-$theme FAIL: masks disappeared before capture" }
                Snapshot ("pane-layout-mask-$theme")
                if ([PaneLayoutProof]::Masks([uint32]$process.Id).Count -ne 10) { throw "pane-layout mask-windows-$theme FAIL: masks disappeared during capture" }
                $maskColors.themes[$theme].pixels = [PaneLayoutProof]::MeasureMasks((Join-Path $Evidence "pane-layout-mask-$theme.png"), $theme, $frame, $client, $browserRect, $masks, $dpi, $scale)
                Save-Json $maskColors 'pane-layout-mask-colours.json'
            }
            foreach ($theme in @('dark', 'light', 'amoled')) {
                [PaneLayoutProof]::CheckMasks($maskColors.themes[$theme].pixels, $theme)
            }
            $result.checks += @{ name = 'pane-layout'; assertions = @('console-uia-hwnd', 'clean-gap', 'group-line-absent', 'row-icon-found', 'group-content-inset', 'mask-windows-dark', 'mask-top-right-dark', 'mask-reference-dark', 'mask-not-black-dark', 'mask-chrome-dark', 'mask-follows-chrome-dark', 'mask-windows-light', 'mask-top-right-light', 'mask-reference-light', 'mask-not-black-light', 'mask-chrome-light', 'mask-windows-amoled', 'mask-top-right-amoled', 'mask-reference-amoled', 'mask-not-black-amoled', 'mask-chrome-amoled', 'mask-follows-chrome-amoled'); pixels = $proof; maskColours = $maskColors }
            Snapshot 'after'
        }
        'chat-first-paint' {
            $launchLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            function Read-LaunchLog { try { return Read-SharedText -Path $launchLog } catch { return '' } }
            function Capture-Window([string]$Name) {
                [void][VerifyNative]::DwmFlush()
                $rect = New-Object VerifyNative+Rect
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
                $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $file = Join-Path $Evidence "$Name.png"
                try {
                    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
                    $bitmap.Save($file, [Drawing.Imaging.ImageFormat]::Png)
                } finally { $graphics.Dispose(); $bitmap.Dispose() }
            }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one real CMD session'
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $pane = Open-BrowserPane 'chat-first-paint-open'
            Press @(0x12, 0x43) 'Alt+C: open Chat View beside the docked browser pane'
            Wait-Until {
                $state = Read-Session
                $tab = $state.tabs[$state.active_tab]
                $tab.PSObject.Properties['cv'] -and $tab.cv -eq $true -and $tab.PSObject.Properties['bon'] -and $tab.bon -eq $true
            } 'Chat View and browser pane both saved by the app'
            Wait-Until { (Read-LaunchLog) -match '\[chat\] composer card' } 'Chat View painted its composer card'
            Start-Sleep -Seconds 3
            Snapshot 'before-quit'
            Save-Json (Read-Session) 'session-before-quit.json'
            Doctor
            Record 'WM_CLOSE: close only the verified owned main window normally'
            if (-not $process.CloseMainWindow()) { throw 'Owned window refused WM_CLOSE' }
            if (-not $process.WaitForExit(20000)) { throw 'chat-first-paint launch 1 did not exit' }
            $stopped = $job.Stop()
            Save-Json @{ pid = $process.Id; activeAfterStop = $stopped.ActiveProcesses } 'launch-1-exit.json'
            $process.Dispose()
            $job.Dispose()
            $script:process = $null
            $script:job = $null
            $script:window = [IntPtr]::Zero
            $snapshotFiles = @(Get-ChildItem -LiteralPath (Join-Path $scratch 'roaming/ZigShell') -Filter '*.launch.json')
            if ($snapshotFiles.Count -ne 1) { throw "chat-first-paint seed invalid: expected one app-written launch snapshot, found $($snapshotFiles.Count)" }
            $snapshot = Get-Content -LiteralPath $snapshotFiles[0].FullName -Raw | ConvertFrom-Json
            if (-not $snapshot.chat) { throw 'chat-first-paint seed invalid: the launch snapshot did not record an open Chat View' }
            $snapshotRow = @($snapshot.rows | Where-Object { $_.id -eq $snapshot.active })[0]
            $snapshotBrowser = $snapshotRow.PSObject.Properties['browser'] -and $snapshotRow.browser -eq $true
            Save-Json @{ chat = $snapshot.chat; rows = @($snapshot.rows).Count; carriesBrowserPane = $snapshotBrowser; browserSplit = $(if ($snapshotRow.PSObject.Properties['browser_split']) { $snapshotRow.browser_split } else { $null }) } 'launch-snapshot-summary.json'
            $logOffset = (Read-LaunchLog).Length
            $script:job = New-Object VerifyJob
            $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'launch-2.stdout.log'), (Join-Path $Evidence 'launch-2.stderr.log'), '--single-window')
            $firstPaint = $false
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            while ([DateTime]::UtcNow -lt $deadline) {
                $process.Refresh()
                if ($process.MainWindowHandle -ne [IntPtr]::Zero) { $script:window = $process.MainWindowHandle }
                $all = Read-LaunchLog
                $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
                if ($script:window -ne [IntPtr]::Zero -and $trace -match 'launch first-paint ms=') {
                    Capture-Window 'first-paint'
                    $firstPaint = $true
                    break
                }
                Start-Sleep -Milliseconds 10
            }
            if (-not $firstPaint) { throw 'chat-first-paint launch 2 never logged its first paint' }
            Wait-Until {
                $all = Read-LaunchLog
                $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
                $trace -match 'launch step=browser'
            } 'launch 2 finished restoring sessions and browser panes' 60
            Start-Sleep -Seconds 6
            Capture-Window 'settled'
            $all = Read-LaunchLog
            $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
            $trace | Out-File -LiteralPath (Join-Path $Evidence 'launch-2.debug.log') -Encoding utf8
            $client = ''
            $events = @()
            foreach ($line in ($trace -split "`n")) {
                if ($line -match '\[reposition\] client=(\d+x\d+)') { $client = $Matches[1]; continue }
                if ($line -match '\[chat\] frame transcript (-?\d+,-?\d+,-?\d+,-?\d+) edit (-?\d+,-?\d+,-?\d+,-?\d+) card (-?\d+,-?\d+,-?\d+,-?\d+)') {
                    $events += [pscustomobject]@{ client = $client; kind = 'transcript'; rect = $Matches[1]; line = $line.Trim() }
                    $events += [pscustomobject]@{ client = $client; kind = 'message box'; rect = $Matches[2]; line = $line.Trim() }
                    $events += [pscustomobject]@{ client = $client; kind = 'composer card'; rect = $Matches[3]; line = $line.Trim() }
                    continue
                }
                if ($line -match '\[chat\] composer card (-?\d+,-?\d+,-?\d+,-?\d+) size=') {
                    $events += [pscustomobject]@{ client = $client; kind = 'composer card'; rect = $Matches[1]; line = $line.Trim() }
                }
            }
            Save-Json @($events) 'chat-layout-events.json'
            foreach ($kind in 'transcript', 'message box', 'composer card') {
                if (@($events | Where-Object { $_.kind -eq $kind }).Count -eq 0) { throw "chat-first-paint: launch 2 never logged a $kind rectangle" }
            }
            $moved = @()
            foreach ($client in @($events | Select-Object -ExpandProperty client -Unique)) {
                foreach ($kind in 'transcript', 'message box', 'composer card') {
                    $rects = @($events | Where-Object { $_.client -eq $client -and $_.kind -eq $kind } | Select-Object -ExpandProperty rect -Unique)
                    if ($rects.Count -gt 1) { $moved += "$kind at window $client moved between $($rects -join ' and ')" }
                }
            }
            Save-Json @{ snapshotCarriesBrowserPane = $snapshotBrowser; moved = $moved; eventCount = $events.Count } 'chat-first-paint-verdict.json'
            if ($moved.Count -gt 0) { throw "chat-first-paint: chat layout moved after first paint: $($moved -join '; ')" }
            $result.checks += @{ name = 'chat-first-paint'; events = $events.Count; moved = 0; snapshotCarriesBrowserPane = $snapshotBrowser }
            Snapshot 'action'
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
            $drafts = @('Wswitch-paint-0', '.switch-paint-1')
            $consoleCodes = @('1F', '2F')
            $consoleRgb = @(-1, -1)
            $regions = @{}
            $patches = @($null, $null)
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
                    $consoleArea = New-Object VerifyNative+Rect
                    if (-not [VerifyNative]::GetWindowRect($consoles[$tab], [ref]$consoleArea)) { throw 'Timing console rectangle unavailable' }
                    $plainRgb = [VerifyNative]::SolidPatch($consoleArea)
                    Type-Text ('color ' + $consoleCodes[$tab])
                    Press @(0x0D) 'Enter: give this timing CMD its own solid color'
                    Wait-Until { $solidRgb = [VerifyNative]::SolidPatch($consoleArea); $solidRgb -ge 0 -and $solidRgb -ne $plainRgb } 'timing CMD shows its own solid color'
                    $consoleRgb[$tab] = [VerifyNative]::SolidPatch($consoleArea)
                    $docks[$tab] = $consoleArea
                }
                $consoleGap = 0
                foreach ($shift in @(16, 8, 0)) { $consoleGap = [Math]::Max($consoleGap, [Math]::Abs((($consoleRgb[0] -shr $shift) -band 255) - (($consoleRgb[1] -shr $shift) -band 255))) }
                if ($consoleGap -le 8) { throw 'Timing console colors are not distinct' }
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
                    $paintRgb = if ($browserOn) { $rgb } else { $consoleRgb }
                    if ($mode -eq 'chat_browser_off') {
                        $gapCase.phase = 'chat-setup'
                        Focus-Palette 'chat view off everywhere' 6347
                        Press @(0x0D) 'Enter: reset both switch test sessions to shell'
                        Wait-Until {
                            $state = Read-Session
                            $null -ne $state -and @($state.tabs).Count -eq 2 -and -not $state.PSObject.Properties['chat_view_mode'] -and
                                @($state.tabs | Where-Object { ($_.PSObject.Properties['cv'] -and $_.cv) -or $_.PSObject.Properties['chat_view_lock'] }).Count -eq 0
                        } 'both switch test sessions saved in shell view without removed locks'
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
                            $regions[$tab] = [VerifyNative]::CaptureComposerStart($composerHandle)
                        }
                        $patches = [VerifyNative]::CalibratePatches($regions[0], $regions[1])
                        Save-Json @{ session0 = @($patches[0]); session1 = @($patches[1]) } 'chat-browser-off-patches.json'
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
                            $html = '<title>' + $pageTitle + '</title><style>html,body{margin:0;width:100%;height:100%;background:' + $colors[$tab] + '}</style><script>let keys=0;addEventListener("keydown",e=>{if([" ","ArrowDown","j","k"].includes(e.key)){e.preventDefault();document.title="' + $pageTitle + ' keys "+(++keys)}})</script>'
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
                            Record 'IGSH-724: leave the omnibox focused before Alt+Q returns to the page'
                            [VerifyNative]::Chord(@(0x11, 0x4C))
                            if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.ClassName -ne 'OmniboxViewViews') { throw 'Ctrl+L did not focus the browser address bar' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } 'IGSH-724 Alt+Q did not restore the session input'
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            $pageKeys = 0
                            foreach ($key in @(0x20, 0x28, 0x4A, 0x4B)) {
                                if ([VerifyNative]::GetForegroundWindow() -ne $browser -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Refusing page key outside the owned browser' }
                                [VerifyNative]::Chord(@($key))
                                $pageKeys++
                                if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 Alt+Q sent a page key to browser chrome' }
                            }
                            Record 'IGSH-972: repeated Alt+Q round trips deliver every page key'
                            foreach ($round in 1..5) {
                                [VerifyNative]::Chord(@(0x12, 0x51))
                                Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } ('IGSH-972 round ' + $round + ' Alt+Q did not restore the session input')
                                [VerifyNative]::Chord(@(0x12, 0x51))
                                foreach ($key in @(0x20, 0x28, 0x4A, 0x4B)) {
                                    if ([VerifyNative]::GetForegroundWindow() -ne $browser -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw ('IGSH-972 round ' + $round + ' refusing page key outside the owned browser') }
                                    [VerifyNative]::Chord(@($key))
                                    $pageKeys++
                                    if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw ('IGSH-972 round ' + $round + ' Alt+Q sent a page key to the browser menu') }
                                }
                            }
                            Record 'IGSH-724: F6 still reaches browser chrome'
                            [VerifyNative]::Chord(@(0x75))
                            if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.ClassName -ne 'OmniboxViewViews') { throw 'F6 did not reach the browser address bar' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Palette 'open browser'
                            $hopLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
                            $hopStart = (Read-SharedText $hopLog).Length
                            Press @(0x0D) 'IGSH-724: opening an existing pane focuses its page'
                            Wait-Until { (Read-SharedText $hopLog).Substring($hopStart) -match 'pane_hop result bh_fg=true' } 'IGSH-998 app finished the open-pane hop to its browser'
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Opening the pane did not focus its browser' }
                            [VerifyNative]::Chord(@(0x20))
                            $pageKeys++
                            if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 opening a pane sent Space to browser chrome' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } 'IGSH-724 page-to-input return lost session typing focus'
                            $result.checks += @{ name = 'IGSH-724 browser-page-focus'; mode = $mode; tab = $tab; pageKeys = $pageKeys; ctrlL = $true; f6 = $true; inputReturn = $true }
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
                    $paintPatch = if ($mode -eq 'chat_browser_off') { $patches } else { @($null, $null) }
                    $gapCase.phase = "$mode-start"
                    Press @(0x11, 0x31) 'Ctrl+1: start timing from first session'
                    Wait-WorkspaceSurface $initial.active_workspace 0 $chat ($composerHandle.ToInt32())
                    Wait-Until { [VerifyNative]::PagePainted($docks[0], $paintRgb[0], $paintPatch[0]) } 'first session color before measurement' -Tight
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
                        [VerifyNative]::RequireSwitchStart($script:window, $composerHandle, $consoles[$source], ('ZigShell-' + $shellIds[$source]), $browsers[$source], $docks[$source], $drafts[$source], $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $drafts[$target], $paintRgb[$source], $paintRgb[$target], $paintPatch[$source], $paintPatch[$target])
                        Record ("Ctrl+Tab timing $mode sample=$sample target=$target shellId=" + $shellIds[$target])
                        $logStart = ((Get-Content $log -Raw) -join '').Length
                        $frozenMarker = if ($frozen) { Join-Path $scratch ("roaming/ZigShell/panehib-zss-$($shellIds[$target]).flag") } else { $null }
                        $measurement = [VerifyNative]::MeasureSessionSwitch($script:window, $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $composerHandle, $drafts[$target], $paintRgb[$target], $frozenMarker, $paintPatch[$target])
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
                        Save-Json @{ expected = $paintRgb[$target]; patch = @($paintPatch[$target]); normal = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $false)); layered = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $true)); dock = $docks[$target] } 'switch-failure-screen-patch.json'
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
        'browser-corners' {
            . "$PSScriptRoot/browser-corners.ps1"
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
                $parkedPanes = @([VerifyNative]::OwnedPaneWindows($script:window) | Where-Object {
                    $rect = New-Object VerifyNative+Rect
                    [VerifyNative]::GetWindowRect($_, [ref]$rect) -and
                        [VerifyNative]::MonitorFromRect([ref]$rect, 0) -eq [IntPtr]::Zero
                })
                $script:overlayLaunches.Count -gt 0 -and $parkedPanes.Count -gt 0
            } 'positioned isolated browser launched while Shortcuts is open' 60
            $launchObservedAt = [DateTime]::UtcNow
            $overlayLaunch = @{ launches = $script:overlayLaunches; monitor = $info.Monitor; mainHwnd = $script:window.ToInt64(); overlayPostedAt = $overlayPostedAt; launchObservedAt = $launchObservedAt; overlayAtLaunch = $overlayPostedAt -lt $launchObservedAt }
            Save-Json $overlayLaunch 'browser-pane-locked-launch-restored-overlay.json'
            if (-not $overlayLaunch.overlayAtLaunch) { throw 'Shortcuts was not posted before the restored launch appeared' }
            if (@($overlayLaunch.launches | Where-Object { -not $_.parsed -or -not $_.inside }).Count -ne 0) { throw 'Browser launch point is outside the owner monitor while Shortcuts is open' }
            $parkedMonitors = Assert-BrowserPaneMonitors 'restored-overlay' -RequireParked
            if (-not [VerifyNative]::PostMessage($script:window, 0x8036, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Could not close Shortcuts after the restored browser launch' }
            Wait-Until {
                [VerifyNative]::PaneVisible($script:window) -and
                    $null -ne (Read-Inbox) -and @((Read-Inbox).shells).Count -gt 0
            } 'startup restored the owned browser pane without an open command' 60
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $restoredLaunch = Assert-BrowserLaunchOnOwnMonitor 'restored'
            if (@($restoredLaunch.launches | Where-Object { $_.pid -in @($initialLaunch.launches | ForEach-Object { $_.pid }) }).Count -ne 0) { throw 'Relaunch reused an initial browser process instead of launching at startup' }
            $result.checks += @{ name = 'browser-pane-locked launch-on-own-monitor'; initial = $initialLaunch; restored = $restoredLaunch; restoredOverlay = $overlayLaunch; parkedMonitors = $parkedMonitors }
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
            $ownWorkspaceName = 'Own profile 989'
            if ($ownWorkspaceName -ceq $script:ownSession.workspaces[0].name) { throw 'Expected a distinct workspace name' }
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
            Press @(0x12, 0x32) 'Alt+2: switch to stored workspace 0'
            $null = Assert-WorkspaceBrowser 'shared-return' $sharedRoot 0
            Press @(0x12, 0x51) 'Alt+Q: focus the shared-profile browser'
            $null = Assert-WorkspaceBrowser 'shared-altq' $sharedRoot 0
            Send-ProfileScreenshot 'shared' '' 1
            Press @(0x12, (0x32 + $ownWorkspace)) ("Alt+" + (2 + $ownWorkspace) + ": switch to stored workspace " + $ownWorkspace)
            $null = Assert-WorkspaceBrowser 'own-return' $ownRoot $ownWorkspace
            Press @(0x12, 0x51) 'Alt+Q: focus the own-profile browser'
            $null = Assert-WorkspaceBrowser 'own-altq' $ownRoot $ownWorkspace
            Send-ProfileScreenshot 'own' $ownToken 2
            Restart-SessionRestore 'own-profile-restart' $false $false {
                Record 'Regenerate the opted-in workspace id in session.json and key the opt-in by workspace name, as after an account layout sync'
                $sessionPath = Join-Path $scratch 'roaming/ZigShell/session.json'
                $sessionText = [IO.File]::ReadAllText($sessionPath)
                $idPattern = '"name":"[^"]*","wid":"' + [regex]::Escape($ownWorkspaceId) + '"'
                if (-not [regex]::IsMatch($sessionText, $idPattern)) { throw 'Opted-in workspace id missing from session.json before regeneration' }
                [IO.File]::WriteAllText($sessionPath, [regex]::Replace($sessionText, $idPattern, ('"name":"' + $ownWorkspaceName + '","wid":"ws-regenerated-989"')))
                [IO.File]::WriteAllText($optIn, $ownWorkspaceName + '=' + $ownWorkspaceId + "`n")
            }
            Wait-Until {
                $state = Read-Inbox
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $selected.Count -eq 1 -and $selected[0].ws -eq $ownWorkspace
            } 'restored selection is the opted-in workspace'
            $regenerated = (Read-Session).workspaces[$ownWorkspace].wid
            if ($regenerated -cne 'ws-regenerated-989') { throw ('Workspace id did not stay regenerated: ' + $regenerated) }
            $script:browserShellId = (Read-Inbox).active_shell_id
            Wait-Until {
                $pane = Read-BrowserPane
                $null -ne $pane -and $pane.browser_state -eq 'connected' -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero
            } 'restored opted-in pane docked without an open command' 90
            $restoredProof = Get-PaneUserDataDir ([VerifyNative]::DockedPaneWindow($script:window))
            if ($restoredProof.userDataDir -ine $ownRoot) { throw ('Restored opted-in workspace lost its own browser profile after its workspace id changed: ' + $restoredProof.userDataDir) }
            Wait-OwnProfilePipe $ownToken 'restored'
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'restored opted-in pane bound through its own native host' 60
            Press @(0x12, 0x32) 'Alt+2: switch to stored workspace 0'
            $null = Assert-WorkspaceBrowser 'shared-restored-return' $sharedRoot 0
            Press @(0x12, (0x32 + $ownWorkspace)) ("Alt+" + (2 + $ownWorkspace) + ": switch to stored workspace " + $ownWorkspace)
            $null = Assert-WorkspaceBrowser 'own-restored-return' $ownRoot $ownWorkspace
            Save-Json @{ token = $ownToken; workspaceId = $ownWorkspaceId; ownRoot = $ownRoot; sharedRoot = $sharedRoot; shared = $sharedProof; opted = $ownProof; restored = $restoredProof; sharedBefore = $sharedBefore; sharedAfter = $sharedAfter; coreBefore = $coreBefore; coreAfter = $coreAfter } 'browser-own-profile.json'
            $result.checks += @{ name = 'browser-own-profile shared'; userDataDir = $sharedProof.userDataDir }
            $result.checks += @{ name = 'browser-own-profile opted-in'; userDataDir = $ownProof.userDataDir; token = $ownToken }
            $result.checks += @{ name = 'browser-own-profile shared-untouched'; entries = $sharedAfter.Count }
            $result.checks += @{ name = 'browser-own-profile restored'; userDataDir = $restoredProof.userDataDir }
            $stableChrome = @(
                (Join-Path $env:ProgramFiles 'Google/Chrome/Application/chrome.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'Google/Chrome/Application/chrome.exe')
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if (-not $stableChrome) { throw 'Branded Chrome stable is required for own-profile verification' }
            $stableVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($stableChrome)
            if ($stableVersion.ProductName -cne 'Google Chrome' -or $stableVersion.ProductMajorPart -lt 137) { throw 'Own-profile regression requires branded Google Chrome 137 or newer' }
            Record 'Switch the app to branded Chrome stable; Chrome for Testing cannot prove the extension bootstrap regression'
            [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $stableChrome)
            Press @(0x12, 0x32) 'Alt+2: keep the own workspace inactive during stable warm-up'
            $null = Assert-WorkspaceBrowser 'shared-stable-warmup' $sharedRoot 0
            $existingOwn = Get-Process -Id $restoredProof.pid
            & taskkill.exe /PID $existingOwn.Id /T /F
            if (-not $existingOwn.WaitForExit(10000)) { throw 'Existing own-profile browser did not exit before stable warm-up' }
            $existingOwn.Dispose()
            $stableWarmupLog = Join-Path $config 'bridge-launch.log'
            $stableWarmupLogStart = if (Test-Path -LiteralPath $stableWarmupLog) { @(Get-Content -LiteralPath $stableWarmupLog).Count } else { 0 }
            $stableWarmupClock = [Diagnostics.Stopwatch]::StartNew()
            $stableWarmup = Start-Process -FilePath (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe') -ArgumentList ('chrome-launch "' + $stableChrome + '" "' + $extension + '" "' + (Join-Path $extension 'themes/dark') + '" "--user-data-dir=' + $ownRoot + '" "--no-first-run" "--no-default-browser-check" "--new-window" "data:text/html,<title>ZSPANE-WARM</title>"') -PassThru
            try {
                Wait-Until {
                    if ($stableWarmup.HasExited) { throw 'Stable warm-up bridge exited before loading the extension' }
                    (Test-Path -LiteralPath $stableWarmupLog) -and
                        @(Get-Content -LiteralPath $stableWarmupLog | Select-Object -Skip $stableWarmupLogStart | Where-Object { $_ -ceq 'extension loaded' }).Count -gt 0
                } 'branded Chrome own-profile warm-up loaded the extension' 60
                Wait-Until {
                    [VerifyNative]::BringToForeground($script:window)
                    [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
                } 'main window foreground after stable warm-up'
                Press @(0x12, (0x32 + $ownWorkspace)) 'Return to the own workspace before the stable restart'
                $null = Assert-WorkspaceBrowser 'own-stable-warmup-return' $ownRoot $ownWorkspace
            } finally {
                $stableWarmupChrome = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = " + $stableWarmup.Id) | Where-Object { $_.ExecutablePath -ieq $stableChrome } | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue })
                if (-not $stableWarmup.HasExited) {
                    & taskkill.exe /PID $stableWarmup.Id /T /F
                }
                foreach ($browser in $stableWarmupChrome) {
                    if (-not $browser.WaitForExit(10000)) { throw 'Stable warm-up Chrome did not exit' }
                    $browser.Dispose()
                }
                if (-not $stableWarmup.WaitForExit(10000)) { throw 'Stable warm-up bridge did not exit' }
                $stableWarmup.Dispose()
                $stableWarmupClock.Stop()
            }
            $result.checks += @{ name = 'browser-own-profile stable-warmup'; seconds = $stableWarmupClock.Elapsed.TotalSeconds }
            Restart-SessionRestore 'stable-chrome-switch' $false
            $null = Assert-WorkspaceBrowser 'stable-existing-own' $ownRoot $ownWorkspace
            Press @(0x11, 0x4E) 'Ctrl+N: create a cold branded Chrome workspace'
            Wait-Until {
                $script:stableSession = Read-Session
                $state = Read-Inbox
                if ($null -eq $script:stableSession -or $null -eq $state) { return $false }
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $script:stableSession.workspace_count -eq $before + 2 -and $selected.Count -eq 1 -and
                    $selected[0].ws -eq $script:stableSession.active_workspace -and $selected[0].ws -ne $ownWorkspace
            } 'branded Chrome workspace persisted'
            $stableWorkspace = $script:stableSession.active_workspace
            $stableWorkspaceId = $script:stableSession.workspaces[$stableWorkspace].wid
            $stableToken = Get-OwnProfileToken $stableWorkspaceId
            $stableRoot = [IO.Path]::GetFullPath((Join-Path $ownBase ('chrome/' + $stableToken))).TrimEnd('\')
            if (Test-Path -LiteralPath $stableRoot) { throw 'Branded Chrome own profile must start empty' }
            [IO.File]::AppendAllText($optIn, $stableWorkspaceId + "`n")
            Wait-Until {
                [VerifyNative]::BringToForeground($script:window)
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'main window foreground before the cold branded Chrome workspace browser opens'
            $script:browserShellId = (Read-Inbox).active_shell_id
            $stableProof = Open-WorkspaceBrowser 'stable-cold-own'
            if ($stableProof.userDataDir -ine $stableRoot) { throw 'Branded Chrome pane used the wrong own profile' }
            $stableProcess = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $stableProof.pid)
            if ($stableProcess.ExecutablePath -ine $stableChrome) { throw 'Cold own pane is not branded Chrome stable' }
            $holder = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $stableProcess.ParentProcessId)
            if ([IO.Path]::GetFileName($holder.ExecutablePath) -ine 'zigshell-bridge.exe' -or $holder.CommandLine -notmatch 'chrome-launch') { throw 'Branded Chrome has no persistent bridge pipe holder' }
            Wait-OwnProfilePipe $stableToken 'stable-cold-own'
            $stablePane = Read-BrowserPane
            if ($stablePane.browser_window_id -le 0) { throw 'Branded Chrome own pane did not resolve a window id' }
            Save-Json @{ executable = $stableChrome; product = $stableVersion.ProductName; version = $stableVersion.ProductVersion; browser = $stableProof; holderPid = $holder.ProcessId; token = $stableToken; windowId = $stablePane.browser_window_id } 'browser-own-profile-stable.json'
            Restart-SessionRestore 'stable-own-restart' $false
            Wait-OwnProfilePipe $stableToken 'stable-restored-own'
            $null = Assert-WorkspaceBrowser 'stable-restored-own' $stableRoot $stableWorkspace
            $result.checks += @{ name = 'browser-own-profile branded Chrome stable cold and restored'; executable = $stableChrome; token = $stableToken; windowId = $stablePane.browser_window_id }
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
            foreach ($height in $heights) {
                if ($height -gt 30 -or $height -lt 20) { throw ('status-card: card height ' + $height + ' outside 20..30; heights ' + ($heights -join ', ')) }
            }
            if (($pages[2].clientBottom - $pages[2].bottom) / $scale -gt 35) { throw 'IGSH-908: usage pill has no frame at the sidebar bottom' }
            Snapshot 'pill-closed'
            $pillX = [int][Math]::Round(60 * $scale)
            $pillY = $client.Bottom - [int][Math]::Round(14 * $scale)
            Record 'Real click: expand AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'AI usage data panel visible'
            $menu = @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible })[0]
            $look = [VerifyNative]::MenuLook([IntPtr]::new([int64]$menu.handle))
            if ($look.cornerShown -or $look.leftEdge -ne $look.fill -or $look.rightEdge -ne $look.fill) { throw 'IGSH-908: expanded usage panel differs from the existing rounded menu style' }
            Snapshot 'pill-open'
            Snapshot 'action'
            Record 'Real second click: close AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on second click'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'usage panel reopens'
            Press @(0x1B) 'Escape: dismiss AI usage panel'
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on Escape'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'usage panel reopens before outside click'
            [VerifyNative]::ClickClient($script:window, [int]($client.Right * 3 / 4), ($client.Bottom - [int][Math]::Round(4 * $scale)))
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on outside click'
            Snapshot 'pill-dismissed'
            if ([IO.File]::ReadAllText($statusFile).Trim() -ne '2') { throw 'AI data panel changed the selected status page' }
            Snapshot 'after'
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look } }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; heights = $heights; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true; entry = 'Ctrl+Shift+G' }
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
        'chat-switch-speed' {
            function Test-TabChat($tab) { return [bool]($tab.PSObject.Properties['cv'] -and $tab.cv) }
            $sessionCount = 5
            $switchCount = 20
            $chatLimitMs = 150
            $hangLimitMs = 100
            $settleMs = 1200
            $modes = @('browser_closed', 'browser_open')
            $timings = [ordered]@{ session_count = $sessionCount; switches_per_mode = $switchCount; click_to_chat_limit_ms = $chatLimitMs; hang_limit_ms = $hangLimitMs }
            foreach ($mode in $modes) { $timings[$mode] = @{ samples_ms = @(); app_ms = @(); hang_ms = @(); missing = 0; median_ms = $null; max_ms = $null; max_hang_ms = $null; first_frame_layout_w = @(); first_frame_client_w = @(); first_frame_wrong_width = 0; moved_after_first_frame = 0; moved_lines = @() } }
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $gapCase = @{ name = 'chat-switch-speed'; status = 'failed'; detail = 'Chat switch measurement did not complete'; phase = 'initial-console' }
            function Read-SharedLog([string]$Path) {
                $stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
                try { $reader = New-Object System.IO.StreamReader($stream); try { return $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
            }
            function Add-SeedTurn([string]$SessionName, [int]$Round) {
                $index = [int]($SessionName -replace '^.*-', '') - 1
                $sid = 'a1b2c3d4-0927-4000-8000-0000000009{0:D2}' -f $index
                $folder = ('C:/verify/work{0}' -f $index) -replace '[^A-Za-z0-9]', '-'
                $path = Join-Path $scratch ("profile/.claude/projects/$folder/$sid.jsonl")
                $text = "Session $index live answer $Round`n`n" + ('This paragraph stands in for a running agent adding a new answer to the conversation while another session is in front. ' * 3)
                $row = [ordered]@{ type = 'assistant'; timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'); sessionId = $sid; uuid = [guid]::NewGuid().ToString(); isSidechain = $false; message = [ordered]@{ role = 'assistant'; id = ('msg_live_' + [guid]::NewGuid().ToString('N').Substring(0, 12)); model = 'claude-opus-5-5'; content = @(@{ type = 'text'; text = $text }) } }
                [IO.File]::AppendAllText($path, (($row | ConvertTo-Json -Depth 6 -Compress) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
            }
            $result.checks += $gapCase
            $shellIds = @()
            $toggleReady = $null
            $probeStarted = $false
            try {
                Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $sessionCount -and @($state.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq $sessionCount } 'five seeded remote sessions restored'
                $gapCase.phase = 'idle-close-fixture'
                Focus-Palette 'browser auto suspend' 6240
                Press @(0x0D) 'Enter: disable timed browser closing while measuring'
                Wait-Until { $state = Read-Session; $state.PSObject.Properties['browser_suspend_min'] -and $state.browser_suspend_min -eq 0 } 'app saved idle browser closing disabled'
                $gapCase.phase = 'manual-tab-order'
                Focus-Palette 'tab order' 6217
                Press @(0x28) 'Down: Tab Order Manual'
                Press @(0x0D) 'Enter: keep saved order for Ctrl+1 to Ctrl+5'
                Wait-Until {
                    $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                    if (-not (Test-Path $path)) { return $false }
                    $launch = Get-Content $path -Raw | ConvertFrom-Json
                    $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
                } 'manual tab order saved before creating sessions'
                for ($tab = 0; $tab -lt $sessionCount; $tab++) {
                    $gapCase.phase = "session-setup-$tab"
                    Press @(0x11, (0x31 + $tab)) "Ctrl+$($tab + 1): select remote session $tab"
                    Wait-Until { $state = Read-Session; $state.active_tab -eq $tab } "remote session $tab selected" 30
                    if ($null -ne $toggleReady) { Wait-Until { [DateTime]::UtcNow -ge $toggleReady } "Alt+C debounce elapsed before session $tab" }
                    Press @(0x12, 0x43) "Alt+C: open Chat View for session $tab"
                    $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
                    Wait-Until { Test-TabChat (Read-Session).tabs[$tab] } "Chat View saved for session $tab" 30
                    $shownId = (Read-Session).tabs[$tab].shell_id
                    Wait-Until { ((Get-Content $log -Raw) -join '') -match ('\[switch\] chat content shown shell=' + $shownId + ' blocks=[1-9]') } "seeded transcript shown for session $tab" 60
                    $shellIds += $shownId
                }
                $state = Read-Session
                if (@($state.tabs).Count -ne $sessionCount -or @($state.tabs | Where-Object { -not (Test-TabChat $_) }).Count -ne 0) { throw 'Not every session is in Chat View' }
                Save-Json @{ shellIds = $shellIds; tabs = @($state.tabs) } 'chat-switch-sessions.json'
                if ($null -ne $warmupJob) {
                    $warmupStopped = $warmupJob.Stop()
                    Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                    $warmupJob.Dispose()
                    $warmupJob = $null
                }
                Snapshot 'before'
                [VerifyNative]::StartHangProbe($script:window)
                $probeStarted = $true
                foreach ($mode in $modes) {
                    $open = $mode -eq 'browser_open'
                    if ($open) {
                        for ($tab = 0; $tab -lt $sessionCount; $tab++) {
                            $gapCase.phase = "$mode-setup-$tab"
                            Press @(0x11, (0x31 + $tab)) "Ctrl+$($tab + 1): select session to open its browser"
                            Wait-Until { (Read-Session).active_tab -eq $tab } "session $tab selected"
                            $script:browserShellId = $shellIds[$tab]
                            $null = Open-BrowserPane ("$mode-$tab")
                            Wait-SwitchNativeHost
                            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero } "session $tab browser connected and docked" 30
                        }
                    }
                    $gapCase.phase = "$mode-start"
                    Press @(0x11, 0x31) 'Ctrl+1: start timing from the first session'
                    Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected'
                    Start-Sleep -Milliseconds 1500
                    foreach ($warm in 1..($sessionCount - 1)) {
                        Press @(0x11, (0x31 + $warm)) "Ctrl+$($warm + 1): first visit warm-up"
                        Wait-Until { (Read-Session).active_tab -eq $warm } "warm-up session $warm selected"
                        Start-Sleep -Milliseconds 800
                    }
                    Press @(0x11, 0x31) 'Ctrl+1: return to the first session after warm-up'
                    Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected after warm-up'
                    Start-Sleep -Milliseconds 1500
                    $current = 0
                    for ($sample = 0; $sample -lt $switchCount; $sample++) {
                        $gapCase.phase = "$mode-sample-$sample"
                        $target = ($current + 1) % $sessionCount
                        Doctor
                        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'main window foreground before the switch' 10
                        Add-SeedTurn (Read-Session).tabs[$target].tmux_session $sample
                        Start-Sleep -Milliseconds 300
                        $offset = (Get-Item -LiteralPath $log).Length
                        $needle = '[switch] chat content shown shell=' + $shellIds[$target] + ' '
                        Record "Ctrl+$($target + 1): switch to Chat View session $target ($mode sample $sample)"
                        $measured = [VerifyNative]::SwitchToSession($target, $log, $offset, $needle, $settleMs)
                        if ((Read-Session).active_tab -ne $target) { throw "Switch $sample did not select session $target" }
                        $text = Read-SharedLog $log
                        $range = if ($offset -le $text.Length) { $text.Substring($offset) } else { '' }
                        $appMs = $null
                        $found = [regex]::Match($range, [regex]::Escape($needle) + 'blocks=\d+ ms=(\d+)')
                        if ($found.Success) { $appMs = [int]$found.Groups[1].Value }
                        if ($open -and -not [VerifyNative]::PaneVisible($script:window)) { throw "Browser pane not visible after switch $sample" }
                        $widths = [regex]::Match($range, [regex]::Escape($needle) + 'blocks=\d+ ms=\d+ layout_w=(-?\d+) client_w=(-?\d+)')
                        if ($widths.Success) {
                            $timings[$mode].first_frame_layout_w += [int]$widths.Groups[1].Value
                            $timings[$mode].first_frame_client_w += [int]$widths.Groups[2].Value
                            if ($widths.Groups[1].Value -ne $widths.Groups[2].Value) { $timings[$mode].first_frame_wrong_width++ }
                            $afterShown = $range.Substring($widths.Index + $widths.Length)
                            $laterMoves = @($afterShown -split "`n" | Where-Object { $_ -match '\[chat\] frame transcript|\[reposition\] client=' })
                            if ($laterMoves.Count -gt 0) { $timings[$mode].moved_after_first_frame++; $timings[$mode].moved_lines += $laterMoves[0].Trim() }
                        }
                        if ($measured[0] -lt 0) { $timings[$mode].missing++ }
                        $timings[$mode].samples_ms += $(if ($measured[0] -lt 0) { $settleMs } else { [Math]::Round($measured[0], 1) })
                        $timings[$mode].app_ms += $appMs
                        $timings[$mode].hang_ms += [Math]::Round($measured[1], 1)
                        $range | Set-Content -Encoding UTF8 (Join-Path $Evidence ("{0}-{1}-debug.log" -f $mode, $sample))
                        $current = $target
                    }
                    $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms
                    $timings[$mode].max_ms = ($timings[$mode].samples_ms | Measure-Object -Maximum).Maximum
                    $timings[$mode].max_hang_ms = ($timings[$mode].hang_ms | Measure-Object -Maximum).Maximum
                    if (-not $open) { Snapshot 'action' }
                }
                $gapCase.phase = 'verdict'
                $summary = foreach ($mode in $modes) { "$mode median $($timings[$mode].median_ms) ms (limit $chatLimitMs), worst $($timings[$mode].max_ms) ms, worst window hang $($timings[$mode].max_hang_ms) ms (limit $hangLimitMs), switches without chat shown: $($timings[$mode].missing), first frame at wrong width: $($timings[$mode].first_frame_wrong_width), layout moved after first frame: $($timings[$mode].moved_after_first_frame)" }
                $gapCase.detail = $summary -join '; '
                foreach ($mode in $modes) {
                    if ($timings[$mode].missing -gt 0 -or $timings[$mode].median_ms -gt $chatLimitMs -or $timings[$mode].max_hang_ms -gt $hangLimitMs -or $timings[$mode].first_frame_wrong_width -gt 0 -or $timings[$mode].moved_after_first_frame -gt 0) { throw $gapCase.detail }
                }
                Snapshot 'after'
                $gapCase.status = 'passed'
            } catch {
                $gapCase.detail = $gapCase.phase + ': ' + $_.Exception.Message
                throw
            } finally {
                if ($probeStarted) { [VerifyNative]::StopHangProbe() }
                Save-Json $timings 'switch-timings.json'
                Save-Json (Read-Session) 'switch-final-session.json'
                if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log (Join-Path $Evidence 'chat-switch-debug.log') -ErrorAction SilentlyContinue }
            }
        }
    }
    if ($Feature -in @('title-bar', 'window-controls')) {
        if (-not $result.windowControls.closed -or -not $process.HasExited) { throw 'Window control journey did not prove normal close' }
    } else { Doctor }
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
                if ($null -ne $switchExtensionRoot) {
                    Remove-Item -LiteralPath $switchExtensionRoot -Recurse -Force
                    $switchExtensionRoot = $null
                }
                foreach ($pinned in $script:pinnedNotifyListeners) { $pinned.Stop() }
                $script:pinnedNotifyListeners = @()
                if ($null -ne $script:uploadReceiver -and -not $script:uploadReceiver.HasExited) { $script:uploadReceiver.Kill() }
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
    if ($null -ne $usageCollector) { $usageCollector.Dispose() }
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    if ($null -ne $originalFontSmoothing) { [VerifyNative]::FontSmoothing([bool]$originalFontSmoothing) }
    if ($Feature -in @('title-bar', 'window-controls') -and ('CaptionProof' -as [type])) {
        try { [CaptionProof]::RestoreDpi() } catch { $result.status = 'failed'; $result.dpiCleanupError = $_.Exception.Message }
    }
    Save-Json $result 'result.json'
}
if ($result.status -ne 'passed') { throw ('Verification failed: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
Write-Output "VERIFIED $Feature with real input and retained evidence"
exit 0
