$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../.claude/skills/verify-multiprompt/control-library.ps1')
Add-Type @'
public static class VerifyNative {
    public static long GetAncestor(long handle, int flag) { return handle; }
    public static long GetForegroundWindow() { return 1; }
    public static long GetFocusedWindow(long handle) { return handle; }
    public static bool SetForegroundWindow(long handle) { return true; }
}
'@
$script:window = 1L
$scratch = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
$Evidence = Join-Path $scratch 'evidence'
New-Item -ItemType Directory -Path (Join-Path $scratch 'roaming/ZigShell'), $Evidence -Force | Out-Null
$script:trace = ''
$script:scene = 'workspace'
$script:changesScreen = $true
$script:cursor = 0
$script:journeyCommands = (& node (Join-Path $PSScriptRoot 'journey-commands.mjs')) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Catalog generation failed' }
$script:ids = @('99999', [string]$script:journeyCommands.'new cmd shell'.target, '99998')
function Doctor {}
function Assert-Foreground {}
function Record([string]$Action) {}
function Retry-PaletteOpen([string]$Log, [int]$Start) {}
function Read-SharedText([string]$Path) { $script:trace }
function Read-Session { @{ tabs = @(@{ name = 'other' }, @{ name = 'Restore middle' }) } }
function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20) {
    if (-not (& $Condition)) { throw "Waited for $Description" }
}
function WindowShot([string]$Name) {
    [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '.png')), $script:scene)
}
function Type-Text([string]$Text) {
    $script:trace += "[palette] rows chars=$($Text.Length) count=$($script:ids.Count) ids=$($script:ids -join ' ')`n"
}
function Press([int[]]$Keys, [string]$Label) {
    if ($Keys -contains 0x4B) {
        $script:scene = 'palette'
        $script:trace += "[palette] ready chars=0 count=3 target=99999`n"
    } elseif ($Keys -contains 0x24) {
        $script:cursor = 0
    } elseif ($Keys -contains 0x28) {
        $script:cursor++
        $script:scene = "palette-$script:cursor"
    } elseif ($Keys -contains 0x0D) {
        if ($script:changesScreen) { $script:scene = 'new workspace screen' }
    }
}
try {
    Invoke-JourneyCommand 'new cmd shell'
    if ($script:cursor -ne 1) { throw 'Named command did not follow the reordered palette row' }
    $script:changesScreen = $false
    $failed = $false
    try { Invoke-JourneyCommand 'new cmd shell' } catch {
        if ($_ -notmatch 'changed the visible screen') { throw }
        $failed = $true
    }
    if (-not $failed) { throw 'A command that left the screen unchanged passed' }
    $script:changesScreen = $true
    $script:ids = @('99999', '1', '99998')
    Invoke-JourneyCommand 'Restore middle' -Session
    Write-Output 'NAMED_COMMAND_ROW_AND_SCREEN_VERIFIED'
} finally {
    Remove-Item -Recurse -Force $scratch
}
