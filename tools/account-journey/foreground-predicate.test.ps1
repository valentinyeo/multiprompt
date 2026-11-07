$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class ReconnectDesktop {
    public static IntPtr foreground;
    public static long focus;
    public static int mainOwner = 5516;
    public static int foregroundOwner = 7984;
    public static string foregroundClass = "ConsoleWindowClass";
    public static IntPtr root = new IntPtr(196956);
    public static IntPtr GetForegroundWindow() { return foreground; }
    public static long[] Focus(IntPtr h) { return new long[] { foreground.ToInt64(), focus }; }
    public static int Owner(IntPtr h) {
        if (h == IntPtr.Zero) return 0;
        if (h == new IntPtr(196956) || h == new IntPtr(196957)) return mainOwner;
        return foregroundOwner;
    }
    public static string Class(IntPtr h) { return foregroundClass; }
    public static IntPtr GetAncestor(IntPtr h, int flags) { return root; }
    public static int EventCount() { return 0; }
    public static object[] EventsSince(int start) { return new object[0]; }
    public static void Key(int key, bool up) { throw new Exception("Unexpected activation"); }
}
'@
. "$PSScriptRoot/foreground.ps1"
$tokens = $null
$parseErrors = $null
$driverAst = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/drive.ps1", [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Could not parse drive.ps1' }
$focusFunctions = @($driverAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-Focus' }, $true))
if ($focusFunctions.Count -ne 1) { throw 'Expected one Assert-Focus function in drive.ps1' }
. ([scriptblock]::Create($focusFunctions[0].Extent.Text))
$main = [IntPtr]196956
$owned = [IntPtr]196957
$console = [IntPtr]327756
$second = [IntPtr]123456
$script:journeyEventStart = 0

function Check-Case([string]$Name, [IntPtr]$Window, [int]$ProcessId, [IntPtr]$Foreground, [bool]$Accept) {
    [ReconnectDesktop]::foreground = $Foreground
    $actual = Test-JourneyForeground $Window $ProcessId $Foreground
    if ($actual -ne $Accept) { throw "$Name predicate: expected $Accept, got $actual" }
    $passed = $true
    try { Assert-Window $Window $ProcessId } catch { $passed = $false }
    if ($passed -ne $Accept) { throw "$Name assertion: expected $Accept, got $passed" }
}

Check-Case 'exact main' $main 5516 $main $true
Check-Case 'cross-process console' $main 5516 $console $true
Set-JourneyForeground $main 5516
[ReconnectDesktop]::root = $second
Check-Case 'foreign console root' $main 5516 $console $false
[ReconnectDesktop]::root = $main
Check-Case 'wrong expected owner' $main 5517 $console $false
[ReconnectDesktop]::mainOwner = 0
Check-Case 'missing expected owner' $main 0 $console $false
[ReconnectDesktop]::mainOwner = 5516
[ReconnectDesktop]::foregroundOwner = 0
Check-Case 'missing foreground owner' $main 5516 $console $false
[ReconnectDesktop]::foregroundOwner = 7984
[ReconnectDesktop]::foregroundClass = 'Edit'
Check-Case 'root-matching nonconsole' $main 5516 $console $false
[ReconnectDesktop]::foregroundClass = 'ConsoleWindowClass'
Check-Case 'zero expected window' ([IntPtr]::Zero) 5516 $console $false
Check-Case 'zero foreground' $main 5516 ([IntPtr]::Zero) $false
[ReconnectDesktop]::foregroundClass = 'ZigShell'
[ReconnectDesktop]::root = $second
Check-Case 'foreign second window' $main 5516 $second $false

[ReconnectDesktop]::foregroundClass = 'ConsoleWindowClass'
[ReconnectDesktop]::root = $main
[ReconnectDesktop]::foreground = $main
[ReconnectDesktop]::focus = $main.ToInt64()
Assert-Focus $main 5516 $main
[ReconnectDesktop]::focus = $owned.ToInt64()
Assert-Focus $main 5516 $owned

function Check-FocusRejected([string]$Name, [IntPtr]$Expected) {
    try {
        Assert-Focus $main 5516 $Expected
    } catch {
        if ($_.Exception.Message -ceq 'Unexpected input focus') { return }
        throw "$Name`: unexpected error: $($_.Exception.Message)"
    }
    throw "$Name`: expected Unexpected input focus"
}

[ReconnectDesktop]::foreground = $console
[ReconnectDesktop]::focus = $main.ToInt64()
Assert-Window $main 5516
Check-FocusRejected 'cross-process foreground' $main
[ReconnectDesktop]::foreground = $main
[ReconnectDesktop]::focus = $console.ToInt64()
Check-FocusRejected 'foreign focus owner' $console
[ReconnectDesktop]::focus = $owned.ToInt64()
[ReconnectDesktop]::root = $second
Check-FocusRejected 'foreign focus root' $owned
Write-Host 'Account journey foreground predicate assertions passed'
