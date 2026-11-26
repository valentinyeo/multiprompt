using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class RoomsDesktop {
    [StructLayout(LayoutKind.Sequential)] public struct Frame {
        public int Left, Top, Right, Bottom;
        public int Width { get { return Right - Left; } }
        public int Height { get { return Bottom - Top; } }
    }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    public delegate bool EnumProc(IntPtr hwnd, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Frame rect);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll")] static extern bool IsChild(IntPtr main, IntPtr child);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    static bool OnScreenFrame(int left, int top, int right, int bottom) {
        return right > left && bottom > top && left < GetSystemMetrics(0) && top < GetSystemMetrics(1) && right > 0 && bottom > 0;
    }
    public static bool OnScreen(IntPtr hwnd) {
        Frame rect;
        return IsWindow(hwnd) && IsWindowVisible(hwnd) && GetWindowRect(hwnd, out rect) && OnScreenFrame(rect.Left, rect.Top, rect.Right, rect.Bottom);
    }
    public static Frame Bounds(IntPtr hwnd) {
        Frame rect;
        if (!IsWindow(hwnd) || !GetWindowRect(hwnd, out rect) || rect.Right <= rect.Left || rect.Bottom <= rect.Top) throw new InvalidOperationException("Window bounds are unavailable");
        return rect;
    }
    public static bool Responding(IntPtr hwnd, int milliseconds) {
        IntPtr result;
        return IsWindow(hwnd) && SendMessageTimeout(hwnd, 0x0000, IntPtr.Zero, IntPtr.Zero, 3, (uint)milliseconds, out result) != IntPtr.Zero;
    }
    public static IntPtr[] Children(IntPtr parent, string className) {
        var found = new List<IntPtr>();
        var name = new StringBuilder(256);
        EnumChildWindows(parent, (h, p) => {
            name.Length = 0;
            GetClassName(h, name, name.Capacity);
            if (name.ToString() == className && OnScreen(h)) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
    public static void Wheel(IntPtr main, IntPtr room, uint pid, int delta) {
        uint owner, parentOwner;
        GetWindowThreadProcessId(room, out owner);
        GetWindowThreadProcessId(main, out parentOwner);
        var name = new StringBuilder(256);
        GetClassName(room, name, name.Capacity);
        Frame rect;
        if (owner != pid || parentOwner != pid || !IsChild(main, room) || GetForegroundWindow() != main ||
            name.ToString() != "MultiPromptRoomView" || !GetWindowRect(room, out rect)) throw new InvalidOperationException("Room wheel ownership mismatch");
        var point = new Point { X = (rect.Left + rect.Right) / 2, Y = rect.Top + (rect.Bottom - rect.Top) / 3 };
        if (WindowFromPoint(point) != room || !SetCursorPos(point.X, point.Y)) throw new InvalidOperationException("Room wheel target is covered");
        mouse_event(0x0800, 0, 0, unchecked((uint)delta), UIntPtr.Zero);
    }
}
