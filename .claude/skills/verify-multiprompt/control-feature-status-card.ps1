function Assert-UsageCardPixels([string]$Name, [int[]]$Bounds, $Palette) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $counts = @{ panel = 0; track = 0; ink = 0; dim = 0 }
        for ($y = [Math]::Max(0, $Bounds[1]); $y -lt [Math]::Min($image.Height, $Bounds[3]); $y++) {
            for ($x = [Math]::Max(0, $Bounds[0]); $x -lt [Math]::Min($image.Width, $Bounds[2]); $x++) {
                $pixel = $image.GetPixel($x, $y)
                if ($pixel.R -eq $Palette.panel[0] -and $pixel.G -eq $Palette.panel[1] -and $pixel.B -eq $Palette.panel[2]) { $counts.panel++ }
                elseif ($pixel.R -eq $Palette.track[0] -and $pixel.G -eq $Palette.track[1] -and $pixel.B -eq $Palette.track[2]) { $counts.track++ }
                elseif ($pixel.R -ge 220 -and $pixel.G -ge 220 -and $pixel.B -ge 220) { $counts.ink++ }
                elseif ($pixel.R -eq $Palette.label[0] -and $pixel.G -eq $Palette.label[1] -and $pixel.B -eq $Palette.label[2]) { $counts.dim++ }
            }
        }
        if ($counts.panel -lt 10000 -or $counts.track -lt 300 -or $counts.ink -lt 20 -or $counts.dim -lt 100) { throw ('IGSH-1086: approved usage card lacks panel, quota bars or readable detail: ' + ($counts | ConvertTo-Json -Compress)) }
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
            $launchPath = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
            Wait-Until {
                if (-not (Test-Path $launchPath)) { return $false }
                $published = Get-Content $launchPath -Raw | ConvertFrom-Json
                $null -ne $published.PSObject.Properties['sort_auto'] -and $published.sidebar_width -ge 100
            } 'app publishes its tab-order and sidebar state before the footer proof' 20
            $sidebarWidth = [int](Get-Content $launchPath -Raw | ConvertFrom-Json).sidebar_width
            if ([bool](Get-Content $launchPath -Raw | ConvertFrom-Json).sort_auto) {
                Invoke-JourneyCommand 'Tab order: auto' -Confirm {
                    Press @(0x0D) 'Enter: switch to manual tab order for a stable footer proof'
                }
            }
            $confirmedAt = [DateTime]::UtcNow
            Press @(0x11, 0x09) 'Ctrl+Tab: refresh manual session export'
            $inboxPath = Join-Path $scratch 'roaming/ZigShell/inbox-default.json'
            Wait-Until {
                if (-not (Test-Path $inboxPath) -or (Get-Item $inboxPath).LastWriteTimeUtc -le $confirmedAt) { return $false }
                $saved = Read-Session
                $live = Read-Inbox
                if ($null -eq $saved -or $null -eq $live -or @($saved.tabs).Count -ne 16 -or @($live.shells).Count -ne 16) { return $false }
                $savedIds = @($saved.tabs | ForEach-Object { [string]$_.shell_id })
                $liveIds = @($live.shells | ForEach-Object { [string]$_.sid })
                ($savedIds -join ',') -ceq ($liveIds -join ',')
            } 'fresh inbox and saved manual order agree' 60
            $manualExportAt = (Get-Item $inboxPath).LastWriteTimeUtc
            $savedOrder = Read-Session
            $order = Read-Inbox
            $target = @($savedOrder.tabs)[-1]
            $targetId = [string]$target.shell_id
            $targetName = [string]$target.name
            if (-not $targetId -or -not $targetName -or @($order.shells | Where-Object { [string]$_.sid -ceq $targetId -and $_.name -ceq $targetName }).Count -ne 1) { throw 'Last manual session identity is ambiguous' }
            $orderedIds = @($savedOrder.tabs | ForEach-Object { [string]$_.shell_id }) -join ','
            Invoke-JourneyCommand $targetName -Session -SelectOnly
            $selectedAt = [DateTime]::UtcNow
            Press @(0x0D) 'Enter: select last manual session'
            Wait-Until {
                if (-not (Test-Path $inboxPath) -or (Get-Item $inboxPath).LastWriteTimeUtc -le $selectedAt) { return $false }
                $saved = Read-Session
                $live = Read-Inbox
                if ($null -eq $saved -or $null -eq $live -or @($saved.tabs).Count -ne 16 -or @($live.shells).Count -ne 16) { return $false }
                $savedIds = @($saved.tabs | ForEach-Object { [string]$_.shell_id }) -join ','
                $liveIds = @($live.shells | ForEach-Object { [string]$_.sid }) -join ','
                $savedIds -ceq $orderedIds -and $liveIds -ceq $orderedIds -and [string]$saved.active_shell_id -ceq $targetId -and [string]$live.active_shell_id -ceq $targetId -and @($live.shells | Where-Object { [string]$_.sid -ceq $targetId -and $_.name -ceq $targetName }).Count -eq 1
            } 'last manual session selected with stable order' 60
            $result.rowIdentity = @{ activeShellId = $targetId; selected = $targetName; order = @($savedOrder.tabs | ForEach-Object { @{ id = [string]$_.shell_id; name = $_.name } }); manualOrder = $true; confirmationUtc = $confirmedAt.ToString('o'); manualExportUtc = $manualExportAt.ToString('o'); selectionUtc = $selectedAt.ToString('o'); selectionExportUtc = (Get-Item $inboxPath).LastWriteTimeUtc.ToString('o') }
            Doctor
            Assert-Foreground
            Record 'Mouse: move away from the sidebar status icon'
            [VerifyNative]::MoveMouseClient($script:window, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2), $false)
            $frame = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Status icon screenshot coordinates unavailable' }
            $iconGeometry = & node (Join-Path $PSScriptRoot '../../../tools/usage-icon-geometry.js') | ConvertFrom-Json
            if ($LASTEXITCODE -ne 0 -or $null -eq $iconGeometry) { throw 'Status icon geometry unavailable from the app source' }
            $offsetX = $origin.X - $frame.Left
            $offsetY = $origin.Y - $frame.Top
            $clientBottom = $offsetY + $client.Bottom
            $icon = @{
                left = $offsetX + [int][Math]::Round($iconGeometry.icon.left * $scale)
                right = $offsetX + [int][Math]::Round($iconGeometry.icon.right * $scale)
                top = $clientBottom - [int][Math]::Round($iconGeometry.icon.topInset * $scale)
                bottom = $clientBottom - [int][Math]::Round($iconGeometry.icon.bottomInset * $scale)
                centerX = $offsetX + [int][Math]::Round($iconGeometry.icon.centerX * $scale)
                centerY = $clientBottom - [int][Math]::Round($iconGeometry.icon.centerYInset * $scale)
            }
            for ($i = 0; $i -lt 12; $i++) { [VerifyNative]::WheelClient($script:window, [uint32]$process.Id, [int](100 * $scale), [int](200 * $scale), -1200) }
            Start-Sleep -Milliseconds 500
            Snapshot 'footer-bottom-a'
            for ($i = 0; $i -lt 3; $i++) { [VerifyNative]::WheelClient($script:window, [uint32]$process.Id, [int](100 * $scale), [int](200 * $scale), -1200) }
            Start-Sleep -Milliseconds 500
            if ($UpdateFixtureRoot) {
                Wait-Until {
                    Snapshot 'footer-pending-test-key'
                    $pendingImage = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'footer-pending-test-key.png'))
                    try {
                        $restart = 0
                        for ($y = $clientBottom - [int][Math]::Round(80 * $scale); $y -lt $clientBottom - [int][Math]::Round(8 * $scale); $y++) {
                            for ($x = $offsetX; $x -lt $offsetX + [int][Math]::Round(290 * $scale); $x++) {
                                $p = $pendingImage.GetPixel($x, $y)
                                if ($p.R -eq 242 -and $p.G -eq 242 -and $p.B -eq 242) { $restart++ }
                            }
                        }
                        $restart -ge [int](500 * $scale * $scale)
                    } finally { $pendingImage.Dispose() }
                } 'signed staged update card shows its Restart button' 60
            }
            Snapshot 'pill-closed'
            $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'pill-closed.png'))
            try {
                $iconProof = [ordered]@{ bounds = @($icon.left, $icon.top, $icon.right, $icon.bottom); center = @($icon.centerX, $icon.centerY); clientBottom = $clientBottom; scale = $scale }
                if ($UpdateFixtureRoot) {
                    $iconProof.coveredBy = 'the pending update card floats over the sidebar bottom'
                } else {
                    $fill = @($iconGeometry.paint.fill)
                    $track = @($iconGeometry.paint.track)
                    $inside = @(
                        $icon.centerX
                        $icon.top + [int][Math]::Round(4 * $scale)
                        $icon.left + [int][Math]::Round(4 * $scale)
                        $icon.centerY
                        $icon.centerX + [int][Math]::Round(12 * $scale)
                        $icon.centerY + [int][Math]::Round(8 * $scale)
                    )
                    for ($i = 0; $i -lt $inside.Count; $i += 2) {
                        $p = $image.GetPixel($inside[$i], $inside[$i + 1])
                        if ($p.R -ne $fill[0] -or $p.G -ne $fill[1] -or $p.B -ne $fill[2]) { throw "Status icon is missing at $($inside[$i]),$($inside[$i + 1]): $p" }
                    }
                    $outside = @(
                        $icon.left - [int][Math]::Round(2 * $scale)
                        $icon.centerY
                        $icon.right + [int][Math]::Round(1 * $scale)
                        $icon.centerY
                        $icon.centerX
                        $icon.top - [int][Math]::Round(2 * $scale)
                        $icon.centerX
                        $icon.bottom + [int][Math]::Round(1 * $scale)
                    )
                    for ($i = 0; $i -lt $outside.Count; $i += 2) {
                        $p = $image.GetPixel($outside[$i], $outside[$i + 1])
                        if ($p.R -eq $fill[0] -and $p.G -eq $fill[1] -and $p.B -eq $fill[2]) { throw "Status icon paints outside its published bounds at $($outside[$i]),$($outside[$i + 1])" }
                    }
                    $disc = 0
                    $gauge = 0
                    $usageInk = 0
                    for ($y = $icon.top; $y -lt $icon.bottom; $y++) {
                        for ($x = $icon.left; $x -lt $icon.right; $x++) {
                            $p = $image.GetPixel($x, $y)
                            if ($p.R -eq $fill[0] -and $p.G -eq $fill[1] -and $p.B -eq $fill[2]) { $disc++ }
                            elseif ($p.R -eq $track[0] -and $p.G -eq $track[1] -and $p.B -eq $track[2]) { $gauge++ }
                            elseif (($p.R -eq $p.G -and $p.G -eq $p.B -and $p.R -ge 90) -or ($p.R -ge 220 -and $p.G -ge 60 -and $p.G -le 180 -and $p.B -le 90)) { $usageInk++ }
                        }
                    }
                    if ($disc -lt [int](600 * $scale * $scale)) { throw "Status icon disc is missing: $disc px" }
                    if ($gauge -lt [int](40 * $scale * $scale)) { throw "Status icon gauge track is missing: $gauge px" }
                    if ($usageInk -lt [int](8 * $scale * $scale)) { throw "Status icon gauge shows no usage ink: $usageInk px" }
                    $removedFooterTop = $clientBottom - [int][Math]::Round(104 * $scale)
                    $dividerPixels = 0
                    for ($dx = [int](8 * $scale); $dx -lt [int](290 * $scale); $dx++) {
                        $p = $image.GetPixel($offsetX + $dx, $removedFooterTop)
                        if ($p.R -eq 46 -and $p.G -eq 46 -and $p.B -eq 46) { $dividerPixels++ }
                    }
                    if ($dividerPixels -ge [int](250 * $scale)) { throw 'The removed footer divider is back across the sidebar bottom' }
                    $barPixels = 0
                    for ($y = $removedFooterTop; $y -lt $clientBottom; $y++) {
                        for ($dx = [int](8 * $scale); $dx -lt [int](290 * $scale); $dx++) {
                            $p = $image.GetPixel($offsetX + $dx, $y)
                            if (($p.R -eq 240 -and $p.G -eq 196 -and $p.B -eq 75) -or ($p.R -eq 242 -and $p.G -eq 139 -and $p.B -eq 130)) { $barPixels++ }
                        }
                    }
                    if ($barPixels -gt 0) { throw "The removed footer usage bars are back: $barPixels px" }
                    $x = $offsetX + [int][Math]::Round(270 * $scale)
                    $selected = @()
                    for ($y = $offsetY; $y -lt $clientBottom; $y++) {
                        $p = $image.GetPixel($x, $y)
                        if ($p.R -eq 58 -and $p.G -eq 58 -and $p.B -eq 58) { $selected += $y }
                    }
                    if ($selected.Count -lt [int](40 * $scale)) { throw 'Selected last row is not fully visible' }
                    $rowTop = ($selected | Measure-Object -Minimum).Minimum
                    $rowBottom = ($selected | Measure-Object -Maximum).Maximum + 1
                    if ($rowBottom -gt $clientBottom -or ($rowBottom - $rowTop) -lt [int](50 * $scale)) { throw 'Last row overlaps or is clipped by the sidebar bottom' }
                    $before = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'footer-bottom-a.png'))
                    try {
                        for ($y = $rowTop; $y -lt $rowBottom; $y++) {
                            if ($before.GetPixel($x, $y).ToArgb() -ne $image.GetPixel($x, $y).ToArgb()) { throw 'Sidebar moved after bottom scroll' }
                        }
                    } finally { $before.Dispose() }
                    $iconProof.disc = $disc
                    $iconProof.gauge = $gauge
                    $iconProof.usageInk = $usageInk
                    $iconProof.dividerPixels = $dividerPixels
                    $iconProof.barPixels = $barPixels
                    $iconProof.rowTop = $rowTop
                    $iconProof.rowBottom = $rowBottom
                    $iconProof.scrollStable = $true
                }
                $result.statusIcon = $iconProof
            } finally { $image.Dispose() }
            $result.statusCard = [ordered]@{ iconBounds = @($icon.left, $icon.top, $icon.right, $icon.bottom); iconCenter = @($icon.centerX, $icon.centerY); clientBottom = $clientBottom; scale = $scale }
            Save-Json $result.statusCard 'status-card.json'
            if ($usagePaceSnapshot) {
                $expected = @($usagePaceSnapshot.accounts | ForEach-Object { foreach ($name in @('week', 'five_hour')) { if ($null -ne $_.$name.used) { $_.$name.pace.verdict } } } | Where-Object { $_ -in @('above', 'below') } | Sort-Object -Unique)
                $pillBounds = @($icon.left, $icon.top, $icon.right, ($icon.bottom + 1))
                $closedInk = Measure-UsagePaceInk -Name 'pill-closed' -Bounds $pillBounds
                $paceProof = [ordered]@{ expectedInks = $expected; closed = $closedInk; panel = $null; bounds = @{ closed = $pillBounds; panel = $null }; sourceTs = $usageSourceTs; replayTs = $usagePaceSnapshot.ts; sourceSha256 = (Get-FileHash $env:VERIFY_USAGE_PACE_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); normalSshReads = @(Get-Content (Join-Path $scratch 'usage-ssh-read.log')).Count }
            }
            $pillX = $icon.centerX
            $pillY = $icon.centerY
            $hoverFocus = [VerifyNative]::GetFocusedWindow($script:window)
            $hoverResults = @()
            $beforeHover = $null
            $afterHover = $null
            $hoverWaitStarted = $null
            $hoverPhase = 'move-away'
            try {
                $beforeHover = [VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY)
                [VerifyNative]::MoveMouseOwnedRoot($script:window, [uint32]$process.Id, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2))
                $beforeHover = [VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY)
                $hoverPhase = 'move-to-icon'
                [VerifyNative]::MoveMouseOwnedRoot($script:window, [uint32]$process.Id, $pillX, $pillY)
                $hoverPhase = 'observe-after-move'
                $afterHover = [VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY)
                $hoverPhase = 'wait-for-card'
                $hoverWaitStarted = [DateTime]::UtcNow.ToString('o')
                Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'hover on the status icon opens the usage card'
                $hoverPhase = 'move-to-card'
                $hoverMenu = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)
                $during = [VerifyNative]::GetFocusedWindow($script:window)
                if ($during -ne $hoverFocus) { throw 'Usage hover changed keyboard focus' }
                [VerifyNative]::MoveMouseClient($hoverMenu, $pillX, ($client.Bottom - [int][Math]::Round($iconGeometry.icon.topInset * $scale) - [int][Math]::Round(4 * $scale)), $true)
                if (-not [VerifyNative]::IsWindowVisible($hoverMenu)) { throw 'Usage hover closed crossing the popup bridge' }
                Snapshot 'footer-hover-icon'
                $hoverPhase = 'live-console-probe'
                $console = [VerifyNative]::GetForegroundWindow()
                if ([VerifyNative]::GetAncestor($console, 3) -ne $script:window -or [VerifyNative]::Class($console) -cne 'ConsoleWindowClass' -or -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $targetId), [StringComparison]::Ordinal)) { throw 'Live hover requires the selected owned CMD console' }
                $consoleRect = New-Object VerifyNative+Rect
                if (-not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect)) { throw 'Owned console bounds unavailable' }
                Snapshot 'hover-console-before'
                [VerifyNative]::Text('for /l %i in (1,1,24) do @echo LIVE HOVER 1190 OUTPUT 0123456789')
                [VerifyNative]::Chord(@(0x0D))
                if ([VerifyNative]::GetForegroundWindow() -ne $console -or -not [VerifyNative]::IsWindowVisible($hoverMenu)) { throw 'Typing changed console focus or dismissed hover' }
                Start-Sleep -Milliseconds 1000
                Snapshot 'hover-console-after'
                $beforeConsole = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'hover-console-before.png'))
                $afterConsole = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'hover-console-after.png'))
                try {
                    $x0 = [Math]::Max($origin.X - $frame.Left + [int](320 * $scale), $consoleRect.Left - $frame.Left + 8)
                    $x1 = [Math]::Min($beforeConsole.Width, $consoleRect.Right - $frame.Left - 8)
                    $y0 = [Math]::Max(0, $consoleRect.Top - $frame.Top + 8)
                    $y1 = [Math]::Min($beforeConsole.Height, $consoleRect.Bottom - $frame.Top - 8)
                    if ($x1 -le $x0 -or $y1 -le $y0) { throw 'Visible console comparison area is empty' }
                    $changed = 0
                    for ($y = $y0; $y -lt $y1; $y++) {
                        for ($x = $x0; $x -lt $x1; $x++) {
                            $a = $beforeConsole.GetPixel($x, $y)
                            $b = $afterConsole.GetPixel($x, $y)
                            if ([Math]::Abs($a.R - $b.R) -gt 40 -or [Math]::Abs($a.G - $b.G) -gt 40 -or [Math]::Abs($a.B - $b.B) -gt 40) { $changed++ }
                        }
                    }
                    if ($changed -lt 1500) { throw "Live console pixels did not change under hover: $changed" }
                    $result.liveHover = @{ console = $console.ToInt64(); selectedId = $targetId; changedPixels = $changed; area = @($x0, $y0, $x1, $y1); marker = 'LIVE HOVER 1190 OUTPUT'; hoverVisible = $true }
                } finally { $beforeConsole.Dispose(); $afterConsole.Dispose() }
                $hoverPhase = 'move-away-from-card'
                [VerifyNative]::MoveMouseOwnedRoot($script:window, [uint32]$process.Id, [int]($client.Right * 3 / 4), [int]($client.Bottom / 2))
                $hoverPhase = 'wait-for-close'
                Wait-Until { -not [VerifyNative]::IsWindowVisible($hoverMenu) } 'usage hover closes on exit'
                if ([VerifyNative]::GetFocusedWindow($script:window) -ne $hoverFocus) { throw 'Usage hover exit changed keyboard focus' }
                $hoverResults += @{ x = $pillX; y = $pillY; focus = $during.ToInt64(); bridge = $true; closed = $true }
            } catch {
                $hoverFailure = $_
                try { $failedHover = [VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY) } catch { $failedHover = @{ error = $_.Exception.Message } }
                try {
                    Save-Json @{ x = $pillX; y = $pillY; phase = $hoverPhase; waitStartedUtc = $hoverWaitStarted; error = $hoverFailure.Exception.Message; expectedClass = 'MultiPromptUsageCard'; expectedTitle = $iconGeometry.card.title; before = $beforeHover; after = $afterHover; atFailure = $failedHover } 'footer-hover-observation.json'
                } catch { Write-Host "Hover observation save failed: $($_.Exception.Message)" }
                throw $hoverFailure
            }
            $result.hover = $hoverResults
            Record 'Real click: expand the usage card from the status icon'
            for ($attempt = 0; $attempt -lt 20 -and [VerifyNative]::GetForegroundWindow() -ne $script:window; $attempt++) {
                [void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)
                [void][VerifyNative]::SetForegroundWindow($script:window)
                Start-Sleep -Milliseconds 100
            }
            if ([VerifyNative]::GetForegroundWindow() -ne $script:window) { throw 'App frame did not reach the foreground for the real click' }
            [VerifyNative]::MoveMouseOwnedRoot($script:window, [uint32]$process.Id, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'hover card is up before the real click'
            [VerifyNative]::ClickClient($hoverMenu, $pillX, $pillY)
            Save-Json ([VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY)) 'footer-click.json'
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'AI usage data panel visible'
            $menu = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)
            Snapshot 'pill-open'
            Snapshot 'action'
            $cardBottom = $icon.top - [int][Math]::Round($iconGeometry.card.gap * $scale)
            $cardSidebar = $offsetX + [int][Math]::Round($sidebarWidth * $scale)
            $cardBounds = @(
                ($icon.left + [int][Math]::Round(2 * $scale)),
                ($cardBottom - [int][Math]::Round(220 * $scale)),
                [Math]::Min(($icon.left + [int][Math]::Round($iconGeometry.card.maxWidth * $scale) - [int][Math]::Round(2 * $scale)), $cardSidebar),
                $cardBottom
            )
            $look = Assert-UsageCardPixels 'pill-open' $cardBounds $iconGeometry.card
            if ($paceProof) {
                $paceProof.panel = $look
            }
            Record 'Real second click: close AI usage pill'
            [VerifyNative]::ClickClient($menu, $pillX, $pillY)
            Save-Json ([VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, $pillX, $pillY)) 'footer-click-second.json'
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'usage panel closes on second click'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'usage panel reopens'
            Press @(0x1B) 'Escape: dismiss AI usage panel'
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'usage panel closes on Escape'
            [VerifyNative]::ClickClient($script:window, $pillX, $pillY)
            Wait-Until { [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'usage panel reopens before outside click'
            [VerifyNative]::ClickClient($menu, [int]($client.Right * 3 / 4), ($client.Bottom - [int][Math]::Round(4 * $scale)))
            Wait-Until { -not [VerifyNative]::IsWindowVisible([VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptUsageCard', $iconGeometry.card.title)) } 'usage panel closes on outside click'
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
            $result.statusCard = [ordered]@{ iconBounds = @($icon.left, $icon.top, $icon.right, $icon.bottom); iconCenter = @($icon.centerX, $icon.centerY); clientBottom = $clientBottom; scale = $scale; usagePanel = @{ secondClick = $true; escape = $true; outside = $true; look = $look }; usagePace = $paceProof }
            Save-Json $result.statusCard 'status-card.json'
            $result.checks += @{ name = 'status-card'; usagePill = $true; menuStyle = $true; secondClick = $true; escape = $true; outside = $true }
