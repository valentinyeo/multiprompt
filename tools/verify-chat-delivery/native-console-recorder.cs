using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public sealed class NativeConsoleRecorder : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr Hwnd; public uint Id; public UIntPtr W; public IntPtr L; public uint Time; public int X, Y; }
    delegate void EventProc(IntPtr hook, uint kind, IntPtr hwnd, int obj, int child, uint thread, uint time);
    delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr module, EventProc callback, uint pid, uint thread, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] static extern int GetMessage(out Message message, IntPtr hwnd, uint min, uint max);
    [DllImport("user32.dll")] static extern bool PostThreadMessage(uint thread, uint message, UIntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool PeekMessage(out Message message, IntPtr hwnd, uint min, uint max, uint flags);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr hwnd, EnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int length);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint command);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("kernel32.dll")] static extern ulong GetTickCount64();
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    readonly Dictionary<IntPtr, string> classes = new Dictionary<IntPtr, string>();
    readonly StreamWriter log;
    readonly string directory;
    readonly Thread worker;
    readonly ManualResetEvent ready = new ManualResetEvent(false);
    readonly EventProc callback;
    uint threadId;
    int captures;
    Exception failure;
    bool disposed;

    public NativeConsoleRecorder(string path) {
        directory = path;
        Directory.CreateDirectory(path);
        log = new StreamWriter(Path.Combine(path, "windows.tsv"), false, new UTF8Encoding(false));
        log.AutoFlush = true;
        callback = OnEvent;
        worker = new Thread(Run);
        worker.IsBackground = true;
        worker.Start();
        if (!ready.WaitOne(10000)) throw new TimeoutException("Native window observer did not start");
        if (failure != null) { worker.Join(); ready.Dispose(); log.Dispose(); throw new Exception("Native window observer failed", failure); }
    }
    void Run() {
        IntPtr objects = IntPtr.Zero, foreground = IntPtr.Zero;
        try {
            SetThreadDpiAwarenessContext(new IntPtr(-4));
            threadId = GetCurrentThreadId();
            Message message;
            PeekMessage(out message, IntPtr.Zero, 0, 0, 0);
            objects = SetWinEventHook(0x8000, 0x8017, IntPtr.Zero, callback, 0, 0, 0);
            foreground = SetWinEventHook(3, 3, IntPtr.Zero, callback, 0, 0, 0);
            if (objects == IntPtr.Zero || foreground == IntPtr.Zero) throw new Exception("SetWinEventHook failed");
            log.WriteLine("start\t" + GetTickCount64());
            EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
                Record("snapshot", GetTickCount64(), hwnd);
                EnumChildWindows(hwnd, delegate(IntPtr child, IntPtr unused) { Record("snapshot", GetTickCount64(), child); return true; }, IntPtr.Zero);
                return true;
            }, IntPtr.Zero);
            ready.Set();
            int status;
            while ((status = GetMessage(out message, IntPtr.Zero, 0, 0)) > 0) {}
            if (status < 0) throw new Exception("Native observer message pump failed");
            log.WriteLine("stop\t" + GetTickCount64());
        } catch (Exception error) { failure = error; log.WriteLine("error\t" + error.GetType().Name); ready.Set(); }
        finally {
            if (objects != IntPtr.Zero) UnhookWinEvent(objects);
            if (foreground != IntPtr.Zero) UnhookWinEvent(foreground);
        }
    }
    void OnEvent(IntPtr hook, uint kind, IntPtr hwnd, int obj, int child, uint thread, uint time) {
        if (hwnd == IntPtr.Zero || obj != 0 || child != 0) return;
        string name;
        switch (kind) {
            case 3: name = "foreground"; break;
            case 0x8000: name = "create"; break;
            case 0x8001: name = "destroy"; break;
            case 0x8002: name = "show"; break;
            case 0x8003: name = "hide"; break;
            case 0x8004: name = "reorder"; break;
            case 0x800A: name = "state"; break;
            case 0x800B: name = "location"; break;
            case 0x800F: name = "parent"; break;
            default: return;
        }
        try {
            ulong now = GetTickCount64();
            ulong tick = now - unchecked((uint)now - time);
            if (Record(name, tick, hwnd) && name == "show" && classes[hwnd] == "ConsoleWindowClass") {
                using (var image = new Bitmap(System.Windows.Forms.SystemInformation.VirtualScreen.Width, System.Windows.Forms.SystemInformation.VirtualScreen.Height)) {
                    using (var graphics = Graphics.FromImage(image)) graphics.CopyFromScreen(System.Windows.Forms.SystemInformation.VirtualScreen.Location, Point.Empty, image.Size);
                    image.Save(Path.Combine(directory, "console-" + (++captures).ToString("D6") + "-" + tick + ".png"), ImageFormat.Png);
                }
            }
        } catch (Exception error) { failure = error; log.WriteLine("error\t" + error.GetType().Name); }
    }
    bool Record(string kind, ulong tick, IntPtr hwnd) {
        var name = new StringBuilder(256);
        GetClassName(hwnd, name, name.Capacity);
        string cls = name.ToString();
        if (cls.Length == 0) classes.TryGetValue(hwnd, out cls);
        if (cls != "ZigShell" && cls != "ZigShellChatTranscript" && cls != "ConsoleWindowClass") return false;
        classes[hwnd] = cls;
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        Rect rect;
        GetWindowRect(hwnd, out rect);
        int z = 0;
        for (IntPtr prior = GetWindow(hwnd, 3); prior != IntPtr.Zero && z < 10000; prior = GetWindow(prior, 3)) z++;
        log.WriteLine(String.Join("\t", new object[] { "window", kind, tick, GetTickCount64(), hwnd.ToInt64(), cls, GetParent(hwnd).ToInt64(), GetAncestor(hwnd, 2).ToInt64(), pid, rect.Left, rect.Top, rect.Right, rect.Bottom, IsWindowVisible(hwnd) ? 1 : 0, unchecked((uint)GetWindowLong(hwnd, -16)), z, GetForegroundWindow().ToInt64() }));
        return true;
    }
    public void Dispose() {
        if (disposed) return;
        disposed = true;
        if (worker.IsAlive) {
            if (!PostThreadMessage(threadId, 0x12, UIntPtr.Zero, IntPtr.Zero)) throw new Exception("Native observer stop failed");
            if (!worker.Join(15000)) throw new TimeoutException("Native observer did not stop");
        }
        log.Dispose();
        ready.Dispose();
        GC.KeepAlive(callback);
        if (failure != null) throw new Exception("Native window recording incomplete", failure);
    }
}
