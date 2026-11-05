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
            $notifyPorts = @(Get-NotifyPorts)
            Wait-Until {
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $process.Id -and $_.LocalPort -in $notifyPorts }).Count -eq 1
            } 'owned notification listener' 30
            $listener = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $process.Id -and $_.LocalPort -in $notifyPorts })
            if ($listener.Count -ne 1) { throw 'Owned notification listener changed' }
            Save-Json @{ pid = $process.Id; owningProcess = $listener[0].OwningProcess; port = $listener[0].LocalPort; address = '127.0.0.1'; payload = 'NOTIFICATION:Inbox Older' } 'inbox-order-notification.json'
            $client = [Net.Sockets.TcpClient]::new()
            try {
                $connect = $client.ConnectAsync([Net.IPAddress]::Loopback, [int]$listener[0].LocalPort)
                if (-not $connect.Wait(5000)) { throw 'Notification connection timed out' }
                $connect.GetAwaiter().GetResult()
                $client.SendTimeout = 5000
                $bytes = [Text.Encoding]::UTF8.GetBytes('NOTIFICATION:Inbox Older')
                $client.GetStream().Write($bytes, 0, $bytes.Length)
            } finally { $client.Dispose() }
            Wait-Until {
                $state = Read-Inbox
                if ($null -eq $state -or -not $state.inbox_active) { return $false }
                $row = @($state.shells | Where-Object { $_.sid -eq $older.sid })
                $other = @($state.shells | Where-Object { $_.sid -eq $newer.sid })
                $row.Count -eq 1 -and $other.Count -eq 1 -and [long]$row[0].la -gt [long]$older.la -and [long]$row[0].la -gt [long]$other[0].la -and [long]$row[0].la -gt [long]$other[0].lv
            } 'scripted update published for older session' 45
            $after = Read-Inbox
            $afterOlder = @($after.shells | Where-Object { $_.sid -eq $older.sid })
            $afterNewer = @($after.shells | Where-Object { $_.sid -eq $newer.sid })
            if ($afterOlder.Count -ne 1 -or $afterNewer.Count -ne 1 -or $afterOlder[0].att -ne 1 -or $afterNewer[0].att -ne 0) { throw 'Expected older unread and newer read after notification' }
            Save-Json $after 'inbox-order-after.json'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'Inbox visible for after capture'
            Snapshot 'inbox-order-after'
            $result.checks += @{ name = 'inbox-order-capture-only'; olderSid = $older.sid; newerSid = $newer.sid; visualReviewRequired = $true; update = 'local scripted notification, not a cloud reply' }
