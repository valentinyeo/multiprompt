using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class ChatSwitchObserver {
    public static int SidebarHeaderHeight;
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] struct Data { [FieldOffset(0)] public Mouse Mouse; [FieldOffset(0)] public Keyboard Keyboard; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint Type; public Data Data; }
    [StructLayout(LayoutKind.Sequential)] struct FileTime { public uint Low, High; public ulong Value { get { return ((ulong)High << 32) | Low; } } }
    delegate bool WindowProc(IntPtr window, IntPtr state);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, WindowProc callback, IntPtr state);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out FileTime idle, out FileTime kernel, out FileTime user);
    static double[] SystemTimes() {
        FileTime idle, kernel, user;
        if (!GetSystemTimes(out idle, out kernel, out user)) throw new InvalidOperationException("System CPU counters unavailable");
        return new double[] { idle.Value, kernel.Value + user.Value };
    }
    static IntPtr Transcript(IntPtr owner, int pid) {
        IntPtr found = IntPtr.Zero;
        int count = 0;
        EnumChildWindows(owner, delegate(IntPtr child, IntPtr state) {
            uint actual;
            GetWindowThreadProcessId(child, out actual);
            var name = new StringBuilder(256);
            GetClassName(child, name, name.Capacity);
            if (actual == pid && IsWindowVisible(child) && name.ToString() == "ZigShellChatTranscript") { found = child; count++; }
            return true;
        }, IntPtr.Zero);
        if (count != 1) throw new InvalidOperationException("Expected one visible owned transcript");
        return found;
    }
    static void Capture(IntPtr owner, int pid, string path) {
        IntPtr view = Transcript(owner, pid);
        Rect rect;
        var origin = new Point();
        if (!GetClientRect(view, out rect) || !ClientToScreen(view, ref origin) || rect.Right <= 0 || rect.Bottom <= 0)
            throw new InvalidOperationException("Transcript capture rectangle unavailable");
        using (var bitmap = new Bitmap(rect.Right, rect.Bottom, PixelFormat.Format32bppRgb)) {
            using (var graphics = Graphics.FromImage(bitmap)) graphics.CopyFromScreen(origin.X, origin.Y, 0, 0, bitmap.Size);
            bitmap.Save(path + ".bmp", ImageFormat.Bmp);
            bitmap.Save(path + ".png", ImageFormat.Png);
        }
    }
    public static Dictionary<string, object> Measure(int pid, IntPtr owner, int target, string log, long offset, string needle, int intervalMs, string imagePrefix) {
        uint actual;
        GetWindowThreadProcessId(owner, out actual);
        if (pid <= 0 || actual != pid || GetForegroundWindow() != owner || target < -1 || target > 4)
            throw new InvalidOperationException("Switch observation requires its owned foreground window");
        bool images = !String.IsNullOrEmpty(imagePrefix);
        if (images && target < 0) throw new InvalidOperationException("Image replay needs a real target");
        var points = new List<Dictionary<string, object>>();
        using (var app = Process.GetProcessById(pid))
        using (var observer = Process.GetCurrentProcess()) {
            app.Refresh(); observer.Refresh();
            double appStart = app.TotalProcessorTime.TotalMilliseconds;
            double observerStart = observer.TotalProcessorTime.TotalMilliseconds;
            var systemStart = SystemTimes();
            var clock = Stopwatch.StartNew();
            points.Add(new Dictionary<string, object> { { "elapsed_ms", 0.0 }, { "cpu_ms", 0.0 } });
            if (target >= 0) {
                if (GetDpiForWindow(owner) != 96) throw new InvalidOperationException("Sidebar fixture requires 96 DPI");
                var point = new Point { X = 100, Y = 8 + SidebarHeaderHeight + 24 + 38 * target + 19 };
                if (!ClientToScreen(owner, ref point) || WindowFromPoint(point) != owner || !SetCursorPos(point.X, point.Y))
                    throw new InvalidOperationException("Sidebar row is not in the owned foreground window");
                var inputs = new Input[2];
                inputs[0].Data.Mouse = new Mouse { Flags = 2 };
                inputs[1].Data.Mouse = new Mouse { Flags = 4 };
                if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length)
                    throw new InvalidOperationException("Observed sidebar click SendInput failed");
            }
            long position = offset;
            string carry = "";
            double shown = -1, cpuAtShown = -1, captureStarted = -1, captureCompleted = -1;
            double nextCpu = 25;
            while (clock.Elapsed.TotalMilliseconds < intervalMs) {
                if (target >= 0 && shown < 0) {
                    using (var stream = new FileStream(log, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
                        if (stream.Length < position) throw new InvalidOperationException("Switch log was truncated");
                        if (stream.Length > position) {
                            stream.Seek(position, SeekOrigin.Begin);
                            var bytes = new byte[stream.Length - position];
                            int count = stream.Read(bytes, 0, bytes.Length);
                            position += count;
                            carry += Encoding.UTF8.GetString(bytes, 0, count);
                            if (carry.Contains(needle)) {
                                shown = clock.Elapsed.TotalMilliseconds;
                                app.Refresh();
                                cpuAtShown = app.TotalProcessorTime.TotalMilliseconds - appStart;
                                if (images) {
                                    captureStarted = clock.Elapsed.TotalMilliseconds;
                                    Capture(owner, pid, imagePrefix + "-first-observed");
                                    captureCompleted = clock.Elapsed.TotalMilliseconds;
                                }
                            }
                            if (carry.Length > 4096) carry = carry.Substring(carry.Length - 4096);
                        }
                    }
                }
                if (clock.Elapsed.TotalMilliseconds >= nextCpu) {
                    app.Refresh();
                    points.Add(new Dictionary<string, object> { { "elapsed_ms", clock.Elapsed.TotalMilliseconds }, { "cpu_ms", app.TotalProcessorTime.TotalMilliseconds - appStart } });
                    nextCpu = clock.Elapsed.TotalMilliseconds + 25;
                }
                Thread.Sleep(1);
            }
            app.Refresh(); observer.Refresh();
            double elapsed = clock.Elapsed.TotalMilliseconds;
            double cpu = app.TotalProcessorTime.TotalMilliseconds - appStart;
            var systemEnd = SystemTimes();
            points.Add(new Dictionary<string, object> { { "elapsed_ms", elapsed }, { "cpu_ms", cpu } });
            if (images) Capture(owner, pid, imagePrefix + "-settled");
            return new Dictionary<string, object> {
                { "input", target < 0 ? "idle" : "sidebar-click" }, { "shown_ms", shown }, { "cpu_at_shown_ms", cpuAtShown },
                { "elapsed_ms", elapsed }, { "cpu_ms", cpu }, { "cpu_one_core_percent", 100 * cpu / elapsed },
                { "cpu_points", points }, { "observer_cpu_ms", observer.TotalProcessorTime.TotalMilliseconds - observerStart },
                { "machine_busy_percent", 100 * (1 - (systemEnd[0] - systemStart[0]) / (systemEnd[1] - systemStart[1])) },
                { "forced_paints", false }, { "image_probe", images },
                { "timing_scope", "first nonempty cached target paint; latest-message receipt verified after timing" },
                { "capture_started_ms", captureStarted }, { "capture_completed_ms", captureCompleted },
                { "frame_scope", "first observed after completed target-paint log; not compositor-first-present" }
            };
        }
    }
}
