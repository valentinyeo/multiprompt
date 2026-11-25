$hostDir = "$profile/home/.local/state/multiprompt/agent-host"
$paletteLog = "$settings/debug.log"
$earlierText = 'earlier claude question'
$afterText = 'after the switch'
function Palette-Choose([string]$Query, [int]$Target, [string]$Screenshot) {
    $offset = (Read-Shared $paletteLog).Length
    Press @(0x11, 0x4B) "Ctrl+K: $Query"
    [void](Wait-For 'palette opened' { (Read-Shared $paletteLog).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $actions.Add(@{case=$plan.name; input='type palette query'; text=$Query; target=$Target})
    foreach ($letter in $Query.ToCharArray()) { Doctor; [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For "palette row for $Query" { (Read-Shared $paletteLog).Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=\d+ target=' + $Target + '\b') } 15)
    Shot $Screenshot
    Press @(0x0D) "Enter: $Query"
}
function Send-Composer([string]$Text) {
    Type-Composer $Text
    if ([ChatDeliveryDesktop]::Text($composer) -cne $Text) { throw ('Composer did not hold ' + $Text) }
    Press @(0x0D) "Enter: send $Text" $true
    [void](Wait-For 'composer cleared after send' { [ChatDeliveryDesktop]::Text($composer) -ceq '' } 10)
}
function Tab-Menu-Show([string]$Query, [int]$Target, [string]$Screenshot) {
    $rows = @([regex]::Matches((Read-Shared $paletteLog), '\[photo-proof\] expanded target=0 rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)'))
    if ($rows.Count -eq 0) { throw 'The app reported no sidebar row geometry for the chat tab' }
    $shape = $rows[$rows.Count - 1].Groups
    $x = [int](([int]$shape[1].Value + [int]$shape[3].Value) / 2)
    $y = [int](([int]$shape[2].Value + [int]$shape[4].Value) / 2)
    $offset = (Read-Shared $paletteLog).Length
    Doctor
    [void](Wait-For 'owned app foreground for the tab row' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main); [ChatDeliveryDesktop]::GetForegroundWindow() -eq $main })
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='right-click the chat tab row'; x=$x; y=$y})
    [ChatDeliveryDesktop]::RightClickClient($main, $app.Id, $x, $y)
    [void](Wait-For 'tab actions palette opened from the tab row' { (Read-Shared $paletteLog).Substring($offset) -match '\[palette\] rows chars=0 count=\d+ ids=\d+' } 15)
    foreach ($letter in $Query.ToCharArray()) { Doctor; [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For "tab actions filtered by $Query" { (Read-Shared $paletteLog).Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=\d+ target=\d+') } 15)
    $chosen = $false
    for ($row = 0; $row -lt 8; $row++) {
        if ((Read-Shared $paletteLog).Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=\d+ target=' + $Target + '\b')) { $chosen = $true; break }
        Press @(0x28) 'Down: next tab action'
        Start-Sleep -Milliseconds 300
    }
    if (-not $chosen) { throw ("The tab actions menu never selected " + $Query) }
    $listed = @([regex]::Matches((Read-Shared $paletteLog).Substring($offset), '\[palette\] rows chars=\d+ count=\d+ ids=[^\r\n]+'))
    if ($listed.Count -eq 0) { throw 'The tab actions palette listed no rows' }
    Shot $Screenshot
    Save @{source='chat tab right-click menu'; query=$Query; selected=$Target; rows=$listed[$listed.Count - 1].Value; screenshot=($Screenshot + '.png'); tabRow=@($x, $y)} "$caseDir/tab-menu.json"
    Press @(0x1B) 'Esc: close the tab actions menu'
    Start-Sleep -Milliseconds 500
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
function Agent-Configs {
    @(Get-ChildItem "$hostDir/*.config.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $config = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $config | Add-Member -NotePropertyName path -NotePropertyValue $_.FullName
        $config
    })
}
function Agent-Configs-Switched-From([string]$Provider) {
    @((Agent-Configs) | Where-Object {
        $from = $null
        if ($_.PSObject.Properties['switched_from']) { $from = $_.switched_from }
        ($_.provider -ceq 'claude') -and $null -ne $from -and ($from.provider -ceq $Provider)
    })
}
$paneCache = "$settings/poll-cache-vps.json"
$agyPane = Wait-For 'app reported the agy tmux pane as Antigravity' {
    try { @(((Read-Shared $paneCache) | ConvertFrom-Json).sessions | Where-Object { $_.name -ceq 'agy-pane' -and [int]$_.agent -eq 8 })[0] } catch { $null }
} 90
if ([int]$agyPane.agent -ne 8) { throw 'The app did not report the agy tmux pane as Antigravity' }
Save @{pane=$agyPane.name; paneCommand='agy'; agent=[int]$agyPane.agent; label='Antigravity'; source='app-written poll-cache-vps.json'} "$caseDir/agy-pane-agent.json"
Send-Composer $earlierText
[void](Wait-For 'claude stand-in answered the earlier message' {
    $files = @(Get-ChildItem "$hostDir/*.history.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains($earlierText) })
    ($files.Count -eq 1) -and (Read-Shared $files[0].FullName).Contains('Claude stand-in answer')
} 30)
$claudeHistory = @(Get-ChildItem "$hostDir/*.history.jsonl" | Where-Object { (Read-Shared $_.FullName).Contains($earlierText) })[0].FullName
Copy-Item $claudeHistory "$caseDir/claude-history.jsonl"
$tabsBefore = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
Shot 'antigravity-chat-before'
Palette-Choose 'switch ai to antigravity' 7053 'antigravity-switch-palette'
[void](Wait-For 'antigravity host enabled by the switch' {
    @((Agent-Configs) | Where-Object {
        $from = $null
        if ($_.PSObject.Properties['switched_from']) { $from = $_.switched_from }
        ($_.provider -ceq 'antigravity') -and $null -ne $from -and ($_.enabled -eq $true)
    }).Count -eq 1
} 90)
$antigravityConfig = @((Agent-Configs) | Where-Object { $_.provider -ceq 'antigravity' })[0].path
$antigravitySid = (Get-Content $antigravityConfig -Raw | ConvertFrom-Json).sid
$savedAfterSwitch = Wait-For 'the desktop adopted the Antigravity provider and session' {
    if (-not (Test-Path "$settings/session.json")) { return $null }
    $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
    $row = $saved.tabs[0]
    if ($row.PSObject.Properties['ai_agent'] -and [int]$row.ai_agent -eq 8 -and $row.PSObject.Properties['csid'] -and $row.csid -ceq $antigravitySid) { $saved }
} 90
if (@($savedAfterSwitch.tabs).Count -ne $tabsBefore.Count) { throw 'The switch changed the number of chat rows' }
if ($savedAfterSwitch.tabs[0].name -cne $tabsBefore[0].name) { throw 'The switch renamed the chat' }
Copy-Item "$settings/session.json" "$caseDir/session-after-switch.json"
Copy-Item $antigravityConfig "$caseDir/antigravity-config.json"
$antigravityRoot = Split-Path $antigravityConfig
$antigravityHistory = @(Get-ChildItem "$antigravityRoot/*.history.jsonl" | Where-Object { (Read-Shared $_.FullName).Contains('Switched AI: Claude to Antigravity') })
if ($antigravityHistory.Count -ne 1) { throw 'The switch did not write one handed-over antigravity history' }
if (-not (Read-Shared $antigravityHistory[0].FullName).Contains($earlierText)) { throw 'The switched chat lost the earlier message' }
Tab-Menu-Show 'switch ai to claude' 7176 'antigravity-tab-menu-switch'
$releaseEvent = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, 'Local\multiprompt-verify-antigravity-release')
$releaseEvent.Reset()
[IO.File]::WriteAllText("$state/hold-reply", '')
Bind-Transcript
Send-Composer $afterText
[void](Wait-For 'antigravity stand-in is still writing the reply' { (Test-Path "$state/antigravity-hold.jsonl") -and (Read-Shared "$state/antigravity-hold.jsonl").Contains('"stage": "replying"') } 30)
$holdRows = @((Read-Shared "$state/antigravity-hold.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
$held = @($holdRows | Where-Object { $_.stage -ceq 'replying' -and $_.text -ceq $afterText })[-1]
if (-not $held) { throw 'The stand-in never held the reply to the new message' }
if (@($holdRows | Where-Object { $_.stage -ceq 'released' -or $_.stage -ceq 'timeout' }).Count -ne 0) { throw 'The reply finished before the switch could be tried' }
$heldReply = $held.reply
$historyRows = @((Read-Shared $antigravityHistory[0].FullName) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
if (@($historyRows | Where-Object { $_.row.role -eq 'assistant' -and $_.row.text -ceq $heldReply }).Count -ne 0) { throw 'The reply finished before the switch could be tried' }
Palette-Choose 'switch ai to claude' 7050 'antigravity-busy-switch-palette'
[void](Wait-For 'the host refused the switch while the chat was replying' { (Test-Path "$state/antigravity-switch.jsonl") -and (Read-Shared "$state/antigravity-switch.jsonl").Contains('"status": "busy"') } 30)
Start-Sleep -Milliseconds 800
Shot 'antigravity-switch-while-replying'
$switchRows = @((Read-Shared "$state/antigravity-switch.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
$busy = @($switchRows | Where-Object { $_.status -eq 'busy' })[-1]
$busyConfig = Get-Content $antigravityConfig -Raw | ConvertFrom-Json
if ($busyConfig.provider -cne 'antigravity' -or $busyConfig.enabled -ne $true) { throw 'The refused switch disabled the Antigravity chat' }
if (@(Agent-Configs-Switched-From 'antigravity').Count -ne 0) { throw 'The refused switch still moved the chat to Claude' }
Save @{notice='Switch AI: wait for this reply to finish'; screenshot='antigravity-switch-while-replying.png'; request=@{provider=$busy.provider; sid=$busy.sid; target=$busy.target}; reply=@{status=$busy.status; reason=$busy.reason}; providerAfter=$busyConfig.provider; sidAfter=$busyConfig.sid; stillReplying=$true; heldReply=$heldReply} "$caseDir/switch-while-replying.json"
Remove-Item -LiteralPath "$state/hold-reply" -Force -ErrorAction SilentlyContinue
[void]$releaseEvent.Set()
[void](Wait-For 'antigravity stand-in released the held reply' { (Read-Shared "$state/antigravity-hold.jsonl").Contains('"stage": "released"') } 30)
$releaseEvent.Dispose()
[void](Wait-For 'antigravity stand-in received the new message' {
    (Test-Path "$state/agy-received.jsonl") -and (Read-Shared "$state/agy-received.jsonl").Contains($afterText)
} 60)
[void](Wait-For 'antigravity reply reached the switched chat' {
    (Read-Shared $antigravityHistory[0].FullName).Contains($heldReply)
} 60)
Copy-Item $antigravityHistory[0].FullName "$caseDir/antigravity-history.jsonl"
Shot 'antigravity-switched-chat'
Shot 'after'
Palette-Choose 'switch ai to claude' 7050 'antigravity-switch-back-palette'
[void](Wait-For 'claude host enabled by the switch back' {
    @(Agent-Configs-Switched-From 'antigravity').Count -eq 1
} 90)
$claudeBackConfig = @(Agent-Configs-Switched-From 'antigravity')[0].path
$claudeBackRoot = Split-Path $claudeBackConfig
$claudeBackHistory = @(Get-ChildItem "$claudeBackRoot/*.history.jsonl" | Where-Object { (Read-Shared $_.FullName).Contains('Switched AI: Antigravity to Claude') })
if ($claudeBackHistory.Count -ne 1) { throw 'The switch back did not write one Claude history' }
foreach ($kept in @($earlierText, $afterText, $heldReply, 'Switched AI: Claude to Antigravity', 'Switched AI: Antigravity to Claude')) {
    if (-not (Read-Shared $claudeBackHistory[0].FullName).Contains($kept)) { throw ('The switch back lost ' + $kept) }
}
$backSid = (Get-Content $claudeBackConfig -Raw | ConvertFrom-Json).sid
[void](Wait-For 'the chat stays on Claude with the same row' {
    if (-not (Test-Path "$settings/session.json")) { return $false }
    $savedBack = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
    $row = $savedBack.tabs[0]
    $hasAgent = [bool]($row.PSObject.Properties['ai_agent'])
    $hasSid = [bool]($row.PSObject.Properties['csid'])
    (@($savedBack.tabs).Count -eq $tabsBefore.Count) -and ($row.name -ceq $tabsBefore[0].name) -and $hasAgent -and ([int]$row.ai_agent -eq 1) -and $hasSid -and ($row.csid -ceq $backSid)
} 60)
$backRows = @((Read-Shared $claudeBackHistory[0].FullName) -split "`n" | Where-Object { $_.Trim() })
if ($backRows.Count -lt 5) { throw 'The switch back kept too few readable history rows' }
Copy-Item $claudeBackConfig "$caseDir/claude-back-config.json"
Copy-Item $claudeBackHistory[0].FullName "$caseDir/claude-back-history.jsonl"
Copy-Item "$settings/session.json" "$caseDir/session-after-switch-back.json"
Bind-Transcript
$renderOffset = (Read-Shared $paletteLog).Length
[void](Wait-For 'switched-back history reaches the real renderer' {
    Press @(0x11, 0x30) 'Ctrl+0: measure switched-back history'
    $frames = [regex]::Matches((Read-Shared $paletteLog).Substring($renderOffset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
    $frames.Count -gt 0 -and [int]$frames[$frames.Count - 1].Groups[1].Value -eq $backRows.Count
} 15)
[Windows.Forms.Clipboard]::Clear()
Palette-Choose 'chat view select all' 6364 'antigravity-switch-back-copy-palette'
Press @(0x11, 0x43) 'Ctrl+C: copy switched-back rendered history'
$copiedBack = [Windows.Forms.Clipboard]::GetText()
[IO.File]::WriteAllText("$caseDir/switch-back-copied.txt", $copiedBack)
foreach ($kept in @($earlierText, 'Claude stand-in answer', $afterText, $heldReply, 'Switched AI: Claude to Antigravity', 'Switched AI: Antigravity to Claude')) {
    if (-not $copiedBack.Contains($kept)) { throw ('The rendered switch back lost ' + $kept) }
}
Press @(0x1B) 'Esc: clear switched-back history selection'
Shot 'antigravity-switch-back-claude'
Save @{notice='Chat switched to Claude'; screenshot='antigravity-switch-back-claude.png'; provider=(Get-Content $claudeBackConfig -Raw | ConvertFrom-Json).provider; switchedFrom=(Get-Content $claudeBackConfig -Raw | ConvertFrom-Json).switched_from.provider; rows=$backRows.Count; name=$tabsBefore[0].name} "$caseDir/switch-back.json"
$runtimeDir = "$profile/home/.multiprompt-runtime"
$sharedReader = Join-Path $runtimeDir 'reader.py'
New-Item -ItemType Directory -Force $runtimeDir | Out-Null
if (Test-Path $sharedReader) { Copy-Item $sharedReader "$caseDir/shared-reader-before-fresh.py" }
$staleReader = Join-Path $PSScriptRoot '../fixtures/MUBO-221/stale-reader.py'
Copy-Item $staleReader $sharedReader -Force
[IO.File]::WriteAllText("$state/stale-reader", 'older shared reader without the Antigravity provider')
Save @{case='fresh antigravity chat'; sharedReader='reader.py'; staleSha256=(Get-FileHash $sharedReader -Algorithm SHA256).Hash.ToLower(); reason='an older client selected its own bundle last'; pinnedRuntime=$null} "$caseDir/fresh-start-runtime.json"
Palette-Choose 'new antigravity sessions' 5109 'antigravity-new-session-palette'
[void](Wait-For 'new Antigravity session tab in Chat View' {
    if (-not (Test-Path "$settings/session.json")) { return $false }
    $tabs = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
    (@($tabs | Where-Object { $_.name -ceq 'Antigravity' -and $_.cv -eq $true }).Count -eq 1) -and ($tabs.Count -eq $tabsBefore.Count + 1)
} 90)
$expectedShells = $tabsBefore.Count + 1
Bind-Transcript
$savedNewSession = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
Copy-Item "$settings/session.json" "$caseDir/session-new-session.json"
$newTab = @($savedNewSession.tabs | Where-Object { $_.name -ceq 'Antigravity' })[0]
if (-not $newTab.tmux_session.StartsWith('live-')) { throw 'The new Antigravity tab is not a hosted live chat' }
[void](Wait-For 'launch command carried the antigravity provider' {
    (Test-Path "$state/invocations.jsonl") -and (Read-Shared "$state/invocations.jsonl").Contains('antigravity')
} 30)
Shot 'antigravity-new-session'
$launch = Wait-For 'the fresh Antigravity chat ran its host enable launch' {
    $found = @((Read-Shared "$state/invocations.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ -and $_.kind -ceq 'reader' -and (($_.argv -join ' ') -match 'host enable antigravity') })
    if ($found.Count -gt 0) { $found[$found.Count - 1] }
} 30
$launchText = $launch.argv -join ' '
$pinned = [regex]::Match($launchText, '\.multiprompt-runtime/([0-9a-f]{64})\.py')
if (-not $pinned.Success) { throw ('The fresh Antigravity chat launched the shared pointer instead of its own published runtime: ' + $launchText) }
$publishRows = @((Read-Shared "$state/runtime-publish.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
$ownRuntime = @($publishRows | Where-Object { $_.sha256 -ceq $pinned.Groups[1].Value })
if ($ownRuntime.Count -lt 1) { throw 'The launched runtime is not a bundle this app published' }
if (-not ($publishRows | Where-Object { $_.sharedPointerHeld -eq $true })) { throw 'The shared reader pointer was not held stale during the fresh launch' }
$heldPublish = @($publishRows | Where-Object { $_.sharedPointerHeld -eq $true })[-1]
Save @{case='fresh antigravity chat'; sharedReader='reader.py'; staleSha256=(Get-FileHash $staleReader -Algorithm SHA256).Hash.ToLower(); reason='an older client selected its own bundle last'; pinnedRuntime=$pinned.Groups[1].Value; launch=$launchText; published=@($ownRuntime.sha256); sharedPointerHeldAtPreparation=$true; generation=$heldPublish.generation} "$caseDir/fresh-start-runtime.json"
$freshSid = $newTab.csid
[void](Wait-For 'the fresh Antigravity chat enabled itself on the server' {
    @((Agent-Configs) | Where-Object { $_.provider -ceq 'antigravity' -and $_.sid -ceq $freshSid -and $_.enabled -eq $true -and $_.tmux.StartsWith('live-') }).Count -eq 1
} 90)
$freshConfig = @((Agent-Configs) | Where-Object { $_.sid -ceq $freshSid })[0].path
Copy-Item $freshConfig "$caseDir/fresh-antigravity-config.json"
$freshHistory = Join-Path (Split-Path $freshConfig) ((Split-Path $freshConfig -Leaf) -replace '\.config\.json$', '.history.jsonl')
$freshText = 'first message in a fresh antigravity chat'
Send-Composer $freshText
[void](Wait-For 'the fresh Antigravity chat sent its first message' {
    (Test-Path "$state/agy-received.jsonl") -and (Read-Shared "$state/agy-received.jsonl").Contains($freshText)
} 60)
[void](Wait-For 'the fresh Antigravity chat showed a reply' {
    (Test-Path $freshHistory) -and (Read-Shared $freshHistory).Contains('Antigravity stand-in reply 1.')
} 60)
Copy-Item $freshHistory "$caseDir/fresh-antigravity-history.jsonl"
Remove-Item -LiteralPath "$state/stale-reader" -Force -ErrorAction SilentlyContinue
Save @{provider='antigravity'; sid=$freshSid; enabled=$true; firstMessage=$freshText; reply='Antigravity stand-in reply 1.'; config=(Split-Path $freshConfig -Leaf); pinnedRuntime=$pinned.Groups[1].Value} "$caseDir/fresh-antigravity-reply.json"
Shot 'antigravity-fresh-reply'
$freshReply = 'Antigravity stand-in reply 1.'
$freshSecondText = 'second message in a fresh antigravity chat'
$freshThirdText = 'third message in a fresh antigravity chat'
$freshSecondReply = 'Antigravity stand-in reply 3.'
$freshThirdReply = 'Antigravity stand-in reply 5.'
$freshTexts = @($freshText, $freshSecondText, $freshThirdText)
$freshReplies = @($freshReply, $freshSecondReply, $freshThirdReply)
$freshState = $freshHistory -replace '\.history\.jsonl$', '.state.json'
if (-not (Test-Path $freshState)) { throw 'The fresh Antigravity host wrote no state file at its start' }
$freshKept = Get-Content $freshState -Raw | ConvertFrom-Json
if ($freshKept.display_history -ne $true) { throw 'The fresh Antigravity host start never claimed its canonical history' }
if ([bool]($freshKept.PSObject.Properties['display_history']) -ne $true) { throw 'The fresh Antigravity state has no display_history field to read' }
Save @{state=(Split-Path $freshState -Leaf); display_history=$freshKept.display_history; history=(Split-Path $freshHistory -Leaf); historyExists=(Test-Path $freshHistory); claimBoundary='production host loop start; the fixture never writes this flag'} "$caseDir/fresh-history-claim.json"
function Fresh-Blocks([string]$Stage) {
    $offset = (Read-Shared $paletteLog).Length
    Press @(0x11, 0x30) "Ctrl+0: measure the $Stage Antigravity history"
    Wait-For "the $Stage Antigravity history paints from the reader" {
        $frames = [regex]::Matches((Read-Shared $paletteLog).Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
        if ($frames.Count -gt 0) {
            $painted = [int]$frames[$frames.Count - 1].Groups[1].Value
            if ($painted -gt 0) { $painted }
        }
    } 20
}
function Fresh-Copied([string]$Stage) {
    [Windows.Forms.Clipboard]::Clear()
    Bind-Transcript
    Palette-Choose 'chat view select all' 6364 ("antigravity-fresh-copy-" + $Stage)
    Press @(0x11, 0x43) ("Ctrl+C: copy the $Stage Antigravity transcript")
    [IO.File]::WriteAllText("$caseDir/fresh-copied-$Stage.txt", [Windows.Forms.Clipboard]::GetText())
    Press @(0x1B) ("Esc: clear the $Stage Antigravity copy selection")
}
function Fresh-Text([string]$Stage) {
    Read-Shared "$caseDir/fresh-copied-$Stage.txt"
}
function Fresh-Transcript([string]$Stage, [string]$Text) {
    $cursor = 0
    foreach ($kept in $freshTexts + $freshReplies) {
        if (([regex]::Matches($Text, [regex]::Escape($kept))).Count -ne 1) { throw ('The ' + $Stage + ' Antigravity transcript does not hold exactly one ' + $kept) }
        $found = $Text.IndexOf($kept, $cursor, [StringComparison]::Ordinal)
        if ($found -lt 0) { throw ('The ' + $Stage + ' Antigravity transcript is out of order at ' + $kept) }
        $cursor = $found + $kept.Length
    }
}
function Fresh-Resync([string]$Stage) {
    $reloadOffset = (Read-Shared $paletteLog).Length
    Press @(0x11, 0x4B) "Ctrl+K: open the chat menu for the $Stage full reload"
    [void](Wait-For "chat menu palette ready for the $Stage full reload" { (Read-Shared $paletteLog).Substring($reloadOffset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $reloadQuery = 'more menu'
    foreach ($letter in $reloadQuery.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For "more menu command selected for the $Stage full reload" { (Read-Shared $paletteLog).Substring($reloadOffset) -match ('\[palette\] ready chars=' + $reloadQuery.Length + ' count=1 target=6466') })
    Press @(0x0D) "Enter: open More Menu for the $Stage full reload"
    $reloadRect = Wait-For "painted Resync row for the $Stage full reload" {
        $rows = [regex]::Matches((Read-Shared $paletteLog).Substring($reloadOffset), '\[chat\] menu resync rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
        if ($rows.Count) { $rows[$rows.Count - 1].Groups }
    }
    $reloadRoot = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $reloadCondition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptMoreMenu')
    $reloadMenus = @($reloadRoot.FindAll([System.Windows.Automation.TreeScope]::Descendants, $reloadCondition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($reloadMenus.Count -ne 1) { throw 'Expected one owned visible chat menu for the full reload' }
    $reloadX = [int](([int]$reloadRect[1].Value + [int]$reloadRect[3].Value) / 2)
    $reloadY = [int](([int]$reloadRect[2].Value + [int]$reloadRect[4].Value) / 2)
    Doctor
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input="real mouse click Resync chat $Stage"; x=$reloadX; y=$reloadY})
    [ChatDeliveryDesktop]::PressClient([IntPtr]$reloadMenus[0].Current.NativeWindowHandle, $app.Id, $reloadX, $reloadY)
    [void](Wait-For "the $Stage Antigravity source reload completes" { (Read-Shared $paletteLog).Substring($reloadOffset).Contains('[chat] resync completed') } 30)
}
Send-Composer $freshSecondText
[void](Wait-For 'the fresh Antigravity chat showed its second reply' { (Read-Shared $freshHistory).Contains($freshSecondReply) } 60)
Send-Composer $freshThirdText
[void](Wait-For 'the fresh Antigravity chat showed its third reply' { (Read-Shared $freshHistory).Contains($freshThirdReply) } 60)
$freshBlocksBefore = Fresh-Blocks 'sent'
Fresh-Copied 'before'
Fresh-Transcript 'sent' (Fresh-Text 'before')
Shot 'antigravity-fresh-before-reload'
Fresh-Resync 'first'
$freshBlocksAfter = Fresh-Blocks 'reloaded'
Fresh-Copied 'after'
Fresh-Transcript 'reloaded' (Fresh-Text 'after')
if ($freshBlocksAfter -ne $freshBlocksBefore) { throw ('The full reload changed the painted Antigravity row count: ' + $freshBlocksBefore + ' -> ' + $freshBlocksAfter) }
if ((Fresh-Text 'after').Trim() -cne (Fresh-Text 'before').Trim()) { throw 'The full reload changed the visible Antigravity transcript' }
Shot 'antigravity-fresh-after-reload'
Fresh-Resync 'second'
Fresh-Copied 'reload-twice'
Fresh-Transcript 'reloaded twice' (Fresh-Text 'reload-twice')
if ((Fresh-Text 'reload-twice').Trim() -cne (Fresh-Text 'before').Trim()) { throw 'The repeated full reload changed the visible Antigravity transcript' }
Shot 'antigravity-fresh-reload-twice'
Press @(0x11, 0x09) 'Ctrl+Tab: leave the fresh Antigravity chat'
Start-Sleep -Milliseconds 500
Shot 'antigravity-fresh-tab-away'
Press @(0x11, 0x09) 'Ctrl+Tab: return to the fresh Antigravity chat'
Fresh-Copied 'tab-away-back'
Fresh-Transcript 'tab away and back' (Fresh-Text 'tab-away-back')
if ((Fresh-Text 'tab-away-back').Trim() -cne (Fresh-Text 'before').Trim()) { throw 'The tab away and back view changed the visible Antigravity transcript' }
Shot 'antigravity-fresh-tab-returned'
$freshSessionRow = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs | Where-Object { $_.name -ceq 'Antigravity' })[0]
if ($freshSessionRow.csid -cne $freshSid) { throw 'The full reloads changed the fresh Antigravity chat identity' }
$freshClaimAfter = Get-Content $freshState -Raw | ConvertFrom-Json
if ($freshClaimAfter.display_history -ne $true) { throw 'The full reloads dropped the claimed Antigravity history flag' }
Save @{provider='antigravity'; sid=$freshSid; messages=$freshTexts.Count; texts=$freshTexts; replies=$freshReplies; reload='Chat View Resync chat'; reloads=2; tabAwayBack=$true; blocksBefore=$freshBlocksBefore; blocksAfter=$freshBlocksAfter; sidAfter=$freshSessionRow.csid; displayHistoryAfter=$freshClaimAfter.display_history; copiedBefore='fresh-copied-before.txt'; copiedAfter='fresh-copied-after.txt'; copiedTwice='fresh-copied-reload-twice.txt'; copiedTabAway='fresh-copied-tab-away-back.txt'; sameTranscript=$true; claim='fresh-history-claim.json'} "$caseDir/fresh-reload.json"
