param(
    [string]$AppPath = "$env:USERPROFILE\Documents\GitHub\zigshell\zig-out\bin\multiprompt.exe",
    [string]$BridgePath = '',
    [string]$ExpectVersion = '',
    [switch]$StartIfMissing,
    [int]$UpdateWaitSeconds = 240,
    [int]$MaxMemoryMb = 3000,
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$checks = New-Object 'System.Collections.Generic.List[object]'

function Add-Check([string]$Name, [bool]$Ok, [string]$Detail) {
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
}

if (-not ('LaptopCheckNative' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class LaptopCheckNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr window, StringBuilder name, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
}
"@
}

function Get-AppVersion([string]$Exe) {
    if (-not (Test-Path -LiteralPath $Exe)) { return '' }
    $found = Select-String -LiteralPath $Exe -Pattern 'MPVERSION=(\d+\.\d+\.\d+)' -Encoding ascii -AllMatches | Select-Object -First 1
    if ($null -eq $found) { return '' }
    return $found.Matches[0].Groups[1].Value
}

function Get-AppProcess([string]$Exe) {
    $full = [IO.Path]::GetFullPath($Exe)
    return @(Get-CimInstance Win32_Process -Filter "Name = 'multiprompt.exe'" | Where-Object { $_.ExecutablePath -eq $full })
}

function Get-WindowClass([IntPtr]$Window) {
    $buffer = New-Object Text.StringBuilder 256
    [void][LaptopCheckNative]::GetClassName($Window, $buffer, 256)
    return $buffer.ToString()
}

function Get-WindowTitle([IntPtr]$Window) {
    $buffer = New-Object Text.StringBuilder 512
    [void][LaptopCheckNative]::GetWindowText($Window, $buffer, 512)
    return $buffer.ToString()
}

function Get-MainWindow([int]$ProcessId, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $appProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $appProcess) { return [IntPtr]::Zero }
        $appProcess.Refresh()
        if ($appProcess.MainWindowHandle -ne [IntPtr]::Zero) { return $appProcess.MainWindowHandle }
        Start-Sleep -Milliseconds 500
    }
    return [IntPtr]::Zero
}

function Start-App([string]$Exe) {
    $folder = Split-Path -Parent $Exe
    Start-Process -FilePath $Exe -WorkingDirectory $folder | Out-Null
}

function Stop-App([string]$Exe) {
    foreach ($target in (Get-AppProcess $Exe)) {
        $window = (Get-Process -Id $target.ProcessId -ErrorAction SilentlyContinue).MainWindowHandle
        if ($null -ne $window -and $window -ne [IntPtr]::Zero) { [void][LaptopCheckNative]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($null -eq (Get-Process -Id $target.ProcessId -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Milliseconds 500
        }
        Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Get-StagedVersion([string]$Exe) {
    $readyPath = Join-Path (Split-Path -Parent $Exe) '.update\ready.txt'
    if (-not (Test-Path -LiteralPath $readyPath)) { return '' }
    $text = (Get-Content -LiteralPath $readyPath -Raw).Trim()
    if ($text -match '^MPVERSION=(\d+\.\d+\.\d+);') { return $Matches[1] }
    return ''
}

$appVersion = Get-AppVersion $AppPath
$updateNote = ''

if ($ExpectVersion -and $appVersion -ne $ExpectVersion -and $StartIfMissing) {
    $updateDeadline = [DateTime]::UtcNow.AddSeconds($UpdateWaitSeconds)
    while ($appVersion -ne $ExpectVersion -and [DateTime]::UtcNow -lt $updateDeadline) {
        if (@(Get-AppProcess $AppPath).Count -eq 0) { Start-App $AppPath }
        Start-Sleep -Seconds 10
        $appVersion = Get-AppVersion $AppPath
        if ($appVersion -eq $ExpectVersion) { break }
        if ((Get-StagedVersion $AppPath) -eq $ExpectVersion) {
            $updateNote = 'applied a staged update'
            Stop-App $AppPath
            Start-App $AppPath
            Start-Sleep -Seconds 15
            $appVersion = Get-AppVersion $AppPath
        }
    }
}

Add-Check 'install' ($appVersion -ne '' -and ($ExpectVersion -eq '' -or $appVersion -eq $ExpectVersion)) "installed $appVersion, expected $(if ($ExpectVersion) { $ExpectVersion } else { 'any' }) $updateNote".Trim()

$appProcesses = @(Get-AppProcess $AppPath)
if ($appProcesses.Count -eq 0 -and $StartIfMissing) {
    Start-App $AppPath
    Start-Sleep -Seconds 2
    $appProcesses = @(Get-AppProcess $AppPath)
}

$window = [IntPtr]::Zero
$startedAt = [DateTime]::MinValue
if ($appProcesses.Count -gt 0) {
    $window = Get-MainWindow $appProcesses[0].ProcessId 120
    $startedAt = $appProcesses[0].CreationDate
}

$windowClass = if ($window -ne [IntPtr]::Zero) { Get-WindowClass $window } else { '' }
$windowTitle = if ($window -ne [IntPtr]::Zero) { Get-WindowTitle $window } else { '' }
$titleOk = $appVersion -ne '' -and $windowTitle -like "*$appVersion*"
Add-Check 'start' ($appProcesses.Count -gt 0 -and $windowClass -ceq 'ZigShell' -and $titleOk) "$($appProcesses.Count) process, window '$windowClass' '$windowTitle'"

$inboxFolder = Join-Path $env:APPDATA 'ZigShell'
$newestInbox = Get-ChildItem -LiteralPath $inboxFolder -Filter 'inbox-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$shellCount = 0
$inboxName = 'none'
if ($null -ne $newestInbox) {
    $inboxName = $newestInbox.Name
    try { $shellCount = @(($newestInbox | Get-Content -Raw | ConvertFrom-Json).shells).Count } catch { $shellCount = 0 }
}
Add-Check 'chats' ($shellCount -gt 0) "$shellCount tabs published in $inboxName"

$bridgeExe = if ($BridgePath) { $BridgePath } else { Join-Path (Split-Path -Parent $AppPath) 'zigshell-bridge.exe' }
$bridgeText = ''
$bridgeOk = $false
if (Test-Path -LiteralPath $bridgeExe) {
    try {
        $bridgeText = (& $bridgeExe status 2>&1 | Out-String).Trim()
        $bridgeOk = $bridgeText -match '"ok":true'
    } catch {
        $bridgeText = $_.Exception.Message
    }
}
Add-Check 'computer-view' $bridgeOk "bridge status $bridgeText"

$pendingPath = Join-Path $inboxFolder 'account-layout-pending.json'
$devicePath = Join-Path $inboxFolder 'account-device.dat'
$syncOk = $true
$syncDetail = 'no account signed in on this laptop'
if (Test-Path -LiteralPath $devicePath) {
    $syncDetail = 'account signed in, no layout pending'
    if (Test-Path -LiteralPath $pendingPath) {
        $pendingMinutes = [math]::Round(([DateTime]::UtcNow - (Get-Item -LiteralPath $pendingPath).LastWriteTimeUtc).TotalMinutes, 1)
        $syncOk = $pendingMinutes -lt 15
        $syncDetail = "layout pending for $pendingMinutes minutes"
    }
}
Add-Check 'sync' $syncOk $syncDetail

$workingSetMb = 0
foreach ($appProcess in $appProcesses) {
    $liveProcess = Get-Process -Id $appProcess.ProcessId -ErrorAction SilentlyContinue
    if ($null -ne $liveProcess) { $workingSetMb += [math]::Round($liveProcess.WorkingSet64 / 1MB) }
}
Add-Check 'memory' ($workingSetMb -gt 0 -and $workingSetMb -lt $MaxMemoryMb) "$workingSetMb MB working set, cap $MaxMemoryMb MB"

$crashFolder = Join-Path $inboxFolder 'crashes'
$freshCrashes = @()
if (Test-Path -LiteralPath $crashFolder) {
    $freshCrashes = @(Get-ChildItem -LiteralPath $crashFolder -Filter 'crash-*.txt' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $startedAt.AddMinutes(-2) })
}
Add-Check 'crashes' ($freshCrashes.Count -eq 0) "$($freshCrashes.Count) crashes since the app started"

$result = [pscustomobject]@{
    host = $env:COMPUTERNAME
    version = $appVersion
    expected = $ExpectVersion
    at = [DateTime]::UtcNow.ToString('o')
    checks = $checks
}

$text = $result | ConvertTo-Json -Depth 6 -Compress
if ($OutFile) { [IO.File]::WriteAllText($OutFile, $text) }
Write-Output 'LAPTOP_CHECK_JSON_BEGIN'
Write-Output $text
Write-Output 'LAPTOP_CHECK_JSON_END'

if (@($checks | Where-Object { -not $_.ok }).Count -gt 0) { exit 1 }
exit 0
