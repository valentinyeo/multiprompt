Add-Type -AssemblyName System.Windows.Forms
$marker = 'SOFT3048SCROLL-42'
$check = @{ name = 'server-shell-input'; passed = $false; marker = $marker }
$result.checks += $check
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.shared_server_connection -eq $true -and @($saved.tabs).Count -ge 1
} 'shared-connection VPS tab restored' 120
Wait-Until {
    Test-Path (Join-Path $serverShellState 'scroll-ready.json')
} 'boundary scrollback marker is ready' 180
$shell = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MPTerminal', $null)
if ($shell -eq [IntPtr]::Zero) { throw 'Native server shell child is missing' }
Wait-Until {
    [VerifyNative]::FocusOwnedWindow($script:window, $process.Id, $shell)
} 'native server shell focused' 60
Snapshot 'server-shell-ready'
$scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
$cellW = [int](8 * $scale)
$cellH = [int](16 * $scale)
[VerifyNative]::DragSelectClient($shell, $cellW * 2, $cellH * 3, $cellW * ($marker.Length + 3), $cellH * 4)
Start-Sleep -Milliseconds 200
Snapshot 'server-shell-selected'
[System.Windows.Forms.Clipboard]::Clear()
Press @(0x11, 0x43) 'Ctrl+C: copy the selected server shell line'
Wait-Until {
    [System.Windows.Forms.Clipboard]::ContainsText() -and [System.Windows.Forms.Clipboard]::GetText() -ceq $marker
} 'clipboard holds the selected marker' 10
Press @(0x0D) 'Enter: acknowledge the prompt'
Type-Text 'sleep 3600'
Press @(0x0D) 'Enter: start a blocking command'
Start-Sleep -Milliseconds 400
Press @(0x11, 0x43) 'Ctrl+C: interrupt the blocking command'
Wait-Until {
    Test-Path (Join-Path $serverShellState 'interrupt.json')
} 'boundary recorded interrupt input' 15
$wheelX = [int](220 * $scale)
$wheelY = [int](260 * $scale)
Snapshot 'server-shell-before-wheel'
for ($step = 0; $step -lt 12; $step++) {
    [VerifyNative]::WheelClient($script:window, [uint32]$process.Id, $wheelX, $wheelY, 120)
    Start-Sleep -Milliseconds 40
}
Snapshot 'server-shell-after-wheel'
$check.passed = $true
$check.clipboard = $marker
$check.interrupt = $true
Save-Json $check 'server-shell-input-proof.json'