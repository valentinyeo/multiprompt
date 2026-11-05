function Capture-InboxFooter([string]$Theme, [string]$State) {
    $name = "inbox-footer-$Theme-$State"
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $true } "Inbox active for $name"
    [VerifyNative]::MoveMouseClient($script:window, 5, 5, $false)
    Snapshot $name
    $frame = New-Object VerifyNative+Rect
    $client = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or
        -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
        -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Inbox footer geometry unavailable' }
    $dpi = [VerifyNative]::GetDpiForWindow($script:window)
    $session = Read-Session
    $uiScale = if ($session.PSObject.Properties['ui_scale']) { [int]$session.ui_scale } else { 100 }
    if ($dpi -eq 0 -or $uiScale -le 0) { throw 'Inbox footer DPI or UI scale unavailable' }
    $scale = $dpi * $uiScale / 9600.0
    $width = $client.Right - $client.Left
    $height = $client.Bottom - $client.Top
    $listWidth = [Math]::Min([int][Math]::Floor(920 * $scale), $width - [int][Math]::Floor(24 * $scale))
    $left = [int][Math]::Floor(($width - $listWidth) / 2)
    $inset = [Math]::Max(2, [int][Math]::Ceiling(4 * $scale))
    $x0 = $left + $inset
    $x1 = $left + $listWidth - $inset
    $y0 = $height - [int][Math]::Floor(30 * $scale) + $inset
    $y1 = $height - $inset
    $dx = $origin.X - $frame.Left
    $dy = $origin.Y - $frame.Top
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($name + '.png')))
    try {
        if ($x0 -lt 0 -or $y0 -lt 0 -or $x1 -le $x0 -or $y1 -le $y0 -or $dx + $x1 -gt $image.Width -or $dy + $y1 -gt $image.Height) { throw 'Inbox footer region outside screenshot' }
        $background = $image.GetPixel($dx + $x0, $dy + $y0)
        $pixels = 0
        for ($y = $y0; $y -lt $y1; $y++) {
            for ($x = $x0; $x -lt $x1; $x++) {
                $pixel = $image.GetPixel($dx + $x, $dy + $y)
                if ([Math]::Abs([int]$pixel.R - [int]$background.R) -gt 3 -or [Math]::Abs([int]$pixel.G - [int]$background.G) -gt 3 -or [Math]::Abs([int]$pixel.B - [int]$background.B) -gt 3) { $pixels++ }
            }
        }
        $measurement = @{ name = 'inbox-footer'; theme = $Theme; state = $State; screenshot = "$name.png"; pixels = $pixels; background = @($background.R, $background.G, $background.B); clientRegion = @($x0, $y0, $x1, $y1); dpi = $dpi; uiScale = $uiScale }
        $script:footerMeasurements += $measurement
        $result.checks += $measurement
        Save-Json $script:footerMeasurements 'inbox-footer-pixels.json'
    } finally { $image.Dispose() }
}

$script:footerMeasurements = @()
Wait-Until { $s = Read-Session; $null -ne $s -and @($s.tabs).Count -eq 1 -and $s.tabs[0].kind -eq 'cmd' } 'one initial CMD session'
Wait-Until { $s = Read-Inbox; $null -ne $s -and @($s.shells).Count -eq 1 } 'one published Inbox session'
$initialInbox = Read-Inbox
$sid = $initialInbox.shells[0].sid
$matchQuery = [string]$initialInbox.shells[0].name
if ([string]::IsNullOrWhiteSpace($matchQuery) -or $matchQuery -notmatch '^[ -~]+$') { throw 'Published CMD name must be nonempty ASCII for keyboard search' }
$themes = @(
    @{ query = 'light'; token = 'light' },
    @{ query = 'amoled'; token = 'amoled' },
    @{ query = 'edge grey'; token = 'edgegray' },
    @{ query = 'dark'; token = 'dark' },
    @{ query = 'mid'; token = 'mid' },
    @{ query = 'multi bot'; token = 'multiprompt' },
    @{ query = 'system'; token = 'system' }
)
$result.checks += @{ name = 'inbox-footer-unavailable-theme'; theme = 'Graphite 2'; reason = 'not shipped; not an alias' }
$result.checks += @{ name = 'inbox-footer-unavailable-release-theme'; theme = 'Dev Blue'; reason = 'development builds only' }
foreach ($theme in $themes) {
    $token = $theme.token
    Select-Theme $theme.query ("inbox-footer-$token-theme") $token
    Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $true } 'Inbox opened'
    Press @(0x12, 0x49) 'Alt+I: select All'
    Capture-InboxFooter $token 'normal'
    if ($token -eq 'light') { Snapshot 'action' }

    Press @(0x11, 0x46) 'Ctrl+F: search Inbox'
    Capture-InboxFooter $token 'search-empty'
    Type-Text 'zzzznomatch1677'
    Capture-InboxFooter $token 'search-no-match'
    Press @(0x0D) 'Enter: no matching session to open'
    Capture-InboxFooter $token 'search-no-match-enter'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $true } 'no-match Enter keeps Inbox open'
    Press @(0x11, 0x46) 'Ctrl+F: restart Inbox search'
    Type-Text $matchQuery
    Capture-InboxFooter $token 'search-match'
    Press @(0x0D) 'Enter: open matching CMD shell'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $false -and $s.active_shell_id -eq $sid } 'matching search opened the published session'
    Wait-Until { $s = Read-Session; $null -ne $s -and @($s.tabs).Count -eq 1 -and $s.active_tab -eq 0 -and $s.tabs[0].shell_id -eq $sid } 'matching session selected and saved'
    Press @(0x12, 0x49) 'Alt+I: open All Inbox'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $true } 'Alt+I opened Inbox'
    Press @(0x11, 0x46) 'Ctrl+F: search before Escape'
    Type-Text 'zzzznomatch1677'
    Press @(0x1B) 'Esc: clear and close search'
    Capture-InboxFooter $token 'search-cleared'
    $beforeAttention = (Read-Inbox).shells[0].att
    Press @(0x55) 'U: toggle selected session read state after search clear'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.shells[0].att -ne $beforeAttention } 'U toggled published attention after Escape'
    $changedAttention = (Read-Inbox).shells[0].att
    Press @(0x55) 'U: restore session read state'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.shells[0].att -eq $beforeAttention } 'U restored published attention'
    Press @(0x11, 0x10, 0x55) 'Ctrl+Shift+U: enable unread only'
    Wait-Until { $s = Read-Session; $null -ne $s -and $s.PSObject.Properties['unread_only'] -and $s.unread_only } 'unread-only saved'
    Capture-InboxFooter $token 'unread'
    Press @(0x11, 0x46) 'Ctrl+F: search unread-only Inbox'
    Type-Text 'zzzznomatch1677'
    Capture-InboxFooter $token 'unread-search'
    Press @(0x1B) 'Esc: close unread search'
    Press @(0x11, 0x10, 0x55) 'Ctrl+Shift+U: disable unread only'
    Wait-Until { $s = Read-Session; $null -ne $s -and (-not $s.PSObject.Properties['unread_only'] -or -not $s.unread_only) } 'unread-only cleared and saved'
    Capture-InboxFooter $token 'unread-cleared'
    Press @(0x1B) 'Esc: close Inbox'
    Wait-Until { $s = Read-Inbox; $null -ne $s -and $s.inbox_active -eq $false } 'Escape closed Inbox'
    Wait-Until { $s = Read-Session; $null -ne $s -and @($s.tabs).Count -eq 1 -and $s.tabs[0].shell_id -eq $sid } 'session survives Inbox journey'
    $result.checks += @{ name = 'inbox-footer-routing'; theme = $token; savedTheme = (Get-Content (Join-Path $scratch 'roaming/ZigShell/theme-mode.txt') -Raw).Trim(); sid = $sid; matchQuery = $matchQuery; attentionBefore = $beforeAttention; attentionChanged = $changedAttention; attentionRestored = (Read-Inbox).shells[0].att; unreadOnlyRestored = $true }
}
Snapshot 'after'
$visible = @($script:footerMeasurements | Where-Object { $_.pixels -ne 0 })
if ($visible.Count -gt 0) { throw ('Inbox shortcut legend still visible: ' + (($visible | ForEach-Object { "$($_.theme)/$($_.state)=$($_.pixels)" }) -join ', ')) }
