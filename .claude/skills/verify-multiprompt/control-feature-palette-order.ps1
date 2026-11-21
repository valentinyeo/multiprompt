
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $usage = @(Get-Content $paletteUsageFixture | Where-Object { $_ } | ForEach-Object { $fields = $_ -split "`t"; [pscustomobject]@{ id = [string]$fields[0]; count = [int]$fields[1]; last = [uint64]$fields[2] } })
            $expected = @($usage | Sort-Object @{ Expression = 'count'; Descending = $true }, @{ Expression = 'last'; Descending = $true } | Select-Object -First 10 | ForEach-Object { $_.id })
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x4B) 'Ctrl+K: open empty command palette with seeded usage history'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
            } 'empty palette ready'
            Snapshot 'action'
            $trace = ((Get-Content $log -Raw) -join '').Substring($start)
            $ready = [regex]::Matches($trace, '\[palette\] ready chars=0 count=(\d+) target=(\d+)')
            $selected = $ready[$ready.Count - 1].Groups[2].Value
            if ($selected -ne $expected[0]) { throw "palette-order: selected row $selected, expected most used command $($expected[0])" }
            $rows = [regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)')
            if ($rows.Count -eq 0) { throw 'palette-order: no empty palette rows trace' }
            $ids = @($rows[$rows.Count - 1].Groups[1].Value -split ' ')
            if ($ids[0] -ne 'h0') { throw "palette-order: first row $($ids[0]), expected Most used header" }
            $band = @($ids[1..10])
            if (($band -join ' ') -ne ($expected -join ' ')) { throw "palette-order: Most used rows $($band -join ' '), expected $($expected -join ' ')" }
            if ($ids[11] -notmatch '^h[1-8]$') { throw "palette-order: row after Most used is $($ids[11]), expected a group header" }
            $headers = @($ids | Where-Object { $_ -match '^h\d$' })
            if (@($headers | Select-Object -Unique).Count -ne $headers.Count) { throw "palette-order: repeated group header in $($ids -join ' ')" }
            $rare = @($usage | Sort-Object count | Select-Object -First 1)[0].id
            if ($band -contains $rare) { throw "palette-order: rarely used command $rare entered Most used" }
            Save-Json @{ ids = $ids; expected = $expected; selected = $selected } 'palette-order-rows.json'
            Press @(0x1B) 'Esc: close empty palette'
            $queries = @(
                @{ text = 'chat view per tab'; id = 0 },
                @{ text = 'copy session diagnostics'; id = 6247 },
                @{ text = 'copy shell diagnostics'; id = 6247 },
                @{ text = 'rename workspace'; id = 7000 },
                @{ text = 'mobile latency mode'; id = 8000 },
                @{ text = 'restore disconnected workspace sessions'; id = 6295 },
                @{ text = 'auto-suspend idle panes'; id = 6240 },
                @{ text = 'use agent or terminal session name'; id = 6248 },
                @{ text = 'insert agent instructions'; id = 6237 }
            )
            $found = @()
            foreach ($query in $queries) {
                $start = ((Get-Content $log -Raw) -join '').Length
                Press @(0x11, 0x4B) ('Ctrl+K: open palette for ' + $query.text)
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                    [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
                } ('empty palette ready for ' + $query.text)
                Type-Text $query.text
                if ($query.id -eq 0) {
                    Wait-Until {
                        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] ready chars=' + $query.text.Length + ' count=0 target=0(?:\r?\n|$)')
                    } 'removed per-tab command has zero palette rows'
                    Snapshot 'removed-absent'
                } else {
                    Wait-Until {
                        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] rows chars=' + $query.text.Length + ' count=[1-9]\d* ids=(?:\S+ )*' + $query.id + '(?: |\r?\n|$)')
                    } ("palette-order: '" + $query.text + "' lists command " + $query.id)
                    $found += @{ query = $query.text; id = $query.id }
                }
                if ($query.text -eq 'copy session diagnostics') { Snapshot 'renamed' }
                Press @(0x1B) ('Esc: close palette for ' + $query.text)
            }
            $result.checks += @{ name = 'palette-order'; mostUsed = $expected; selected = $selected; headers = $headers; removedRowCount = 0; renamedFound = $found; entry = 'Ctrl+K' }
            Snapshot 'after'
            Restart-SessionRestore 'palette-ranking' $false $false $paletteRankingSeed
            $result.paletteRankingBoundary = 'One saved local CMD session, one closed workspace registry entry and its saved session file are seeded before relaunch; no setter or remote service is used.'
            Wait-Until { @((Read-Inbox).shells | Where-Object { $_.name -eq 'Funeralprints' }).Count -eq 1 } 'saved Funeralprints session restored'
            $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
            $workspaceIndex = -1
            for ($i = 0; $i -lt @($registry.windows).Count; $i++) { if ($registry.windows[$i].id -eq 'closed-fune-fixture') { $workspaceIndex = $i } }
            if ($workspaceIndex -lt 0) { throw 'palette-order: closed workspace fixture missing from registry' }
            $workspaceId = [string](6500 + $workspaceIndex)
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x4B) 'Ctrl+K: open palette for session and workspace ranking'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+' -and
                [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
            } 'ranking palette ready and focused'
            Type-Text 'fune'
            Wait-Until {
                ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=4 count=(?:[2-9]|[1-9]\d+) target=0(?:\r?\n|$)'
            } 'typed ranking selects session with at least two rows'
            $trace = ((Get-Content $log -Raw) -join '').Substring($start)
            $matches = [regex]::Matches($trace, '\[palette\] rows chars=4 count=\d+ ids=([^\r\n]*)')
            $ranked = @($matches[$matches.Count - 1].Groups[1].Value -split ' ')
            if ($ranked.Count -lt 2 -or $ranked -notcontains $workspaceId -or $ranked[0] -ne '0' -or $ranked[-1] -ne $workspaceId) { throw "palette-order: expected session 0 first and closed workspace $workspaceId last, got $($ranked -join ' ')" }
            Snapshot 'typed-session-workspace'
            Save-Json @{ ids = $ranked; session = '0'; closedWorkspace = $workspaceId; query = 'fune' } 'palette-ranking-rows.json'
            $result.checks += @{ name = 'session-workspace-ranking'; ids = $ranked; entry = 'Ctrl+K fune' }
            Press @(0x1B) 'Esc: close ranking palette'
        