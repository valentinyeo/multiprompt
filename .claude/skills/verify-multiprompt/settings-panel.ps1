Press @(0x11, 0xBC) 'Ctrl+Comma: open Settings'
Wait-Until {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    [VerifyNative]::Class($candidate) -eq 'MultipromptSettings'
} 'centred Settings panel opened through its keyboard shortcut'
$settingsWindow = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
[uint32]$settingsPid = 0
[void][VerifyNative]::GetWindowThreadProcessId($settingsWindow, [ref]$settingsPid)
if ($settingsPid -ne $process.Id) { throw 'Settings belongs to another process' }
Snapshot 'settings-panel'
Press @(0x1B) 'Escape: close Settings'
Wait-Until { -not [VerifyNative]::IsWindowVisible($settingsWindow) } 'Settings dismissed with Escape'
Palette 'settings'
Press @(0x0D) 'Enter: open Settings from the command palette'
Wait-Until {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    [VerifyNative]::Class($candidate) -eq 'MultipromptSettings'
} 'Settings opened through its palette entry'
Snapshot 'settings-palette'
Press @(0x1B) 'Escape: return to the workspace'
$result.checks += @{ name = 'settings-open-dismiss'; shortcut = 'Ctrl+Comma'; palette = 'Settings'; ownerPid = $settingsPid }
