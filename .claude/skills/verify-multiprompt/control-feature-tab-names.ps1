
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'seeded restore finished' 60
            $expected = @($seedNames)
            function Assert-TabNamesHold([string]$Stage, [string[]]$Expected) {
                $settle = [Diagnostics.Stopwatch]::StartNew()
                $samples = 0
                while ($settle.Elapsed.TotalSeconds -lt 45) {
                    if ($samples % 8 -eq 0) { Doctor }
                    $saved = Read-Session
                    $state = Read-Inbox
                    if ($null -ne $saved -and $null -ne $state -and @($saved.tabs).Count -gt 0) {
                        $savedNames = @($saved.tabs | ForEach-Object { $_.name })
                        $shownNames = @($state.shells | ForEach-Object { $_.name })
                        $drift = (@($savedNames).Count -ne $Expected.Count) -or (($savedNames -join '|') -cne ($Expected -join '|')) -or (@($Expected | Where-Object { $shownNames -ccontains $_ }).Count -ne $Expected.Count)
                        if ($drift) {
                            Snapshot ($Stage + '-drift')
                            Save-Json @{ expected = $Expected; saved = $savedNames; shown = $shownNames; seconds = $settle.Elapsed.TotalSeconds } ($Stage + '-drift.json')
                            throw ('Tab names or order changed after ' + $Stage + ': expected [' + ($Expected -join ', ') + '], saved [' + ($savedNames -join ', ') + '], shown [' + ($shownNames -join ', ') + ']')
                        }
                        $samples++
                    }
                    Start-Sleep -Milliseconds 250
                }
                if ($samples -lt 40) { throw "Too few state samples after ${Stage}: $samples" }
                Doctor
                Save-Json (Read-Inbox) ($Stage + '-after.inbox.json')
                Save-Json (Read-Session) ($Stage + '-after.session.json')
                Snapshot ($Stage + '-after')
                $script:holdSamples = $samples
            }
            Assert-TabNamesHold 'names-launch' $expected
            $result.checks += @{ name = 'names-launch'; names = $expected; samples = $script:holdSamples; settledSeconds = 45 }
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep the seeded order'
            Wait-Until {
                $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                if (-not (Test-Path $path)) { return $false }
                $launch = Get-Content $path -Raw | ConvertFrom-Json
                $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
            } 'manual tab order saved before reordering'
            Focus-Palette $seedNames[2] 2
            Press @(0x0D) 'Enter: select the last seeded tab by name'
            Wait-Until { $saved = Read-Session; $null -ne $saved -and $saved.active_tab -eq 2 -and $saved.tabs[2].name -ceq $seedNames[2] } 'last seeded tab selected'
            Press @(0x11, 0x10, 0x26) 'Ctrl+Shift+Up: move the last tab above the middle one'
            $custom = @($seedNames[0], $seedNames[2], $seedNames[1])
            Wait-Until { (@((Read-Session).tabs | ForEach-Object { $_.name }) -join '|') -ceq ($custom -join '|') } 'custom tab order persisted' 30
            Snapshot 'action'
            $stages = @(@('names-restart-1', $false), @('names-restart-2', $true), @('names-restart-3', $false))
            foreach ($stage in $stages) {
                Restart-SessionRestore $stage[0] $stage[1]
                $before = Get-Content -Raw -LiteralPath (Join-Path $Evidence ($stage[0] + '-before.session.json')) | ConvertFrom-Json
                $expectedNow = @($before.tabs | ForEach-Object { $_.name })
                if (($expectedNow -join '|') -cne ($custom -join '|')) { throw "Saved names before $($stage[0]) are not the seeded names in the custom order: $($expectedNow -join ', ')" }
                if (@($before.tabs | Where-Object { $_.PSObject.Properties['manual'] -and $_.manual }).Count -ne 0) { throw "A seeded name became manual before $($stage[0])" }
                Assert-TabNamesHold $stage[0] $custom
                $result.checks += @{ name = $stage[0]; names = $custom; samples = $script:holdSamples; settledSeconds = 45; crash = $stage[1] }
            }
            $result.checks += @{ name = 'tab-names-order-survive-restarts'; restarts = 3 }
            Snapshot 'after'
        