$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class ReconnectDesktop {
    public static bool Opened, Ready, Typed, Selected, Entered;
    public static string Mode = "happy";
    public static void Key(ushort key, bool up) { }
    public static void Type(ushort key) {
        if (key == 0x4B) Opened = true;
        if (key == 0x0D) {
            if (!Selected) throw new Exception("Entered before rename selection was ready");
            Entered = true;
        }
    }
    public static long[] Focus(IntPtr window) { return new long[] { 100, Entered ? (Mode.StartsWith("missing") ? 0 : 200) : 100 }; }
    public static int Owner(IntPtr window) { return 42; }
    public static IntPtr GetAncestor(IntPtr window, int flags) { return new IntPtr(100); }
    public static string Class(IntPtr window) { return "Edit"; }
    public static string Text(IntPtr window) { return Mode == "wrong" ? "synthetic-secret-wrong-name" : "Runners"; }
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
    if ([ReconnectDesktop]::Entered -and [ReconnectDesktop]::Mode -eq 'missing-confirmed') {
        $script:trace += "2026-10-18 03:04:05.067 [palette] confirm target=7000`n"
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
. (Join-Path (Get-Location) 'tools/account-journey/diagnostics.ps1')
$secrets = @{ admin_key = 'synthetic-secret' }
foreach ($mode in @('wrong', 'missing-confirmed', 'missing-unconfirmed')) {
    $script:trace = "[palette] confirm target=7000`n"
    [ReconnectDesktop]::Opened = $false
    [ReconnectDesktop]::Ready = $false
    [ReconnectDesktop]::Typed = $false
    [ReconnectDesktop]::Selected = $false
    [ReconnectDesktop]::Entered = $false
    [ReconnectDesktop]::Mode = $mode
    $script:reads = 0
    $caught = $null
    try { Open-Rename ([IntPtr]100) 42 'private-expected-name' | Out-Null } catch { $caught = $_ }
    if (!$caught) { throw 'Expected rename timeout' }
    $diagnostic = Get-JourneyError $caught
    $message = $diagnostic.message
    if ($message -notmatch '^Timed out: workspace rename edit; expected_window=100 expected_pid=42 foreground=100 ' -or
        $message -notmatch "expected_name_match=False confirm_target_7000=$($mode -eq 'missing-confirmed')$" -or
        $message -match 'synthetic-secret|wrong-name|private-expected-name' -or
        !$caught.Exception.InnerException -or $caught.Exception.InnerException.Message -cne 'Timed out: workspace rename edit' -or
        $diagnostic.original_script_stack -notmatch 'Wait-For') { throw 'Unsafe or incomplete rename timeout diagnostic' }
    if ($mode -eq 'wrong' -and $message -notmatch 'focus=200 owner=42 root=100 edit_class=True ') { throw 'Wrong-name edit not identified' }
    if ($mode -like 'missing-*' -and $message -notmatch 'focus=0 owner=0 root=0 edit_class=False ') { throw 'Missing edit not identified' }
}
Write-Output 'Delayed palette and rename timeout diagnostics passed'
