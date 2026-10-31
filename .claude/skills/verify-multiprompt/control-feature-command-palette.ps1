
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
            Palette ''
            Snapshot 'ctrl-k-empty'
            Press @(0x1B) 'Esc: close empty palette'
            Palette 'More shells'
            Snapshot 'more-shells-search'
            Press @(0x0D) 'Enter: More shells'
            Snapshot 'more-shells'
            Press @(0x1B) 'Esc: close More shells'
            $result.checks += @{ name = 'new-session-rows'; empty = 'ctrl-k-empty.png'; shells = 'more-shells.png' }
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
        