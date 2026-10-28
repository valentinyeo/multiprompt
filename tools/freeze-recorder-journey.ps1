param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Evidence, [string]$AccountState = '', [string]$Service = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Freeze journey requires an isolated GitHub Windows runner' }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FreezeJourney {
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint access, bool inherit, uint thread);
    [DllImport("kernel32.dll")] public static extern uint SuspendThread(IntPtr thread);
    [DllImport("kernel32.dll")] public static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wp, IntPtr lp, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
}
'@
$Exe = (Resolve-Path $Exe).Path
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('freeze-' + [guid]::NewGuid().ToString('N'))
foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
$env:APPDATA = Join-Path $scratch 'roaming'
$env:LOCALAPPDATA = Join-Path $scratch 'local'
$env:USERPROFILE = Join-Path $scratch 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:IGSH_246 = '0'
$env:ZIGSHELL_DEBUG = '1'
$crashes = Join-Path $env:APPDATA 'ZigShell/crashes'
if ($AccountState) {
    try { Add-Type -AssemblyName System.Security } catch {}
    $state = Get-Content $AccountState -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{refresh_token=$state.refresh_token} | ConvertTo-Json -Compress))
    $protected = [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $settings = Split-Path $crashes
    New-Item -ItemType Directory -Force $settings | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), $protected)
    Remove-Item Env:MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
}
function Service-Reports {
    return @((Invoke-RestMethod "$Service/__journey/reports").reports)
}
function Wait-Uploads([int]$Count) {
    $deadline = [DateTime]::UtcNow.AddSeconds(50)
    do {
        $rows = @(Service-Reports)
        if ($rows.Count -eq $Count) { return $rows }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Expected $Count uploaded reports; found $($rows.Count)"
}
$app = $null
$thread = [IntPtr]::Zero
function Wait-Window {
    param([Diagnostics.Process]$App)
    $until = [DateTime]::UtcNow.AddSeconds(45)
    do {
        $App.Refresh()
        if ($App.HasExited) { throw 'App exited before its window responded' }
        $window = $App.MainWindowHandle
        $reply = [UIntPtr]::Zero
        if ($window -ne [IntPtr]::Zero -and [FreezeJourney]::SendMessageTimeout($window, 0, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 500, [ref]$reply) -ne [IntPtr]::Zero) { return $window }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $until)
    throw 'Window never responded'
}
function Reports { return @(Get-ChildItem $crashes -Filter 'freeze-*.txt' -ErrorAction SilentlyContinue) }
function Stall([bool]$VerifyLive = $false) {
    if ([FreezeJourney]::SuspendThread($script:thread) -eq [uint32]::MaxValue) { throw 'Cannot suspend fixture main thread' }
    try {
        [void][FreezeJourney]::ShowWindow($script:window, 0)
        Start-Sleep -Seconds 10
        if ($VerifyLive) {
            $rows = @(Wait-Uploads 1)
            if ($rows[0].received_at - $rows[0].captured_at -ge 60) { throw 'Upload missed the one-minute gate' }
            if ($rows[0].stack_trace -notmatch '0x[0-9A-F]+') { throw 'Uploaded stack missing' }
            $rows | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Evidence 'uploaded-first.json')
        }
    } finally {
        [void][FreezeJourney]::ResumeThread($script:thread)
        [void][FreezeJourney]::ShowWindow($script:window, 5)
    }
    [void](Wait-Window $script:app)
    Start-Sleep -Seconds 2
}
try {
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $window = Wait-Window $app
    Start-Sleep -Seconds 12
    if (@(Reports).Count -ne 0) { throw 'Healthy window wrote a freeze report' }
    $privateText = 'PRIVATE-FREEZE-FIXTURE-message-host-path'
    [IO.File]::AppendAllText((Join-Path $env:APPDATA 'ZigShell/debug.log'), $privateText)
    $owner = [uint32]0
    $mainThread = [FreezeJourney]::GetWindowThreadProcessId($window, [ref]$owner)
    if ($owner -ne $app.Id) { throw 'Window belongs to another process' }
    $thread = [FreezeJourney]::OpenThread(2, $false, $mainThread)
    if ($thread -eq [IntPtr]::Zero) { throw 'Cannot open fixture main thread' }
    Stall ([bool]$AccountState)
    $reports = @(Reports)
    if ($reports.Count -ne 1) { throw "Ten-second stall must write exactly one report; found $($reports.Count)" }
    $text = [IO.File]::ReadAllText($reports[0].FullName)
    if ($text -notmatch '(?m)^stack_rvas:' -or $text -notmatch '(?m)^  0x[0-9A-F]+$' -or $text -notmatch '(?m)^instruction: [a-z0-9_.-]+\+0x[0-9A-F]+$') { throw 'Stuck location missing' }
    foreach ($sensitive in @($privateText, $scratch, $env:USERPROFILE, 'debug_log_tail', 'PRIVATE-')) { if ($text.Contains($sensitive)) { throw 'Private content leaked into report' } }
    Copy-Item $reports[0].FullName (Join-Path $Evidence 'first-freeze.txt')
    if ($AccountState) { [void](Invoke-RestMethod "$Service/__journey/offline/true") }
    Stall
    if ($AccountState -and @(Get-ChildItem $crashes -Filter 'upload-*.json').Count -ne 1) { throw 'Offline upload was not retained' }
    if (@(Reports).Count -ne 2) { throw 'A recovered window must record its next freeze exactly once' }
    [void][FreezeJourney]::CloseHandle($thread)
    $thread = [IntPtr]::Zero
    Stop-Process -Id $app.Id -Force
    $app.WaitForExit()
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $window = Wait-Window $app
    Start-Sleep -Seconds 3
    $rect = New-Object FreezeJourney+Rect
    if (-not [FreezeJourney]::GetWindowRect($window, [ref]$rect)) { throw 'Missing notice window bounds' }
    $bitmap = New-Object Drawing.Bitmap ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (-not [FreezeJourney]::PrintWindow($window, $dc, 2)) { throw 'Cannot capture next-start notice' } } finally { $graphics.ReleaseHdc($dc) }
    $bitmap.Save((Join-Path $Evidence 'next-start.png'))
    $graphics.Dispose()
    $bitmap.Dispose()
    $log = -join (Get-Content -LiteralPath (Join-Path $env:APPDATA 'ZigShell/debug.log') -Raw)
    if (-not $log.Contains('Multiprompt froze last time, a report was saved')) { throw 'Next-start freeze notice missing' }
    if (Test-Path (Join-Path $crashes 'freeze.marker')) { throw 'Next-start notice was not consumed' }
    if (@(Reports).Count -ne 2) { throw 'Restart created an extra freeze report' }
    if ($AccountState) {
        if (@(Get-ChildItem $crashes -Filter 'upload-*.json').Count -ne 1) { throw 'Restart lost pending report' }
        [void](Invoke-RestMethod "$Service/__journey/offline/false")
        $rows = @(Wait-Uploads 2)
        $rows | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Evidence 'uploaded-reports.json')
        foreach ($row in $rows) {
            if (!$row.app_version -or $row.summary -ne 'Windows freeze' -or $row.stack_trace -notmatch '(?m)^  0x[0-9A-F]+$') { throw 'Uploaded diagnostic fields missing' }
            foreach ($sensitive in @($privateText, $scratch, $env:USERPROFILE, 'debug_log_tail', 'PRIVATE-')) {
                if (($row | ConvertTo-Json -Compress).Contains($sensitive)) { throw 'Upload leaked private content' }
            }
        }
        Start-Sleep -Seconds 6
        if (@(Service-Reports).Count -ne 2) { throw 'Retry duplicated a service report' }
        if (@(Get-ChildItem $crashes -Filter 'upload-*.json').Count -ne 0) { throw 'Acknowledged uploads remain pending' }
        Write-Host 'FREEZE_UPLOAD_JOURNEY_OK'
    }
    @{ healthyReports = 0; firstStallReports = 1; secondStallReports = 2; restartNotice = $true; privateTextAbsent = $true; exeHash = (Get-FileHash $Exe -Algorithm SHA256).Hash } | ConvertTo-Json | Set-Content (Join-Path $Evidence 'result.json')
    Write-Host 'FREEZE_JOURNEY_OK'
} finally {
    if ($thread -ne [IntPtr]::Zero) { [void][FreezeJourney]::ResumeThread($thread); [void][FreezeJourney]::CloseHandle($thread) }
    if ($app -and -not $app.HasExited) { Stop-Process -Id $app.Id -Force }
}
