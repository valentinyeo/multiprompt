using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RoomsDesktop {
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll")] static extern bool IsChild(IntPtr main, IntPtr child);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    public static void Wheel(IntPtr main, IntPtr room, uint pid, int delta) {
        uint owner, parentOwner;
        GetWindowThreadProcessId(room, out owner);
        GetWindowThreadProcessId(main, out parentOwner);
        var name = new StringBuilder(256);
        GetClassName(room, name, name.Capacity);
        Rect rect;
        if (owner != pid || parentOwner != pid || !IsChild(main, room) || GetForegroundWindow() != main ||
            name.ToString() != "MultiPromptRoomView" || !GetWindowRect(room, out rect)) throw new InvalidOperationException("Room wheel ownership mismatch");
        var point = new Point { X = (rect.Left + rect.Right) / 2, Y = rect.Top + (rect.Bottom - rect.Top) / 3 };
        if (WindowFromPoint(point) != room || !SetCursorPos(point.X, point.Y)) throw new InvalidOperationException("Room wheel target is covered");
        mouse_event(0x0800, 0, 0, unchecked((uint)delta), UIntPtr.Zero);
    }
}
