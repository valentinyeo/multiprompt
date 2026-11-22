Add-Type -AssemblyName System.Windows.Forms
$marker = 'SOFT3048SCROLL-42'

function Read-VisibleShellText {
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        [VerifyNative]::DragSelectClient($shell, 1, 1, [int]($client.Right - 2), [int]($client.Bottom - 2))
        Start-Sleep -Milliseconds 120
        [System.Windows.Forms.Clipboard]::Clear()
        Press @(0x11, 0x43) 'Ctrl+C: copy the selected server shell text'
        try {
            if ([System.Windows.Forms.Clipboard]::ContainsText()) { return [System.Windows.Forms.Clipboard]::GetText() }
        } catch {}
    }
    throw 'Ctrl+C never copied the selected server shell text'
}

function Get-FirstScrollIndex([string]$Text) {
    $found = [regex]::Match($Text, 'scroll-(\d{3})')
    if (-not $found.Success) { return -1 }
    return [int]$found.Groups[1].Value
}

$check = @{ name = 'server-shell-input'; passed = $false; marker = $marker }
$result.checks += $check
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.shared_server_connection -eq $true -and @($saved.tabs).Count -ge 1
} 'shared-connection VPS tab restored' 120
Wait-Until {
    Test-Path (Join-Path $serverShellState 'ready.json')
} 'boundary painted the server shell transcript' 180
$shell = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MPTerminal', $null)
if ($shell -eq [IntPtr]::Zero -or [VerifyNative]::GetAncestor($shell, 2) -ne $script:window) { throw 'Native server shell child is missing' }
$client = New-Object VerifyNative+Rect
Wait-Until {
    [void][VerifyNative]::GetClientRect($shell, [ref]$client)
    $client.Right -gt 0 -and $client.Bottom -gt 0
} 'native server shell client area' 60
[VerifyNative]::ClickClient($shell, [int]($client.Right / 2), [int]($client.Bottom - 12))
Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -eq $shell } 'native server shell holds keyboard focus' 30
Snapshot 'server-shell-ready'
$visible = Read-VisibleShellText
if ($visible -notlike ('*' + $marker + '*')) { throw 'Ctrl+C did not copy the seeded server shell line' }
$beforeIndex = Get-FirstScrollIndex $visible
if ($beforeIndex -lt 0) { throw 'Ctrl+C copied no seeded scrollback from the server shell' }
Snapshot 'server-shell-copied'
Press @(0x0D) 'Enter: acknowledge the shell prompt'
Type-Text 'sleep 3600'
Press @(0x0D) 'Enter: start a blocking command'
Start-Sleep -Milliseconds 400
Press @(0x11, 0x43) 'Ctrl+C: interrupt the blocking command with nothing selected'
Wait-Until {
    Test-Path (Join-Path $serverShellState 'interrupt.json')
} 'boundary recorded the interrupt bytes' 20
Snapshot 'server-shell-interrupted'
$wheelX = [int]($client.Right / 2)
$wheelY = [int]($client.Bottom / 2)
Snapshot 'server-shell-before-wheel'
for ($step = 0; $step -lt 12; $step++) {
    [VerifyNative]::WheelClientPoint($script:window, [uint32]$process.Id, $shell, $wheelX, $wheelY, 120)
    Start-Sleep -Milliseconds 50
}
Snapshot 'server-shell-after-wheel'
$scrolled = Read-VisibleShellText
$afterIndex = Get-FirstScrollIndex $scrolled
if ($afterIndex -lt 0 -or $afterIndex -ge $beforeIndex) { throw ('Wheel up did not scroll back through server shell output: ' + $beforeIndex + ' to ' + $afterIndex) }
$check.passed = $true
$check.clipboard = $marker
$check.interrupt = $true
$check.beforeScroll = $beforeIndex
$check.afterScroll = $afterIndex
Save-Json $check 'server-shell-input-proof.json'
