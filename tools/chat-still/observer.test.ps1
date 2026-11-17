$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/observer.cs"
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
$log = Join-Path $env:RUNNER_TEMP 'chat-still-oracle.log'
try {
    [IO.File]::WriteAllText($log, "[chat-still] begin shell=7 dirty=0 width=800 layout=800 height=2000`n[chat-still] end`n")
    Reject { $observer.GetType().GetMethod('Read', $flags).Invoke($observer, @($log, '7', [IntPtr]::Zero)) } 'flickered blank'
} finally { Remove-Item $log -ErrorAction SilentlyContinue }
Write-Host 'PASS: exact rectangle, first-frame dirty layout, width mismatch, missing identity and blank paint controls'
