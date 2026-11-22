$repoLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$reposFile = Join-Path $env:MP_VERIFY_STATE 'picker-refresh-repos.txt'
$gateFile = Join-Path $env:MP_VERIFY_STATE 'picker-refresh-gate.txt'
$waitingFile = Join-Path $env:MP_VERIFY_STATE 'picker-refresh-waiting.txt'
$folder = '/work/projects/multiprompt'
$siblings = @(0..23 | ForEach-Object { '/work/projects/multiprompt-tools-{0:d2}' -f $_ })
$beforeRows = @('/work/projects/multiprompt-android', $folder) + $siblings
$afterRows = @('/work/projects/multiprompt-ios') + $beforeRows
$eventName = 'Local\MultipromptPickerRefresh-' + [Guid]::NewGuid().ToString('N')
$refreshEvent = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
try {
    [IO.File]::WriteAllLines($reposFile, [string[]]$beforeRows)
    $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
    Press @(0x11, 0x54) 'Ctrl+T: prime sibling repository cache'
    Type-Text 'mul'
    Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore) -match '\[palette\] rows chars=3 count=27 ' } 'initial sibling listing published'
    Press @(0x1B) 'Esc: leave primed picker'
    Press @(0x1B) 'Esc: close palette'
    [IO.File]::WriteAllLines($reposFile, [string[]]$afterRows)
    [IO.File]::WriteAllText($gateFile, $eventName)
    $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
    Press @(0x11, 0x54) 'Ctrl+T: open picker while refreshed listing is held'
    Wait-Until { Test-Path -LiteralPath $waitingFile } 'late repository response waiting' 5
    Type-Text 'mul'
    Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore) -match '\[palette\] rows chars=3 count=27 ' } 'cached sibling rows shown before refresh' 5
    Press @(0x28) 'Down: highlight multiprompt rather than multiprompt-android'
    Snapshot 'ctrl-t-mul-before-refresh'
    $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
    Record 'Release the pending SSH listing; no picker input until after-refresh screenshot'
    [void]$refreshEvent.Set()
    Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore) -match '\[palette\] rows chars=3 count=28 ' } 'late repository publication adds a row before the highlighted folder'
    Snapshot 'ctrl-t-mul-after-refresh'
    Press @(0x0D) 'Enter: open the highlighted folder without moving after refresh'
    Wait-Until {
        $state = Read-Session
        if (@($state.tabs).Count -ne 4) { return $false }
        $tab = $state.tabs[$state.active_tab]
        $tab.cwd -ceq $folder -and $tab.tmux_host -eq 2 -and $tab.cv -eq $true
    } 'exact multiprompt folder remains selected after refresh' 60
    Save-Json (Read-Session) 'ctrl-t-mul-selected-session.json'
    Save-Json @{ before = $beforeRows; after = $afterRows; query = 'mul'; selectedHost = 2; selectedPath = $folder; boundary = 'SSH listing stand-in; released app paints and selects all rows; no real server or agent' } 'ctrl-t-mul-refresh.json'
    $result.checks += @{ name = 'ctrl-t-mul-highlight-stable'; cwd = $folder; host = 2; beforeCount = 27; afterCount = 28 }
    Invoke-JourneyCommand 'Archive chat' -Confirm {
        Press @(0x0D) 'Enter: hide refresh-proof chat'
    }
    Wait-Until { @((Read-Session).tabs).Count -eq 3 } 'refresh-proof chat hidden'
    Invoke-JourneyCommand 'Second' -Session -Confirm {
        Press @(0x0D) 'Enter: return to seeded host 2'
    }
    Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_session -ceq 'second' -and $state.tabs[$state.active_tab].tmux_host -eq 2 } 'seeded host 2 restored after refresh proof'
} finally {
    [void]$refreshEvent.Set()
    $refreshEvent.Dispose()
    Remove-Item -LiteralPath $reposFile, $gateFile -Force -ErrorAction SilentlyContinue
}
