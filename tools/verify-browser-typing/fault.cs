using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

public sealed class BrowserTypingFault : IDisposable {
    delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] struct KeyEvent { public uint vk, scan, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr hwnd; public uint message; public UIntPtr wp; public IntPtr lp; public uint time; public Point point; public uint privateData; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] struct GuiInfo { public uint size, flags; public IntPtr active, focus, capture, menuOwner, moveSize, caret; public Rect caretRect; }
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetWindowsHookEx(int type, HookProc callback, IntPtr module, uint thread);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll", SetLastError=true)] static extern int GetMessage(out Message message, IntPtr window, uint min, uint max);
    [DllImport("user32.dll")] static extern bool PostThreadMessage(uint thread, uint message, UIntPtr wp, IntPtr lp);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo(uint thread, ref GuiInfo info);
    [DllImport("user32.dll")] static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

    readonly ManualResetEvent ready = new ManualResetEvent(false);
    readonly object sync = new object();
    readonly List<string> events = new List<string>();
    readonly HookProc callback;
    Thread thread;
    IntPtr hook;
    uint threadId;
    volatile bool armed;
    volatile bool down;
    volatile bool dropped;
    Exception failure;

    public BrowserTypingFault() { callback = OnKey; }
    public bool Down { get { return down; } }
    public bool Dropped { get { return dropped; } }
    public string[] Events { get { lock (sync) return events.ToArray(); } }
    public bool AltDown { get { return (GetAsyncKeyState(0x12) & 0x8000) != 0; } }
    public bool CtrlDown { get { return (GetAsyncKeyState(0x11) & 0x8000) != 0; } }
    public static string MenuState(IntPtr window) {
        uint pid;
        uint id = GetWindowThreadProcessId(window, out pid);
        GuiInfo info = new GuiInfo(); info.size = (uint)Marshal.SizeOf(typeof(GuiInfo));
        if (id == 0 || !GetGUIThreadInfo(id, ref info)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return String.Format("flags={0:X} menuOwner={1:X} focus={2:X}", info.flags, info.menuOwner.ToInt64(), info.focus.ToInt64());
    }

    public void Start() {
        thread = new Thread(Pump); thread.IsBackground = true; thread.Start();
        if (!ready.WaitOne(5000)) throw new InvalidOperationException("Keyboard hook message pump did not start");
        if (failure != null) throw new InvalidOperationException("Keyboard hook setup failed", failure);
    }
    void Pump() {
        try {
            threadId = GetCurrentThreadId();
            hook = SetWindowsHookEx(13, callback, GetModuleHandle(null), 0);
            if (hook == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            ready.Set();
            Message msg;
            while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) { }
        } catch (Exception e) { failure = e; ready.Set(); }
        finally { if (hook != IntPtr.Zero) { UnhookWindowsHookEx(hook); hook = IntPtr.Zero; } }
    }
    IntPtr OnKey(int code, IntPtr message, IntPtr data) {
        if (code >= 0 && armed) {
            KeyEvent key = (KeyEvent)Marshal.PtrToStructure(data, typeof(KeyEvent));
            long msg = message.ToInt64();
            if ((key.vk == 0x12 || key.vk == 0xA4 || key.vk == 0xA5) && (key.flags & 0x10) != 0) {
                bool isDown = msg == 0x100 || msg == 0x104;
                bool isUp = msg == 0x101 || msg == 0x105;
                bool suppress = isUp && down && !dropped;
                lock (sync) events.Add(String.Format("vk={0:X} message={1:X} flags={2:X} time={3} extra={4:X} suppressed={5}", key.vk, msg, key.flags, key.time, key.extra.ToUInt64(), suppress));
                if (isDown) down = true;
                if (suppress) { dropped = true; return new IntPtr(1); }
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }
    public void Arm() {
        if (AltDown || CtrlDown) throw new InvalidOperationException("Modifier is already down before fault");
        armed = true;
    }
    public void Disarm() { armed = false; }
    public void Dispose() {
        armed = false;
        if (thread != null && thread.IsAlive) {
            if (!PostThreadMessage(threadId, 0x12, UIntPtr.Zero, IntPtr.Zero) || !thread.Join(5000)) throw new InvalidOperationException("Keyboard hook did not stop");
        }
        if (dropped) keybd_event(0x12, 0, 2, UIntPtr.Zero);
        ready.Dispose();
    }
}
