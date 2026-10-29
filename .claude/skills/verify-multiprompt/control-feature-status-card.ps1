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
            Assert-AppVersionInk 'pill-closed' $pages[2] $scale
            if ($usagePaceSnapshot) {
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Usage pace screenshot coordinates unavailable' }
                $offsetX = $origin.X - $frame.Left
                $expected = @($usagePaceSnapshot.accounts | ForEach-Object { foreach ($name in @('week', 'five_hour')) { if ($null -ne $_.$name.used) { $_.$name.pace.verdict } } } | Where-Object { $_ -in @('above', 'below') } | Sort-Object -Unique)
                $pillBounds = @($offsetX, $pages[2].top, ($offsetX + [int][Math]::Round(240 * $scale)), ($pages[2].bottom + 1))
                $closedInk = Measure-UsagePaceInk -Name 'pill-closed' -Bounds $pillBounds
                Assert-UsagePaceInk $closedInk $usagePaceSnapshot 'usage pill'
                $paceProof = [ordered]@{ expectedInks = $expected; closed = $closedInk; panel = $null; bounds = @{ closed = $pillBounds; panel = $null }; sourceTs = $usageSourceTs; replayTs = $usagePaceSnapshot.ts; sourceSha256 = (Get-FileHash $env:VERIFY_USAGE_PACE_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); normalSshReads = @(Get-Content (Join-Path $scratch 'usage-ssh-read.log')).Count }
            }
            $pillX = [int][Math]::Round(60 * $scale)
            $pillY = $client.Bottom - [int][Math]::Round(14 * $scale)
            Record 'Real click: expand AI usage pill'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')) } 'AI usage data panel visible'
            $menu = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', 'AI usage this week')
            Snapshot 'pill-open'
            Snapshot 'action'
            $look = Assert-UsageCardPixels 'pill-open' $pages[2] $scale
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

            if ([IO.File]::ReadAllText($statusFile).Trim() -ne '2') { throw 'AI data panel changed the selected status page' }
            Snapshot 'after'
            $result.statusCard = [ordered]@{ heights = $heights; minimum = 20; maximum = 30; pages = $pages; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look }; usagePace = $paceProof }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; heights = $heights; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true; entry = 'Ctrl+Shift+G' }
