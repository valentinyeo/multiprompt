param([string]$Driver, [string]$Scratch, [switch]$LegacyArray)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type @'
using System;
public static class VerifyNative {
    public struct Rect { public int Left; }
    public static int Left = 300;
    public static IntPtr GetForegroundWindow() { return new IntPtr(1); }
    public static bool GetWindowRect(IntPtr window, out Rect rect) { rect = new Rect { Left = Left }; return true; }
    public static bool IsWindowVisible(IntPtr window) { return true; }
}
'@
function ConvertFrom-Json {
    param([Parameter(ValueFromPipeline=$true)][string]$InputObject)
    process {
        $parsed = Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject $InputObject
        if ($LegacyArray) { return ,$parsed }
        return $parsed
    }
}
function Select-Theme([string]$Theme, [string]$Shot, [string]$SavedTheme = $Theme) {
    $script:themeCalls += $Theme
    $script:fakeRgb = @{ dark=16; light=243; mid=60; amoled=0; 'edge grey'=51 }[$Theme]
    if ($null -eq $script:fakeRgb) { throw "Unknown theme query $Theme" }
    [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/theme-mode.txt'), $SavedTheme)
}
function Sidebar-Dominant([string]$Name) { return @{ r=$script:fakeRgb; g=$script:fakeRgb; b=$script:fakeRgb } }
function Snapshot([string]$Name) { $script:shots += $Name }
function Read-Session { return $script:fakeState }
function Wait-WorkspaceSurface([int]$Workspace, [int]$Tab, [bool]$Chat) {
    if ($Workspace -ne 0 -or $Tab -ne 0 -or $Chat) { throw 'Wrong unit console target' }
}
function Wait-Until([scriptblock]$Condition, [string]$Description) {
    if (-not (& $Condition)) { throw "Waited 20 s for $Description" }
}
function Invoke-JourneyCommand([string]$Name) {
    if ($Name -cne 'Sidebar: expand') { throw "Wrong sidebar command $Name" }
    $script:commands += $Name
    $script:fakeState.hide_sidebar = $false
    $script:fakeState.sidebar_collapsed = $false
    [VerifyNative]::Left = 300
}
function Press([int[]]$Keys, [string]$Label) {
    if (($Keys -join ',') -cne '17,16,66') { throw 'Wrong sidebar shortcut' }
    $script:presses++
    if ($script:brokenShortcut) { return }
    switch ($script:presses % 3) {
        1 { $script:fakeState.sidebar_collapsed=$true; [VerifyNative]::Left=60 }
        2 { $script:fakeState.sidebar_collapsed=$false; $script:fakeState.hide_sidebar=$true; [VerifyNative]::Left=0 }
        0 { $script:fakeState.hide_sidebar=$false; [VerifyNative]::Left=300 }
    }
}
$scratch = $Scratch
New-Item -ItemType Directory -Force (Join-Path $scratch 'roaming/ZigShell') | Out-Null
$cases = @('generated-theme-dark', 'generated-theme-mid', 'generated-theme-light', 'generated-theme-amoled', 'generated-theme-edgegray', 'generated-sidebar-cycle', 'generated-sidebar-expand', 'generated-missing', 'broken-shortcut')
$observations = @(foreach ($case in $cases) {
    $Feature = if ($case -eq 'broken-shortcut') { 'generated-sidebar-cycle' } else { $case }
    $script:brokenShortcut = $case -eq 'broken-shortcut'
    $script:fakeState = [pscustomobject]@{ active_workspace=0; active_tab=0; hide_sidebar=$false; sidebar_collapsed=$false }
    $script:themeCalls=@(); $script:commands=@(); $script:shots=@(); $script:presses=0
    $result = @{ checks=@() }
    $status='passed'; $failure=$null
    try { . $Driver } catch { $status='failed'; $failure=$_.Exception.Message }
    @{ feature=$case; status=$status; error=$failure; checks=$result.checks; themes=$script:themeCalls; commands=$script:commands; presses=$script:presses; shots=$script:shots }
})
ConvertTo-Json -InputObject $observations -Depth 8 -Compress
