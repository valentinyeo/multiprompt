fn browserLaunchWorker(exe: [320]u16, params: [2048]u16) void {
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    defer if (co >= 0) CoUninitialize();
    _ = ShellExecuteW(null, L("open"), @ptrCast(&exe), @ptrCast(&params), null, SW_SHOWNOACTIVATE);
}
