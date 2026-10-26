using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
public sealed class RemoteSwitchFrames : IDisposable {
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool InvalidateRect(IntPtr hwnd, IntPtr rect, bool erase);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    public sealed class Frame { public double completedMs, gapMs, paintMs; public bool painted; }
    readonly IntPtr view;
    readonly Thread thread;
    readonly Stopwatch clock = new Stopwatch();
    readonly List<Frame> frames = new List<Frame>();
    volatile bool stopped;
    public RemoteSwitchFrames(IntPtr view, uint pid) {
        uint owner;
        GetWindowThreadProcessId(view, out owner);
        if (owner != pid || pid == 0) throw new InvalidOperationException("Frame window owner mismatch");
        this.view = view;
        thread = new Thread(Run) { IsBackground = true };
        clock.Start();
        thread.Start();
    }
    void Run() {
        double last = 0;
        while (!stopped) {
            double start = clock.Elapsed.TotalMilliseconds;
            IntPtr result;
            bool painted = InvalidateRect(view, IntPtr.Zero, false) && SendMessageTimeout(view, 0x000F, IntPtr.Zero, IntPtr.Zero, 2, 1000, out result) != IntPtr.Zero;
            double completed = clock.Elapsed.TotalMilliseconds;
            lock (frames) frames.Add(new Frame { completedMs = completed, gapMs = completed - last, paintMs = completed - start, painted = painted });
            last = completed;
            Thread.Sleep(16);
        }
    }
    public double ElapsedMs { get { return clock.Elapsed.TotalMilliseconds; } }
    public Frame[] Finish() {
        stopped = true;
        if (!thread.Join(1500)) throw new InvalidOperationException("Frame sampler did not stop");
        clock.Stop();
        lock (frames) return frames.ToArray();
    }
    public void Dispose() { Finish(); }
}
