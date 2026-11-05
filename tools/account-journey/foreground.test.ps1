$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/../verify-reconnect/desktop.cs"
. "$PSScriptRoot/foreground.ps1"
$source = @'
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$form = [System.Windows.Forms.Form]::new()
$form.Text = 'Account journey foreground probe'
[System.Windows.Forms.Application]::Run($form)
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
$processes = @()
$logs = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $logs | Out-Null
try {
    foreach ($index in 0, 1) {
        $processes += Start-Process powershell.exe -ArgumentList '-NoProfile', '-STA', '-EncodedCommand', $encoded -PassThru -RedirectStandardError (Join-Path $logs "$index.err")
    }
    $windows = @()
    foreach ($index in 0, 1) {
        $process = $processes[$index]
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        $window = [IntPtr]::Zero
        do {
            $process.Refresh()
            if ($process.HasExited) { break }
            $candidate = $process.MainWindowHandle
            if ($candidate -ne [IntPtr]::Zero -and [ReconnectDesktop]::IsWindowVisible($candidate) -and [ReconnectDesktop]::Class($candidate) -like 'WindowsForms10.*') { $window = $candidate; break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($window -eq [IntPtr]::Zero) {
            $detail = Get-Content -Raw (Join-Path $logs "$index.err")
            throw "Foreground probe window did not appear (pid=$($process.Id), exited=$($process.HasExited)): $detail"
        }
        $windows += $window
    }
    foreach ($index in @(0, 1, 0, 1)) {
        Set-JourneyForeground $windows[$index] $processes[$index].Id
        Assert-Window $windows[$index] $processes[$index].Id
        if ([ReconnectDesktop]::Focus($windows[$index])[0] -ne $windows[$index].ToInt64()) { throw 'Foreground probe focus mismatch' }
    }
    $rejected = $false
    try { Set-JourneyForeground $windows[0] $processes[1].Id } catch { $rejected = $_.Exception.Message -match 'expected hwnd=.*owner=.*foreground=' }
    if (!$rejected) { throw 'Foreground probe accepted a window owned by another process' }
    Write-Host 'Account journey foreground assertions passed'
} finally {
    foreach ($process in $processes) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
    }
    Remove-Item -Recurse -Force $logs
}
