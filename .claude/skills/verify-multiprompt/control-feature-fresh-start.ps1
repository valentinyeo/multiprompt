$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$hostRoot = Join-Path $scratch 'profile/home/.local/state/multiprompt/agent-host'
$case = @{ name = 'fresh-start'; status = 'failed'; detail = 'Fresh start did not keep the same Multibot chat' }
$result.checks += $case
function Read-HostIdentity([string]$Sid) {
    if (-not (Test-Path $hostRoot)) { return $null }
    foreach ($configPath in Get-ChildItem $hostRoot -Filter '*.config.json') {
        $config = Get-Content $configPath.FullName -Raw | ConvertFrom-Json
        if ($config.sid -cne $Sid) { continue }
        $statePath = $configPath.FullName -replace '\.config\.json$', '.state.json'
        if (-not (Test-Path $statePath)) { return $null }
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
        $native = ''
        if ($state.PSObject.Properties.Name -contains 'native_session' -and $state.native_session) {
            $native = [string]$state.native_session
        } elseif ($state.PSObject.Properties.Name -contains 'context_session' -and $state.context_session) {
            $native = [string]$state.context_session
        }
        $provider = if ($config.PSObject.Properties.Name -contains 'provider') { [string]$config.provider } else { 'claude' }
        return @{
            sid = [string]$config.sid
            tmux = [string]$config.tmux
            provider = $provider
            native_session = $native
            configFile = $configPath.Name
            stateFile = [IO.Path]::GetFileName($statePath)
        }
    }
    return $null
}
function Capture-Identity([string]$Label) {
    $session = Read-Session
    $tab = $session.tabs[$session.active_tab]
    $sid = [string]$tab.csid
  $identity = Read-HostIdentity $sid
    if ($null -eq $identity) { throw "$Label host identity unavailable" }
    $inbox = Read-Inbox
    $rowName = [string]$tab.name
    $rows = @($inbox.shells | Where-Object { $_.PSObject.Properties['name'] -and $_.name -ceq $rowName })
    return @{
        label = $Label
        sid = $identity.sid
        tmux = $identity.tmux
        native_session = $identity.native_session
        rowName = $rowName
        csid = $sid
        active_tab = $session.active_tab
        tab_shell_id = $tab.shell_id
        matchingSidebarRows = $rows.Count
    }
}
try {
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'tmux' -and
            $state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv -and
            $state.tabs[0].PSObject.Properties['csid'] -and $state.tabs[0].csid -and
        $state.tabs[0].PSObject.Properties['ai_agent'] -and $state.tabs[0].ai_agent -eq 1
    } 'seeded remote Chat View tab restored' 60
    Wait-Until {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
        $script:transcript = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
        $script:transcript.Count -eq 1
    } 'Chat View transcript visible' 45
    Wait-ChatFocus 'Edit' 'fresh-start-ready'
    $hostJsonl = Join-Path $remoteState 'fresh-start-host.jsonl'
    Wait-Until {
        (Get-Content $log -Raw) -match '\[chat\] transcript load shell=\d+ ok'
    } 'seeded transcript painted before send' 90
    for ($n = 1; $n -le 2; $n++) {
        $text = "fresh-start probe $n"
        Type-Text $text
        Press @(0x0D) "Enter: send composer message $n"
        Wait-Until {
            if (-not (Test-Path $hostJsonl)) { return $false }
            @((Get-Content $hostJsonl -Raw) -split "`n" | Where-Object { $_ -match '"stage": "replied"' }).Count -ge $n
        } "hosted reply $n" 90
    }
    $before = Capture-Identity 'before'
    Save-Json $before 'fresh-start-before.json'
    Snapshot 'before'
    Invoke-JourneyCommand 'Chat View: Fresh start' -Confirm {
        Press @(0x0D) 'Enter: confirm Chat View: Fresh start'
    }
    $start = if (Test-Path $log) { (Get-Content $log -Raw).Length } else { 0 }
    Wait-Until {
        $identity = Read-HostIdentity $before.csid
        if ($null -eq $identity) { return $false }
        $statePath = Join-Path $hostRoot ($identity.configFile -replace '\.config\.json$', '.state.json')
        $hostState = Get-Content $statePath -Raw | ConvertFrom-Json
        $hostReady = -not ($hostState.PSObject.Properties.Name -contains 'fresh_start')
        $rotated = $identity.native_session -and $identity.native_session -cne $before.native_session
        $raw = if (Test-Path $log) { (Get-Content $log -Raw) } else { '' }
        $traceStart = [Math]::Min($start, $raw.Length)
        $trace = if ($raw.Length -gt $traceStart) { $raw.Substring($traceStart) } else { '' }
        $hostJsonl = Join-Path $remoteState 'fresh-start-host.jsonl'
        $handover = $trace -match 'Finish the saved draft' -or
            ((Test-Path $hostJsonl) -and ((Get-Content $hostJsonl -Raw) -match 'handover_visible|handover_saved'))
        return $hostReady -and $rotated -and $handover
    } 'fresh start completed with saved handover and new native session' 120
    $after = Capture-Identity 'after'
    $after.handoverSeen = $true
    Save-Json $after 'fresh-start-after.json'
    Snapshot 'after'
    $hostJsonl = Join-Path $remoteState 'fresh-start-host.jsonl'
    $hostRows = @(Get-Content $hostJsonl | ForEach-Object { $_ | ConvertFrom-Json })
    $visible = @($hostRows | Where-Object { $_.stage -eq 'handover_visible' })
    $savedRows = @($hostRows | Where-Object { $_.stage -eq 'handover_saved' })
    if ($visible.Count -lt 2) { throw "expected the agent to send its handover twice, saw $($visible.Count)" }
    if ($savedRows.Count -ne 1) { throw "expected one saved handover, saw $($savedRows.Count)" }
    $marker = 'Finish the saved draft.'
    $draft = [string]$savedRows[0].text
    if (([regex]::Matches($draft, [regex]::Escape($marker))).Count -ne 1) { throw 'saved handover repeated its own text' }
    $draftBytes = [Text.Encoding]::UTF8.GetByteCount($draft)
    if ($draftBytes -lt 4096 -or $draftBytes -gt 8192) { throw "saved handover is $draftBytes bytes, outside the repeated-handover window" }
    $after.repeatHandoverSeen = $true
    Save-Json $after 'fresh-start-after.json'
    if ($before.sid -cne $after.sid -or $before.tmux -cne $after.tmux -or $before.rowName -cne $after.rowName -or $before.csid -cne $after.csid) {
        throw 'Public chat identity changed across fresh start'
    }
    if ($before.native_session -ceq $after.native_session) { throw 'native_session did not rotate' }
    if ($after.matchingSidebarRows -ne 1) { throw "expected one sidebar row, found $($after.matchingSidebarRows)" }
    Wait-ChatFocus 'Edit' 'fresh-start-after-ready'
    Type-Text 'fresh-start after'
    Press @(0x0D) 'Enter: send composer message after fresh start'
    Wait-Until {
        if (-not (Test-Path $hostJsonl)) { return $false }
        @((Get-Content $hostJsonl -Raw) -split "`n" | Where-Object { $_ -match '"stage": "replied"' }).Count -ge 3
    } 'hosted reply after fresh start' 90
    $afterReply = Capture-Identity 'after-reply'
    if ($afterReply.native_session -cne $after.native_session) { throw 'native_session rotated again after the fresh start reply' }
    if ($afterReply.matchingSidebarRows -ne 1) { throw "expected one sidebar row after the reply, found $($afterReply.matchingSidebarRows)" }
    $after.replySeen = $true
    Save-Json $after 'fresh-start-after.json'
    Snapshot 'after-reply'
    & node (Join-Path $PSScriptRoot '../../../tools/chat-fresh-start-proof.mjs') $Evidence
    if ($LASTEXITCODE -ne 0) { throw 'fresh-start proof checker failed' }
    $case.status = 'passed'
    $case.detail = 'Fresh start kept sid, tmux and row name, rotated native_session once, saved one handover from two sends, kept layout csid and answered in the new chat'
} catch {
    $case.detail = $_.Exception.Message
    throw
} finally {
    if (Test-Path $log) { Copy-Item $log (Join-Path $Evidence 'fresh-start-debug.log') }
    $boundary = Join-Path $remoteState 'fresh-start-host.jsonl'
    if (Test-Path $boundary) { Copy-Item $boundary (Join-Path $Evidence 'fresh-start-host.jsonl') }
    $agentLog = Join-Path $remoteState 'fresh-start-agent.jsonl'
    if (Test-Path $agentLog) { Copy-Item $agentLog (Join-Path $Evidence 'fresh-start-agent.jsonl') }
    if (Test-Path $hostRoot) { Copy-Item $hostRoot (Join-Path $Evidence 'agent-host') -Recurse -Force }
}