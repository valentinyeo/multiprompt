using System;
using System.Runtime.InteropServices;

public static class CaptionProof {
    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint paths, out uint modes);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint paths, IntPtr path, ref uint modes, IntPtr mode, IntPtr topology);
    [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(IntPtr packet);
    [DllImport("user32.dll")] static extern int DisplayConfigSetDeviceInfo(IntPtr packet);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern uint GetDpiForSystem();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string device, int mode, IntPtr settings);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int ChangeDisplaySettings(IntPtr settings, uint flags);
    static byte[] originalDisplay;
    static byte[] source;
    static int originalRelative, recommendedIndex;
    static bool originalKnown;
    static readonly int[] scales = { 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500 };
    static void Require(bool value, string detail) {
        if (!value) throw new InvalidOperationException("IGSH-845 " + detail);
    }
    static IntPtr Packet(int type, int size) {
        IntPtr packet = Marshal.AllocHGlobal(size);
        for (int i = 0; i < size; i++) Marshal.WriteByte(packet, i, 0);
        Marshal.WriteInt32(packet, 0, type);
        Marshal.WriteInt32(packet, 4, size);
        Marshal.Copy(source, 0, IntPtr.Add(packet, 8), 12);
        return packet;
    }
    public static void SetDpi(int dpi) {
        Require(SetThreadDpiAwarenessContext(new IntPtr(-4)) != IntPtr.Zero, "per-monitor awareness unavailable");
        IntPtr settings = Marshal.AllocHGlobal(220);
        try {
            for (int i = 0; i < 220; i++) Marshal.WriteByte(settings, i, 0);
            Marshal.WriteInt16(settings, 68, 220);
            Require(EnumDisplaySettings(null, -1, settings), "current display mode unavailable");
            originalDisplay = new byte[220];
            Marshal.Copy(settings, originalDisplay, 0, 220);
            if (Marshal.ReadInt32(settings, 172) < 1920 || Marshal.ReadInt32(settings, 176) < 1080) {
                Marshal.WriteInt32(settings, 72, 0x180000);
                Marshal.WriteInt32(settings, 172, 1920);
                Marshal.WriteInt32(settings, 176, 1080);
                Require(ChangeDisplaySettings(settings, 0) == 0, "1920x1080 disposable display mode unavailable");
            }
        } finally { Marshal.FreeHGlobal(settings); }
        uint paths, modes;
        Require(GetDisplayConfigBufferSizes(2, out paths, out modes) == 0 && paths > 0, "display paths unavailable");
        IntPtr path = Marshal.AllocHGlobal((int)paths * 72), mode = Marshal.AllocHGlobal((int)modes * 64);
        try {
            Require(QueryDisplayConfig(2, ref paths, path, ref modes, mode, IntPtr.Zero) == 0 && paths == 1, "requires one active disposable runner display");
            source = new byte[12];
            Marshal.Copy(path, source, 0, 12);
        } finally { Marshal.FreeHGlobal(path); Marshal.FreeHGlobal(mode); }
        IntPtr get = Packet(-3, 32);
        try {
            Require(DisplayConfigGetDeviceInfo(get) == 0, "monitor DPI query unsupported");
            originalRelative = Marshal.ReadInt32(get, 24);
            originalKnown = true;
            int current = Array.IndexOf(scales, (int)GetDpiForSystem() * 100 / 96);
            Require(current >= 0, "unrecognized initial DPI");
            recommendedIndex = current - originalRelative;
            int desired = Array.IndexOf(scales, dpi * 100 / 96) - recommendedIndex;
            Require(Array.IndexOf(scales, dpi * 100 / 96) >= 0 && desired >= Marshal.ReadInt32(get, 20) && desired <= Marshal.ReadInt32(get, 28), "requested real monitor DPI unavailable");
            SetRelative(desired);
        } finally { Marshal.FreeHGlobal(get); }
    }
    static void SetRelative(int relative) {
        IntPtr packet = Packet(-4, 24);
        try {
            Marshal.WriteInt32(packet, 20, relative);
            Require(DisplayConfigSetDeviceInfo(packet) == 0, "monitor DPI change failed");
        } finally { Marshal.FreeHGlobal(packet); }
    }
    public static void RestoreDpi() {
        try { if (originalKnown) SetRelative(originalRelative); }
        finally {
            if (originalDisplay != null) {
                IntPtr settings = Marshal.AllocHGlobal(originalDisplay.Length);
                try {
                    Marshal.Copy(originalDisplay, 0, settings, originalDisplay.Length);
                    Require(ChangeDisplaySettings(settings, 0) == 0, "original display mode restore failed");
                } finally { Marshal.FreeHGlobal(settings); }
            }
        }
    }
}
