param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Launch proof requires GitHub Windows' }
$exePath = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$evidencePath = (Resolve-Path $Evidence).Path
$root = Join-Path $env:RUNNER_TEMP ('release-launch-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $root 'roaming'
$env:LOCALAPPDATA = Join-Path $root 'local'
$env:USERPROFILE = Join-Path $root 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:IGSH_246 = '1'
New-Item -ItemType Directory -Force $root, $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
Add-Type -Path tools/verify-chat-delivery/job.cs
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ReleaseWindow {
    public delegate bool EnumProc(IntPtr window, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out Rect rectangle);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rectangle);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
    public static IntPtr Find(uint process) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((window, data) => {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            var name = new StringBuilder(128);
            GetClassName(window, name, name.Capacity);
            Rect client;
            if (owner == process && name.ToString() == "ZigShell" && IsWindowVisible(window) && GetClientRect(window, out client) && client.Right > 0 && client.Bottom > 0) {
                found = window;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@
$eventName = 'Local\MultipromptReleaseLaunch-' + [guid]::NewGuid().ToString('N')
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $eventName)
$job = [VerifyJob]::new()
$process = $null
try {
    $process = $job.Start($exePath, $root, "$evidencePath/stdout.log", "$evidencePath/stderr.log", "--single-window --no-window-restore --update-ready $eventName")
    if (-not $ready.WaitOne(15000)) { throw 'Built app did not become ready' }
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        if ($process.HasExited) { throw "Built app exited with $($process.ExitCode)" }
        $window = [ReleaseWindow]::Find([uint32]$process.Id)
        if ($window -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($window -eq [IntPtr]::Zero) { throw 'Built app did not show its main window' }
    Start-Sleep -Seconds 2
    if ($process.HasExited -or [ReleaseWindow]::Find([uint32]$process.Id) -ne $window) { throw 'Main window closed after launch' }
    $response = [IntPtr]::Zero
    if ([ReleaseWindow]::SendMessageTimeout($window, 0, [IntPtr]::Zero, [IntPtr]::Zero, 2, 2000, [ref]$response) -eq [IntPtr]::Zero) { throw 'Main window is unresponsive' }
    $rectangle = New-Object ReleaseWindow+Rect
    if (-not [ReleaseWindow]::GetWindowRect($window, [ref]$rectangle)) { throw 'Main window bounds unavailable' }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $dc = $graphics.GetHdc()
        try { if (-not [ReleaseWindow]::PrintWindow($window, $dc, 2)) { throw 'Main window capture failed' } }
        finally { $graphics.ReleaseHdc($dc) }
        $bitmap.Save("$evidencePath/main-window.png", [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    @{
        tag = $env:RELEASE_TAG
        sha = $env:SOURCE_SHA
        executableSha256 = (Get-FileHash $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
        pid = $process.Id
        windowClass = 'ZigShell'
        visible = $true
        responsive = $true
        width = $width
        height = $height
    } | ConvertTo-Json | Set-Content -Encoding UTF8 "$evidencePath/launch.json"
} finally {
    $stopped = $job.Stop()
    $job.Dispose()
    $ready.Dispose()
    if ($null -ne $process) { $process.Dispose() }
    if ($stopped.ActiveProcesses -ne 0) { throw 'Launch proof left owned processes' }
}
