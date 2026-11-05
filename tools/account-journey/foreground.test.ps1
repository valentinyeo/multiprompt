$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/../verify-reconnect/desktop.cs"
. "$PSScriptRoot/foreground.ps1"
$source = @'
Add-Type -AssemblyName System.Windows.Forms
$form = [System.Windows.Forms.Form]::new()
$form.Text = 'Account journey foreground probe'
[System.Windows.Forms.Application]::Run($form)
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
$processes = @()
try {
    $processes += Start-Process powershell.exe -ArgumentList '-NoProfile', '-STA', '-EncodedCommand', $encoded -PassThru
    $processes += Start-Process powershell.exe -ArgumentList '-NoProfile', '-STA', '-EncodedCommand', $encoded -PassThru
    $windows = @()
    foreach ($process in $processes) {
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        do {
            $window = [ReconnectDesktop]::Window($process.Id)
            if ($window -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($window -eq [IntPtr]::Zero) { throw 'Foreground probe window did not appear' }
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
        if (!$process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
