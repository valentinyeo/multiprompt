function Assert-AppVersionInk([string]$Name, $Pill, [double]$Scale) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $ink = 0
        for ($y = [int]($Pill.top - 22 * $Scale); $y -lt [int]($Pill.top - 2 * $Scale); $y++) {
            for ($x = [int](24 * $Scale); $x -lt [int](180 * $Scale); $x++) {
                $color = $image.GetPixel($x, $y)
                if ($color.R -ge 65 -and $color.R -le 120 -and [Math]::Abs($color.R - $color.G) -lt 4 -and [Math]::Abs($color.G - $color.B) -lt 4) { $ink++ }
            }
        }
        if ($ink -lt 20) { throw 'IGSH-1086: installed version is missing above the usage pill' }
    } finally { $image.Dispose() }
}

function Assert-UsageCardPixels([string]$Name, $Pill, [double]$Scale) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $counts = @{ panel = 0; track = 0; used = 0; dim = 0 }
        $x0 = [int](16 * $Scale)
        $x1 = [int](320 * $Scale)
        $bottom = [int]($Pill.top - 8 * $Scale)
        $top = [Math]::Max([int](8 * $Scale), [int]($bottom - 401 * $Scale))
        for ($y = $top; $y -lt $bottom; $y++) {
            for ($x = $x0; $x -lt $x1; $x++) {
                $pixel = $image.GetPixel($x, $y)
                if ($pixel.R -eq 24 -and $pixel.G -eq 24 -and $pixel.B -eq 24) { $counts.panel++ }
                if ($pixel.R -eq 42 -and $pixel.G -eq 42 -and $pixel.B -eq 42) { $counts.track++ }
                if ($pixel.R -ge 220 -and $pixel.G -ge 220 -and $pixel.B -ge 220) { $counts.used++ }
                if ($pixel.R -eq 138 -and $pixel.G -eq 138 -and $pixel.B -eq 138) { $counts.dim++ }
            }
        }
        if ($counts.panel -lt 10000 -or $counts.track -lt 300 -or $counts.used -lt 300 -or $counts.dim -lt 100) { throw ('IGSH-1086: approved usage card lacks panel, quota bars or readable detail: ' + ($counts | ConvertTo-Json -Compress)) }
        return $counts
    } finally { $image.Dispose() }
}

function Assert-UsagePaceInk([Collections.IDictionary]$Counts, $Snapshot, [string]$Surface) {
    $marks = @{ above = 0; below = 0 }
    foreach ($account in $Snapshot.accounts) {
        foreach ($name in @('week', 'five_hour')) {
            $window = $account.$name
            if ($null -ne $window.used -and $window.pace.verdict -in @('above', 'below')) { $marks[$window.pace.verdict]++ }
        }
    }
    $grades = @($marks.Keys | Where-Object { $marks[$_] -gt 0 })
    foreach ($grade in $grades) {
        $minimum = if ($grades.Count -eq 1) { 12 } else { 2 * $marks[$grade] }
        if ($Counts[$grade] -lt $minimum) { throw "IGSH-997: $Surface lacks $grade pace ink" }
    }
}

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
            $logPath = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logStart = if (Test-Path $logPath) { (Get-Content $logPath -Raw).Length } else { 0 }
            Palette 'manual'
            Press @(0x0D) 'Enter: use manual tab order'
            Wait-Until { (Test-Path $logPath) -and (Get-Content $logPath -Raw).Substring($logStart) -match '\[confirm\].*target=6218' } 'manual order command selected'
            Wait-Until {
                $s = Read-Inbox
                $null -ne $s -and @($s.shells).Count -eq 16 -and @($s.shells | Where-Object { $_.sid -eq $s.active_shell_id -and $_.name -ceq 'Footer last row' }).Count -eq 1
            } 'seeded last session selected' 60
            $order = Read-Inbox
            if (@($order.shells)[-1].name -cne 'Footer last row') { throw 'Selected session is not last in manual sidebar order' }
            $result.rowIdentity = @{ activeShellId = $order.active_shell_id; selected = 'Footer last row'; order = @($order.shells | ForEach-Object { $_.name }); manualOrder = $true }
            Doctor
            Assert-Foreground
            Record 'Mouse: move away from the sidebar status card'
            [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
            $frame = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Footer screenshot coordinates unavailable' }
            $footerTop = $origin.Y - $frame.Top + $client.Bottom - [int][Math]::Round(104 * $scale)
            $footer = @{ top = $footerTop; bottom = $origin.Y - $frame.Top + $client.Bottom; clientBottom = $origin.Y - $frame.Top + $client.Bottom }
            for ($i = 0; $i -lt 12; $i++) { [VerifyNative]::WheelClient($script:window, [int](100 * $scale), [int](200 * $scale), -1200) }
            Start-Sleep -Milliseconds 500
            Snapshot 'footer-bottom-a'
            for ($i = 0; $i -lt 3; $i++) { [VerifyNative]::WheelClient($script:window, [int](100 * $scale), [int](200 * $scale), -1200) }
            Start-Sleep -Milliseconds 500
            if ($UpdateFixtureRoot) {
                Wait-Until {
                    Snapshot 'footer-pending-test-key'
                    $pendingImage = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'footer-pending-test-key.png'))
                    try {
                        $p = $pendingImage.GetPixel(($origin.X - $frame.Left + [int](25 * $scale)), ($footerTop + [int](75 * $scale)))
                        $p.R -eq 53 -and $p.G -eq 53 -and $p.B -eq 53
                    } finally { $pendingImage.Dispose() }
                } 'signed staged update pill visible' 60
            }
            Snapshot 'pill-closed'
            $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'pill-closed.png'))
            try {
                $pixel = $image.GetPixel(($origin.X - $frame.Left + [int](50 * $scale)), $footerTop)
                if ($pixel.R -ne 46 -or $pixel.G -ne 46 -or $pixel.B -ne 46) { throw 'Footer divider is missing' }
                $offsetX = $origin.X - $frame.Left
                $dividerPixels = 0
                for ($dx = [int](8 * $scale); $dx -lt [int](290 * $scale); $dx++) {
                    $p = $image.GetPixel($offsetX + $dx, $footerTop)
                    if ($p.R -eq 46 -and $p.G -eq 46 -and $p.B -eq 46) { $dividerPixels++ }
                }
                if ($dividerPixels -lt [int](250 * $scale)) { throw 'Footer divider is not continuous' }
                $x = $offsetX + [int][Math]::Round(270 * $scale)
                $selected = @()
                for ($y = $origin.Y - $frame.Top; $y -lt $footerTop; $y++) {
                    $p = $image.GetPixel($x, $y)
                    if ($p.R -eq 58 -and $p.G -eq 58 -and $p.B -eq 58) { $selected += $y }
                }
                if ($selected.Count -lt [int](40 * $scale)) { throw 'Selected last row is not fully visible' }
                $rowTop = ($selected | Measure-Object -Minimum).Minimum
                $rowBottom = ($selected | Measure-Object -Maximum).Maximum + 1
                if ($rowBottom -gt $footerTop -or ($rowBottom - $rowTop) -lt [int](50 * $scale)) { throw 'Last row overlaps or is clipped by the footer' }
                $before = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'footer-bottom-a.png'))
                try {
                    for ($y = $rowTop; $y -lt $rowBottom; $y++) {
                        if ($before.GetPixel($x, $y).ToArgb() -ne $image.GetPixel($x, $y).ToArgb()) { throw 'Sidebar moved after bottom scroll' }
                    }
                } finally { $before.Dispose() }
                $result.footerGeometry = @{ dividerTop = $footerTop; clientBottom = $footer.clientBottom; rowTop = $rowTop; rowBottom = $rowBottom; sidebarWidth = [int](300 * $scale); scale = $scale; scrollStable = $true }
                if ($usagePaceSnapshot -and @($usagePaceSnapshot.accounts).Count -eq 3) {
                    $barWidth = [Math]::Floor((300 - 32 - 20) / 3)
                    $bars = @()
                    for ($i = 0; $i -lt 3; $i++) {
                        $used = $usagePaceSnapshot.accounts[$i].week.used
                        $bx = $offsetX + [int][Math]::Round((16 + $i * ($barWidth + 10) + 5) * $scale)
                        $by = $footerTop + [int][Math]::Round(35 * $scale)
                        $barPixel = $image.GetPixel($bx, $by)
                        $expected = if ($null -eq $used) { @(16,16,16) } elseif ($used -ge 100) { @(242,139,130) } elseif ($used -ge 85) { @(240,196,75) } else { @(242,242,242) }
                        if ($barPixel.R -ne $expected[0] -or $barPixel.G -ne $expected[1] -or $barPixel.B -ne $expected[2]) { throw "Usage bar $i color mismatch: $barPixel" }
                        $bars += @{ pool = $i; used = $used; x = $bx; y = $by; rgb = @($barPixel.R, $barPixel.G, $barPixel.B) }
                    }
                    $result.footerBars = $bars
                }
            } finally { $image.Dispose() }
            $result.statusCard = [ordered]@{ expectedFooterTop = $footerTop; clientBottom = $footer.clientBottom; scale = $scale }
            Save-Json $result.statusCard 'status-card.json'
            if ($usagePaceSnapshot) {
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Usage pace screenshot coordinates unavailable' }
                $offsetX = $origin.X - $frame.Left
                $expected = @($usagePaceSnapshot.accounts | ForEach-Object { foreach ($name in @('week', 'five_hour')) { if ($null -ne $_.$name.used) { $_.$name.pace.verdict } } } | Where-Object { $_ -in @('above', 'below') } | Sort-Object -Unique)
                $pillBounds = @($offsetX, $footer.top, ($offsetX + [int][Math]::Round(240 * $scale)), ($footer.bottom + 1))
                $closedInk = Measure-UsagePaceInk -Name 'pill-closed' -Bounds $pillBounds
                $paceProof = [ordered]@{ expectedInks = $expected; closed = $closedInk; panel = $null; bounds = @{ closed = $pillBounds; panel = $null }; sourceTs = $usageSourceTs; replayTs = $usagePaceSnapshot.ts; sourceSha256 = (Get-FileHash $env:VERIFY_USAGE_PACE_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); normalSshReads = @(Get-Content (Join-Path $scratch 'usage-ssh-read.log')).Count }
            }
            $pillX = [int][Math]::Round(60 * $scale)
            $pillY = $client.Bottom - [int][Math]::Round(80 * $scale)
            $hoverFocus = [VerifyNative]::GetFocusedWindow($script:window)
            $hoverResults = @()
            foreach ($column in @(45, 130, 215)) {
                [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
                [VerifyNative]::MoveMouseClient($script:window, [int]($column * $scale), $pillY, $false)
                Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'hover opens usage card'
                $hoverMenu = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')
                $during = [VerifyNative]::GetFocusedWindow($script:window)
                if ($during -ne $hoverFocus) { throw 'Usage hover changed keyboard focus' }
                [VerifyNative]::MoveMouseClient($hoverMenu, [int]($column * $scale), ($client.Bottom - [int](114 * $scale)), $false)
                if (-not [VerifyNative]::IsWindowVisible($hoverMenu)) { throw 'Usage hover closed crossing the popup bridge' }
                Snapshot ("footer-hover-$column")
                [VerifyNative]::MoveMouseClient($hoverMenu, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
                Wait-Until { -not [VerifyNative]::IsWindowVisible($hoverMenu) } 'usage hover closes on exit'
                if ([VerifyNative]::GetFocusedWindow($script:window) -ne $hoverFocus) { throw 'Usage hover exit changed keyboard focus' }
                $hoverResults += @{ x = $column; focus = $during.ToInt64(); bridge = $true; closed = $true }
            }
            $result.hover = $hoverResults
            Record 'Real click: expand AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'AI usage data panel visible'
            $menu = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')
            Snapshot 'pill-open'
            Snapshot 'action'
            $look = Assert-UsageCardPixels 'pill-open' $footer $scale
            if ($paceProof) {
                $paceProof.panel = $look
            }
            Record 'Real second click: close AI usage pill'
            [VerifyNative]::ClickClient($menu, $pillX, $pillY)
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'usage panel closes on second click'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'usage panel reopens'
            Press @(0x1B) 'Escape: dismiss AI usage panel'
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'usage panel closes on Escape'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'usage panel reopens before outside click'
            [VerifyNative]::ClickClient($menu, [int]($client.Right * 3 / 4), ($client.Bottom - [int][Math]::Round(4 * $scale)))
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'usage panel closes on outside click'
            Snapshot 'pill-dismissed'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible($menu) } 'usage panel reopens for release notes'
            Press @(0x09) 'Tab: focus release notes'
            Press @(0x0D) 'Enter: open release notes'
            Wait-Until { -not [VerifyNative]::IsWindowVisible($menu) } 'release notes closes usage card'
            Snapshot 'usage-release-notes'
            Press @(0x1B) 'Escape: close release notes'

            Press @(0x11, 0x4B) 'Ctrl+K opens palette above the footer'
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match '\[palette\] ready' } 'palette opened'
            Snapshot 'footer-palette'
            Press @(0x1B) 'Escape closes palette'
            Press @(0x11, 0x10, 0x42) 'Collapse sidebar'
            Snapshot 'footer-collapsed'
            Press @(0x11, 0x10, 0x47) 'Cycle collapsed status card'
            Snapshot 'footer-collapsed-cycled'
            Press @(0x11, 0x10, 0x42) 'Hide sidebar'
            Snapshot 'footer-hidden'
            Press @(0x11, 0x10, 0x42) 'Restore expanded sidebar'
            Snapshot 'after'
            $result.statusCard = [ordered]@{ footerTop = $footerTop; clientBottom = $footer.clientBottom; scale = $scale; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look }; usagePace = $paceProof }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true }
