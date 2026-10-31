using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class VerifyNative {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool RemoveFontResourceEx(string path, uint flags, IntPtr reserved);
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
    public static double ImmediateBrowserTogglePair(int delay) {
        var inputs = new List<Input>();
        Action<ushort, uint> key = (code, flags) => {
            Input input = new Input(); input.type = 1;
            input.data.keyboard = new Keyboard { key = code, flags = flags };
            inputs.Add(input);
        };
        key(0x12, 0); key(0x41, 0); key(0x41, 2); key(0x12, 2);
        Input[] batch = inputs.ToArray();
        Action chord = () => {
            if (SendInput((uint)batch.Length, batch, Marshal.SizeOf(typeof(Input))) != (uint)batch.Length) throw new InvalidOperationException("SendInput chord failed");
        };
        var clock = System.Diagnostics.Stopwatch.StartNew();
        chord();
        double remaining = delay - clock.Elapsed.TotalMilliseconds;
        if (remaining > 0) Thread.Sleep((int)(remaining));
        double gap = clock.Elapsed.TotalMilliseconds;
        chord();
        return gap;
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
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumWindow callback, IntPtr data);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool ScreenToClient(IntPtr hwnd, ref Point point);
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
    public static Dictionary<string, object> ObserveUsageHover(IntPtr owner, uint pid, int intendedX, int intendedY) {
        uint actualPid;
        GetWindowThreadProcessId(owner, out actualPid);
        if (actualPid != pid || Class(owner) != "ZigShell" || GetAncestor(owner, 2) != owner || GetAncestor(owner, 3) != owner) throw new InvalidOperationException("Hover observation owner mismatch");
        Point screen;
        if (!GetCursorPos(out screen)) throw new InvalidOperationException("Cannot read hover pointer");
        Point client = screen;
        if (!ScreenToClient(owner, ref client)) throw new InvalidOperationException("Cannot map hover pointer");
        IntPtr hit = WindowFromPoint(screen);
        bool ownedHit = hit != IntPtr.Zero && GetAncestor(hit, 3) == owner;
        IntPtr foreground = GetForegroundWindow();
        bool ownedForeground = foreground != IntPtr.Zero && GetAncestor(foreground, 3) == owner;
        var children = new List<Dictionary<string, object>>();
        EnumChildWindows(owner, delegate(IntPtr hwnd, IntPtr data) {
            if (Class(hwnd) != "MultiPromptUsageCard") return true;
            var identity = WindowIdentity(hwnd);
            Rect rectangle;
            identity["parent"] = GetParent(hwnd).ToInt64();
            identity["direct"] = GetParent(hwnd) == owner;
            identity["rect"] = GetWindowRect(hwnd, out rectangle) ? new int[] { rectangle.Left, rectangle.Top, rectangle.Right, rectangle.Bottom } : null;
            children.Add(identity);
            return true;
        }, IntPtr.Zero);
        var result = new Dictionary<string, object> {
            { "observedUtc", DateTime.UtcNow.ToString("o") }, { "main", WindowIdentity(owner) },
            { "mainFocus", GetFocusedWindow(owner).ToInt64() }, { "foregroundHandle", foreground.ToInt64() },
            { "foregroundOwned", ownedForeground }, { "foreground", ownedForeground ? WindowIdentity(foreground) : null },
            { "intendedClient", new int[] { intendedX, intendedY } }, { "actualClient", new int[] { client.X, client.Y } },
            { "actualScreen", new int[] { screen.X, screen.Y } }, { "hitOwned", ownedHit },
            { "hitHandle", hit.ToInt64() }, { "hitRoot", GetAncestor(hit, 2).ToInt64() }, { "hitRootOwner", GetAncestor(hit, 3).ToInt64() },
            { "hitWindow", ownedHit ? WindowIdentity(hit) : null }, { "usageChildren", children }
        };
        if (ownedHit) {
            UIntPtr hitResult;
            int packed = unchecked((screen.Y << 16) | (screen.X & 0xffff));
            bool ok = SendMessageTimeout(hit, 0x0084, UIntPtr.Zero, new IntPtr(packed), 2, 500, out hitResult) != IntPtr.Zero;
            result["hitTestResponded"] = ok;
            result["hitTest"] = ok ? unchecked((int)hitResult.ToUInt64()) : (object)null;
        }
        return result;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string className, string title);
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
    static long probeWindowStarted;
    static readonly object probeLock = new object();
    public static void StartHangProbe(IntPtr owner) {
        probeRun = true;
        probeThread = new Thread(() => {
            while (probeRun) {
                UIntPtr result;
                long started = System.Diagnostics.Stopwatch.GetTimestamp();
                SendMessageTimeout(owner, 0, UIntPtr.Zero, IntPtr.Zero, 2, 5000, out result);
                long ended = System.Diagnostics.Stopwatch.GetTimestamp();
                lock (probeLock) {
                    double elapsed = Math.Max(0, ended - Math.Max(started, probeWindowStarted)) * 1000.0 / System.Diagnostics.Stopwatch.Frequency;
                    if (elapsed > probeMax) probeMax = elapsed;
                }
                Thread.Sleep(2);
            }
        });
        probeThread.IsBackground = true;
        probeThread.Start();
    }
    public static void ResetHangProbe() { lock (probeLock) { probeWindowStarted = System.Diagnostics.Stopwatch.GetTimestamp(); probeMax = 0; } }
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
    public static double ChangelogResponse(IntPtr owner) {
        UIntPtr result;
        var timer = System.Diagnostics.Stopwatch.StartNew();
        if (SendMessageTimeout(owner, 0, UIntPtr.Zero, IntPtr.Zero, 2, 2000, out result) == IntPtr.Zero) throw new InvalidOperationException("Changelog response timed out");
        return timer.Elapsed.TotalMilliseconds;
    }
    public static double MeasureChangelogKey(IntPtr owner, ushort key) {
        if (GetForegroundWindow() != owner) throw new InvalidOperationException("Changelog does not own keyboard focus");
        Rect frame;
        if (!GetWindowRect(owner, out frame)) throw new InvalidOperationException("Missing changelog frame");
        int x = frame.Left + (frame.Right - frame.Left) / 2 + 100;
        int y = frame.Top + (frame.Bottom - frame.Top) / 2 - 48;
        using (var pixels = new System.Drawing.Bitmap(96, 96))
        using (var graphics = System.Drawing.Graphics.FromImage(pixels)) {
            ReadPatch(x, y, pixels, graphics);
            var before = new int[576];
            for (int row = 0; row < 24; row++) for (int col = 0; col < 24; col++) before[row * 24 + col] = pixels.GetPixel(col * 4, row * 4).ToArgb();
            Input[] inputs = new Input[2];
            inputs[0].type = inputs[1].type = 1;
            inputs[0].data.keyboard = new Keyboard { key = key };
            inputs[1].data.keyboard = new Keyboard { key = key, flags = 2 };
            var timer = System.Diagnostics.Stopwatch.StartNew();
            if (SendInput(2, inputs, Marshal.SizeOf(typeof(Input))) != 2) throw new InvalidOperationException("Changelog input failed");
            do {
                ReadPatch(x, y, pixels, graphics);
                int changed = 0;
                for (int row = 0; row < 24; row++) for (int col = 0; col < 24; col++) if (before[row * 24 + col] != pixels.GetPixel(col * 4, row * 4).ToArgb()) changed++;
                if (changed >= 8) { ChangelogResponse(owner); return timer.Elapsed.TotalMilliseconds; }
                Thread.Sleep(1);
            } while (timer.ElapsedMilliseconds < 10000);
            throw new InvalidOperationException("Changelog key never changed the visible text surface");
        }
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
    public static void MoveMouseOwnedRoot(IntPtr owner, uint pid, int x, int y) {
        uint actualPid;
        GetWindowThreadProcessId(owner, out actualPid);
        if (actualPid != pid || Class(owner) != "ZigShell" || GetAncestor(owner, 2) != owner || GetAncestor(owner, 3) != owner) throw new InvalidOperationException("Mouse owner mismatch");
        Point target = new Point { X = x, Y = y };
        if (!ClientToScreen(owner, ref target) || GetAncestor(WindowFromPoint(target), 3) != owner || GetAncestor(GetForegroundWindow(), 3) != owner) throw new InvalidOperationException("Mouse target is outside the owned foreground window");
        MoveMouseClient(owner, x, y, false);
    }
    public static void WheelClient(IntPtr hwnd, uint pid, int x, int y, int delta) {
        uint actualPid;
        GetWindowThreadProcessId(hwnd, out actualPid);
        if (actualPid != pid || Class(hwnd) != "ZigShell" || GetAncestor(hwnd, 2) != hwnd || GetAncestor(hwnd, 3) != hwnd) throw new InvalidOperationException("Wheel owner mismatch");
        Point point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd || GetAncestor(GetForegroundWindow(), 3) != hwnd) throw new InvalidOperationException("Wheel target is not the owned foreground sidebar");
        if (delta == 0 || delta % 120 != 0) throw new ArgumentOutOfRangeException("delta");
        MouseAt(point.X, point.Y, 0);
        Input input = new Input(); input.type = 0;
        input.data.mouse = new Mouse { data = unchecked((uint)delta), flags = 0x0800 };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Sidebar wheel input failed");
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
    public static Dictionary<string, object> Check(string path, VerifyNative.Rect frame, VerifyNative.Point origin, uint dpi, int scale, bool hidePills, bool collapsed, int sidebarWidth) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int clientLeft = origin.X - frame.Left;
            int left = clientLeft + S(8, dpi, scale);
            int right = clientLeft + S(sidebarWidth, dpi, scale) - S(8, dpi, scale) / 2;
            int top = origin.Y - frame.Top + S(8, dpi, scale) + (hidePills ? 0 : 34) + S(52, dpi, scale);
            int headerHeight = 28, rowHeight = S(58, dpi, scale);
            int secondHeader = top + headerHeight + (collapsed ? 0 : 2 * rowHeight);
            int groupBottom = secondHeader + headerHeight + 2 * rowHeight;
            var background = image.GetPixel(clientLeft + S(2, dpi, scale), top);
            var muted = System.Drawing.Color.FromArgb(138, 138, 138);
            var rail = System.Drawing.Color.FromArgb(145, 149, 157);
            int fillMismatch = 0, railPixels = 0, brightHeaderPixels = 0, largestPrefixGap = 0;
            var nameXs = new List<int>();
            var sessionXs = new List<int>();
            bool flushLeft = true;
            for (int group = 0; group < 2; group++) {
                int headerTop = group == 0 ? top : secondHeader;
                foreach (int y in new int[] { headerTop, headerTop + headerHeight - 1 })
                    for (int x = clientLeft; x < clientLeft + S(sidebarWidth, dpi, scale) - 1; x++)
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
            proof["sidebarRect"] = new int[] { clientLeft, top, clientLeft + S(sidebarWidth, dpi, scale) - 1, groupBottom };
            proof["railSearchX"] = new int[] { clientLeft, left + S(10, dpi, scale) };
            proof["background"] = new int[] { background.R, background.G, background.B };
        }
        return proof;
    }
    public static Dictionary<string, object> Labels(string path, VerifyNative.Rect frame, VerifyNative.Point origin, uint dpi, int scale, int sectionTop, int headlineX, int rowHeight, int sidebarWidth) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int clientLeft = origin.X - frame.Left;
            int right = clientLeft + S(sidebarWidth, dpi, scale) - S(8, dpi, scale);
            int sectionHeight = 24, buttonHeight = 32;
            var muted = System.Drawing.Color.FromArgb(138, 138, 138);
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
            bool capitals = present && capRatio > 0.75;
            bool mutedInk = mutedPixels >= 8;
            int buttonTop = sectionTop + sectionHeight + 2 * rowHeight + 4;
            var buttonBackground = image.GetPixel(right, buttonTop + buttonHeight / 2);
            int minX = int.MaxValue, maxX = -1, minY = int.MaxValue, maxY = -1, buttonInk = 0;
            for (int y = buttonTop; y < buttonTop + buttonHeight; y++) {
                for (int x = clientLeft + S(2, dpi, scale); x < clientLeft + S(sidebarWidth, dpi, scale) - S(2, dpi, scale); x++) {
                    if (Distance(image.GetPixel(x, y), buttonBackground) <= 30) continue;
                    buttonInk++;
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x);
                    minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
                }
            }
            bool formerButtonRegionEmpty = buttonInk == 0;
            proof["labelPresent"] = present;
            proof["noArrow"] = noArrow;
            proof["capitals"] = capitals;
            proof["mutedInk"] = mutedInk;
            proof["sameStyle"] = present && capitals && mutedInk && noArrow;
            proof["formerButtonRegionEmpty"] = formerButtonRegionEmpty;
            proof["labelFirstInkX"] = firstInk;
            proof["headlineX"] = headlineX;
            proof["capRatio"] = capRatio;
            proof["labelInkPixels"] = inkPixels;
            proof["labelMutedPixels"] = mutedPixels;
            proof["labelRect"] = new int[] { clientLeft, sectionTop, right, sectionTop + sectionHeight };
            proof["formerButtonScanRect"] = new int[] { clientLeft + S(2, dpi, scale), buttonTop, clientLeft + S(sidebarWidth, dpi, scale) - S(2, dpi, scale), buttonTop + buttonHeight };
            proof["formerButtonInkBox"] = buttonInk == 0 ? new int[0] : new int[] { minX, minY, maxX, maxY };
            proof["formerButtonInkPixels"] = buttonInk;
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
        VerifyNative.Rect client, VerifyNative.Rect console, VerifyNative.Rect browser, uint dpi, int scale, int sidebarWidth) {
        int gap = S(8, dpi, scale), inset = S(10, dpi, scale), margin = S(2, dpi, scale);
        int browserLeft = browser.Left - inset;
        int primaryLeft = client.Left + S(sidebarWidth, dpi, scale) + gap / 2;
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
        int appX = client.Left + S(2, dpi, scale), appY = client.Top + S(200, dpi, scale);
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
        VerifyNative.Rect console, VerifyNative.Rect browser, uint dpi, int scale, bool hidePills, int sidebarWidth) {
        var proof = new Dictionary<string, object>();
        using (var image = new System.Drawing.Bitmap(path)) {
            int ox = frame.Left, oy = frame.Top;
            Func<int, int, System.Drawing.Color> pixel = (x, y) => image.GetPixel(x - ox, y - oy);
            int gap = S(8, dpi, scale), pad = S(6, dpi, scale), border = S(1, dpi, scale);
            int sidebarLeft = client.Left + gap;
            int sidebarRight = client.Left + S(sidebarWidth, dpi, scale) - gap / 2;
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
            int rowTop = client.Top + gap + (hidePills ? 0 : 34) + S(52, dpi, scale) + 28;
            int rowBottom = rowTop + S(58, dpi, scale);
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
