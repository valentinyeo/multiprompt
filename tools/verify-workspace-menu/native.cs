using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public sealed class WorkspaceMenuProof : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [DllImport("__HASH_DLL__", CallingConvention=CallingConvention.Cdecl)] static extern ulong registryHash(byte[] bytes, UIntPtr length);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW")] static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wp, IntPtr lp, uint flags, uint timeout, out UIntPtr result);
    readonly ManualResetEvent ready = new ManualResetEvent(false);
    readonly ManualResetEvent stop = new ManualResetEvent(false);
    readonly Thread thread;
    Exception failure;
    public string MutexName { get; private set; }

    WorkspaceMenuProof(string path) {
        byte[] bytes = Encoding.UTF8.GetBytes(path);
        MutexName = "Local\\ZigShell-registry-" + registryHash(bytes, new UIntPtr((uint)bytes.Length)).ToString("x");
        thread = new Thread(() => {
            try {
                using (var mutex = new Mutex(false, MutexName)) {
                    if (!mutex.WaitOne(10000)) throw new InvalidOperationException("Registry fixture could not acquire the production mutex");
                    try { ready.Set(); stop.WaitOne(); } finally { mutex.ReleaseMutex(); }
                }
            } catch (Exception error) { failure = error; ready.Set(); }
        });
        thread.IsBackground = true;
        thread.Start();
        if (!ready.WaitOne(12000)) { Dispose(); throw new InvalidOperationException("Registry holder never became ready"); }
        if (failure != null) { Dispose(); throw failure; }
    }

    public static WorkspaceMenuProof HoldRegistry(string path) { return new WorkspaceMenuProof(path); }
    public void Dispose() {
        stop.Set();
        if (!thread.Join(15000)) throw new InvalidOperationException("Registry holder did not stop");
        ready.Dispose();
        stop.Dispose();
    }

    public static IntPtr Card(IntPtr owner) {
        IntPtr card = FindWindowEx(owner, IntPtr.Zero, "MultiPromptWorkspaceSwitcher", "Workspaces");
        return card != IntPtr.Zero && IsWindowVisible(card) ? card : IntPtr.Zero;
    }

    static int Pixel(IntPtr card, int x, int y) {
        Point point = new Point { X = x, Y = y };
        uint pid;
        GetWindowThreadProcessId(card, out pid);
        if (pid == 0 || !ClientToScreen(card, ref point) || WindowFromPoint(point) != card) throw new InvalidOperationException("Menu pixel is not in the visible owned card");
        using (var image = new Bitmap(1, 1))
        using (var graphics = Graphics.FromImage(image)) {
            graphics.CopyFromScreen(point.X, point.Y, 0, 0, image.Size);
            return image.GetPixel(0, 0).ToArgb() & 0xFFFFFF;
        }
    }

    public static bool Highlighted(IntPtr card, int row) {
        return Pixel(card, 12, 6 + row * 28 + 14) != Pixel(card, 2, 6 + row * 28 + 14);
    }

    public static IntPtr WaitPaint(IntPtr owner, uint pid, int selectedRow, int milliseconds) {
        var clock = Stopwatch.StartNew();
        while (clock.ElapsedMilliseconds < milliseconds) {
            IntPtr card = Card(owner);
            uint actual;
            GetWindowThreadProcessId(card, out actual);
            if (card != IntPtr.Zero && actual == pid && GetAncestor(card, 2) == owner && Highlighted(card, selectedRow)) return card;
            Thread.Sleep(1);
        }
        throw new InvalidOperationException("Workspace menu was not visibly painted within 200 ms of the click");
    }

    public static double[] AssertResponsive(IntPtr owner, IntPtr card) {
        var samples = new List<double>();
        var duration = Stopwatch.StartNew();
        while (duration.ElapsedMilliseconds < 1200) {
            var clock = Stopwatch.StartNew();
            UIntPtr result;
            if (Card(owner) != card || SendMessageTimeout(owner, 0, UIntPtr.Zero, IntPtr.Zero, 2, 150, out result) == IntPtr.Zero) throw new InvalidOperationException("App stopped responding while the registry was held");
            samples.Add(clock.Elapsed.TotalMilliseconds);
            if (clock.Elapsed.TotalMilliseconds > 200) throw new InvalidOperationException("Window response exceeded 200 ms");
            Thread.Sleep(20);
        }
        return samples.ToArray();
    }
}
