param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/native.ps1"
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use a GitHub Windows runner' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$workProfile = Join-Path $env:RUNNER_TEMP ('server-chat-real-pi-' + [guid]::NewGuid().ToString('N'))
$settings = Join-Path $workProfile 'roaming/ZigShell'
$actions = [Collections.Generic.List[object]]::new()
$initialSid = 'a1b2c3d4-2567-4000-8000-000000000523'
$tabName = 'Pi Codex Disposable Proof'
$tmuxName = 'live-pi-ci'
$bytes = New-Object byte[] 12
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$marker = 'MUBO523-' + ([BitConverter]::ToString($bytes) -replace '-', '')
$result = @{
    feature = 'server-chat'
    mode = 'real-pi'
    status = 'failed'
    version = $ExpectedVersion
    sha256 = $ExpectedHash
    marker = $marker
    logicalIdentity = @{ name = $tabName; tmux = $tmuxName; hostSlot = 0 }
    cases = @()
    historyPreservation = @{ storedOrdered = $false; visibleOrdered = $false }
    modelRecall = @{ piTurn3 = $false; codexAfterSwitch = $false; piAfterReturn = $false }
    unsupportedReturnHops = @(
        'claude: no approved runner Claude server-chat credential wired',
        'antigravity: no unattended Google credential approved; Pi-first per MUBO-523'
    )
    agentBoundary = 'Real Windows app, Windows OpenSSH, WSL2 Linux OpenSSH server, tmux, real production host/reader, real Pi 1.5.0 (openai-codex/gpt-6.1-sol) and real Codex 0.169.0 via fail-closed CODEX_AUTH_JSON conversion. Zero synthetic provider stand-ins.'
}
$job = $null
Start-Transcript "$Evidence/driver.log"
function Save-Json($Value, [string]$OutPath) { [IO.File]::WriteAllText($OutPath, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Label, [scriptblock]$Check, [int]$Seconds = 150) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 300 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Label"
}
function Read-DebugLog {
    $logPath = "$settings/debug.log"
    if (-not (Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $reader = [IO.StreamReader]::new($stream); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
}
function Assert-Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    $element = [Windows.Automation.AutomationElement]::FromHandle($main)
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id) { throw 'Doctor: app is not visible' }
}
function Capture-Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Send-Chord([int[]]$Keys, [string]$Label) {
    Assert-Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    [ChatDeliveryDesktop]::Chord($Keys)
    Start-Sleep -Milliseconds 150
}
function Type-String([string]$Text) {
    $actions.Add(@{ input = 'type'; text = $Text; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    foreach ($letter in $Text.ToCharArray()) { Assert-Doctor; [ChatDeliveryDesktop]::Character($letter); Start-Sleep -Milliseconds 15 }
}
function Open-PaletteAndChoose([string]$Query, [string]$TargetPattern, [string]$Label) {
    $offset = (Read-DebugLog).Length
    Send-Chord @(0x11, 0x4B) "Ctrl+K: open command palette ($Label)"
    [void](Wait-For "palette ready ($Label)" { (Read-DebugLog).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' } 45)
    Type-String $Query
    $len = $Query.Length
    [void](Wait-For "palette match ($Label)" { (Read-DebugLog).Substring($offset) -match ('\[palette\] ready chars=' + $len + ' count=\d+ target=' + $TargetPattern + '(?:\s|$)') } 45)
    Send-Chord @(0x0D) "Enter: confirm ($Label)"
}
function Copy-VisibleChat([string]$Name) {
    Open-PaletteAndChoose 'chat view select all' '6364' "select all ($Name)"
    Send-Chord @(0x11, 0x43) "Ctrl+C: copy rendered messages ($Name)"
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $copied)
    Send-Chord @(0x1B) "Escape: return to composer ($Name)"
    return $copied
}
function Send-ComposerText([string]$Text) {
    $composer = Wait-For 'owned composer' { $handle = [ChatDeliveryDesktop]::Composer($main); if ($handle -ne [IntPtr]::Zero) { $handle } } 45
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Type-String $Text
    [void](Wait-For 'exact composer text' { [ChatDeliveryDesktop]::Text($composer) -ceq $Text } 30)
    Send-Chord @(0x1B) 'Escape: dismiss completion without changing text'
    Send-Chord @(0x0D) 'Enter: send prompt'
    [void](Wait-For 'composer cleared' { [ChatDeliveryDesktop]::Text($composer) -ceq '' } 30)
}
function Read-ServerSnapshot([string]$Name) {
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/tools/verify-server-chat/real-pi-snapshot.py") -Evidence $Evidence -Name ($Name + '-' + [guid]::NewGuid().ToString('N'))
    $snapshot = ($raw -join "`n") | ConvertFrom-Json
    Save-Json $snapshot "$Evidence/$Name.json"
    return $snapshot
}
function Test-OrderedSubstrings([string]$Haystack, [string[]]$Needles) {
    $cursor = 0
    foreach ($needle in $Needles) {
        if ([string]::IsNullOrWhiteSpace($needle)) { continue }
        $idx = $Haystack.IndexOf($needle, $cursor, [StringComparison]::Ordinal)
        if ($idx -lt 0) { return $false }
        $cursor = $idx + $needle.Length
    }
    return $true
}
function Select-PiCodexSol([string]$StageName, [string]$ExpectedSid) {
    $offset = (Read-DebugLog).Length
    Open-PaletteAndChoose 'pi model' '13000' "open Pi Model ($StageName)"
    [void](Wait-For "Pi models list ready ($StageName)" { (Read-DebugLog).Substring($offset) -match '\[palette\] ready chars=0 count=[2-9]\d* target=13001(?:\s|$)' } 60)
    $filterOffset = (Read-DebugLog).Length
    Type-String 'gpt-6.1-sol'
    [void](Wait-For "gpt-6.1-sol row selected ($StageName)" { (Read-DebugLog).Substring($filterOffset) -match '\[palette\] ready chars=11 count=\d+ target=(1300[1-9]|130[1-9]\d|13[1-4]\d\d)(?:\s|$)' } 30)
    Send-Chord @(0x0D) "Enter: select openai-codex/gpt-6.1-sol ($StageName)"
    $ackSnap = Wait-For "Pi RPC set_model ack ($StageName)" {
        $snap = Read-ServerSnapshot "$StageName-server"
        $hostRow = @($snap.hosts | Where-Object { $_.provider -eq 'pi' -and $_.sid -eq $ExpectedSid }) | Select-Object -First 1
        if (-not $hostRow) { return $null }
        $ack = @($hostRow.log_events | Where-Object { $_.event -eq 'pi_set_model_reply' -and $_.success -eq $true -and $_.provider -ceq 'openai-codex' -and $_.model -ceq 'gpt-6.1-sol' }) | Select-Object -Last 1
        if ($ack) { return $snap }
        return $null
    } 60
    return $ackSnap
}
function Read-SavedSession {
    $sessionFile = "$settings/session.json"
    if (-not (Test-Path $sessionFile)) { return $null }
    return (Get-Content $sessionFile -Raw | ConvertFrom-Json)
}
try {
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'driver-repo-path').Trim()
    & "$PSScriptRoot/start.ps1" -Profile $workProfile -Evidence $Evidence
    $startLogLines = Get-Content "$Evidence/server-start.stdout.log"
    $seedJsonLine = @($startLogLines | Where-Object { $_.TrimStart().StartsWith('{') -and $_.Contains('"provenance"') }) | Select-Object -Last 1
    if (-not $seedJsonLine) { throw 'Missing real-Pi seed provenance output in server-start.stdout.log' }
    $seedInfo = $seedJsonLine | ConvertFrom-Json
    Save-Json $seedInfo.provenance "$Evidence/pi-provenance.json"
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $env:APPDATA = "$workProfile/roaming"
    $env:LOCALAPPDATA = "$workProfile/local"
    $env:USERPROFILE = "$workProfile/home"
    $env:HOME = "$workProfile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    Save-Json @{
        active_tab = 0
        single_window = $false
        chat_active = $false
        tabs = @(@{
            kind = 'tmux'
            name = $tabName
            manual = $true
            tmux_host = 0
            tmux_session = $tmuxName
            ai_agent = 3
            csid = $initialSid
            cv = $false
            pid = 0
        })
    } "$settings/session.json"
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/job.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $workProfile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned app window' { $handle = [ChatDeliveryDesktop]::Window($app.Id); if ($handle -ne [IntPtr]::Zero) { $handle } } 60
    Send-Chord @(0x11, 0x31) 'Ctrl+1: open Pi server tab'
    Send-Chord @(0x12, 0x43) 'Alt+C: open Pi Chat View'
    [void](Wait-For 'owned composer visible' { $handle = [ChatDeliveryDesktop]::Composer($main); if ($handle -ne [IntPtr]::Zero) { $handle } } 60)
    Open-PaletteAndChoose 'auto-switch ai' '7053' 'disable auto-switch AI'
    [void](Wait-For 'auto_switch.on == false persisted' {
        $snap = Read-ServerSnapshot 'auto-switch-off-server'
        $hostRow = @($snap.hosts | Where-Object { $_.provider -eq 'pi' -and $_.sid -eq $initialSid }) | Select-Object -First 1
        if ($hostRow -and $null -ne $hostRow.auto_switch -and $hostRow.auto_switch.on -eq $false) { return $snap }
        return $null
    } 45)
    Capture-Shot 'auto-switch-off'
    $result.cases += @{ name = 'auto-switch-off'; passed = $true; detail = 'Toggled Auto-switch AI off via Ctrl+K and confirmed persisted auto_switch.on=false' }
    [void](Select-PiCodexSol 'pi-model-select' $initialSid)
    Capture-Shot 'pi-model-select'
    $result.cases += @{ name = 'pi-model-select'; passed = $true; detail = 'Selected openai-codex/gpt-6.1-sol through Pi Model picker with real Pi RPC acknowledgement' }
    $turn1Prompt = "Remember this session marker verbatim: $marker. Reply with ACK $marker on one short line and do not call tools."
    Send-ComposerText $turn1Prompt
    $turn1Snap = Wait-For 'real Pi Turn 1 reply' {
        $snap = Read-ServerSnapshot 'pi-turn1-server'
        $sess = @($snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
        if (-not $sess) { return $null }
        $replies = @($sess.messages | Where-Object { $_.role -eq 'assistant' })
        if ($replies.Count -ge 1) { return $snap }
        return $null
    } 150
    $turn1Sess = @($turn1Snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
    $turn1Reply = @($turn1Sess.messages | Where-Object { $_.role -eq 'assistant' })[0]
    if ($turn1Reply.provider -cne 'openai-codex' -or $turn1Reply.model -cne 'gpt-6.1-sol' -or $turn1Reply.stopReason -cne 'stop') {
        throw ('Turn 1 Pi reply invalid: ' + ($turn1Reply | ConvertTo-Json -Compress))
    }
    $turn1Snippet = $turn1Reply.text.Trim()
    if ($turn1Snippet.Length -gt 48) { $turn1Snippet = $turn1Snippet.Substring(0, 48) }
    $turn1Copied = Wait-For 'Turn 1 visible in copied Chat View' {
        $txt = Copy-VisibleChat 'pi-turn1-copied'
        if ($txt.Contains($marker) -and $txt.Contains($turn1Snippet)) { return $txt }
        return $null
    } 60
    Capture-Shot 'pi-turn1'
    $result.cases += @{ name = 'pi-marker-reply'; passed = $true; detail = 'Real Pi openai-codex/gpt-6.1-sol completed reply with high-entropy marker' }
    $turn2Prompt = '/valentin-mode Confirm valentin-mode loaded, read ../responsive-mode/SKILL.md and run sh version.sh in your valentin-mode skill folder, and reply with the exact valentin-mode version line in one short sentence. Skip board-drain and pstack-diff in this disposable check.'
    Send-ComposerText $turn2Prompt
    $turn2Snap = Wait-For 'real Pi Turn 2 valentin-mode reply' {
        $snap = Read-ServerSnapshot 'pi-valentin-mode-server'
        $sess = @($snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
        if (-not $sess) { return $null }
        $replies = @($sess.messages | Where-Object { $_.role -eq 'assistant' })
        if ($replies.Count -ge 2) { return $snap }
        return $null
    } 180
    $turn2Sess = @($turn2Snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
    $turn2Reply = @($turn2Sess.messages | Where-Object { $_.role -eq 'assistant' })[1]
    if ($turn2Reply.provider -cne 'openai-codex' -or $turn2Reply.model -cne 'gpt-6.1-sol' -or $turn2Reply.stopReason -cne 'stop') {
        throw ('Turn 2 Pi valentin-mode reply invalid: ' + ($turn2Reply | ConvertTo-Json -Compress))
    }
    $matchedSkill = @($turn2Sess.skill_loads | Where-Object { $_.location.EndsWith('/valentin-mode/SKILL.md') -and $_.body_sha256 -ceq $seedInfo.provenance.valentin_mode_body_sha256 }) | Select-Object -First 1
    if (-not $matchedSkill) { throw 'Native Pi transcript did not record the pinned valentin-mode SKILL.md body hash' }
    $turn2Snippet = $turn2Reply.text.Trim()
    if ($turn2Snippet.Length -gt 48) { $turn2Snippet = $turn2Snippet.Substring(0, 48) }
    [void](Wait-For 'Turn 2 visible in copied Chat View' {
        $txt = Copy-VisibleChat 'pi-valentin-mode-copied'
        if ($txt.Contains($turn2Snippet)) { return $txt }
        return $null
    } 60)
    Capture-Shot 'pi-valentin-mode'
    $result.valentinMode = @{
        skillLocation = $matchedSkill.location
        loadedBodySha256 = $matchedSkill.body_sha256
        expectedVersionLine = $seedInfo.provenance.valentin_mode_version_line
        replyContainsVersionLine = $turn2Reply.text.Contains($seedInfo.provenance.valentin_mode_version_line)
        replyText = $turn2Reply.text
    }
    $result.cases += @{ name = 'pi-valentin-mode'; passed = $true; detail = 'Loaded real pinned vstack valentin-mode via /valentin-mode and verified SKILL.md body hash in Pi session' }
    $turn3Prompt = 'What exact session marker did I ask you to remember in my first message? Reply with only the marker and do not call tools.'
    Send-ComposerText $turn3Prompt
    $turn3Snap = Wait-For 'real Pi Turn 3 recall reply' {
        $snap = Read-ServerSnapshot 'pi-recall-server'
        $sess = @($snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
        if (-not $sess) { return $null }
        $replies = @($sess.messages | Where-Object { $_.role -eq 'assistant' })
        if ($replies.Count -ge 3) { return $snap }
        return $null
    } 150
    $turn3Sess = @($turn3Snap.pi_sessions | Where-Object { $_.session_id -eq $initialSid }) | Select-Object -First 1
    $turn3Reply = @($turn3Sess.messages | Where-Object { $_.role -eq 'assistant' })[2]
    if ($turn3Reply.provider -cne 'openai-codex' -or $turn3Reply.model -cne 'gpt-6.1-sol' -or $turn3Reply.stopReason -cne 'stop') {
        throw ('Turn 3 Pi recall reply invalid: ' + ($turn3Reply | ConvertTo-Json -Compress))
    }
    $result.modelRecall.piTurn3 = $turn3Reply.text.Contains($marker)
    $turn3Snippet = $turn3Reply.text.Trim()
    if ($turn3Snippet.Length -gt 48) { $turn3Snippet = $turn3Snippet.Substring(0, 48) }
    $turn3Copied = Wait-For 'Turn 3 visible in copied Chat View' {
        $txt = Copy-VisibleChat 'pi-recall-copied'
        if ($txt.Contains($turn3Snippet)) { return $txt }
        return $null
    } 60
    if (-not (Test-OrderedSubstrings $turn3Copied @($turn1Prompt, $turn1Snippet, $turn2Snippet, $turn3Prompt, $turn3Snippet))) {
        throw 'Pi visible history lost original message order before switching'
    }
    Capture-Shot 'pi-recall-bottom'
    for ($step = 0; $step -lt 12; $step++) { Send-Chord @(0x26) 'Up: scroll toward oldest Pi message' }
    Capture-Shot 'pi-recall-top'
    Send-Chord @(0x1B) 'Escape: return to composer after scrolling'
    $result.cases += @{ name = 'pi-recall-and-history'; passed = $true; detail = 'Completed ordinary follow-up on Pi, checked separate model recall and ordered visible/stored history' }
    Open-PaletteAndChoose 'switch ai to codex' '7051' 'switch AI to Codex'
    $codexSwitchSnap = Wait-For 'switch Pi -> Codex handover finished' {
        $snap = Read-ServerSnapshot 'switch-codex-server'
        $codexHost = @($snap.hosts | Where-Object { $_.provider -eq 'codex' -and $_.enabled -eq $true -and $_.tmux -eq $tmuxName }) | Select-Object -First 1
        if (-not $codexHost) { return $null }
        if ($null -ne $codexHost.fresh_start) { return $null }
        if ($codexHost.auto_switch.on -ne $false) { throw 'auto_switch.on did not remain false after switching to Codex' }
        return $snap
    } 180
    $codexHost = @($codexSwitchSnap.hosts | Where-Object { $_.provider -eq 'codex' -and $_.enabled -eq $true }) | Select-Object -First 1
    $codexSid = $codexHost.sid
    if ($codexSid -ceq $initialSid) { throw 'Codex switch reused Pi SID' }
    $codexPrompt = 'Confirm you are replying on Codex after switching from Pi, and repeat the exact session marker from the first message on one short line. Do not call tools.'
    Send-ComposerText $codexPrompt
    $codexReplySnap = Wait-For 'real Codex reply after switch' {
        $snap = Read-ServerSnapshot 'codex-reply-server'
        $hostNow = @($snap.hosts | Where-Object { $_.provider -eq 'codex' -and $_.sid -eq $codexSid }) | Select-Object -First 1
        if (-not $hostNow) { return $null }
        $doneTurns = @($hostNow.log_events | Where-Object { $_.event -eq 'turn_done' -and $_.subtype -eq 'completed' })
        if ($doneTurns.Count -ge 2) { return $snap }
        return $null
    } 180
    $codexHostNow = @($codexReplySnap.hosts | Where-Object { $_.provider -eq 'codex' -and $_.sid -eq $codexSid }) | Select-Object -First 1
    $codexAssistantRows = @($codexHostNow.history_rows | Where-Object { $_.role -eq 'assistant' })
    $codexLastReply = $codexAssistantRows | Select-Object -Last 1
    $codexSnippet = if ($codexLastReply) { $codexLastReply.text.Trim() } else { '' }
    if ($codexSnippet.Length -gt 48) { $codexSnippet = $codexSnippet.Substring(0, 48) }
    $result.modelRecall.codexAfterSwitch = [bool]($codexLastReply -and $codexLastReply.text.Contains($marker))
    $codexCopied = Wait-For 'Codex reply and prior Pi history visible in copied Chat View' {
        $txt = Copy-VisibleChat 'codex-reply-copied'
        if ($txt.Contains($marker) -and $txt.Contains('Switched AI: Pi to Codex') -and (-not $codexSnippet -or $txt.Contains($codexSnippet))) { return $txt }
        return $null
    } 60
    if (-not (Test-OrderedSubstrings $codexCopied @($turn1Prompt, $turn1Snippet, $turn2Snippet, $turn3Prompt, 'Switched AI: Pi to Codex', $codexPrompt))) {
        throw 'Visible history after switching to Codex lost earlier Pi messages or order'
    }
    $savedAfterCodex = Read-SavedSession
    $tabAfterCodex = @($savedAfterCodex.tabs)[0]
    if ($tabAfterCodex.name -cne $tabName -or $tabAfterCodex.tmux_session -cne $tmuxName -or $tabAfterCodex.ai_agent -ne 2 -or $tabAfterCodex.csid -cne $codexSid) {
        throw 'Logical chat identity or adopted Codex SID mismatch in session.json'
    }
    Capture-Shot 'codex-reply'
    $result.cases += @{ name = 'switch-pi-to-codex'; passed = $true; detail = 'Switched Pi -> Codex via Ctrl+K, retained logical identity, auto_switch=false, stored/visible history and real Codex reply' }
    Open-PaletteAndChoose 'switch ai to pi' '7052' 'switch AI back to Pi'
    $piReturnSwitchSnap = Wait-For 'switch Codex -> Pi handover finished' {
        $snap = Read-ServerSnapshot 'switch-back-pi-server'
        $piHost2 = @($snap.hosts | Where-Object { $_.provider -eq 'pi' -and $_.enabled -eq $true -and $_.sid -cne $initialSid }) | Select-Object -First 1
        if (-not $piHost2) { return $null }
        if ($null -ne $piHost2.fresh_start) { return $null }
        if ($piHost2.auto_switch.on -ne $false) { throw 'auto_switch.on did not remain false after switching back to Pi' }
        return $snap
    } 180
    $piHost2 = @($piReturnSwitchSnap.hosts | Where-Object { $_.provider -eq 'pi' -and $_.enabled -eq $true -and $_.sid -cne $initialSid }) | Select-Object -First 1
    $returnPiSid = $piHost2.sid
    if ($returnPiSid -ceq $initialSid -or $returnPiSid -ceq $codexSid) { throw 'Returned Pi switch reused an old SID' }
    [void](Select-PiCodexSol 'pi-return-model-select' $returnPiSid)
    $finalPrompt = 'After returning to Pi, reply with OK and the exact session marker from the first message on one short line. Do not call tools.'
    Send-ComposerText $finalPrompt
    $finalSnap = Wait-For 'real Pi return reply' {
        $snap = Read-ServerSnapshot 'pi-return-server'
        $sess = @($snap.pi_sessions | Where-Object { $_.session_id -eq $returnPiSid }) | Select-Object -First 1
        if (-not $sess) { return $null }
        $replies = @($sess.messages | Where-Object { $_.role -eq 'assistant' })
        if ($replies.Count -ge 2) { return $snap }
        return $null
    } 150
    $returnSess = @($finalSnap.pi_sessions | Where-Object { $_.session_id -eq $returnPiSid }) | Select-Object -First 1
    $finalReply = @($returnSess.messages | Where-Object { $_.role -eq 'assistant' }) | Select-Object -Last 1
    if ($finalReply.provider -cne 'openai-codex' -or $finalReply.model -cne 'gpt-6.1-sol' -or $finalReply.stopReason -cne 'stop') {
        throw ('Final returned Pi reply invalid: ' + ($finalReply | ConvertTo-Json -Compress))
    }
    $result.modelRecall.piAfterReturn = $finalReply.text.Contains($marker)
    $finalSnippet = $finalReply.text.Trim()
    if ($finalSnippet.Length -gt 48) { $finalSnippet = $finalSnippet.Substring(0, 48) }
    $finalCopied = Wait-For 'final Pi reply and full roundtrip history visible in copied Chat View' {
        $txt = Copy-VisibleChat 'pi-return-copied'
        if ($txt.Contains($marker) -and $txt.Contains('Switched AI: Codex to Pi') -and $txt.Contains($finalSnippet)) { return $txt }
        return $null
    } 60
    $finalHost = @($finalSnap.hosts | Where-Object { $_.provider -eq 'pi' -and $_.sid -eq $returnPiSid }) | Select-Object -First 1
    $storedCombined = (@($finalHost.history_rows | ForEach-Object { $_.text }) -join "`n")
    $expectedOrder = @($turn1Prompt, $turn1Snippet, $turn2Snippet, $turn3Prompt, 'Switched AI: Pi to Codex', $codexPrompt, 'Switched AI: Codex to Pi', $finalPrompt, $finalSnippet)
    $result.historyPreservation.storedOrdered = Test-OrderedSubstrings $storedCombined $expectedOrder
    $result.historyPreservation.visibleOrdered = Test-OrderedSubstrings $finalCopied $expectedOrder
    if (-not $result.historyPreservation.storedOrdered) { throw 'Stored history on returned Pi host lost earlier messages or order' }
    if (-not $result.historyPreservation.visibleOrdered) { throw 'Visible copied history on returned Pi host lost earlier messages or order' }
    $savedAfterReturn = Read-SavedSession
    $tabAfterReturn = @($savedAfterReturn.tabs)[0]
    if ($tabAfterReturn.name -cne $tabName -or $tabAfterReturn.tmux_session -cne $tmuxName -or $tabAfterReturn.ai_agent -ne 3 -or $tabAfterReturn.csid -cne $returnPiSid) {
        throw 'Logical chat identity or adopted returned Pi SID mismatch in session.json'
    }
    $result.logicalIdentity.initialPiSid = $initialSid
    $result.logicalIdentity.codexSid = $codexSid
    $result.logicalIdentity.returnedPiSid = $returnPiSid
    Capture-Shot 'roundtrip-bottom'
    for ($step = 0; $step -lt 10; $step++) { Send-Chord @(0x26) 'Up: scroll to middle of roundtrip history' }
    Capture-Shot 'roundtrip-middle'
    for ($step = 0; $step -lt 20; $step++) { Send-Chord @(0x26) 'Up: scroll to oldest roundtrip message' }
    Capture-Shot 'roundtrip-top'
    Send-Chord @(0x1B) 'Escape: return to composer after roundtrip inspection'
    $result.cases += @{ name = 'switch-codex-back-to-pi'; passed = $true; detail = 'Switched Codex -> Pi via Ctrl+K, reselected openai-codex/gpt-6.1-sol with RPC ack, proved reply and ordered stored/visible history' }
    Save-Json @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
    $result.status = 'passed'
} catch {
    $result.error = $_.ToString()
    if ($null -ne $job) { Capture-Shot 'failure' }
    throw
} finally {
    if ($null -ne $job) { $cleanup = $job.Stop(); $result.cleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $job.Dispose() }
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/debug.log" }
    try {
        $linuxEvidence = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $Evidence) -Evidence $Evidence -Name 'evidence-path').Trim()
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$repo/tools/verify-server-chat/stop.sh", $linuxEvidence) -Evidence $Evidence -Name 'server-stop')
        $authCheck = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', '-c', 'if [ -e /home/mpverify/.pi/agent/auth.json ] || [ -e /home/mpverify/.codex/auth.json ]; then echo PRESENT; else echo REMOVED; fi') -Evidence $Evidence -Name 'auth-cleanup-check').Trim()
        $result.authFilesRemoved = ($authCheck -ceq 'REMOVED')
        if (-not $result.authFilesRemoved) { $result.status = 'failed'; $result.cleanupError = 'Auth files still existed after stop.sh' }
    } catch {
        $result.cleanupError = $_.ToString()
        $result.status = 'failed'
    }
    try {
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'wsl-terminate')
    } catch {
        $result.cleanupError = ($result['cleanupError'], $_.ToString() -join "`n")
        $result.status = 'failed'
    }
    Remove-Item -LiteralPath $workProfile -Recurse -Force -ErrorAction SilentlyContinue
    $result.keyRemoved = -not (Test-Path "$settings/ssh-key/multibot_ed25519")
    if (-not $result.keyRemoved) { $result.status = 'failed'; $result.error = 'Private key cleanup failed' }
    Save-Json $actions "$Evidence/actions.json"
    Save-Json $result "$Evidence/result.json"
    Stop-Transcript
}
if ($result.status -ne 'passed') { throw ($result['error'], $result['cleanupError'] -join "`n") }
