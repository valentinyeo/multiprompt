using System;
using System.Runtime.InteropServices;

public static class ProviderBadgeInput {
    [StructLayout(LayoutKind.Sequential)]
    struct Input {
        public uint Type;
        public Union Data;
    }
    [StructLayout(LayoutKind.Explicit)]
    struct Union {
        [FieldOffset(0)] public Keyboard Keyboard;
        [FieldOffset(0)] public Mouse Mouse;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct Keyboard {
        public ushort Key;
        public ushort Scan;
        public uint Flags;
        public uint Time;
        public IntPtr Extra;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct Mouse {
        public int X;
        public int Y;
        public uint Data;
        public uint Flags;
        public uint Time;
        public IntPtr Extra;
    }
    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")]
    static extern bool SetCursorPos(int x, int y);

    public static void Control(bool down) {
        var inputs = new Input[1];
        inputs[0].Type = 1;
        inputs[0].Data.Keyboard.Key = 0x11;
        inputs[0].Data.Keyboard.Flags = down ? 0u : 2u;
        if (SendInput(1, inputs, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("SendInput failed for Control");
    }

    public static void Move(int x, int y) {
        SetCursorPos(x - 3, y - 3);
        SetCursorPos(x, y);
    }
}
