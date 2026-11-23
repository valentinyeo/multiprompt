$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/observer.cs" -ReferencedAssemblies System,System.Core,System.Drawing
function Reject([scriptblock]$Run, [string]$Expected) {
    try { & $Run } catch {
        if ($_.Exception.ToString() -notmatch $Expected) { throw }
        return
    }
    throw "Observer accepted broken frame: $Expected"
}
$rect = [int[]]@(100, 200, 500, 300)
[ChatStillObserver]::AssertFrame($rect, $rect, 0, 800, 800)
for ($edge = 0; $edge -lt 4; $edge++) {
    $moved = [int[]]$rect.Clone()
    $moved[$edge]++
    Reject { [ChatStillObserver]::AssertFrame($rect, $moved, 0, 800, 800) } 'moved after its first frame'
}
Reject { [ChatStillObserver]::AssertFrame($rect, $rect, 1, 800, 800) } 'Half-laid-out'
Reject { [ChatStillObserver]::AssertFrame($rect, $rect, 0, 800, 799) } 'Half-laid-out'
Reject { [ChatStillObserver]::AssertFrame($rect, $null, 0, 800, 800) } 'moved after its first frame'
$flags = [Reflection.BindingFlags]'NonPublic,Instance'
$observer = New-Object ChatStillObserver
$observer.GetType().GetField('first', $flags).SetValue($observer, [double]1)
$observer.GetType().GetField('key', $flags).SetValue($observer, '42/10')
$observer.GetType().GetField('latest', $flags).SetValue($observer, '99/10')
$observer.GetType().GetField('target', $flags).SetValue($observer, $true)
Reject { $observer.GetType().GetMethod('Sample', $flags).Invoke($observer, @([IntPtr]::Zero, 'paint')) } 'message disappeared'
$log = [IO.Path]::Combine($env:RUNNER_TEMP, 'chat-still-oracle.log')
try {
    [IO.File]::WriteAllText($log, "[chat-still] begin shell=7 dirty=0 width=800 layout=800 height=2000 view_h=600 view_top=0`n[chat-still] end`n")
    Reject { $observer.GetType().GetMethod('Read', $flags).Invoke($observer, @([string]$log, '7', [IntPtr]::Zero)) } 'flickered blank'
} finally { Remove-Item $log -ErrorAction SilentlyContinue }
Write-Host 'PASS: exact rectangle, first-frame dirty layout, width mismatch, missing identity and blank paint controls'

$crop = [int[]]@(100, 200, 102, 202)
$pixels = [byte[]]@(20, 30, 40, 0, 70, 80, 90, 0, 21, 31, 41, 0, 71, 81, 91, 0)
[ChatStillObserver]::AssertPixels($pixels, $pixels, 2, $crop, $null)
$changed = [byte[]]$pixels.Clone()
$changed[4]++
Reject { [ChatStillObserver]::AssertPixels($pixels, $changed, 2, $crop, $null) } 'pixels changed after the first frame'
Reject { [ChatStillObserver]::AssertPixels($pixels, [byte[]]@(0), 2, $crop, $null) } 'pixel area changed'
[ChatStillObserver]::AssertPixels($pixels, $changed, 2, $crop, [int[]]@(100, 200, 102, 202))
Reject { [ChatStillObserver]::AssertPixels($pixels, $changed, 2, $crop, [int[]]@(101, 201, 102, 202)) } 'pixels changed after the first frame'
$overlay = [byte[]]$pixels.Clone()
$overlay[12]++
[ChatStillObserver]::AssertPixels($pixels, $overlay, 2, $crop, [int[]]@(101, 201, 102, 202))
Reject { [ChatStillObserver]::AssertPixels($pixels, $overlay, 2, $crop, [int[]]@(100, 200, 101, 201)) } 'pixels changed after the first frame'
Write-Host 'PASS: a one-frame pixel change fails even with unchanged paint rectangles, and only the declared pill is masked'
$live = @(
    '[chat] new messages count=0 visible=0 up=1 rect=0,0,0,0',
    '[chat] new messages count=1 visible=1 up=1 rect=534,546,762,572',
    'unrelated line') -join "`n"
$lastSeen = [ChatStillObserver]::ParseOverlay($live)
if (($lastSeen -join ',') -ne '534,546,762,572') { throw 'The oracle did not read the declared pill rectangle' }
$cleared = @(
    '[chat] new messages count=1 visible=1 up=1 rect=534,546,762,572',
    '[chat] new messages count=1 visible=0 up=0 rect=0,0,0,0') -join "`n"
$dismissed = [ChatStillObserver]::ParseOverlay($cleared)
if ($null -ne $dismissed) { throw 'The oracle kept masking a dismissed pill' }
if ($null -ne [ChatStillObserver]::ParseOverlay('unrelated line')) { throw 'The oracle invented a pill rectangle' }
$inflated = [ChatStillObserver]::Inflate([int[]]@(534, 546, 762, 572), 2)
if (($inflated -join ',') -ne '532,544,764,574') { throw 'The pill mask does not allow for the painted border' }
Write-Host 'PASS: the declared pill rectangle is read from the live log, cleared when dismissed and inflated by its border'
