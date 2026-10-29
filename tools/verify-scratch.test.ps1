$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$driver = Join-Path $PSScriptRoot '../.claude/skills/verify-multiprompt/control-library.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($driver, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Test-VanishedScratchItem', 'Prepare-ScratchEvidence', 'Remove-ScratchPath', 'Release-ScratchConsoleFonts')) {
    $definition = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    if ($null -eq $definition) { throw "Missing production function $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$oldPrepare = @'
function Prepare-ScratchEvidence([string]$Path) {
    $blockedAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    foreach ($entry in Get-ChildItem -LiteralPath $Path -Force) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $script:scratchLinks += @{ path = $entry.FullName.Substring($scratch.Length + 1); attributes = $entry.Attributes.ToString(); linkType = $entry.LinkType; target = @($entry.Target) }
            Save-Json @($script:scratchLinks) 'scratch-links.json'
            $entry.Delete()
            Record 'Cleanup: recorded and unlinked scratch reparse point without traversing its target'
        } else {
            $entry.Attributes = $entry.Attributes -band (-bnot $blockedAttributes)
            if ($entry -is [IO.DirectoryInfo]) { Prepare-ScratchEvidence $entry.FullName }
        }
    }
}
'@
$prepare = ${function:Prepare-ScratchEvidence}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('verify-scratch-' + [guid]::NewGuid().ToString('N'))
$script:vanish = $null
function Get-ChildItem {
    param([string]$LiteralPath, [switch]$Force, [switch]$Recurse)
    $entries = @(Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $LiteralPath -Force:$Force -Recurse:$Recurse)
    if ($null -ne $script:vanish) {
        [IO.File]::Delete($script:vanish)
        $script:vanish = $null
    }
    return $entries
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $lock = Join-Path $scratch 'lockfile'
    $kept = Join-Path $scratch 'remaining.txt'
    [IO.File]::WriteAllText($kept, 'remaining')
    [IO.File]::SetAttributes($kept, [IO.FileAttributes]::ReadOnly)
    . ([scriptblock]::Create($oldPrepare))
    [IO.File]::WriteAllText($lock, 'lock')
    $script:vanish = $lock
    $rejected = $false
    try { Prepare-ScratchEvidence $scratch } catch {
        if (-not (Test-VanishedScratchItem $_ $lock)) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'ISSUE-559 baseline failed to reproduce the vanished lockfile exception' }
    Write-Output 'ISSUE-559 old cleanup rejected: file vanished after enumeration before Attributes assignment'

    ${function:Prepare-ScratchEvidence} = $prepare
    [IO.File]::SetAttributes($kept, [IO.FileAttributes]::ReadOnly)
    [IO.File]::WriteAllText($lock, 'lock')
    $script:vanish = $lock
    Prepare-ScratchEvidence $scratch
    if (Test-Path -LiteralPath $lock) { throw 'ISSUE-559 lockfile did not vanish' }
    if (([IO.File]::GetAttributes($kept) -band [IO.FileAttributes]::ReadOnly) -ne 0) { throw 'ISSUE-559 preparation skipped a surviving file' }
    foreach ($exception in @(
        (New-Object System.Management.Automation.ItemNotFoundException 'missing'),
        (New-Object IO.FileNotFoundException 'missing'),
        (New-Object IO.DirectoryNotFoundException 'missing')
    )) {
        $failure = New-Object System.Management.Automation.ErrorRecord $exception, 'missing', ([System.Management.Automation.ErrorCategory]::ObjectNotFound), $lock
        if (-not (Test-VanishedScratchItem $failure $lock)) { throw 'ISSUE-559 missing path was not tolerated' }
        if (Test-VanishedScratchItem $failure $kept) { throw 'ISSUE-559 existing path was silently ignored' }
    }
    $denied = New-Object System.Management.Automation.ErrorRecord (New-Object UnauthorizedAccessException 'denied'), 'denied', ([System.Management.Automation.ErrorCategory]::PermissionDenied), $lock
    if (Test-VanishedScratchItem $denied $lock) { throw 'ISSUE-559 permission failure was silently ignored' }
    Remove-ScratchPath $scratch
    if (Test-Path -LiteralPath $scratch) { throw 'ISSUE-559 scratch survived removal' }

    New-Item -ItemType Directory -Path $scratch | Out-Null
    [IO.File]::WriteAllText($kept, 'locked')
    $handle = [IO.File]::Open($kept, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $reported = $false
        try { Remove-ScratchPath $scratch 1 } catch {
            if ($_.Exception.Message -notlike '*Scratch cleanup left paths:*' -or -not $_.Exception.Message.Contains($kept)) { throw }
            $reported = $true
        }
        if (-not $reported -or -not (Test-Path -LiteralPath $kept)) { throw 'ISSUE-559 real leftover was not reported' }
    } finally { $handle.Dispose() }
    Write-Output 'ISSUE-559 production cleanup passed vanished-file, surviving-file, permission and locked-leftover checks'
} finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

$fontScratch = Join-Path ([IO.Path]::GetTempPath()) ('verify-font-' + [guid]::NewGuid().ToString('N'))
$fontRoot = Join-Path $fontScratch 'local/ZigShell/fonts'
$registrar = $null
$native = @'
using System;
using System.Runtime.InteropServices;
public static class VerifyNative {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string path, uint flags, IntPtr reserved);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool RemoveFontResourceEx(string path, uint flags, IntPtr reserved);
}
'@
Add-Type -TypeDefinition $native
function Save-Json($Value, [string]$Name) {
    if ($Name -cne 'console-font-cleanup.json') { throw 'Unexpected font evidence name' }
    $script:fontCleanup = @($Value)
}
$script:fontCleanup = @()
try {
    New-Item -ItemType Directory -Force $fontRoot | Out-Null
    $font = Join-Path $fontRoot 'NordwandMono-SemiBold-proof.ttf'
    Copy-Item (Join-Path $PSScriptRoot '../src/fonts/NordwandMono-SemiBold.ttf') $font
    $env:FONT_TEST_PATH = $font
    $env:FONT_TEST_READY = Join-Path $fontScratch 'registered.txt'
    $scriptFile = Join-Path $fontScratch 'register.ps1'
    $child = "`$ErrorActionPreference = 'Stop'`nAdd-Type -TypeDefinition @'`n$native`n'@`n" + @'
foreach ($registration in @(1, 2)) {
    if ([VerifyNative]::AddFontResourceEx($env:FONT_TEST_PATH, 0, [IntPtr]::Zero) -le 0) { throw 'Font registration failed' }
}
[IO.File]::WriteAllText($env:FONT_TEST_READY, '2')
[Threading.Thread]::Sleep([Threading.Timeout]::Infinite)
'@
    [IO.File]::WriteAllText($scriptFile, $child)
    $registrar = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $scriptFile + '"') -PassThru -WindowStyle Hidden
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $env:FONT_TEST_READY)) {
        if ($registrar.HasExited -or $clock.ElapsedMilliseconds -ge 30000) { throw 'Owned font registrar did not publish readiness' }
        Start-Sleep -Milliseconds 50
    }
    $registrar.Kill()
    if (-not $registrar.WaitForExit(10000)) { throw 'Owned font registrar did not stop' }
    $locked = $false
    try { $handle = [IO.File]::Open($font, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $handle.Dispose() }
    catch [UnauthorizedAccessException] { $locked = $true }
    catch [IO.IOException] { $locked = $true }
    if (-not $locked) { throw 'Baseline did not reproduce a font locked after registrar death' }
    Write-Output 'GLOBAL_FONT_KILLED_REGISTRAR_LOCK_PROVEN'
    Release-ScratchConsoleFonts $fontScratch
    if ($script:fontCleanup.Count -ne 1 -or $script:fontCleanup[0].registrations -ne 2) { throw 'Both orphaned font registrations were not reclaimed' }
    Release-ScratchConsoleFonts $fontScratch
    if ($script:fontCleanup[0].registrations -ne 0) { throw 'Font cleanup did not converge' }
    Remove-ScratchPath $fontScratch 1
    if (Test-Path -LiteralPath $fontScratch) { throw 'Font scratch survived resource teardown' }
    Write-Output 'GLOBAL_FONT_OWNED_CLEANUP_OK'
} finally {
    if ($null -ne $registrar) {
        if (-not $registrar.HasExited) { $registrar.Kill(); [void]$registrar.WaitForExit(10000) }
        $registrar.Dispose()
    }
    if (Test-Path -LiteralPath $fontRoot) {
        foreach ($file in [IO.Directory]::EnumerateFiles($fontRoot, '*.ttf')) {
            while ([VerifyNative]::RemoveFontResourceEx($file, 0, [IntPtr]::Zero)) {}
        }
    }
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $fontScratch -Recurse -Force -ErrorAction SilentlyContinue
}
