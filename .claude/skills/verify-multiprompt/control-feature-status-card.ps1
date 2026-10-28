function Measure-UsagePaceInk([string]$Name, [int[]]$Bounds) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    $counts = [ordered]@{ above = 0; below = 0 }
    $palette = @{ above = @(245, 165, 65); below = @(85, 190, 115) }
    try {
        for ($y = [Math]::Max(0, $Bounds[1]); $y -lt [Math]::Min($image.Height, $Bounds[3]); $y++) {
            for ($x = [Math]::Max(0, $Bounds[0]); $x -lt [Math]::Min($image.Width, $Bounds[2]); $x++) {
                $pixel = $image.GetPixel($x, $y)
                foreach ($grade in $palette.Keys) {
                    $color = $palette[$grade]
                    if ([Math]::Max([Math]::Abs($pixel.R - $color[0]), [Math]::Max([Math]::Abs($pixel.G - $color[1]), [Math]::Abs($pixel.B - $color[2]))) -le 18) { $counts[$grade]++ }
                }
            }
        }
    } finally { $image.Dispose() }
    return $counts
}

            $paceProof = $null
            if ($env:VERIFY_USAGE_PACE_FILE) {
                Wait-Until { Test-Path (Join-Path $scratch 'usage-ssh-read.log') } 'Token Ladder status fetched through the normal SSH boundary' 240
            }
            $client = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client)) { throw 'status-card client rectangle unavailable' }
            $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
            Doctor
            Assert-Foreground
            Record 'Mouse: move away from the sidebar status card'
            [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
            $statusFile = Join-Path $scratch 'roaming/ZigShell/sidebar-status-card.txt'
            $pages = @()
            $heights = @()
            foreach ($page in 0..2) {
                if ($page -gt 0) {
                    Press @(0x11, 0x10, 0x47) ('Ctrl+Shift+G: status card page ' + ($page + 1))
                    Wait-Until { (Test-Path -LiteralPath $statusFile) -and ([IO.File]::ReadAllText($statusFile).Trim() -eq [string]$page) } ('status card page ' + ($page + 1) + ' saved by the app')
                    Start-Sleep -Milliseconds 500
                }
                $shot = 'status-card-' + ($page + 1)
                Snapshot $shot
                $measure = Measure-StatusCard $shot
                $measure.page = $page + 1
                $pages += $measure
                $heights += $measure.height
            }
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages }
            Save-Json $result.statusCard 'status-card.json'
            foreach ($height in $heights) {
                if ($height -gt 30 -or $height -lt 20) { throw ('status-card: card height ' + $height + ' outside 20..30; heights ' + ($heights -join ', ')) }
            }
            if (($pages[2].clientBottom - $pages[2].bottom) / $scale -gt 35) { throw 'IGSH-908: usage pill has no frame at the sidebar bottom' }
            Snapshot 'pill-closed'
            if ($usagePaceSnapshot) {
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Usage pace screenshot coordinates unavailable' }
                $offsetX = $origin.X - $frame.Left
                $expected = @($usagePaceSnapshot.accounts | ForEach-Object { foreach ($name in @('week', 'five_hour')) { if ($null -ne $_.$name.used) { $_.$name.pace.verdict } } } | Where-Object { $_ -in @('above', 'below') } | Sort-Object -Unique)
                $pillBounds = @($offsetX, $pages[2].top, ($offsetX + [int][Math]::Round(240 * $scale)), ($pages[2].bottom + 1))
                $closedInk = Measure-UsagePaceInk -Name 'pill-closed' -Bounds $pillBounds
                foreach ($grade in $expected) {
                    if ($closedInk[$grade] -lt 12) { throw "IGSH-997: usage pill lacks $grade pace ink" }
                }
                $paceProof = [ordered]@{ expectedInks = $expected; closed = $closedInk; panel = $null; bounds = @{ closed = $pillBounds; panel = $null }; sourceTs = $usageSourceTs; replayTs = $usagePaceSnapshot.ts; sourceSha256 = (Get-FileHash $env:VERIFY_USAGE_PACE_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); normalSshReads = @(Get-Content (Join-Path $scratch 'usage-ssh-read.log')).Count }
            }
            $pillX = [int][Math]::Round(60 * $scale)
            $pillY = $client.Bottom - [int][Math]::Round(14 * $scale)
            Record 'Real click: expand AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'AI usage data panel visible'
            $menu = @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible })[0]
            $look = [VerifyNative]::MenuLook([IntPtr]::new([int64]$menu.handle))
            if ($look.cornerShown -or $look.leftEdge -ne $look.fill -or $look.rightEdge -ne $look.fill) { throw 'IGSH-908: expanded usage panel differs from the existing rounded menu style' }
            Snapshot 'pill-open'
            Snapshot 'action'
            if ($paceProof) {
                $panel = New-Object VerifyNative+Rect
                if (-not [VerifyNative]::GetWindowRect([IntPtr]::new([int64]$menu.handle), [ref]$panel)) { throw 'Usage pace panel rectangle unavailable' }
                $paceProof.bounds.panel = @(($panel.Left - $frame.Left), ($panel.Top - $frame.Top), ($panel.Right - $frame.Left), ($panel.Bottom - $frame.Top))
                $paceProof.panel = Measure-UsagePaceInk -Name 'pill-open' -Bounds $paceProof.bounds.panel
                foreach ($grade in $paceProof.expectedInks) {
                    if ($paceProof.panel[$grade] -lt 12) { throw "IGSH-997: expanded panel lacks $grade pace ink" }
                }
            }
            Record 'Real second click: close AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on second click'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'usage panel reopens'
            Press @(0x1B) 'Escape: dismiss AI usage panel'
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on Escape'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'usage panel reopens before outside click'
            [VerifyNative]::ClickClient($script:window, [int]($client.Right * 3 / 4), ($client.Bottom - [int][Math]::Round(4 * $scale)))
            Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'usage panel closes on outside click'
            Snapshot 'pill-dismissed'
            if ([IO.File]::ReadAllText($statusFile).Trim() -ne '2') { throw 'AI data panel changed the selected status page' }
            Snapshot 'after'
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look }; usagePace = $paceProof }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; heights = $heights; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true; entry = 'Ctrl+Shift+G' }
