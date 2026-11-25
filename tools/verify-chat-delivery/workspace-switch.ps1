function Read-WsJournal {
    $path = "$state/workspace-switch.jsonl"
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    @((Read-Shared $path) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}
function Get-WsStage([string]$Stage) {
    @(Read-WsJournal | Where-Object { $_.stage -eq $Stage })
}
function Read-WsSession {
    $path = "$settings/session.json"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $text = Read-Shared $path
    if (-not $text.Trim()) { return $null }
    $text | ConvertFrom-Json
}
function Get-WsTabAgent([object]$Tab) {
    if ($null -eq $Tab -or -not $Tab.PSObject.Properties['ai_agent']) { return 0 }
    [int]$Tab.ai_agent
}
function Get-WsTabSid([object]$Tab) {
    if ($null -eq $Tab -or -not $Tab.PSObject.Properties['csid']) { return '' }
    [string]$Tab.csid
}
function Get-WsSavedTabs {
    $session = Read-WsSession
    if ($null -eq $session -or -not $session.PSObject.Properties['tabs']) { return @() }
    @($session.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -cmatch '^ws-chat-(one|two)$' })
}
function Wait-WsSavedChats([int]$Agent, [int]$Seconds = 180) {
    Wait-For ("both workspace chats are saved on the agent numbered " + $Agent) {
        $tabs = Get-WsSavedTabs
        $tabs.Count -eq 2 -and @($tabs | Where-Object { (Get-WsTabAgent $_) -eq $Agent -and (Get-WsTabSid $_) }).Count -eq 2
    } $Seconds
}
function Wait-WsReplies([string]$To, [string]$Status, [int]$Seconds = 180) {
    Wait-For ("two completed switch replies to " + $To) {
        @(Get-WsStage 'switch-reply' | Where-Object { $_.to -ceq $To -and $_.status -ceq $Status }).Count -eq 2
    } $Seconds
}
function Open-WsChatView([string]$Name) {
    if ([ChatDeliveryDesktop]::Composer($main) -eq [IntPtr]::Zero) {
        Press @(0x12, 0x43) ('Alt+C: open Chat View for ' + $Name)
    }
    $script:composer = Wait-For ('native Chat View composer for ' + $Name) { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } } 20
    [void](Wait-For 'composer typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
}
function Select-WsChat([int]$Index, [string]$Name) {
    Press @(0x11, (0x30 + $Index)) ('Ctrl+' + $Index + ': select ' + $Name)
    Open-WsChatView $Name
    [void](Scroll-Transcript -12000)
}
function Copy-WsChat([string]$Name) {
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $copy = Copy-Rendered $Name
        if ($copy) { return $copy }
    }
    throw ('The rendered conversation never copied for ' + $Name)
}
function Invoke-WsPaletteRow([string]$Query, [int]$Target, [string]$Name) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) ('Ctrl+K: open the command palette for ' + $Name)
    [void](Wait-For 'palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($letter in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    $pattern = '\[palette\] ready chars=' + $Query.Length + ' count=[1-9]\d* target=' + $Target + '(?:\s|$)'
    [void](Wait-For ('the real palette offers ' + $Name) { (Read-Shared "$settings/debug.log").Substring($offset) -match $pattern } 20)
    Press @(0x0D) ('Enter: ' + $Name)
}
function Measure-WsNoticeInk([string]$Name) {
    Shot $Name
    $image = [Drawing.Bitmap]::new((Join-Path $Evidence ($Name + '.png')))
    try {
        $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
        $width = [Math]::Min($image.Width, [ChatDeliveryDesktop]::GetSystemMetrics(0))
        $ink = 0
        for ($y = $origin.Y; $y -lt [Math]::Min($origin.Y + 70, $image.Height); $y++) {
            for ($x = $origin.X; $x -lt $width; $x++) {
                $color = $image.GetPixel($x, $y)
                if ($color.R -gt 150 -and $color.G -gt 80 -and $color.B -lt 150 -and $color.R -gt $color.G) { $ink++ }
            }
        }
        return $ink
    } finally { $image.Dispose() }
}
function Assert-WsHistory([string]$Name, [string]$Copy, [string[]]$Markers, [string]$Divider = '') {
    if (-not $Copy) { throw ('The rendered conversation is empty for ' + $Name) }
    foreach ($marker in $Markers) {
        if (-not $Copy.Contains($marker)) { throw ($Name + ' lost its history: ' + $marker) }
    }
    if ($Divider -and -not $Copy.Contains($Divider)) { throw ($Name + ' does not show ' + $Divider) }
}

$wsSeeded = Wait-For 'the switch fixture seeded two live chats' { $rows = @(Get-WsStage 'seeded'); if ($rows.Count -ge 1) { $rows[0] } } 60
$wsChats = @($wsSeeded.chats)
if ($wsChats.Count -ne 2) { throw 'The switch fixture seeded the wrong number of chats' }
if (@($wsChats | ForEach-Object { $_.tmux }) -join ',' -cne 'ws-chat-one,ws-chat-two') { throw 'The seeded chats are not the two saved workspace tabs' }
$wsMarkers = @{}
foreach ($chat in $wsChats) { $wsMarkers[$chat.tmux] = @([string]$chat.question, [string]$chat.reply) }
$actions.Add(@{case=$plan.name; input='workspace switch: two saved Claude chats with history'; chats=@($wsChats | ForEach-Object { @{tmux=$_.tmux; sid=$_.sid} })})
[void](Wait-WsSavedChats 1 120)
$beforeSids = @{}
foreach ($tab in (Get-WsSavedTabs)) { $beforeSids[$tab.tmux_session] = (Get-WsTabSid $tab) }
if ($beforeSids['ws-chat-one'] -cne $wsChats[0].sid -or $beforeSids['ws-chat-two'] -cne $wsChats[1].sid) { throw 'The saved chats are not the fixture identities' }

Select-WsChat 1 'workspace chat one'
$beforeOne = Copy-WsChat 'ws-before-one'
Select-WsChat 2 'workspace chat two'
$beforeTwo = Copy-WsChat 'ws-before-two'
Assert-WsHistory 'workspace chat one before the switch' $beforeOne $wsMarkers['ws-chat-one']
Assert-WsHistory 'workspace chat two before the switch' $beforeTwo $wsMarkers['ws-chat-two']

Invoke-WsPaletteRow 'switch all chats antigravity' 7056 'Workspace: Switch every chat to Antigravity'
$antigravityRows = Wait-For 'both chats refused Antigravity' {
    $rows = @(Get-WsStage 'switch-reply' | Where-Object { $_.to -ceq 'antigravity' })
    if ($rows.Count -ge 2) { $rows }
} 120
$antigravityRefused = @($antigravityRows | Where-Object { $_.status -ceq 'refused' -and $_.reason -ceq 'unsupported_provider' })
if ($antigravityRefused.Count -ne 2) { throw 'Antigravity was not refused for both chats with unsupported_provider' }
$antigravityInk = Measure-WsNoticeInk 'workspace-switch-antigravity-refused'
if ($antigravityInk -lt 10) { throw 'The Antigravity refusal notice is not visibly painted' }
[void](Wait-WsSavedChats 1 60)
foreach ($tab in (Get-WsSavedTabs)) {
    if ((Get-WsTabAgent $tab) -ne 1 -or (Get-WsTabSid $tab) -cne $beforeSids[$tab.tmux_session]) { throw ('A refused Antigravity switch moved ' + $tab.tmux_session) }
}
$observation.antigravity = @{ refused = $antigravityRefused.Count; reason = 'unsupported_provider'; noticeInk = $antigravityInk }

Invoke-WsPaletteRow 'switch all chats codex' 7055 'Workspace: Switch every chat to Codex'
Wait-WsReplies 'codex' 'switched' 240
$codexRows = @(Get-WsStage 'switch-reply' | Where-Object { $_.to -ceq 'codex' -and $_.status -ceq 'switched' })
if (@($codexRows | Where-Object { -not $_.switched_sid }).Count -ne 0) { throw 'A Codex switch reply carried no chat identity' }
if (@(Get-WsStage 'provider-start' | Where-Object { $_.provider -ceq 'codex' }).Count -lt 2) { throw 'Both chats did not start on Codex' }
[void](Wait-WsSavedChats 2 240)
$codexSids = @{}
foreach ($row in (Get-WsSavedTabs)) {
    $expected = @($codexRows | Where-Object { $_.sid -ceq (Get-WsTabSid $row) -or $_.switched_sid -ceq (Get-WsTabSid $row) })
    if ($expected.Count -eq 1) { $codexSids[$row.tmux_session] = (Get-WsTabSid $row) }
}
if ($codexSids.Count -ne 2) { throw 'The saved Codex chats are not the identities the switch replied with' }
Select-WsChat 1 'workspace chat one'
$codexOne = Copy-WsChat 'ws-codex-one'
Select-WsChat 2 'workspace chat two'
$codexTwo = Copy-WsChat 'ws-codex-two'
Assert-WsHistory 'workspace chat one on Codex' $codexOne $wsMarkers['ws-chat-one'] 'Switched AI: Claude to Codex'
Assert-WsHistory 'workspace chat two on Codex' $codexTwo $wsMarkers['ws-chat-two'] 'Switched AI: Claude to Codex'
Shot 'workspace-switch-codex'
$codexSession = Read-WsSession
if ($codexSession.workspaces[0].name -cne 'Verify workspace') { throw 'The switch changed the saved workspace name' }
Save @{ agent = 2; chats = $codexSids; workspace = $codexSession.workspaces[0].name } "$caseDir/workspace-switch-codex.json"

Invoke-WsPaletteRow 'switch all chats claude' 7054 'Workspace: Switch every chat to Claude'
Wait-WsReplies 'claude' 'switched' 240
[void](Wait-WsSavedChats 1 240)
$claudeRows = @(Get-WsStage 'switch-reply' | Where-Object { $_.to -ceq 'claude' -and $_.status -ceq 'switched' })
$claudeSids = @{}
foreach ($row in (Get-WsSavedTabs)) {
    if (@($claudeRows | Where-Object { $_.sid -ceq (Get-WsTabSid $row) -or $_.switched_sid -ceq (Get-WsTabSid $row) }).Count -eq 1) { $claudeSids[$row.tmux_session] = (Get-WsTabSid $row) }
}
if ($claudeSids.Count -ne 2) { throw 'The saved Claude chats are not the identities the switch replied with' }
Select-WsChat 1 'workspace chat one'
$claudeOne = Copy-WsChat 'ws-claude-one'
Select-WsChat 2 'workspace chat two'
$claudeTwo = Copy-WsChat 'ws-claude-two'
Assert-WsHistory 'workspace chat one back on Claude' $claudeOne $wsMarkers['ws-chat-one'] 'Switched AI: Codex to Claude'
Assert-WsHistory 'workspace chat two back on Claude' $claudeTwo $wsMarkers['ws-chat-two'] 'Switched AI: Codex to Claude'
Shot 'workspace-switch-claude'
Save @{ agent = 1; chats = $claudeSids } "$caseDir/workspace-switch-claude.json"

$zsbWrapper = Join-Path (Split-Path $Exe) 'zsb.exe'
if (-not (Test-Path -LiteralPath $zsbWrapper)) { throw 'The zsb command-line stand-in was not built for this journey' }
$port = Wait-For 'app-owned loopback listener port' {
    $found = [regex]::Match((Read-Shared "$settings/debug.log"), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
    if ($found.Success) { [int]$found.Groups[1].Value }
} 30
$env:ZSB_PORT = [string]$port
$env:MULTIPROMPT_ZSB = $zsbWrapper
$actions.Add(@{case=$plan.name; input='run the mb workspace switch-ai verb'; workspace='Verify workspace'; target='codex'; port=$port})
$mbLines = & node "$PSScriptRoot/../mb.mjs" workspace switch-ai 'Verify workspace' codex --json
$mbExit = $LASTEXITCODE
$mbText = (@($mbLines) -join "`n").Trim()
[IO.File]::WriteAllText("$caseDir/workspace-switch-mb.txt", $mbText)
if ($mbExit -ne 0) { throw ('The mb workspace switch-ai verb exited ' + $mbExit + ': ' + $mbText) }
$mb = $mbText | ConvertFrom-Json
if ($mb.ok -ne $true -or $mb.status -cne 'complete' -or $mb.verb -cne 'workspace switch-ai') { throw ('The mb workspace switch-ai verb did not complete: ' + $mbText) }
if ([int]$mb.switched -ne 2) { throw ('The mb verb did not switch both chats: ' + $mbText) }
$mbSids = @($mb.chats | Where-Object { $_.outcome -ceq 'switched' } | ForEach-Object { [string]$_.sid })
if ($mbSids.Count -ne 2) { throw ('The mb verb reported no switched identities: ' + $mbText) }
[void](Wait-WsSavedChats 2 240)
$mbSidsByTmux = @{}
foreach ($row in (Get-WsSavedTabs)) {
    if ($mbSids -notcontains (Get-WsTabSid $row)) { throw ('The saved tab does not carry the mb switch identity: ' + $row.tmux_session) }
    $mbSidsByTmux[$row.tmux_session] = (Get-WsTabSid $row)
}
if ($mbSidsByTmux.Count -ne 2) { throw 'The saved tabs do not carry two mb switch identities' }
Select-WsChat 1 'workspace chat one'
$mbOne = Copy-WsChat 'ws-mb-one'
Select-WsChat 2 'workspace chat two'
$mbTwo = Copy-WsChat 'ws-mb-two'
Assert-WsHistory 'workspace chat one after the mb verb' $mbOne $wsMarkers['ws-chat-one'] 'Switched AI: Claude to Codex'
Assert-WsHistory 'workspace chat two after the mb verb' $mbTwo $wsMarkers['ws-chat-two'] 'Switched AI: Claude to Codex'
Shot 'workspace-switch-mb'
$observation.workspaceSwitch = @{
    workspace = 'Verify workspace'
    chats = @($wsChats | ForEach-Object { @{tmux=$_.tmux; question=$_.question; reply=$_.reply; seeded=$_.sid; codex=$codexSids[$_.tmux]; claude=$claudeSids[$_.tmux]; mb=$mbSidsByTmux[$_.tmux]} })
    antigravity = $observation.antigravity
    mb = @{ exit = $mbExit; ok = $mb.ok; status = $mb.status; switched = [int]$mb.switched; already = [int]$mb.already; sids = $mbSids }
    dividers = @('Switched AI: Claude to Codex', 'Switched AI: Codex to Claude')
}
Save $observation.workspaceSwitch "$caseDir/workspace-switch.json"
