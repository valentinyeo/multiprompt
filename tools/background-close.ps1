param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
Start-Transcript "$Output/driver.log"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CloseProbe {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, UIntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, UIntPtr wp, IntPtr lp, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
}
'@
$profile = Join-Path $env:RUNNER_TEMP ('background-close-' + [guid]::NewGuid().ToString('N'))
$settings = "$profile/roaming/ZigShell"
$log = "$settings/debug.log"
$results = [Collections.Generic.List[object]]::new()
$app = $null
$other = $null
function Read-Log {
    if (-not (Test-Path $log)) { return '' }
    $stream = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
}
function Wait-For([string]$Description, [scriptblock]$Check) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        [Windows.Forms.Application]::DoEvents()
        if (& $Check) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Output/$Name.png") }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Record([string]$Case, [string]$Detail) {
    $results.Add(@{case=$Case; pass=$true; detail=$Detail})
    $results.ToArray() | ConvertTo-Json -Depth 6 -AsArray | Set-Content "$Output/summary.json"
    Write-Output "PASS $Case $Detail"
}
try {
    New-Item -ItemType Directory -Force $settings, "$profile/local" | Out-Null
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(@{kind='cmd'; name='Close message proof'; manual=$true; cv=$false; pid=0})} | ConvertTo-Json -Depth 5 | Set-Content "$settings/session.json"
    $app = Start-Process -FilePath $Exe -PassThru
    Wait-For 'owned app visible' { $app.Refresh(); $app.MainWindowHandle -ne [IntPtr]::Zero }
    $main = $app.MainWindowHandle
    $other = [Windows.Forms.Form]::new()
    $other.Text = 'External close sender: PowerShell'
    $other.Width = 460
    $other.Height = 150
    $label = [Windows.Forms.Label]::new()
    $label.Text = "Multiprompt must stay open behind this window.`nExternal sender process: $([Diagnostics.Process]::GetCurrentProcess().Id)"
    $label.Dock = 'Fill'
    $other.Controls.Add($label)
    $other.Show()
    [void][CloseProbe]::SetForegroundWindow($other.Handle)
    Wait-For 'external sender foreground' { [CloseProbe]::GetForegroundWindow() -eq $other.Handle }
    Shot 'before'
    foreach ($case in @('sent', 'posted', 'malformed')) {
        $offset = (Read-Log).Length
        $word = if ($case -eq 'malformed') { [UIntPtr]0x4D5043FF } else { [UIntPtr]::Zero }
        if ($case -eq 'sent') {
            $reply = [UIntPtr]::Zero
            if ([CloseProbe]::SendMessageTimeout($main, 0x0010, $word, [IntPtr]::Zero, 2, 5000, [ref]$reply) -eq [IntPtr]::Zero) { throw 'External sent close was not delivered' }
        } else {
            if (-not [CloseProbe]::PostMessage($main, 0x0010, $word, [IntPtr]::Zero)) { throw 'External posted close was not delivered' }
        }
        Wait-For "ignored $case close" {
            if ($app.HasExited -or -not [CloseProbe]::IsWindow($main)) { throw "App closed after external $case WM_CLOSE" }
            (Read-Log).Substring($offset) -match 'close-request action=ignore reason=unsolicited sender=unavailable'
        }
        $entry = @((Read-Log).Substring($offset) -split "`n" | Where-Object { $_ -match 'close-request action=ignore' })[0]
        if ($case -eq 'sent' -and $entry -notmatch 'transport=sent ') { throw 'Sent close lost transport provenance' }
        if ($case -ne 'sent' -and $entry -notmatch 'transport=posted-or-local ') { throw 'Posted close lost transport provenance' }
        if ($entry -notmatch "foreground_pid=$([Diagnostics.Process]::GetCurrentProcess().Id)\b") { throw 'Foreground process was not recorded separately' }
        Record "background-$case" $entry.Trim()
    }
    Shot 'background-close-blocked'
    [void][CloseProbe]::SetForegroundWindow($main)
    Wait-For 'owned foreground main' { [CloseProbe]::GetForegroundWindow() -eq $main }
    if (-not $app.CloseMainWindow() -or -not $app.WaitForExit(15000)) { throw 'Intentional foreground close stopped working' }
    Record 'foreground-close' 'Standard foreground close still exits normally'
    $app.Dispose()
    $app = Start-Process -FilePath $Exe -PassThru
    Wait-For 'second owned app visible' { $app.Refresh(); $app.MainWindowHandle -ne [IntPtr]::Zero }
    $main = $app.MainWindowHandle
    [void][CloseProbe]::SetForegroundWindow($other.Handle)
    Wait-For 'external foreground again' { [CloseProbe]::GetForegroundWindow() -eq $other.Handle }
    if (-not [CloseProbe]::PostMessage($main, 0x0112, [UIntPtr]0xF060, [IntPtr]::Zero) -or -not $app.WaitForExit(15000)) { throw 'Explicit system-menu close stopped working' }
    if ((Read-Log) -notmatch 'close-request action=accept reason=window_control sender=declared declared_sender_pid=\d+') { throw 'Explicit close reason missing' }
    Record 'system-menu-close' 'SC_CLOSE carries a named reason, including background taskbar close'
    Copy-Item $log "$Output/debug.log"
    Write-Output 'BACKGROUND_CLOSE_JOURNEY_OK'
} finally {
    if (Test-Path $log) { Copy-Item $log "$Output/debug.log" -Force }
    if ($app) { if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }; $app.Dispose() }
    if ($other) { $other.Close(); $other.Dispose() }
    Stop-Transcript
}
