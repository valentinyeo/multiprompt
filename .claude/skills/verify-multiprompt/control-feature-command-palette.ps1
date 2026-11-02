
            $changelogSpeed = [ordered]@{ open_ms = @(); scroll_ms = @(); close_ms = @(); before_ms = @(); after_ms = @(); samples = 5; input = 'native SendInput'; completion = 'visible text patch changed and UI thread responded'; errors = 0 }
            for ($sample = 0; $sample -lt 5; $sample++) {
                $changelogSpeed.before_ms += [VerifyNative]::ChangelogResponse($script:window)
                Focus-Palette 'changelog' 6241
                $changelogSpeed.open_ms += [VerifyNative]::MeasureChangelogKey($script:window, 0x0D)
                if ($sample -eq 0) { Snapshot 'changelog-open' }
                $changelogSpeed.scroll_ms += [VerifyNative]::MeasureChangelogKey($script:window, 0x22)
                if ($sample -eq 0) { Snapshot 'changelog-scrolled' }
                $changelogSpeed.close_ms += [VerifyNative]::MeasureChangelogKey($script:window, 0x1B)
                $changelogSpeed.after_ms += [VerifyNative]::ChangelogResponse($script:window)
            }
            Save-Json $changelogSpeed 'changelog-speed.json'
            foreach ($kind in @('open_ms', 'scroll_ms', 'close_ms', 'after_ms')) {
                if (($changelogSpeed[$kind] | Measure-Object -Maximum).Maximum -ge 100) { throw ('Changelog ' + $kind + ' reached 100 milliseconds: ' + ($changelogSpeed[$kind] -join ', ')) }
            }
            Snapshot 'changelog-closed'
            $result.checks += @{ name = 'changelog-speed'; timings = $changelogSpeed; budget_ms = 100; entry = 'Ctrl+K Changelog' }
            function Test-FreshPaletteLog([string]$Path, [long]$From) {
                if (-not (Test-Path $Path)) { return $false }
                $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
                try {
                    $null = $stream.Seek($From, 'Begin')
                    $reader = New-Object IO.StreamReader($stream)
                    $fresh = $reader.ReadToEnd()
                } finally { $stream.Dispose() }
                return ($fresh -match '\[palette\] ready chars=\d+ count=\d+')
            }
            $commandsPath = Join-Path $scratch 'roaming/ZigShell/commands.json'
            New-Item -ItemType Directory -Force -Path (Split-Path $commandsPath) | Out-Null
            $folder = '/tmp/multiprompt-harness-folder'
            $seedNames = @('Other', 'Workspace 1', 'Workspace 2', 'Starred', 'Main', 'Software Factory', 'Verification')
            $seedEntries = @(foreach ($name in $seedNames) { [ordered]@{ label = ('Harness folder ' + $name); kind = 'vps'; folder_host = '0'; default = $true; workspace = $name; cwd = $folder } })
            $seedJson = [ordered]@{ commands = $seedEntries } | ConvertTo-Json -Depth 5
            [IO.File]::WriteAllText($commandsPath, $seedJson, (New-Object Text.UTF8Encoding($false)))
            Start-Sleep -Milliseconds 500
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logStart = if (Test-Path $debugLog) { (Get-Item $debugLog).Length } else { 0 }
            Palette ''
            Snapshot 'ctrl-k-empty'
            Save-Json (Read-Session) 'ctrl-k-empty.session.json'
            Press @(0x1B) 'Esc: close empty palette'
            Palette 'More shells'
            Snapshot 'more-shells-search'
            $logStart = if (Test-Path $debugLog) { (Get-Item $debugLog).Length } else { 0 }
            Press @(0x0D) 'Enter: More shells'
            Start-Sleep -Milliseconds 700
            $shellsOpened = (Test-FreshPaletteLog $debugLog $logStart)
            if (-not $shellsOpened) {
                Press @(0x28) 'Down: leave the most used header'
                Press @(0x0D) 'Enter: More shells again'
                Start-Sleep -Milliseconds 700
                $shellsOpened = (Test-FreshPaletteLog $debugLog $logStart)
            }
            Snapshot 'more-shells'
            Type-Text 'powershell'
            Start-Sleep -Milliseconds 400
            Snapshot 'more-shells-search-inside'
            Press @(0x1B) 'Esc: clear the sub-list query'
            $result.checks += @{ name = 'new-session-rows'; empty = 'ctrl-k-empty.png'; shells = 'more-shells.png'; fallbackDown = (-not $shellsOpened); commands = 'harness workspace folder seeded' }
            Press @(0x1B) 'Esc: close More shells'
            $tabRowsBefore = @(Get-Content $debugLog | Where-Object { $_ -match '\[palette\] rows chars=' }).Count
            Doctor
            Assert-Foreground
            Record 'Right-click the tab row for tab actions'
            [VerifyNative]::RightClickClient($script:window, 100, 127)
            Wait-Until { @(Get-Content $debugLog | Where-Object { $_ -match '\[palette\] rows chars=' }).Count -gt $tabRowsBefore } 'tab actions palette opened'
            Type-Text 'move chat'
            Wait-Until { @(Get-Content $debugLog | Where-Object { $_ -match '\[palette\] rows chars=9 ' }).Count -gt 0 } 'tab actions filtered by move chat'
            $moveRows = @(Get-Content $debugLog | Where-Object { $_ -match '\[palette\] rows chars=9 ' } | ForEach-Object { [string]$_ })
            if ($moveRows[-1] -match '\b7186\b') { throw 'A plain terminal tab without a Claude chat offered Move chat to new mode' }
            $result.checks += @{ name = 'move-chat-row-hidden-on-plain-tab'; rows = ('{0}' -f $moveRows[-1]); shot = 'move-chat-row.png' }
            Snapshot 'move-chat-row'
            Press @(0x1B) 'Esc: close tab actions'
            Remove-Item -LiteralPath $commandsPath -Force
            $repoCommands = Join-Path $scratch 'roaming/ZigShell/commands.json'
            New-Item -ItemType Directory -Force -Path (Split-Path $repoCommands) | Out-Null
            $repoFolder = '/tmp/multiprompt-harness-folder'
            $repoNames = @('Other', 'Workspace 1', 'Workspace 2', 'Starred', 'Main', 'Software Factory', 'Verification')
            $repoEntries = @(foreach ($name in $repoNames) { [ordered]@{ label = ('Harness folder ' + $name); kind = 'vps'; folder_host = '0'; default = $true; workspace = $name; cwd = $repoFolder } })
            [IO.File]::WriteAllText($repoCommands, ([ordered]@{ commands = $repoEntries } | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
            Start-Sleep -Milliseconds 500
            $repoTabsBefore = @((Read-Session).tabs).Count
            Press @(0x11, 0x54) 'Ctrl+T: new tab in the harness folder'
            Wait-Until { @((Read-Session).tabs).Count -eq $repoTabsBefore + 1 } 'harness folder tab open'
            Start-Sleep -Milliseconds 500
            $otherEntries = @($repoEntries | Where-Object { $_.workspace -ne 'Other' })
            [IO.File]::WriteAllText($repoCommands, ([ordered]@{ commands = $otherEntries } | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
            Start-Sleep -Milliseconds 700
            $pickTabsBefore = @((Read-Session).tabs).Count
            Palette 'pick repo'
            Snapshot 'pick-repo-row'
            Press @(0x0D) 'Enter: Pick repo'
            Wait-Until {
                $repoLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
                ((Get-Content $repoLog -Raw) -join '') -match '\[palette\] rows chars=0 count=2 ids=6702 6710'
            } 'Pick repo list shows Back and the harness folder repo'
            Snapshot 'pick-repo-list'
            $repoLogText = ((Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -join '')
            $repoRows = ([regex]::Matches($repoLogText, '\[palette\] rows chars=0 count=2 ids=6702 6710')).Count
            if ($repoRows -lt 1) { throw 'Pick repo list showed no repo row for the harness folder' }
            Press @(0x1B) 'Esc: leave Pick repo list'
            Snapshot 'pick-repo-back'
            Press @(0x1B) 'Esc: close command palette'
            $pickTabsAfter = @((Read-Session).tabs).Count
            if ($pickTabsAfter -ne $pickTabsBefore) { throw ('Pick repo changed the tab count: ' + $pickTabsBefore + ' -> ' + $pickTabsAfter) }
            $result.checks += @{ name = 'pick-repo-list'; row = 'pick-repo-row.png'; list = 'pick-repo-list.png'; back = 'pick-repo-back.png'; tabsBefore = $pickTabsBefore; tabsAfter = $pickTabsAfter; escapeLeavesTabs = $true; repoRows = $repoRows; repo = $repoFolder }
            $repoLogPath = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $repoListsBefore = ([regex]::Matches(((Get-Content $repoLogPath -Raw) -join ''), '\[palette\] rows chars=0 count=2 ids=6702 6710')).Count
            Palette 'pick repo'
            Press @(0x0D) 'Enter: reopen Pick repo'
            Wait-Until { ([regex]::Matches(((Get-Content $repoLogPath -Raw) -join ''), '\[palette\] rows chars=0 count=2 ids=6702 6710')).Count -gt $repoListsBefore } 'Pick repo list reopened'
            Press @(0x0D) 'Enter: open the harness folder repo'
            Wait-Until { @((Read-Session).tabs).Count -eq $pickTabsBefore + 1 } 'Pick repo opened one new tab'
            $openedTabs = @((Read-Session).tabs)
            $openedRepo = @($openedTabs | Where-Object { $_.PSObject.Properties.Name -contains 'cwd' -and $_.cwd -eq $repoFolder })
            if ($openedRepo.Count -ne 1) { throw ('Pick repo saved ' + $openedRepo.Count + ' tabs for the harness folder') }
            Doctor
            $crashReports = 0
            $crashRoot = Join-Path $scratch 'roaming/ZigShell/crashes'
            if (Test-Path -LiteralPath $crashRoot) { $crashReports = @(Get-ChildItem -LiteralPath $crashRoot -Filter 'crash-*.txt' -File -ErrorAction SilentlyContinue).Count }
            if ($crashReports -ne 0) { throw 'Pick repo left a crash report behind' }
            Snapshot 'pick-repo-opened'
            Press @(0x11, 0x57) 'Ctrl+W: close the tab Pick repo opened'
            Wait-Until { @((Read-Session).tabs).Count -eq $pickTabsBefore } 'Pick repo tab closed'
            $result.checks += @{ name = 'pick-repo-open'; shot = 'pick-repo-opened.png'; tabsBefore = $pickTabsBefore; tabsAfter = $openedTabs.Count; tabCwd = $openedRepo[0].cwd; crashReports = $crashReports }
            Press @(0x11, 0x57) 'Ctrl+W: close the harness folder tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $repoTabsBefore } 'harness folder tab closed'
            Snapshot 'pick-repo-closed'
            Remove-Item -LiteralPath $repoCommands -Force
            Palette 'interface'
            Snapshot 'action'
            Press @(0x0D) 'Enter: UI Size: Increase'
            Wait-Until { (Read-Session).ui_scale -eq 110 } 'UI scale saved as 110'
            Snapshot 'after'
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: UI Size: Reset'
            Wait-Until { $state = Read-Session; -not ($state.PSObject.Properties.Name -contains 'ui_scale') -or $state.ui_scale -eq 100 } 'UI scale reset to default'
            Snapshot 'reset'
            $result.checks += @{ name = 'palette-increase-reset'; increasedScale = 110; resetScale = 100 }
            Palette 'restart to update'
            Snapshot 'update-command'
            $image = New-Object Drawing.Bitmap((Join-Path $Evidence 'update-command.png'))
            $selectedTextPixels = 0
            try {
                $top = $image.Height
                $bottom = 0
                for ($y = [int]($image.Height * 0.2); $y -lt [int]($image.Height * 0.8); $y++) {
                    $pixel = $image.GetPixel([int]($image.Width / 2), $y)
                    if ($pixel.R -eq 53 -and $pixel.G -eq 53 -and $pixel.B -eq 53) {
                        $top = [Math]::Min($top, $y)
                        $bottom = [Math]::Max($bottom, $y)
                    }
                }
                for ($y = $top; $y -le $bottom; $y++) {
                    for ($x = [int]($image.Width * 0.3); $x -lt [int]($image.Width * 0.7); $x++) {
                        $pixel = $image.GetPixel($x, $y)
                        if ($pixel.R -gt 180 -and $pixel.G -gt 180 -and $pixel.B -gt 180) { $selectedTextPixels++ }
                    }
                }
                if ($selectedTextPixels -lt 40) { throw 'Update command row is blank or unreadable' }
            } finally { $image.Dispose() }
            Press @(0x0D) 'Enter: Restart to update with no update ready'
            Doctor
            Snapshot 'update-idle'
            $result.checks += @{ name = 'update-command-without-ready-keeps-session'; pid = $process.Id; scale = 100; selectedTextPixels = $selectedTextPixels }
            $snippetFile = Join-Path $scratch 'roaming/ZigShell/snippets.json'
            [IO.File]::WriteAllText($snippetFile, '{"version":1,"snippets":[{"name":"Remove Me","text":"Saved text for Remove Me"},{"name":"Keep Me","text":"Saved text for Keep Me"}]}')
            Record 'Prepare two saved snippets through the existing version-one storage format'
            $beforeSnippets = [IO.File]::ReadAllText($snippetFile)
            Focus-Palette 'manage snippets' 6296
            Snapshot 'manage-snippets-command'
            Press @(0x0D) 'Enter: Manage Snippets'
            Press @(0x0D) 'Enter: request deletion of Remove Me'
            Snapshot 'snippet-delete-confirmation'
            if ([IO.File]::ReadAllText($snippetFile) -cne $beforeSnippets) { throw 'First delete action changed saved snippets without confirmation' }
            Press @(0x1B) 'Escape: cancel deletion'
            if ([IO.File]::ReadAllText($snippetFile) -cne $beforeSnippets) { throw 'Escape deleted or changed snippets' }
            Focus-Palette 'manage snippets' 6296
            Press @(0x0D) 'Enter: reopen Manage Snippets'
            Press @(0x28) 'Down: choose Keep Me'
            Press @(0x26) 'Up: choose Remove Me'
            Press @(0x2E) 'Delete: request selected deletion'
            if ([IO.File]::ReadAllText($snippetFile) -cne $beforeSnippets) { throw 'Delete skipped confirmation' }
            Press @(0x0D) 'Enter: confirm selected deletion'
            Wait-Until {
                $saved = Get-Content $snippetFile -Raw | ConvertFrom-Json
                @($saved.snippets).Count -eq 1 -and $saved.snippets[0].name -eq 'Keep Me' -and $saved.snippets[0].text -eq 'Saved text for Keep Me'
            } 'only chosen snippet removed from disk'
            Snapshot 'snippet-deleted'
            Press @(0x1B) 'Escape: close Manage Snippets'
            Restart-ChatView 1
            Focus-Palette 'use snippets' 6254
            Press @(0x0D) 'Enter: existing snippet picker after restart'
            Type-Text 'Keep Me'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { ((Get-Content $log -Raw) -join '') -match '\[palette\] ready chars=7 count=2 target=6257' } 'remaining snippet loaded into existing picker after restart'
            Snapshot 'snippet-kept-after-restart'
            Press @(0x1B) 'Escape: close Use Snippets without pasting'
            $result.checks += @{ name = 'manage-snippets'; seeded = 2; deleted = 'Remove Me'; preserved = 'Keep Me'; escapeUnchanged = $true; reloadedAfterRestart = $true; entry = 'Ctrl+K Manage Snippets' }
        