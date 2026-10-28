
            Write-Host "group-rail verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            Select-Theme 'dark' 'group-rail-dark'
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep stable manual sidebar order'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.active_workspace -eq 0 -and $state.tabs[0].kind -eq 'cmd' } 'one initial CMD session'
            Press @(0x71) 'F2: rename first session'
            Press @(0x11, 0x41) 'Ctrl+A: replace first session name'
            Type-Text 'Rail A'
            Press @(0x0D) 'Enter: save first session name'
            Wait-Until { (Read-Session).tabs[0].name -eq 'Rail A' } 'short synthetic first name saved'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create second CMD session'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 } 'second CMD session saved and selected'
            Press @(0x71) 'F2: rename second session'
            Press @(0x11, 0x41) 'Ctrl+A: replace second session name'
            Type-Text 'Rail B'
            Press @(0x0D) 'Enter: save second session name'
            Wait-Until { (Read-Session).tabs[1].name -eq 'Rail B' } 'short synthetic second name saved'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create group for second session'
            Wait-Until { $state = Read-Session; $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[1].group_id -eq $state.groups[0].id } 'second session in new saved group'
            Press @(0x1B) 'Esc: finish default group name'
            $group = (Read-Session).groups[0]
            Press @(0x11, 0x31) 'Ctrl+1: select the original session in manual order'
            Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text $group.name
            Press @(0x0D) 'Enter: move first session into same group'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.tabs[0].group_id -eq $group.id -and $state.tabs[1].group_id -eq $group.id -and $state.active_tab -eq 0 } 'two real sessions saved in one group'
            foreach ($index in @(2, 3, 4, 5)) {
                Palette 'new cmd'
                Press @(0x0D) ('Enter: create CMD session ' + ($index + 1))
                Wait-Until { $state = Read-Session; @($state.tabs).Count -eq ($index + 1) -and $state.active_tab -eq $index } 'new CMD session saved and selected'
                Press @(0x71) 'F2: rename session'
                Press @(0x11, 0x41) 'Ctrl+A: replace session name'
                $name = 'Rail ' + [char](65 + $index)
                Type-Text $name
                Press @(0x0D) 'Enter: save short session name'
                Wait-Until { (Read-Session).tabs[$index].name -eq $name } 'short synthetic session name saved'
            }
            Press @(0x11, 0x33) 'Ctrl+3: select third session for second group'
            Wait-Until { (Read-Session).active_tab -eq 2 } 'third session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: create adjacent second group'
            Wait-Until { $state = Read-Session; @($state.groups).Count -eq 2 -and $state.tabs[2].group_id -eq $state.groups[1].id } 'third session in second saved group'
            Press @(0x1B) 'Esc: finish second default group name'
            $secondGroup = (Read-Session).groups[1]
            Press @(0x11, 0x34) 'Ctrl+4: select fourth session'
            Wait-Until { (Read-Session).active_tab -eq 3 } 'fourth session selected'
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text $secondGroup.name
            Press @(0x0D) 'Enter: move fourth session into second group'
            Wait-Until {
                $state = Read-Session
                @($state.tabs).Count -eq 6 -and @($state.groups).Count -eq 2 -and
                    $state.tabs[0].group_id -eq $group.id -and $state.tabs[1].group_id -eq $group.id -and
                    $state.tabs[2].group_id -eq $secondGroup.id -and $state.tabs[3].group_id -eq $secondGroup.id -and
                    (-not $state.tabs[4].PSObject.Properties['group_id'] -or $state.tabs[4].group_id -eq 0) -and
                    (-not $state.tabs[5].PSObject.Properties['group_id'] -or $state.tabs[5].group_id -eq 0)
            } 'two adjacent two-member groups followed by two ungrouped sessions'
            $state = Read-Session
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $noFill = $true
            $noRail = $true
            $flushLeft = $true
            foreach ($selected in @(0, 1)) {
                Press @(0x11, (0x31 + $selected)) ('Ctrl+' + ($selected + 1) + ': select grouped session')
                Wait-Until { (Read-Session).active_tab -eq $selected } 'grouped selection persisted'
                $shot = 'group-rail-selected-' + $selected
                Snapshot $shot
                $frame = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'group-rail native geometry unavailable' }
                $proof = [GroupRailProof]::Check((Join-Path $Evidence ($shot + '.png')), $frame, $origin, $dpi, $scale, $hidePills, $false)
                Save-Json @{ pixels = $proof; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; session = Read-Session; tag = $env:RELEASE_TAG; version = $ExpectedVersion } ($shot + '.json')
                $noFill = $noFill -and $proof['noFill']
                $noRail = $noRail -and $proof['noRail']
                $flushLeft = $flushLeft -and $proof['flushLeft']
                $result.checks += @{ name = $shot; pixels = $proof }
            }
            if ($noFill) { Write-Host 'sidebar-headline no-fill PASS' } else { Write-Host 'sidebar-headline no-fill FAIL' }
            if ($noRail) { Write-Host 'sidebar-headline no-rail PASS' } else { Write-Host 'sidebar-headline no-rail FAIL' }
            if ($flushLeft) { Write-Host 'sidebar-headline flush-left PASS' } else { Write-Host 'sidebar-headline flush-left FAIL' }
            $labels = [GroupRailProof]::Labels((Join-Path $Evidence 'group-rail-selected-1.png'), $frame, $origin, $dpi, $scale, [int]$proof['sidebarRect'][3], [int]$proof['nameX'][0], [int]$proof['rowHeight'])
            Save-Json @{ labels = $labels; pixels = $proof; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-labels.json'
            $result.checks += @{ name = 'sidebar-label-parity'; pixels = $labels }
            $sameStyle = [bool]$labels['sameStyle']
            $noArrow = [bool]$labels['noArrow']
            $plusOnly = [bool]$labels['plusOnly']
            if ($sameStyle) { Write-Host 'sidebar-label same-style PASS' } else { Write-Host 'sidebar-label same-style FAIL' }
            if ($noArrow) { Write-Host 'sidebar-label no-arrow PASS' } else { Write-Host 'sidebar-label no-arrow FAIL' }
            if ($plusOnly) { Write-Host 'sidebar-newtab plus-only PASS' } else { Write-Host 'sidebar-newtab plus-only FAIL' }
            $clickToggle = $false
            try {
                $beforeToggle = Read-Session
                $membership = ($beforeToggle.tabs | ForEach-Object { $g = 0; if ($_.PSObject.Properties['group_id']) { $g = $_.group_id }; [string]$_.shell_id + ':' + [string]$g }) -join ','
                $clickX = [int]$proof['nameX'][0] + 4 + $frame.Left - $origin.X
                if ($proof['nameX'][0] -lt 0) { $clickX = [int]([long]20 * $dpi * $scale / 9600) }
                $clickY = [int]$proof['headerTops'][0] + 14 + $frame.Top - $origin.Y
                Doctor
                Record 'Click the first group headline to hide its member sessions'
                [VerifyNative]::ClickClient($script:window, $clickX, $clickY)
                Wait-Until {
                    $state = Read-Session
                    $savedGroup = @($state.groups | Where-Object { $_.id -eq $group.id })
                    $savedGroup.Count -eq 1 -and $savedGroup[0].PSObject.Properties['collapsed'] -and $savedGroup[0].collapsed
                } 'headline click persisted the existing group collapsed memory'
                Snapshot 'group-rail-collapsed'
                $hidden = [GroupRailProof]::Check((Join-Path $Evidence 'group-rail-collapsed.png'), $frame, $origin, $dpi, $scale, $hidePills, $true)
                Save-Json @{ pixels = $hidden; session = Read-Session; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-collapsed.json'
                Doctor
                Record 'Click the same headline to restore its member sessions'
                Start-Sleep -Milliseconds 700
                [VerifyNative]::ClickClient($script:window, ($clickX + 24), $clickY)
                Wait-Until {
                    $state = Read-Session
                    $savedGroup = @($state.groups | Where-Object { $_.id -eq $group.id })
                    $savedGroup.Count -eq 1 -and (-not $savedGroup[0].PSObject.Properties['collapsed'] -or -not $savedGroup[0].collapsed)
                } 'headline click persisted expanded group memory'
                Snapshot 'group-rail-restored'
                $restored = [GroupRailProof]::Check((Join-Path $Evidence 'group-rail-restored.png'), $frame, $origin, $dpi, $scale, $hidePills, $false)
                $firstRow = [int]$proof['headerTops'][0] + [int]$proof['headerHeight']
                $scanBottom = [int]$proof['sidebarRect'][3] + 24 + 2 * [int]$proof['rowHeight']
                $toggle = [GroupRailProof]::Toggle((Join-Path $Evidence 'group-rail-selected-1.png'), (Join-Path $Evidence 'group-rail-collapsed.png'), (Join-Path $Evidence 'group-rail-restored.png'), [int]$proof['sessionTextX'][0], $firstRow, [int]$proof['rowHeight'], [int]$proof['headerTops'][0], $scanBottom, $dpi, $scale)
                $state = Read-Session
                $afterMembership = ($state.tabs | ForEach-Object { $g = 0; if ($_.PSObject.Properties['group_id']) { $g = $_.group_id }; [string]$_.shell_id + ':' + [string]$g }) -join ','
                $clickToggle = $toggle['membersDisappearAndReturn'] -and $membership -ceq $afterMembership -and @($state.tabs).Count -eq 6 -and @($state.groups).Count -eq 2
                Save-Json @{ pixels = $restored; toggle = $toggle; clickToggle = $clickToggle; before = $beforeToggle; session = $state; frame = $frame; origin = $origin; dpi = $dpi; scale = $scale; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'group-rail-restored.json'
                $result.checks += @{ name = 'sidebar-headline-click-toggle'; passed = $clickToggle; pixels = $toggle }
            } catch {
                Write-Host 'sidebar-headline click-toggle FAIL'
                throw
            }
            Snapshot 'after'
            if ($clickToggle) { Write-Host 'sidebar-headline click-toggle PASS' } else { Write-Host 'sidebar-headline click-toggle FAIL' }
            if (-not $noFill -or -not $noRail -or -not $flushLeft -or -not $clickToggle -or -not $sameStyle -or -not $noArrow -or -not $plusOnly) { throw 'sidebar-headline assertions failed' }
        