Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/layout-capture.cs')
[LayoutCapture]::Display()
[void][VerifyNative]::ShowWindow($script:window, 9)
[void][VerifyNative]::MoveWindow($script:window, 0, 0, 1920, 1032, $true)
foreach ($attempt in 1..3) {
    $client = New-Object VerifyNative+Rect
    $frame = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or -not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Inbox window geometry unavailable' }
    if ($client.Right -eq 1920 -and $client.Bottom -eq 1032) { break }
    [void][VerifyNative]::MoveWindow($script:window, 0, 0, ($frame.Right - $frame.Left + 1920 - $client.Right), ($frame.Bottom - $frame.Top + 1032 - $client.Bottom), $true)
}
Wait-Until { [void][VerifyNative]::GetClientRect($script:window, [ref]$client); $client.Right -eq 1920 -and $client.Bottom -eq 1032 } 'screenshot-sized Inbox client'
if ([VerifyNative]::GetDpiForWindow($script:window) -ne 96) { throw 'Screenshot proof requires 96 DPI' }
$session = Read-Session
if ($session.PSObject.Properties['ui_scale'] -and $session.ui_scale -ne 100) { throw 'Screenshot proof requires default UI scale' }
Select-Theme 'amoled' 'inbox-space-theme'
foreach ($count in 2..18) {
    Palette 'new cmd'
    Press @(0x0D) 'Enter: add an existing CMD session to the Inbox'
    Wait-Until { $state = Read-Session; @($state.tabs).Count -eq $count } "app saved $count user-created sessions"
}
Wait-Until { $state = Read-Inbox; @($state.shells).Count -eq 18 } 'all user-created sessions published'
Save-Json (Read-Session) 'inbox-space-sessions.json'
Press @(0x12, 0x49) 'Alt+I: open All Inbox'
Wait-Until { (Read-Inbox).inbox_active } 'All Inbox visible'
foreach ($step in 1..20) { Press @(0x26) 'Up: select the first Inbox row' }
Snapshot 'before'
foreach ($step in 1..15) { Press @(0x28) 'Down: select the sixteenth Inbox row' }
Snapshot 'action'
$origin = New-Object VerifyNative+Point
if (-not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Inbox screenshot origin unavailable' }
$left = 500
$top = 72 + 15 * 58
$bitmap = [Drawing.Bitmap]::new((Join-Path $Evidence 'action.png'))
$selectedPixels = 0
try {
    foreach ($y in (($top + 8)..($top + 47))) {
        foreach ($x in (($left + 100)..($left + 819))) {
            $color = $bitmap.GetPixel($origin.X - $frame.Left + $x, $origin.Y - $frame.Top + $y)
            if ([Math]::Abs($color.R - 53) -le 2 -and [Math]::Abs($color.G - 53) -le 2 -and [Math]::Abs($color.B - 53) -le 2) { $selectedPixels++ }
        }
    }
} finally { $bitmap.Dispose() }
Save-Json @{clientWidth=$client.Right; clientHeight=$client.Bottom; rowTop=$top; rowBottom=($top + 56); footerTop=1002; selectedPixels=$selectedPixels; sessions=18} 'inbox-space-pixels.json'
if ($selectedPixels -lt 20000) { throw "IGSH1688_UNUSED_INBOX_SPACE: sixteenth row not painted in the empty band ($selectedPixels selected pixels)" }
Press @(0x71) 'F2: read the newly visible row identity'
$script:inboxSpaceRename = [IntPtr]::Zero
Wait-Until {
    $handle = [VerifyNative]::GetFocusedWindow($script:window)
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    if ($element.Current.ProcessId -eq $process.Id -and $element.Current.ClassName -eq 'Edit' -and [VerifyNative]::Title($handle).Length -gt 0) { $script:inboxSpaceRename = $handle; return $true }
    $false
} 'owned rename edit identifies the sixteenth row'
$expectedName = [VerifyNative]::Title($script:inboxSpaceRename)
Snapshot 'inbox-space-rename'
Press @(0x1B) 'Esc: cancel rename without changing the row'
Wait-Until { (Read-Inbox).inbox_active -and [VerifyNative]::GetFocusedWindow($script:window) -ne $script:inboxSpaceRename } 'Inbox remains open after cancel'
Record 'Click the newly visible sixteenth Inbox row'
[VerifyNative]::ClickClient($script:window, 960, ($top + 28))
Wait-Until { $state = Read-Inbox; $null -ne $state -and -not $state.inbox_active } 'bottom row opens its session'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].name -ceq $expectedName } 'opened session matches the visible bottom row'
Snapshot 'after'
$result.checks += @{name='inbox-space-bottom-row'; sessions=18; row=16; selectedPixels=$selectedPixels; openedName=$expectedName; clientWidth=1920; clientHeight=1032; rowBottom=998; footerTop=1002; source='real palette-created CMD sessions; no seeded history or settings'}
