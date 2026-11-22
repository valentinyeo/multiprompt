$ErrorActionPreference = 'Stop'
$ssh = "$env:SystemRoot\System32\OpenSSH\ssh.exe"
$keygen = "$env:SystemRoot\System32\OpenSSH\ssh-keygen.exe"
& $ssh -V

$capability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -First 1
if ($capability.State -ne 'Installed') { Add-WindowsCapability -Online -Name $capability.Name | Out-Null }
Start-Service sshd

$work = Join-Path $env:RUNNER_TEMP 'ssh-detached'
New-Item -ItemType Directory -Force $work | Out-Null
$key = Join-Path $work 'id_ed25519'
& $keygen -q -t ed25519 -N '' -f $key
if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed' }
$authorized = "$env:ProgramData\ssh\administrators_authorized_keys"
Copy-Item "$key.pub" $authorized -Force
icacls $authorized /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
$config = Join-Path $work 'config'
@(
  'Host proof',
  '  HostName 127.0.0.1',
  "  User $env:USERNAME",
  "  IdentityFile $key",
  '  IdentitiesOnly yes',
  '  StrictHostKeyChecking no',
  "  UserKnownHostsFile $work\known_hosts",
  '  BatchMode yes'
) | Set-Content -Encoding ascii $config
$warm = & $ssh -F $config proof echo warm-ok
if ("$warm" -notmatch 'warm-ok') { throw "sshd is not reachable: $warm" }

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class SshSpawn {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct STARTUPINFO { public int cb; public string lpReserved; public string lpDesktop; public string lpTitle; public int dwX; public int dwY; public int dwXSize; public int dwYSize; public int dwXCountChars; public int dwYCountChars; public int dwFillAttribute; public int dwFlags; public short wShowWindow; public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError; }
  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }
  [StructLayout(LayoutKind.Sequential)]
  struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public int bInheritHandle; }
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  static extern bool CreateProcessW(string app, System.Text.StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern bool CreatePipe(out IntPtr read, out IntPtr write, ref SECURITY_ATTRIBUTES sa, int size);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern bool SetHandleInformation(IntPtr handle, int mask, int flags);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern uint WaitForSingleObject(IntPtr handle, uint ms);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
  [DllImport("kernel32.dll", SetLastError = true)]
  static extern bool TerminateProcess(IntPtr handle, uint code);
  public class Child { public int Pid; public IntPtr Process; public FileStream Input; public FileStream Output; }
  public static Child Start(string cmd, uint flags, bool pipes) {
    STARTUPINFO si = new STARTUPINFO();
    si.cb = Marshal.SizeOf(si);
    IntPtr inRead = IntPtr.Zero, inWrite = IntPtr.Zero, outRead = IntPtr.Zero, outWrite = IntPtr.Zero;
    if (pipes) {
      SECURITY_ATTRIBUTES sa = new SECURITY_ATTRIBUTES();
      sa.nLength = Marshal.SizeOf(sa);
      sa.bInheritHandle = 1;
      if (!CreatePipe(out inRead, out inWrite, ref sa, 0) || !CreatePipe(out outRead, out outWrite, ref sa, 1 << 20)) throw new System.ComponentModel.Win32Exception();
      SetHandleInformation(inWrite, 1, 0);
      SetHandleInformation(outRead, 1, 0);
      si.dwFlags = 0x100;
      si.hStdInput = inRead;
      si.hStdOutput = outWrite;
      si.hStdError = outWrite;
    }
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(null, new System.Text.StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, pipes, flags, IntPtr.Zero, null, ref si, out pi)) throw new System.ComponentModel.Win32Exception();
    CloseHandle(pi.hThread);
    Child child = new Child();
    child.Pid = pi.dwProcessId;
    child.Process = pi.hProcess;
    if (pipes) {
      CloseHandle(inRead);
      CloseHandle(outWrite);
      child.Input = new FileStream(new SafeFileHandle(inWrite, true), FileAccess.Write);
      child.Output = new FileStream(new SafeFileHandle(outRead, true), FileAccess.Read);
    }
    return child;
  }
  public static bool Alive(Child child) { return WaitForSingleObject(child.Process, 0) == 0x102; }
  public static long Wait(Child child, uint ms) {
    if (WaitForSingleObject(child.Process, ms) != 0) return -1;
    uint code;
    GetExitCodeProcess(child.Process, out code);
    return code;
  }
  public static void Kill(Child child) { TerminateProcess(child.Process, 1); }
}
'@

$DETACHED_PROCESS = [uint32]0x00000008
$CREATE_NO_WINDOW = [uint32]0x08000000
$failures = [System.Collections.Generic.List[string]]::new()
function Check([bool]$ok, [string]$what) {
  if ($ok) { Write-Host "PASS $what" } else { Write-Host "FAIL $what"; $failures.Add($what) }
}
function Consoles([int]$processId) {
  @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$processId AND Name='conhost.exe'").Count
}
function RoundTrip([uint32]$flags) {
  $child = [SshSpawn]::Start("`"$ssh`" -F `"$config`" -T -o ServerAliveInterval=5 proof sort", $flags, $true)
  $reader = [System.IO.StreamReader]::new($child.Output)
  $text = $reader.ReadToEndAsync()
  Start-Sleep -Seconds 3
  $alive = [SshSpawn]::Alive($child)
  $consoles = Consoles $child.Pid
  $line = [System.Text.Encoding]::ASCII.GetBytes("helper-ping`n")
  $child.Input.Write($line, 0, $line.Length)
  $child.Input.Flush()
  $child.Input.Dispose()
  $code = [SshSpawn]::Wait($child, 20000)
  $null = $text.Wait(5000)
  [pscustomobject]@{ Alive = $alive; Consoles = $consoles; Code = $code; Output = $text.Result }
}

$detached = RoundTrip $DETACHED_PROCESS
Write-Host "detached: alive=$($detached.Alive) consoles=$($detached.Consoles) exit=$($detached.Code) output=$($detached.Output.Trim())"
Check ($detached.Alive) 'detached ssh with pipe stdio stays connected while waiting for input'
Check ($detached.Consoles -eq 0) 'detached ssh has no conhost child'
Check ($detached.Code -eq 0 -and $detached.Output -match 'helper-ping') 'detached ssh round-trips a request through the remote command'

$hidden = RoundTrip $CREATE_NO_WINDOW
Write-Host "hidden console: alive=$($hidden.Alive) consoles=$($hidden.Consoles) exit=$($hidden.Code) output=$($hidden.Output.Trim())"
Check ($hidden.Consoles -eq 1) 'CREATE_NO_WINDOW ssh, the old flag, has one conhost child'

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 47010)
$listener.Start()
$keeper = [SshSpawn]::Start("`"$ssh`" -F `"$config`" -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -R 127.0.0.1:47011:127.0.0.1:47010 proof", $DETACHED_PROCESS, $false)
$relayed = ''
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline -and -not $relayed) {
  try {
    $client = [System.Net.Sockets.TcpClient]::new('127.0.0.1', 47011)
    $accept = $listener.AcceptTcpClientAsync()
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("relay-ok`n")
    $client.GetStream().Write($bytes, 0, $bytes.Length)
    if ($accept.Wait(5000)) {
      $buffer = New-Object byte[] 64
      $count = $accept.Result.GetStream().Read($buffer, 0, $buffer.Length)
      $relayed = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
    }
    $client.Close()
  } catch { Start-Sleep -Milliseconds 500 }
}
$keeperAlive = [SshSpawn]::Alive($keeper)
$keeperConsoles = Consoles $keeper.Pid
[SshSpawn]::Kill($keeper)
$listener.Stop()
Write-Host "keeper: alive=$keeperAlive consoles=$keeperConsoles relayed=$($relayed.Trim())"
Check ($relayed -match 'relay-ok') 'detached ssh -N -R without std handles forwards a connection'
Check $keeperAlive 'detached tunnel keeper stays up'
Check ($keeperConsoles -eq 0) 'detached tunnel keeper has no conhost child'

if ($failures.Count -gt 0) { throw "Failed: $($failures -join '; ')" }
