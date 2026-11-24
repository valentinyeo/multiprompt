$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$start = ((Get-Content $log -Raw) -join '').Length
Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
Wait-Until {
    ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
    [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
} 'command palette ready'
Snapshot 'before'
Type-Text 'permission requests'
Wait-Until {
    $trace = ((Get-Content $log -Raw) -join '').Substring($start)
    $trace -match '\[palette\] ready chars=19 count=\d+ target=\d+(?:\r?\n|$)'
} 'permission requests entry listed'
$trace = ((Get-Content $log -Raw) -join '').Substring($start)
$ready = [regex]::Matches($trace, '\[palette\] ready chars=19 count=(\d+) target=(\d+)')
$last = $ready[$ready.Count - 1]
if ([int]$last.Groups[1].Value -lt 1) { throw "permission-requests: the entry left no column for Permission requests" }
$rows = [regex]::Matches($trace, '\[palette\] rows chars=19 count=\d+ ids=([^\r\n]*)')
if ($rows.Count -eq 0) { throw 'permission-requests: the palette wrote no row list for this query' }
$ids = @($rows[$rows.Count - 1].Groups[1].Value -split ' ' | Where-Object { $_ })
if (-not ($ids -contains '7271')) { throw "permission-requests: Permission requests entry missing from $($ids -join ' ')" }
$result.checks += @{ name = 'permission-requests-entry'; rows = $ids }
Snapshot 'entry'
$toEntry = 0
while ($toEntry -lt $ids.Count -and $ids[$toEntry] -ne '7271') { $toEntry += 1 }
for ($i = 0; $i -lt $toEntry; $i += 1) { Press @(0x28) 'Down: move to the Permission requests entry' }
$opened = ((Get-Content $log -Raw) -join '').Length
Press @(0x0D) 'Enter: open the Permission requests list'
Wait-Until {
    $after = ((Get-Content $log -Raw) -join '').Substring($opened)
    $after -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)'
} 'Permission requests list open'
$after = ((Get-Content $log -Raw) -join '').Substring($opened)
$list = [regex]::Matches($after, '\[palette\] ready chars=0 count=(\d+) target=(\d+)')
$listReady = $list[$list.Count - 1]
$listRows = [regex]::Matches($after, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)')
if ($listRows.Count -eq 0) { throw 'permission-requests: the list wrote no row trace' }
$listIds = @($listRows[$listRows.Count - 1].Groups[1].Value -split ' ' | Where-Object { $_ })
if ($listIds.Count -lt 1) { throw 'permission-requests: the list is empty with no Back row' }
if ($listIds[0] -ne '6300') { throw "permission-requests: first list row is $($listIds[0]), expected the Back row" }
Wait-Until {
    ((Get-Content $log -Raw) -join '').Substring($opened) -match '\[palette\] ready chars=0 count=\d+ target=6300(?:\r?\n|$)'
} 'Back row selected in the list'
Snapshot 'list'
$result.checks += @{ name = 'permission-requests-list'; count = [int]$listReady.Groups[1].Value; ids = $listIds }
Save-Json @{ entry = $ids; list = $listIds } 'permission-requests.json'
Press @(0x0D) 'Enter: leave the list through Back'
Wait-Until {
    ((Get-Content $log -Raw) -join '').Substring($opened) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)'
} 'palette back to the command list'
Snapshot 'after'
