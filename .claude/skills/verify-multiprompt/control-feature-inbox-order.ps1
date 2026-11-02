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
                if ($null -eq $state -or -not $state.inbox_active) { return $false }
                $row = @($state.shells | Where-Object { $_.sid -eq $older.sid })
                $other = @($state.shells | Where-Object { $_.sid -eq $newer.sid })
                $row.Count -eq 1 -and $other.Count -eq 1 -and [long]$row[0].la -gt [long]$older.la -and [long]$row[0].la -gt [long]$other[0].la -and [long]$row[0].la -gt [long]$other[0].lv
            } 'scripted update published for older session' 45
            $after = Read-Inbox
            Save-Json $after 'inbox-order-after.json'
            Start-Sleep -Seconds 2
            Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'Inbox visible for after capture'
            Snapshot 'inbox-order-after'
            $result.checks += @{ name = 'inbox-order-capture-only'; olderSid = $older.sid; newerSid = $newer.sid; visualReviewRequired = $true; update = 'local scripted notification, not a cloud reply' }
