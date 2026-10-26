using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
public sealed class RemoteSwitchFrames : IDisposable {
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool InvalidateRect(IntPtr hwnd, IntPtr rect, bool erase);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr CreateWaitableTimerEx(IntPtr attributes, string name, uint flags, uint access);
    [DllImport("kernel32.dll")] static extern bool SetWaitableTimer(IntPtr timer, ref long due, int period, IntPtr completion, IntPtr argument, bool resume);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint timeout);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    public sealed class Frame { public double completedMs, gapMs, paintMs; public bool painted; }
    readonly IntPtr view;
    readonly Thread thread;
    readonly Stopwatch clock = new Stopwatch();
    readonly List<Frame> frames = new List<Frame>();
    IntPtr timer;
    Exception failure;
    volatile bool stopped;
    public RemoteSwitchFrames(IntPtr view, uint pid) {
        uint owner;
        GetWindowThreadProcessId(view, out owner);
        if (owner != pid || pid == 0) throw new InvalidOperationException("Frame window owner mismatch");
        this.view = view;
        timer = CreateWaitableTimerEx(IntPtr.Zero, null, 2, 0x00100002);
        if (timer == IntPtr.Zero) throw new InvalidOperationException("High-resolution frame timer unavailable");
        thread = new Thread(Run) { IsBackground = true };
        clock.Start();
        thread.Start();
    }
    void Run() {
        try {
            double last = 0;
            while (!stopped) {
                double start = clock.Elapsed.TotalMilliseconds;
                IntPtr result;
                bool painted = InvalidateRect(view, IntPtr.Zero, false) && SendMessageTimeout(view, 0x000F, IntPtr.Zero, IntPtr.Zero, 2, 1000, out result) != IntPtr.Zero;
                double completed = clock.Elapsed.TotalMilliseconds;
                lock (frames) frames.Add(new Frame { completedMs = completed, gapMs = completed - last, paintMs = completed - start, painted = painted });
                last = completed;
                double remaining = start + 16 - clock.Elapsed.TotalMilliseconds;
                if (remaining > 0) {
                    long due = -(long)Math.Ceiling(remaining * 10000);
                    if (!SetWaitableTimer(timer, ref due, 0, IntPtr.Zero, IntPtr.Zero, false) || WaitForSingleObject(timer, 1000) != 0) throw new InvalidOperationException("Frame timer failed");
                }
            }
        } catch (Exception error) { failure = error; }
    }
    public double ElapsedMs { get { return clock.Elapsed.TotalMilliseconds; } }
    public Frame[] Finish() {
        stopped = true;
        if (!thread.Join(1500)) throw new InvalidOperationException("Frame sampler did not stop");
        clock.Stop();
        if (timer != IntPtr.Zero) { CloseHandle(timer); timer = IntPtr.Zero; }
        if (failure != null) throw new InvalidOperationException("Frame sampler failed", failure);
        lock (frames) return frames.ToArray();
    }
    public void Dispose() { Finish(); }
}
