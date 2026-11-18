param([string]$Library, [string]$Scratch, [switch]$BlockFocus, [switch]$AlreadyFocused)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type @'
using System;
public static class VerifyNative {
    public static IntPtr Foreground = new IntPtr(29);
    public static bool Block;
    public static int Activations;
    public static IntPtr GetForegroundWindow() { return Foreground; }
    public static IntPtr GetAncestor(IntPtr hwnd, uint flags) { return new IntPtr(17); }
    public static IntPtr GetFocusedWindow(IntPtr hwnd) { return new IntPtr(17); }
    public static bool SetForegroundWindow(IntPtr hwnd) { return false; }
    public static void BringToForeground(IntPtr hwnd) {
        if (hwnd.ToInt64() != 17) throw new Exception("Wrong foreground target");
        Activations++;
        if (!Block) Foreground = hwnd;
    }
}
'@
. $Library 6>$null
$script:window = [IntPtr]17
$script:journeyCommands = [pscustomobject]@{ themes=[pscustomobject]@{query='themes'; target=4000} }
$scratch = $Scratch
$Evidence = Join-Path $scratch 'evidence'
New-Item -ItemType Directory -Force $Evidence | Out-Null
$script:trace = ''
$script:typed = ''
$script:confirmed = $false
[VerifyNative]::Block = $BlockFocus
if ($AlreadyFocused) { [VerifyNative]::Foreground = $script:window }
function Doctor {}
function Assert-Foreground {
    if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -ne $script:window) { throw 'Foreign window' }
}
function Record([string]$Action) {}
function Read-SharedText([string]$Path) { return $script:trace }
function WindowShot([string]$Name) {
    $content = if ($script:confirmed) { 'command applied' } else { $Name }
    [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '.png')), $content)
}
function Press([int[]]$Keys, [string]$Label) {
    switch ($Keys -join ',') {
        '17,75' { $script:trace += "[palette] ready chars=0 count=1 target=4000`n" }
        '36' {}
        '13' { $script:confirmed = $true }
        default { throw 'Wrong palette input' }
    }
}
function Retry-PaletteOpen([string]$Log, [int]$Start) {}
function Type-Text([string]$Text) {
    if ([VerifyNative]::GetForegroundWindow() -ne $script:window) { throw 'Typed into hidden console' }
    $script:typed = $Text
    $script:trace += "[palette] rows chars=$($Text.Length) count=1 ids=4000`n"
}
function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20) {
    if (-not (& $Condition)) { throw "Waited $Seconds s for $Description" }
}
$status='passed'; $failure=$null
try { Invoke-JourneyCommand 'Themes' } catch { $status='failed'; $failure=$_.Exception.Message }
@{ status=$status; error=$failure; typed=$script:typed; confirmed=$script:confirmed; foreground=[VerifyNative]::Foreground.ToInt64(); activations=[VerifyNative]::Activations } | ConvertTo-Json -Compress
