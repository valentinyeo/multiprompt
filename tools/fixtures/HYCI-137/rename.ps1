$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class ReconnectDesktop {
    public static bool Opened, Ready, Typed, Selected, Entered;
    public static void Key(ushort key, bool up) { }
    public static void Type(ushort key) {
        if (key == 0x4B) Opened = true;
        if (key == 0x0D) {
            if (!Selected) throw new Exception("Entered before rename selection was ready");
            Entered = true;
        }
    }
    public static long[] Focus(IntPtr window) { return new long[] { 100, Entered ? 200 : 100 }; }
    public static int Owner(IntPtr window) { return 42; }
    public static IntPtr GetAncestor(IntPtr window, int flags) { return new IntPtr(100); }
    public static string Class(IntPtr window) { return "Edit"; }
    public static string Text(IntPtr window) { return "Runners"; }
}
'@
$script:trace = "[palette] ready chars=0 count=1 target=1`n[palette] ready chars=16 count=1 target=7000`n"
$script:reads = 0
$app = [pscustomobject]@{ Id = 42 }
$appB = $null
$log = 'fixture'
function Read-Log([string]$LogPath) {
    if ([ReconnectDesktop]::Opened) {
        $script:reads++
        if (![ReconnectDesktop]::Typed -and $script:reads -eq 2) {
            [ReconnectDesktop]::Ready = $true
            $script:trace += "[palette] ready chars=0 count=2 target=1`n"
        }
        if ([ReconnectDesktop]::Typed -and $script:reads -eq 4) {
            [ReconnectDesktop]::Selected = $true
            $script:trace += "[palette] ready chars=16 count=1 target=7000`n"
        }
    }
    return $script:trace
}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds) {
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $value = & $Check
        if ($value) { return $value }
    }
    throw "Timed out: $Description"
}
function Set-JourneyForeground([IntPtr]$Window, [int]$ProcessId) { }
function Assert-Window([IntPtr]$Window, [int]$ProcessId) {
    if ($Window -ne [IntPtr]100 -or $ProcessId -ne 42) { throw 'Wrong window' }
}
function Assert-Focus([IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    Assert-Window $Window $ProcessId
    if ([ReconnectDesktop]::Focus($Window)[1] -ne $Expected.ToInt64()) { throw 'Wrong focus' }
}
function Type-Ascii([string]$Value, [IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    Assert-Focus $Window $ProcessId $Expected
    if (![ReconnectDesktop]::Ready) { throw 'Typed before fresh palette readiness' }
    if ($Value -cne 'rename workspace') { throw 'Wrong search query' }
    [ReconnectDesktop]::Typed = $true
    $script:trace += "[palette] ready chars=16 count=1 target=42`n"
}
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'tools/account-journey/drive.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Could not parse drive.ps1' }
$function = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Open-Rename' }, $true)
if ($function.Count -ne 1) { throw 'Open-Rename not found' }
. ([scriptblock]::Create($function[0].Extent.Text))
$edit = Open-Rename ([IntPtr]100) 42 'Runners'
if ($edit -ne [IntPtr]200 -or ![ReconnectDesktop]::Entered -or ![ReconnectDesktop]::Selected) { throw 'Rename did not return the owned edit' }
Write-Output 'Delayed palette returned the owned rename edit'
