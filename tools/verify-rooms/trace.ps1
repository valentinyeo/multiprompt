param([Parameter(Mandatory)][int]$ProcessId, [Parameter(Mandatory)][long]$Window, [Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or [IntPtr]::Size -ne 8) { throw 'Hosted x64 Windows only' }
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
public static class RoomOwnedTrace {
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenThread(uint access, bool inherit, uint tid);
    [DllImport("kernel32.dll")] static extern uint SuspendThread(IntPtr thread);
    [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] static extern bool GetThreadContext(IntPtr thread, IntPtr context);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] data, UIntPtr count, out UIntPtr read);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    public static object[] Capture(int pid, long hwnd, string exe) {
        var process = Process.GetProcessById(pid);
        uint owner;
        uint main = GetWindowThreadProcessId(new IntPtr(hwnd), out owner);
        if (owner != pid || main == 0 || !String.Equals(process.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Owned app identity changed");
        var modules = new List<ProcessModule>();
        foreach (ProcessModule module in process.Modules) modules.Add(module);
        ulong appBase = (ulong)process.MainModule.BaseAddress.ToInt64();
        ulong appSize = (ulong)process.MainModule.ModuleMemorySize;
        IntPtr handle = OpenProcess(0x410, false, (uint)pid);
        if (handle == IntPtr.Zero) throw new InvalidOperationException("Owned app cannot be read");
        var rows = new List<object>();
        try {
            foreach (ProcessThread entry in process.Threads) {
                IntPtr thread = OpenThread(0x4a, false, (uint)entry.Id);
                if (thread == IntPtr.Zero) continue;
                IntPtr memory = Marshal.AllocHGlobal(1248);
                IntPtr context = new IntPtr((memory.ToInt64() + 15) & ~15L);
                bool suspended = false;
                try {
                    Marshal.Copy(new byte[1232], 0, context, 1232);
                    Marshal.WriteInt32(context, 48, 0x100003);
                    if (SuspendThread(thread) == UInt32.MaxValue) continue;
                    suspended = true;
                    if (!GetThreadContext(thread, context)) continue;
                    ulong ip = (ulong)Marshal.ReadInt64(context, 248);
                    long sp = Marshal.ReadInt64(context, 152);
                    byte[] stack = new byte[8192];
                    UIntPtr read;
                    ReadProcessMemory(handle, new IntPtr(sp), stack, new UIntPtr((uint)stack.Length), out read);
                    ResumeThread(thread);
                    suspended = false;
                    string moduleName = "unavailable", ipRva = "unavailable";
                    foreach (var module in modules) {
                        ulong start = (ulong)module.BaseAddress.ToInt64();
                        if (ip >= start && ip - start < (ulong)module.ModuleMemorySize) {
                            string name = module.ModuleName.ToLowerInvariant();
                            if (name == "multiprompt.exe" || name == "ntdll.dll" || name == "kernelbase.dll" || name == "kernel32.dll" || name == "user32.dll" || name == "win32u.dll" || name == "gdi32.dll" || name == "gdi32full.dll" || name == "dwrite.dll") {
                                moduleName = name;
                                ipRva = "0x" + (ip - start).ToString("x");
                            }
                            break;
                        }
                    }
                    var frames = new List<string>();
                    if (ip >= appBase && ip - appBase < appSize) frames.Add("0x" + (ip - appBase).ToString("x"));
                    int count = (int)Math.Min((ulong)stack.Length, read.ToUInt64());
                    for (int offset = 0; offset + 8 <= count && frames.Count < 24; offset += 8) {
                        ulong address = BitConverter.ToUInt64(stack, offset);
                        if (address >= appBase && address - appBase < appSize) frames.Add("0x" + (address - appBase).ToString("x"));
                    }
                    rows.Add(new { thread = entry.Id, main = (uint)entry.Id == main, module = moduleName, instruction_rva = ipRva, app_stack_rvas = frames.ToArray() });
                } finally {
                    if (suspended) ResumeThread(thread);
                    Marshal.FreeHGlobal(memory);
                    CloseHandle(thread);
                }
            }
        } finally { CloseHandle(handle); process.Dispose(); }
        return rows.ToArray();
    }
}
'@
$frames = [RoomOwnedTrace]::Capture($ProcessId, $Window, (Resolve-Path $Exe).Path)
[IO.File]::WriteAllText($Output, (ConvertTo-Json -InputObject @($frames) -Depth 6), [Text.UTF8Encoding]::new($false))
