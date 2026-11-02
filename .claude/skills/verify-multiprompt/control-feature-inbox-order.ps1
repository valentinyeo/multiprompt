            Wait-Until {
                $state = Read-Inbox
                $null -ne $state -and @($state.shells | Where-Object { $_.name -ceq 'Inbox Older' }).Count -eq 1 -and @($state.shells | Where-Object { $_.name -ceq 'Inbox Newer' }).Count -eq 1
            } 'both owned Inbox sessions published' 60
            $before = Read-Inbox
            $older = @($before.shells | Where-Object { $_.name -ceq 'Inbox Older' })[0]
            $newer = @($before.shells | Where-Object { $_.name -ceq 'Inbox Newer' })[0]
            if ($older.sid -eq $newer.sid -or [long]$older.la -ge [long]$newer.la -or [long]$older.lv -ge [long]$newer.la) { throw 'Seeded session identities or activity times invalid' }
            if ($older.att -ne 1 -or $newer.att -ne 0) { throw 'Expected older unread and newer read before opening Inbox' }
            Save-Json $before 'inbox-order-before.json'
            Press @(0x12, 0x49) 'Alt+I: open All Inbox'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'Inbox open'
            Snapshot 'inbox-order-before'
            Doctor
            Wait-Foreground
            Record 'gg: select top row'
            Assert-Foreground
            [VerifyNative]::KeyDown(0x47); [VerifyNative]::KeyUp(0x47)
            [VerifyNative]::KeyDown(0x47); [VerifyNative]::KeyUp(0x47)
            $prior = $newer.att
            Press @(0x55) 'u: identify top row'
            Wait-Until { $state = Read-Inbox; @($state.shells | Where-Object { $_.sid -eq $newer.sid -and $_.att -ne $prior }).Count -eq 1 } 'newer session was top'
            Press @(0x55) 'u: restore read state'
            Wait-Until { $state = Read-Inbox; @($state.shells | Where-Object { $_.sid -eq $newer.sid -and $_.att -eq $prior }).Count -eq 1 } 'newer read state restored'
            Start-Sleep -Seconds 65
            $notifyProcess = Start-Process -FilePath $Exe -ArgumentList @('--notify', '"NOTIFICATION:Inbox Older"') -PassThru
            try {
                if (-not $notifyProcess.WaitForExit(15000)) {
                    $notifyProcess.Kill()
                    $notifyProcess.WaitForExit()
                    throw 'Scripted notification process timed out'
                }
                if ($notifyProcess.ExitCode -ne 0) { throw "Scripted notification process exited $($notifyProcess.ExitCode)" }
            } finally { $notifyProcess.Dispose() }
            Wait-Until {
                $state = Read-Inbox
                $row = @($state.shells | Where-Object { $_.sid -eq $older.sid })
                $row.Count -eq 1 -and [long]$row[0].la -gt [long]$newer.la -and [long]$row[0].la -gt [long]$newer.lv
            } 'scripted update published for older session' 45
            $after = Read-Inbox
            Save-Json $after 'inbox-order-after.json'
            Start-Sleep -Seconds 2
            Doctor
            Wait-Foreground
            Record 'gg: select top row after update'
            Assert-Foreground
            [VerifyNative]::KeyDown(0x47); [VerifyNative]::KeyUp(0x47)
            [VerifyNative]::KeyDown(0x47); [VerifyNative]::KeyUp(0x47)
            Snapshot 'inbox-order-after'
            $priorOlder = @($after.shells | Where-Object { $_.sid -eq $older.sid })[0].att
            Press @(0x55) 'u: identify promoted top row'
            Wait-Until { $state = Read-Inbox; @($state.shells | Where-Object { $_.sid -eq $older.sid -and $_.att -ne $priorOlder }).Count -eq 1 } 'updated older session was top'
            $result.checks += @{ name = 'inbox-order-scripted-update'; olderSid = $older.sid; newerSid = $newer.sid; before = 'newer top'; after = 'older top'; update = 'local scripted notification, not a cloud reply' }
