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
Send-Composer $earlierText
[void](Wait-For 'claude stand-in answered the earlier message' {
    $files = @(Get-ChildItem "$hostDir/*.history.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains($earlierText) })
    ($files.Count -eq 1) -and (Read-Shared $files[0].FullName).Contains('Claude stand-in answer')
} 30)
$claudeHistory = @(Get-ChildItem "$hostDir/*.history.jsonl" | Where-Object { (Read-Shared $_.FullName).Contains($earlierText) })[0].FullName
Copy-Item $claudeHistory "$caseDir/claude-history.jsonl"
$tabsBefore = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
Shot 'antigravity-chat-before'
Palette-Choose 'switch ai to antigravity keep chat name' 7053 'antigravity-switch-palette'
[void](Wait-For 'antigravity host enabled by the switch' {
    $configs = @(Get-ChildItem "$hostDir/*.config.json" -ErrorAction SilentlyContinue)
    (@($configs | Where-Object { (Read-Shared $_.FullName) -match '"provider":"antigravity"' -and (Read-Shared $_.FullName) -match '"switched_from"' }).Count -eq 1)
} 90)
$antigravityConfig = @(Get-ChildItem "$hostDir/*.config.json" | Where-Object { (Read-Shared $_.FullName) -match '"provider":"antigravity"' })[0].FullName
$savedAfterSwitch = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
if (@($savedAfterSwitch.tabs).Count -ne $tabsBefore.Count) { throw 'The switch changed the number of chat rows' }
if ($savedAfterSwitch.tabs[0].name -cne $tabsBefore[0].name) { throw 'The switch renamed the chat' }
Copy-Item "$settings/session.json" "$caseDir/session-after-switch.json"
Copy-Item $antigravityConfig "$caseDir/antigravity-config.json"
$antigravityRoot = Split-Path $antigravityConfig
$antigravityHistory = @(Get-ChildItem "$antigravityRoot/*.history.jsonl" | Where-Object { (Read-Shared $_.FullName).Contains('Switched AI: Claude to Antigravity') })
if ($antigravityHistory.Count -ne 1) { throw 'The switch did not write one handed-over antigravity history' }
Copy-Item $antigravityHistory[0].FullName "$caseDir/antigravity-history.jsonl"
if (-not (Read-Shared $antigravityHistory[0].FullName).Contains($earlierText)) { throw 'The switched chat lost the earlier message' }
Bind-Transcript
Send-Composer $afterText
[void](Wait-For 'antigravity stand-in received the new message' {
    (Test-Path "$state/antigravity-deliver.jsonl") -and (Read-Shared "$state/antigravity-deliver.jsonl").Contains($afterText)
} 60)
[void](Wait-For 'antigravity reply reached the switched chat' {
    (Read-Shared $antigravityHistory[0].FullName).Contains('Antigravity stand-in reply')
} 60)
Shot 'antigravity-switched-chat'
Shot 'after'
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
