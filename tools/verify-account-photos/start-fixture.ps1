$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
if (!$env:PHOTO_PROOF_CREDENTIAL) { throw 'Missing fixture credential' }
$config = $env:PHOTO_PROOF_CREDENTIAL | ConvertFrom-Json
foreach ($name in @('account_id', 'desktop_device_id', 'android_device_id', 'desktop_refresh_token', 'android_refresh_token')) {
    $value = [string]$config.$name
    if (!$value -or $value -match '[\r\n]') { throw 'Invalid fixture credential' }
    Write-Output ('::add-mask::' + $value.Replace('%', '%25'))
}
if ($config.account_id -cne 'journey@example.com' -or $config.desktop_device_id -cne 'journey-device' -or $config.android_device_id -cne 'journey-device-b' -or $config.desktop_refresh_token -ceq $config.android_refresh_token) { throw 'Unexpected fixture identity' }
$work = Join-Path $env:RUNNER_TEMP 'account-photo-fixture'
if (Test-Path $work) { throw 'Fixture directory already exists' }
New-Item -ItemType Directory $work | Out-Null
$configPath = Join-Path $work 'credential.json'
[IO.File]::WriteAllText($configPath, $env:PHOTO_PROOF_CREDENTIAL, [Text.UTF8Encoding]::new($false))
Remove-Item Env:PHOTO_PROOF_CREDENTIAL
$config = $null
$statePath = Join-Path $work 'processes.json'
$owned = [Collections.Generic.List[object]]::new()
function Save-Process($Process, [string]$ExpectedPath) {
    $Process.Refresh()
    $owned.Add([ordered]@{ pid = $Process.Id; path = $ExpectedPath; started = $Process.StartTime.ToUniversalTime().Ticks })
    [IO.File]::WriteAllText($statePath, (ConvertTo-Json -InputObject @($owned.ToArray()) -Compress), [Text.UTF8Encoding]::new($false))
}
$cloudflared = Join-Path $work 'cloudflared.exe'
Invoke-WebRequest 'https://github.com/cloudflare/cloudflared/releases/download/2026.10.7/cloudflared-windows-amd64.exe' -OutFile $cloudflared
if ((Get-FileHash $cloudflared -Algorithm SHA256).Hash.ToLowerInvariant() -cne '2493dbc168923bb3e59e5e7716f71deced92992eea9acd6e9d74f84ac7751343') { throw 'Cloudflared checksum mismatch' }
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class FixtureProcess {
    [StructLayout(LayoutKind.Sequential)]
    struct SecurityAttributes { public int Length; public IntPtr SecurityDescriptor; public int InheritHandle; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct StartupInfo {
        public int cb; public string reserved, desktop, title;
        public int x, y, xSize, ySize, xCountChars, yCountChars, fillAttribute, flags;
        public short showWindow, reserved2; public IntPtr reservedPtr, stdInput, stdOutput, stdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct StartupInfoEx { public StartupInfo startup; public IntPtr attributes; }
    [StructLayout(LayoutKind.Sequential)]
    struct ProcessInformation { public IntPtr process, thread; public int processId, threadId; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateFile(string name, uint access, uint share, ref SecurityAttributes security, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateProcess(string application, StringBuilder command, IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string directory, ref StartupInfoEx startup, out ProcessInformation process);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool InitializeProcThreadAttributeList(IntPtr attributes, int count, int flags, ref IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool UpdateProcThreadAttribute(IntPtr attributes, uint flags, IntPtr attribute, IntPtr value, IntPtr size, IntPtr previous, IntPtr returnSize);
    [DllImport("kernel32.dll")]
    static extern void DeleteProcThreadAttributeList(IntPtr attributes);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    public static Process Start(string executable, string arguments, string stdout, string stderr) {
        var security = new SecurityAttributes { Length = Marshal.SizeOf<SecurityAttributes>(), InheritHandle = 1 };
        IntPtr input = IntPtr.Zero, output = IntPtr.Zero, error = IntPtr.Zero;
        IntPtr attributes = IntPtr.Zero, handles = IntPtr.Zero;
        bool attributesInitialized = false;
        try {
            input = CreateFile("NUL", 0x80000000, 3, ref security, 3, 0, IntPtr.Zero);
            if (input == new IntPtr(-1)) throw new Win32Exception();
            output = CreateFile(stdout, 0x40000000, 3, ref security, 2, 0, IntPtr.Zero);
            if (output == new IntPtr(-1)) throw new Win32Exception();
            error = CreateFile(stderr, 0x40000000, 3, ref security, 2, 0, IntPtr.Zero);
            if (error == new IntPtr(-1)) throw new Win32Exception();
            IntPtr size = IntPtr.Zero;
            InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
            if (size == IntPtr.Zero) throw new Win32Exception();
            attributes = Marshal.AllocHGlobal(size);
            if (!InitializeProcThreadAttributeList(attributes, 1, 0, ref size)) throw new Win32Exception();
            attributesInitialized = true;
            handles = Marshal.AllocHGlobal(3 * IntPtr.Size);
            Marshal.Copy(new[] { input, output, error }, 0, handles, 3);
            if (!UpdateProcThreadAttribute(attributes, 0, new IntPtr(0x20002), handles, new IntPtr(3 * IntPtr.Size), IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
            var startup = new StartupInfoEx {
                startup = new StartupInfo { cb = Marshal.SizeOf<StartupInfoEx>(), flags = 0x101, showWindow = 0, stdInput = input, stdOutput = output, stdError = error },
                attributes = attributes
            };
            ProcessInformation info;
            if (!CreateProcess(executable, new StringBuilder("\"" + executable + "\" " + arguments), IntPtr.Zero, IntPtr.Zero, true, 0x00080010, IntPtr.Zero, null, ref startup, out info)) throw new Win32Exception();
            try { return Process.GetProcessById(info.processId); }
            finally { CloseHandle(info.thread); CloseHandle(info.process); }
        } finally {
            if (attributesInitialized) DeleteProcThreadAttributeList(attributes);
            if (handles != IntPtr.Zero) Marshal.FreeHGlobal(handles);
            if (attributes != IntPtr.Zero) Marshal.FreeHGlobal(attributes);
            if (input != IntPtr.Zero && input != new IntPtr(-1)) CloseHandle(input);
            if (output != IntPtr.Zero && output != new IntPtr(-1)) CloseHandle(output);
            if (error != IntPtr.Zero && error != new IntPtr(-1)) CloseHandle(error);
        }
    }
}
'@
$nodePath = (Get-Command node -CommandType Application | Select-Object -First 1).Source
$serverPath = (Resolve-Path 'service/journey/server.mjs').Path
$server = [FixtureProcess]::Start($nodePath, ('"' + $serverPath + '" --port=18787 --bind=127.0.0.1 --config="' + $configPath + '"'), (Join-Path $work 'service.out'), (Join-Path $work 'service.err'))
Save-Process $server $nodePath
$timer = [Diagnostics.Stopwatch]::StartNew()
do {
    if ($server.HasExited) { throw 'Fixture exited during startup' }
    if ((Test-Path (Join-Path $work 'service.out')) -and (Get-Content (Join-Path $work 'service.out') -Raw) -match 'journey service ready') { break }
    Start-Sleep -Seconds 1
} while ($timer.Elapsed.TotalSeconds -lt 90)
if ($timer.Elapsed.TotalSeconds -ge 90) { throw 'Fixture startup timed out' }
$tunnel = [FixtureProcess]::Start($cloudflared, 'tunnel --no-autoupdate --protocol http2 --url http://127.0.0.1:18787', (Join-Path $work 'tunnel.out'), (Join-Path $work 'tunnel.err'))
Save-Process $tunnel $cloudflared
$timer.Restart()
$endpoint = $null
do {
    if ($tunnel.HasExited -or $server.HasExited) { throw 'Fixture or tunnel exited during startup' }
    $log = Get-Content (Join-Path $work 'tunnel.err') -Raw -ErrorAction SilentlyContinue
    if ($log) {
        $match = [regex]::Match($log, 'https://[a-z0-9-]+\.trycloudflare\.com')
        if ($match.Success) { $endpoint = $match.Value; break }
    }
    Start-Sleep -Seconds 1
} while ($timer.Elapsed.TotalSeconds -lt 120)
if (!$endpoint) { throw 'Tunnel endpoint timed out' }
New-Item -ItemType Directory -Force 'picture-endpoint' | Out-Null
[IO.File]::WriteAllText((Join-Path $PWD 'picture-endpoint/endpoint.txt'), $endpoint, [Text.UTF8Encoding]::new($false))
