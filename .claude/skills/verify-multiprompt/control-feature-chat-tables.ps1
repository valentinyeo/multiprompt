
            $command = 'powershell -nop -c "''250c 2500 252c 2500 2510'',''2502 0041 2502 0042 2502'',''251c 2500 253c 2500 2524'',''2502 0031 2502 0032 2502'',''2514 2500 2534 2500 2518''|ForEach-Object{-join($_.Split('' '')|ForEach-Object{[char][Convert]::ToInt32($_,16)})}"'
            $command += ' && echo table-ready>"' + (Join-Path $scratch 'table-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print table and persist console completion marker in CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'table-ready.txt') } 'real console table command completed'
            Press @(0x12, 0x43) 'Alt+C: open formatted Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_tab -ge 0 -and $state.active_tab -lt @($state.tabs).Count } 'saved initial table tab'
            $tableTab = (Read-Session).active_tab
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Test-Path $log) -and ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE rows=1 columns=2 .*source=box' } 'formatted table built from real console output'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'Chat View preference persisted for table tab'
            Snapshot 'before'
            $buildsBefore = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create another real CMD tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 -and (Read-Session).active_tab -ne $tableTab } 'new CMD tab active and saved'
            Snapshot 'away'
            $awayLogLength = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x10, 0x09) 'Ctrl+Shift+Tab: return to table Chat View'
            Wait-Until { (Read-Session).active_tab -eq $tableTab -and (Read-Session).tabs[$tableTab].cv } 'original Chat View tab active again'
            Wait-Until { $text = (Get-Content $log -Raw) -join ''; $text.Length -gt $awayLogLength -and $text.Substring($awayLogLength) -match '\[switch\] chat painted in' } 'returned Chat View painted'
            Snapshot 'after'
            $buildsAfter = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            if ($buildsAfter -ne $buildsBefore) { throw "Unchanged table rebuilt across tab switch: $buildsBefore -> $buildsAfter" }
            $result.checks += @{ name = 'console-table-switch-return'; tableTab = $tableTab; buildsBefore = $buildsBefore; buildsAfter = $buildsAfter; marker = (Get-Content (Join-Path $scratch 'table-ready.txt') -Raw).Trim(); chatViewSaved = $true }
        