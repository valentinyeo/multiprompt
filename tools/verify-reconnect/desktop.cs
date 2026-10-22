using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ReconnectDesktop {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct GUI { public uint cbSize, flags; public IntPtr active, focus, capture, menu, move, caret; public RECT caretRect; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public UNION data; }
    [StructLayout(LayoutKind.Explicit)] public struct UNION { [FieldOffset(0)] public MOUSE mouse; [FieldOffset(0)] public KEY key; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSE { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEY { public ushort vk, scan; public uint flags, time; public UIntPtr extra; }
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc fn, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc fn, IntPtr p);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError=true)] public static extern bool GetGUIThreadInfo(uint thread, ref GUI info);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT rect);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder text, int max);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, INPUT[] inputs, int size);
    public static uint Owner(IntPtr h) { uint pid; GetWindowThreadProcessId(h,out pid); return pid; }
    public static string Class(IntPtr h) { var s=new StringBuilder(256); GetClassName(h,s,256); return s.ToString(); }
    public static IntPtr Window(uint pid) { IntPtr found=IntPtr.Zero; EnumWindows((h,p)=>{ uint owner; GetWindowThreadProcessId(h,out owner); if(owner==pid && IsWindowVisible(h) && Class(h)!="ConsoleWindowClass") { found=h; return false; } return true; },IntPtr.Zero); return found; }
    public static IntPtr InputSurface(IntPtr parent) { IntPtr found=IntPtr.Zero; EnumChildWindows(parent,(h,p)=>{ if(Class(h)=="ConsoleWindowClass" && IsWindowVisible(h)) { found=h; return false; } return true; },IntPtr.Zero); return found; }
    public static long[] Focus(IntPtr main) { uint pid; uint thread=GetWindowThreadProcessId(main,out pid); var g=new GUI(); g.cbSize=(uint)Marshal.SizeOf<GUI>(); if(!GetGUIThreadInfo(thread,ref g)) throw new Exception("GetGUIThreadInfo failed"); return new[]{GetForegroundWindow().ToInt64(),g.focus.ToInt64(),g.active.ToInt64()}; }
    static void Send(INPUT i) { if(SendInput(1,new[]{i},Marshal.SizeOf<INPUT>())!=1) throw new Exception("SendInput failed"); }
    public static void Key(ushort vk,bool up) { var i=new INPUT(); i.type=1; i.data.key.vk=vk; i.data.key.flags=up?2u:0u; Send(i); System.Threading.Thread.Sleep(80); }
    public static void Activate(IntPtr h) { Key(0x12,false); Key(0x12,true); if(!SetForegroundWindow(h)) throw new Exception("Could not activate app window"); RECT r; GetWindowRect(h,out r); MouseAt(r.Left+Math.Min(300,(r.Right-r.Left)/2),r.Top+12); }
    static void MouseAt(int x,int y) { var i=new INPUT(); i.data.mouse.x=x*65535/(GetSystemMetrics(0)-1); i.data.mouse.y=y*65535/(GetSystemMetrics(1)-1); i.data.mouse.flags=0x8003; Send(i); i.data.mouse.flags=0x8005; Send(i); }
    public static void Click(IntPtr h) { RECT r; if(!GetWindowRect(h,out r)) throw new Exception("Missing click rect"); var i=new INPUT(); i.data.mouse.x=(r.Left+(r.Right-r.Left)/2)*65535/(GetSystemMetrics(0)-1); i.data.mouse.y=(r.Top+(r.Bottom-r.Top)/2)*65535/(GetSystemMetrics(1)-1); i.data.mouse.flags=0x8003; Send(i); i.data.mouse.flags=0x8005; Send(i); }
}
