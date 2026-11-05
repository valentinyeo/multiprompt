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
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
    [StructLayout(LayoutKind.Sequential)] struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] struct Data { [FieldOffset(0)] public Mouse Mouse; [FieldOffset(0)] public Keyboard Keyboard; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint Type; public Data Data; }
    [DllImport("user32.dll")] static extern uint SendInput(uint count, Input[] inputs, int size);
    public static void Activate(IntPtr window) {
        Input[] input = new Input[2];
        for (int i = 0; i < input.Length; i++) {
            input[i].Type = 1;
            input[i].Data.Keyboard = new Keyboard { Key = 0x12, Flags = i == 0 ? 0u : 2u };
        }
        if (SendInput(2, input, Marshal.SizeOf(typeof(Input))) != 2) throw new InvalidOperationException("Activation SendInput failed");
        SetForegroundWindow(window);
    }
    public static void FontBigger() {
        Input[] input = new Input[4];
        ushort[] keys = { 0x11, 0xBB, 0xBB, 0x11 };
        for (int i = 0; i < input.Length; i++) {
            input[i].Type = 1;
            input[i].Data.Keyboard = new Keyboard { Key = keys[i], Flags = i < 2 ? 0u : 2u };
        }
        if (SendInput(4, input, Marshal.SizeOf(typeof(Input))) != 4) throw new InvalidOperationException("Font command SendInput failed");
    }
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
function Service-Reports([string]$Summary = 'Windows freeze') {
    return @((Invoke-RestMethod "$Service/__journey/reports").reports | Where-Object { $_.summary -eq $Summary })
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
function Capture-NoticePixels([string]$Name) {
    $rect = New-Object FreezeJourney+Rect
    if (-not [FreezeJourney]::GetWindowRect($script:window, [ref]$rect)) { throw 'Missing owned window bounds' }
    $bitmap = New-Object Drawing.Bitmap ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $dc = $graphics.GetHdc()
        try { if (-not [FreezeJourney]::PrintWindow($script:window, $dc, 2)) { throw 'Cannot capture owned window' } }
        finally { $graphics.ReleaseHdc($dc) }
        $bitmap.Save((Join-Path $Evidence $Name))
        $orange = 0
        $scale = [FreezeJourney]::GetDpiForWindow($script:window) / 96.0
        for ($y = [int](32 * $scale); $y -lt [Math]::Min([int](64 * $scale), $bitmap.Height); $y++) {
            for ($x = [int]($bitmap.Width / 2); $x -lt $bitmap.Width - 8; $x++) {
                $color = $bitmap.GetPixel($x, $y)
                if ($color.R -ge 120 -and $color.G -ge 60 -and $color.G -le 220 -and $color.B -le 130 -and $color.R -ge $color.G + 20 -and $color.G -ge $color.B + 15) { $orange++ }
            }
        }
        return $orange
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Reports { return @(Get-ChildItem $crashes -Filter 'freeze-*.txt' -ErrorAction SilentlyContinue) }
function Stall([bool]$VerifyLive = $false) {
    if ([FreezeJourney]::SuspendThread($script:thread) -eq [uint32]::MaxValue) { throw 'Cannot suspend fixture main thread' }
    try {
        [void][FreezeJourney]::ShowWindowAsync($script:window, 0)
        Start-Sleep -Seconds 10
        if ($VerifyLive) {
            $rows = @(Wait-Uploads 1)
            if ($rows[0].received_at - $rows[0].captured_at -ge 60) { throw 'Upload missed the one-minute gate' }
            if ($rows[0].stack_trace -notmatch '0x[0-9A-F]+') { throw 'Uploaded stack missing' }
            $rows | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Evidence 'uploaded-first.json')
        }
    } finally {
        [void][FreezeJourney]::ResumeThread($script:thread)
        [void][FreezeJourney]::ShowWindowAsync($script:window, 5)
    }
    [void](Wait-Window $script:app)
    Start-Sleep -Seconds 2
}
try {
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $window = Wait-Window $app
    Start-Sleep -Seconds 12
    if (@(Reports).Count -ne 0) { throw 'Healthy window wrote a freeze report' }
    $healthReceipt = $null
    if ($Service) {
        $deadline = [DateTime]::UtcNow.AddSeconds(80)
        do {
            $healthRows = @(Service-Reports 'Windows watchdog health')
            if ($healthRows.Count -gt 0) { break }
            if ($app.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Actual watchdog coverage never reached the report service' }
            Start-Sleep -Milliseconds 250
        } while ($true)
        if ($healthRows.Count -ne 1) { throw 'Initial coverage receipt was duplicated' }
        $healthReceipt = $healthRows[0]
        $coverage = [regex]::Match($healthReceipt.stack_trace, '\Aobserved_ms: (\d+)\nresponsive_ms: (\d+)\nunobserved_ms: (\d+)\nfreezes: (\d+)\n\z')
        if (!$coverage.Success -or [long]$coverage.Groups[1].Value -lt 60000 -or [long]$coverage.Groups[2].Value -lt 55000 -or [long]$coverage.Groups[4].Value -ne 0 -or $healthReceipt.thread -ne 'watchdog' -or $healthReceipt.report_id -notmatch '^watchdog-\d+-\d+-\d+-0$') { throw 'Watchdog health receipt lacks actual healthy coverage' }
        $healthReceipt | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Evidence 'watchdog-health.json')
        if (@(Reports).Count -ne 0) { throw 'Healthy coverage interval wrote a freeze report' }
    }
    $privateText = 'PRIVATE-FREEZE-FIXTURE-message-host-path'
    [IO.File]::AppendAllText((Join-Path $env:APPDATA 'ZigShell/debug.log'), $privateText)
    $owner = [uint32]0
    $mainThread = [FreezeJourney]::GetWindowThreadProcessId($window, [ref]$owner)
    if ($owner -ne $app.Id) { throw 'Window belongs to another process' }
    $thread = [FreezeJourney]::OpenThread(2, $false, $mainThread)
    if ($thread -eq [IntPtr]::Zero) { throw 'Cannot open fixture main thread' }
    Stall ([bool]$Service)
    $reports = @(Reports)
    if ($reports.Count -ne 1) { throw "Ten-second stall must write exactly one report; found $($reports.Count)" }
    $text = [IO.File]::ReadAllText($reports[0].FullName)
    if ($text -notmatch '(?m)^stack_rvas:' -or $text -notmatch '(?m)^  0x[0-9A-F]+$' -or $text -notmatch '(?m)^instruction: [a-z0-9_.-]+\+0x[0-9A-F]+$') { throw 'Stuck location missing' }
    foreach ($sensitive in @($privateText, $scratch, $env:USERPROFILE, 'debug_log_tail', 'PRIVATE-')) { if ($text.Contains($sensitive)) { throw 'Private content leaked into report' } }
    Copy-Item $reports[0].FullName (Join-Path $Evidence 'first-freeze.txt')
    if ($Service) { [void](Invoke-RestMethod "$Service/__journey/offline/true") }
    Stall
    if ($Service -and @(Get-ChildItem $crashes -Filter 'upload-*.json').Count -ne 1) { throw 'Offline upload was not retained' }
    if (@(Reports).Count -ne 2) { throw 'A recovered window must record its next freeze exactly once' }
    [void][FreezeJourney]::CloseHandle($thread)
    $thread = [IntPtr]::Zero
    Stop-Process -Id $app.Id -Force
    $app.WaitForExit()
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $window = Wait-Window $app
    Start-Sleep -Seconds 3
    $restartNoticePixels = Capture-NoticePixels 'next-start.png'
    if ($restartNoticePixels -ne 0) { throw "Unprompted restart notice remains: $restartNoticePixels orange pixels" }
    [FreezeJourney]::Activate($window)
    $focusDeadline = [DateTime]::UtcNow.AddSeconds(5)
    while ([FreezeJourney]::GetForegroundWindow() -ne $window) {
        if ($app.HasExited -or [DateTime]::UtcNow -gt $focusDeadline) { throw 'Cannot focus owned app for action feedback' }
        Start-Sleep -Milliseconds 50
    }
    [FreezeJourney]::FontBigger()
    Start-Sleep -Milliseconds 250
    $userActionNoticePixels = Capture-NoticePixels 'user-action.png'
    if ($userActionNoticePixels -lt 10) { throw 'User font command lost its visible feedback' }
    $log = -join (Get-Content -LiteralPath (Join-Path $env:APPDATA 'ZigShell/debug.log') -Raw)
    if (-not $log.Contains('Multi Bot froze last time, a report was saved')) { throw 'Quiet restart lost the saved freeze diagnostic' }
    if (Test-Path (Join-Path $crashes 'freeze.marker')) { throw 'Quiet restart did not consume the freeze marker' }
    if (@(Reports).Count -ne 2) { throw 'Restart created an extra freeze report' }
    if ($Service) {
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
    if ($AccountState -and !$Service) {
        $deadline = [DateTime]::UtcNow.AddSeconds(50)
        while (@(Get-ChildItem $crashes -Filter 'upload-*.json').Count -gt 0) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Live service never acknowledged pending reports' }
            Start-Sleep -Milliseconds 250
        }
        @{ device = $state.device_id; version = ([regex]::Match($text, '(?m)^version: (.+)$')).Groups[1].Value; captured = ([regex]::Match($text, '(?m)^time_unix: (.+)$')).Groups[1].Value } | ConvertTo-Json | Set-Content (Join-Path $Evidence 'live-result.json')
        Write-Host 'FREEZE_LIVE_UPLOAD_OK'
    }
    @{ healthyReports = 0; firstStallReports = 1; secondStallReports = 2; watchdogHealth = [bool]$healthReceipt; restartNoticePixels = $restartNoticePixels; userActionNoticePixels = $userActionNoticePixels; privateTextAbsent = $true; exeHash = (Get-FileHash $Exe -Algorithm SHA256).Hash } | ConvertTo-Json | Set-Content (Join-Path $Evidence 'result.json')
    Stop-Process -Id $app.Id -Force
    if (-not $app.WaitForExit(5000)) { throw 'Original freeze journey process did not exit' }
    $app.Dispose()
    $app = $null
    $baseline = Join-Path $env:RUNNER_TEMP ('background-baseline-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Invoke-WebRequest 'https://github.com/valentinyeo/multiprompt/releases/download/v0.28.1450/multiprompt-x64.exe' -OutFile $baseline
        Invoke-WebRequest 'https://github.com/valentinyeo/multiprompt/releases/download/v0.28.1450/SHA256SUMS.txt' -OutFile ($baseline + '.sha256')
        $manifest = Get-Content -LiteralPath ($baseline + '.sha256') -Raw
        $checksum = [regex]::Match($manifest, '(?m)^([a-fA-F0-9]{64})\s+\*?multiprompt-x64\.exe\r?$')
        if (-not $checksum.Success -or (Get-FileHash $baseline -Algorithm SHA256).Hash -ne $checksum.Groups[1].Value) { throw 'Background baseline checksum mismatch' }
        $redEvidence = Join-Path $Evidence 'background-red'
        $red = & pwsh -NoProfile -File "$PSScriptRoot/background-freeze-journey.ps1" -Exe $baseline -Evidence $redEvidence 2>&1
        $redCode = $LASTEXITCODE
        $red | Set-Content (Join-Path $Evidence 'background-red-output.txt')
        $redResult = Get-Content (Join-Path $redEvidence 'result.json') -Raw | ConvertFrom-Json
        if ($redCode -eq 0 -or $redResult.phase -ne 'geometry' -or $redResult.geometry.ClientWidth -ne 8 -or ($red -join "`n") -notmatch 'WM_NCCALCSIZE clipped the proposal from \d+ to 8 pixels') { throw 'Background geometry red control failed for an unexpected reason' }
        $global:LASTEXITCODE = 0
    } finally { Remove-Item -LiteralPath $baseline, ($baseline + '.sha256') -Force -ErrorAction SilentlyContinue }
    & "$PSScriptRoot/background-freeze-journey.ps1" -Exe $Exe -Evidence (Join-Path $Evidence 'background')
    Write-Host 'FREEZE_JOURNEY_OK'
} finally {
    if ($thread -ne [IntPtr]::Zero) { [void][FreezeJourney]::ResumeThread($thread); [void][FreezeJourney]::CloseHandle($thread) }
    if ($app -and -not $app.HasExited) { Stop-Process -Id $app.Id -Force }
}
