$bindingName = 'workspace'
$bindingCheck = @{ name = 'tmux-binding-five-reopens'; passed = $false; beforeCount = 1; afterCount = 0; launches = @() }
$result.checks += $bindingCheck
$bindingLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$bindingPort = [regex]::Match((Read-SharedText $bindingLog), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
if (-not $bindingPort.Success) { throw 'Owned tunnel-inbound listener missing' }
$adoption = Invoke-Zsb @('pane-info') ([int]$bindingPort.Groups[1].Value) 'binding-adoption'
if ($adoption.tab_name -cne $bindingName) { throw 'Public pane-info resolved the wrong remote tab' }
Press @(0x12, 0x53) 'Alt+S: persist the confirmed remote binding through a real user action'
Wait-Until {
    $state = Read-Session
    $tabs = @($state.tabs)
    $tabs.Count -eq 1 -and $tabs[0].kind -eq 'tmux' -and $tabs[0].tmux_session -ceq $bindingName -and $tabs[0].tmux_host -eq 1
} 'confirmed remote identity adopted and saved' 180
Snapshot 'before'
New-Item -ItemType File (Join-Path $bindingState 'binding-status-hidden') | Out-Null
Wait-Until {
    $ready = Join-Path $bindingState 'ready.json'
    (Test-Path $ready) -and (Get-Content $ready -Raw | ConvertFrom-Json).screen.Contains('Status temporarily hidden')
} 'remote console really removed the status row' 30
$bindingLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$bindingLogStart = (Read-SharedText $bindingLog).Length
Wait-Until {
    $saved = Read-Session
    $tab = @($saved.tabs)[0]
    if ($tab.kind -ne 'tmux' -or $tab.tmux_session -cne $bindingName -or $tab.tmux_host -ne 1) { throw 'IGSH-985 confirmed remote identity was erased when its status row disappeared' }
    ([regex]::Matches((Read-SharedText $bindingLog).Substring($bindingLogStart), 'POLL\[t=')).Count -ge 4
} 'four real name polls preserve the confirmed identity without status text' 300
if (@((Read-Session).tabs)[0].tmux_identity -cne '1700:123:$7') { throw 'Confirmed session generation was not learned and saved by the real SSH probe' }
Snapshot 'action'
foreach ($cycle in 1..5) {
    Restart-SessionRestore "binding-reopen-$cycle" $false
    Wait-Until {
        $saved = Read-Session
        $tabs = @($saved.tabs)
        $tabs.Count -eq 1 -and $tabs[0].kind -eq 'tmux' -and $tabs[0].tmux_session -ceq $bindingName -and $tabs[0].tmux_host -eq 1 -and $tabs[0].tmux_identity -ceq '1700:123:$7' -and
            ([regex]::Matches((Read-SharedText (Join-Path $bindingState 'invocations.jsonl')), '"kind": "attach"')).Count -eq $cycle
    } "reopen $cycle restored the exact remote identity" 60
    $saved = Read-Session
    $tabs = @($saved.tabs)
    $calls = @(Get-Content (Join-Path $bindingState 'invocations.jsonl') | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    $logins = @($calls | Where-Object { $_.kind -eq 'login' })
    $attachments = @($calls | Where-Object { $_.kind -eq 'attach' })
    if ($logins.Count -ne 1 -or $attachments.Count -ne $cycle -or @($attachments | Where-Object { $_.session -cne $bindingName }).Count -ne 0) { throw 'IGSH-985 reopen launched a bare shell or attached a different remote session' }
    $names = @((Get-Content (Join-Path $bindingState 'state.json') -Raw | ConvertFrom-Json).sessions)
    if ($names.Count -ne 1 -or $names[0] -cne $bindingName) { throw 'IGSH-985 remote session count or identity changed' }
    $bindingCheck.launches += @{ cycle = $cycle; session = $bindingName; host = $tabs[0].tmux_host; sessionCount = $names.Count; identity = $tabs[0].tmux_identity; attachCount = $attachments.Count; loginCount = $logins.Count }
    Save-Json $saved "binding-reopen-$cycle.session.json"
    Snapshot "binding-reopen-$cycle"
}
$bindingCheck.afterCount = $names.Count
$replaceGeneration = {
    $bindingDocument['generation'] = '1700:123:$8'
    [IO.File]::WriteAllText((Join-Path $bindingState 'state.json'), ($bindingDocument | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
Restart-SessionRestore 'binding-name-reused' $false $false $replaceGeneration
Wait-Until {
    (Read-SharedText (Join-Path $bindingState 'invocations.jsonl')).Contains('"kind": "refused"')
} 'same name with a new server session generation was refused before attachment' 60
$calls = @(Get-Content (Join-Path $bindingState 'invocations.jsonl') | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
if (@($calls | Where-Object { $_.kind -eq 'attach' }).Count -ne 5) { throw 'IGSH-985 reopened into another session that reused the saved name' }
$saved = Read-Session
if (@($saved.tabs)[0].tmux_identity -cne '1700:123:$7') { throw 'Replacement generation overwrote the original saved identity' }
$bindingCheck.reusedName = @{ expected = '1700:123:$7'; actual = '1700:123:$8'; refused = $true; attachCount = 5 }
Snapshot 'binding-reused-name-refused'
$bindingCheck.passed = $true
Save-Json $bindingCheck 'binding-proof.json'
Copy-Item (Join-Path $bindingState 'invocations.jsonl') (Join-Path $Evidence 'binding-commands.jsonl')
Snapshot 'after'
