
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
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look } }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; heights = $heights; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true; entry = 'Ctrl+Shift+G' }
        