param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Hosted Windows only' }
Remove-Item Env:ROOMS_PROOF_CREDENTIAL -ErrorAction SilentlyContinue
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Security, UIAutomationClient, UIAutomationTypes
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/control-native.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$profile = Join-Path $env:RUNNER_TEMP ('rooms-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $profile 'roaming'
$env:LOCALAPPDATA = Join-Path $profile 'local'
$env:USERPROFILE = Join-Path $profile 'home'
$env:HOME = $env:USERPROFILE
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
$env:MP_VERIFY_STATE = Join-Path $profile 'remote'
$env:MP_VERIFY_PYTHON = (Get-Command python).Source
$env:MP_VERIFY_BOUNDARY = Join-Path $PSScriptRoot 'boundary.py'
Remove-Item Env:MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
$settings = Join-Path $env:APPDATA 'ZigShell'
New-Item -ItemType Directory -Force $settings, $env:LOCALAPPDATA, $env:USERPROFILE, $env:MP_VERIFY_STATE, (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Documents') | Out-Null
$hostName = 'account.multiprompt.dev'
$hostsFile = "$env:SystemRoot/System32/drivers/etc/hosts"
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$hostsChanged = $false
$cert = $null
$rootCertAdded = $false
$accountJob = $null
$accountServer = $null
$logPath = Join-Path $settings 'debug.log'
$checks = [Collections.Generic.List[object]]::new()
$actions = [Collections.Generic.List[object]]::new()
$result = @{status='failed'; cleanup='pending'; account_cleanup='pending'; checks=$checks; error=$null; boundary='Preview only: actual isolated account Worker and native UI plus embedded bridge/store; synthetic SSH, host ownership and provider stdin/output; in-process canonical transaction/host reducers; no POSIX lock or real provider proof'}
$job = $null
$app = $null
$main = [IntPtr]::Zero
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check) {
    $result.phase='wait: ' + $Name
    Save $result (Join-Path $Evidence 'result.json')
    Write-Host ('ROOM_WAIT ' + $Name)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($timer.Elapsed.TotalSeconds -lt 90)
    throw "Timed out: $Name"
}
function Check([string]$Name, [bool]$Condition) {
    $checks.Add(@{name=$Name; passed=$Condition})
    $result.phase='check: ' + $Name
    Save $result (Join-Path $Evidence 'result.json')
    Write-Host ('ROOM_CHECK ' + $Name + ' passed=' + $Condition)
    if (!$Condition) { throw "Failed: $Name" }
}
function Log {
    if (!(Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Invoke-NativeInput($Value) {
    if ($app.HasExited -or [ChatDeliveryDesktop]::Window([uint32]$app.Id) -ne $main -or [ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App does not own keyboard' }
    $Value.pid=$app.Id
    $Value.hwnd=$main.ToInt64()
    $Value.focus=[ChatDeliveryDesktop]::Focus($main)[1]
    $result.phase='native input: ' + $Value.kind
    Save $result (Join-Path $Evidence 'result.json')
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind=$Value['kind']; keys=$Value['keys']; text=$Value['text']; focus=$Value['focus']})
    Save @($actions) (Join-Path $Evidence 'actions.json')
    $requestPath=Join-Path $profile 'input.json'
    Save $Value $requestPath
    $inputJob=[VerifyJob]::new()
    try {
        $sender=$inputJob.Start((Get-Command powershell.exe).Source, $profile, (Join-Path $profile 'input.stdout'), (Join-Path $profile 'input.stderr'), ('-NoProfile -NonInteractive -File "' + "$PSScriptRoot/input.ps1" + '" -Request "' + $requestPath + '"'), $true)
        if (!$sender.WaitForExit(20000)) { throw 'Native keyboard input stalled for twenty seconds' }
        if ($sender.ExitCode -ne 0) { throw 'Native keyboard input failed ownership or delivery' }
    } finally {
        $remaining=$inputJob.Stop()
        $inputJob.Dispose()
        if ($remaining.ActiveProcesses -ne 0) { throw 'Native keyboard sender cleanup failed' }
    }
}
function Press([int[]]$Keys) {
    if ($app.HasExited -or [ChatDeliveryDesktop]::Window([uint32]$app.Id) -ne $main -or [ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App does not own keyboard' }
    $opensPalette = $Keys.Count -eq 2 -and $Keys[0] -eq 0x11 -and $Keys[1] -eq 0x4b
    $offset = if ($opensPalette) { (Log).Length } else { 0 }
    Invoke-NativeInput @{kind='keys'; keys=$Keys; text=$null}
    if ($opensPalette) { [void](Wait-For 'palette opened' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=[1-9]\d*' }) }
}
function Query([string]$Text, [int]$Target) {
    $offset = (Log).Length
    Invoke-NativeInput @{kind='text'; text=$Text; keys=$null}
    [void](Wait-For 'palette selection' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match ("\[palette\] ready chars="+$Text.Length+" count=[1-9]\d* target="+$Target+"(?:\r?\n|$)") })
}
function Focus {
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$app.Id, $main) })
}
function Room-Window {
    if ($app.HasExited) { throw ('App exited: '+$app.ExitCode) }
    $room = [VerifyNative]::FindWindowEx($main, [IntPtr]::Zero, 'MultiPromptRoomView', 'Room')
    if ($room -ne [IntPtr]::Zero -and [VerifyNative]::IsWindowVisible($room)) { return $room }
}
function Witness {
    $path = Join-Path $env:MP_VERIFY_STATE 'witness.json'
    if (Test-Path $path) { return Get-Content $path -Raw | ConvertFrom-Json }
    return $null
}
function Shot([string]$Name) {
    $result.phase='screenshot: ' + $Name
    Save $result (Join-Path $Evidence 'result.json')
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind='screenshot'; name=$Name})
    Save @($actions) (Join-Path $Evidence 'actions.json')
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Start-App {
    Remove-Item (Join-Path $env:MP_VERIFY_STATE 'snapshot-live.json') -ErrorAction SilentlyContinue
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, (Join-Path $profile 'stdout.log'), (Join-Path $profile 'stderr.log'), '--single-window --no-window-restore')
    $script:main = Wait-For 'owned main window' {
        if ($app.HasExited) { throw ('App exited: '+$app.ExitCode) }
        $window = [ChatDeliveryDesktop]::Window([uint32]$app.Id)
        if ($window -ne [IntPtr]::Zero) { $window }
    }
    [void](Wait-For 'startup completed' { (Log) -match 'launch step=browser' })
    Focus
}
function Stop-App {
    $stopped = $job.Stop()
    Check 'owned-processes-cleaned' ($stopped.ActiveProcesses -eq 0)
    $job.Dispose(); $script:job=$null
}
try {
    Check 'binary-sha256' ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ExpectedHash.ToLowerInvariant())
    Check 'embedded-version' ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;"))
    & node --test "$repo/tools/rooms-preview-boundary.test.js"
    Check 'scoped-boundary-contracts' ($LASTEXITCODE -eq 0)
    Push-Location "$repo/service"
    try {
        & npm.cmd ci --no-audit --no-fund --prefer-offline
        if ($LASTEXITCODE -ne 0) { throw 'Account fixture dependency install failed' }
        & npx.cmd --no-install wrangler deploy --dry-run --outdir .build
        if ($LASTEXITCODE -ne 0) { throw 'Account fixture build failed' }
    } finally { Pop-Location }
    $passwordText = [guid]::NewGuid().ToString('N')
    $password = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
    $cert = New-SelfSignedCertificate -DnsName $hostName -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(1)
    $pfx = Join-Path $profile 'account.pfx'
    $cer = Join-Path $profile 'account.cer'
    [void](Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $password)
    [void](Export-Certificate -Cert $cert -FilePath $cer)
    $rootCertAdded = $true
    [void](Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root)
    $hostsChanged = $true
    [IO.File]::AppendAllText($hostsFile, "`r`n127.0.0.1 $hostName`r`n")
    $accountState = Join-Path $profile 'account-state.json'
    $accountJob = [VerifyJob]::new()
    $accountServer = $accountJob.Start((Get-Command node).Source, $repo, (Join-Path $profile 'account.stdout'), (Join-Path $profile 'account.stderr'), ('"' + "$repo/service/journey/server.mjs" + '" --bind=127.0.0.1 --port=443 --pfx="' + $pfx + '" --pfxpass=' + $passwordText + ' --state="' + $accountState + '"'))
    $passwordText = $null
    [void](Wait-For 'isolated account Worker' {
        if ($accountServer.HasExited) { throw 'Account fixture exited' }
        Test-Path $accountState
    })
    $account = Get-Content $accountState -Raw | ConvertFrom-Json
    foreach ($key in @('refresh_token', 'admin_key', 'workspace_key', 'other_key')) { Write-Output ('::add-mask::' + $account.$key) }
    $layout = @{schema=1; revision=1; hosts=@(@{slot=0; name='Synthetic host'; hostname='fixture.invalid'; port=22; user='proof'}); workspaces=@(@{name='Work'}); tabs=@(
        @{kind='tmux'; name='Alpha'; manual=$true; tmux_host=0; tmux_session='room-alpha'; workspace='Work'},
        @{kind='tmux'; name='Beta'; manual=$true; tmux_host=0; tmux_session='room-beta'; workspace='Work'}
    )}
    $published = Invoke-RestMethod -Method Put -TimeoutSec 20 -Uri "https://$hostName/v1/layout" -ContentType 'application/json' -Headers @{Authorization=('Bearer ' + $account.admin_key); 'X-Layout-Features'='hosts'} -Body (@{base_revision=1; layout=$layout} | ConvertTo-Json -Depth 8 -Compress)
    Check 'isolated-account-layout' ($published.layout.tabs.Count -eq 2 -and $published.layout.hosts.Count -eq 1)
    $secret = [Text.Encoding]::UTF8.GetBytes((@{refresh_token=$account.refresh_token} | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), [Security.Cryptography.ProtectedData]::Protect($secret, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    [Array]::Clear($secret, 0, $secret.Length)
    $account = $null
    Save @{name='rooms'; mode='idle'; fake=$true; suggestion=''; sessions=@('room-alpha','room-beta')} (Join-Path $env:MP_VERIFY_STATE 'state.json')
    Save @{active_tab=0; single_window=$true; chat_active=$false; workspace_count=1; workspaces=@(@{name='Work'; wid='work'}); tabs=@(
        @{kind='tmux'; name='Alpha'; manual=$true; tmux_host=0; tmux_session='room-alpha'; sync_owned=$true; csid='a1313000-0000-4000-8000-000000000001'; workspace=0; cv=$false; pid=0},
        @{kind='tmux'; name='Beta'; manual=$true; tmux_host=0; tmux_session='room-beta'; sync_owned=$true; csid='b1313000-0000-4000-8000-000000000002'; workspace=0; cv=$false; pid=0}
    )} (Join-Path $settings 'session.json')
    [IO.File]::WriteAllText((Join-Path $settings 'ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
    Start-App
    [void](Wait-For 'account-owned session identities' {
        try {
            $state = Get-Content (Join-Path $settings 'session.json') -Raw | ConvertFrom-Json
            @($state.tabs | Where-Object { $_.PSObject.Properties['sync_owned'] -and $_.sync_owned -and $_.PSObject.Properties['csid'] }).Count -eq 2
        } catch { $false }
    })
    Shot 'before'
    Focus; Press @(0x11,0x4b); Query 'new room' 5105; Press @(0x0d)
    [void](Wait-For 'native room window' { Room-Window })
    [void](Wait-For 'both candidates checked' { @(Get-ChildItem $env:MP_VERIFY_STATE -Filter 'status-*.json').Count -ge 2 })
    $nameEdit = Wait-For 'room name owns focus' {
        $h = [ChatDeliveryDesktop]::Composer((Room-Window))
        if ($h -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::Focus($main)[1] -eq $h.ToInt64()) { $h }
    }
    Invoke-NativeInput @{kind='text'; text='Product sync'; keys=$null}
    Check 'native-room-name' ([ChatDeliveryDesktop]::Text($nameEdit) -ceq 'Product sync')
    Press @(0x09)
    Press @(0x0d); Press @(0x28); Press @(0x0d)
    Shot 'create-members'
    Press @(0x11,0x0d)
    [void](Wait-For 'room saved through remote store' { $w=Witness; $w -and @($w.rooms).Count -eq 1 -and @($w.rooms[0].members).Count -eq 2 })
    [void](Wait-For 'new room returned in the app catalog' {
        try {
            $observed=Get-Content (Join-Path $env:MP_VERIFY_STATE 'catalog-observed.json') -Raw | ConvertFrom-Json
            $w=Witness
            $w -and @($observed.room_ids | Where-Object { $_ -ceq $w.rooms[0].id }).Count -eq 1
        } catch { $false }
    })
    Press @(0x11,0x4b); Query 'product sync' 20000; Press @(0x0d)
    $room = Wait-For 'room composer' { $h=Room-Window; if ($h -and [ChatDeliveryDesktop]::Composer($h) -ne [IntPtr]::Zero) { $h } }
    $composer = [ChatDeliveryDesktop]::Composer($room)
    [void](Wait-For 'composer owns focus' { [ChatDeliveryDesktop]::Focus($main)[1] -eq $composer.ToInt64() })
    [void](Wait-For 'created room selected by the app' {
        try {
            $files=@(Get-ChildItem $settings -Filter 'room-ui-*.json')
            if ($files.Count -ne 1) { return $false }
            $record=(Get-Content $files[0].FullName -Raw | ConvertFrom-Json).record
            $w=Witness
            $record.selected_front -and $record.selected -and $w -and $record.selected.room_id -ceq $w.rooms[0].id
        } catch { $false }
    })
    [void]$app.WaitForInputIdle(5000)
    Shot 'created'
    Invoke-NativeInput @{kind='text'; text='Keep this draft on old peers'; keys=$null}
    Press @(0x0d)
    Check 'legacy-peer-keeps-draft' ([ChatDeliveryDesktop]::Text($composer) -ceq 'Keep this draft on old peers')
    $witness = Witness
    Check 'legacy-peer-never-posts' (@($witness.rooms[0].events | Where-Object { $_.type -eq 'human' }).Count -eq 0)
    Shot 'legacy-refusal'
    [void](Wait-For 'selected room and draft persisted' {
        try {
            $files = @(Get-ChildItem $settings -Filter 'room-ui-*.json')
            if ($files.Count -ne 1) { return $false }
            $record = (Get-Content $files[0].FullName -Raw | ConvertFrom-Json).record
            $record.selected_front -and $null -ne $record.selected -and $record.selected.room_id -ceq $witness.rooms[0].id -and
                @($record.drafts | Where-Object { $_.location.room_id -ceq $record.selected.room_id -and $_.location.store_uuid -ceq $record.selected.store_uuid -and $_.text -ceq 'Keep this draft on old peers' }).Count -eq 1
        } catch { $false }
    })
    Check 'selection-and-draft-persisted-before-stop' $true
    Stop-App
    Start-App
    $room = Wait-For 'selected room restored' { Room-Window }
    $composer = Wait-For 'restored room composer' { $h=[ChatDeliveryDesktop]::Composer($room); if ($h -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::Text($h) -ceq 'Keep this draft on old peers') { $h } }
    Check 'draft-restored' ([ChatDeliveryDesktop]::Text($composer) -ceq 'Keep this draft on old peers')
    $witness = Witness
    Check 'room-and-members-restored' (@($witness.rooms).Count -eq 1 -and @($witness.rooms[0].members).Count -eq 2)
    Save $witness (Join-Path $Evidence 'witness.json')
    Shot 'after-restart'
    Stop-App
    [IO.File]::WriteAllText((Join-Path $env:MP_VERIFY_STATE 'live-replies'), 'Synthetic providers only')
    Start-App
    $room = Wait-For 'live room restored' { Room-Window }
    $composer = Wait-For 'live composer focus' {
        $h = [ChatDeliveryDesktop]::Composer($room)
        if ($h -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::Focus($main)[1] -eq $h.ToInt64()) { $h }
    }
    [void](Wait-For 'scoped room snapshot loaded' { Test-Path (Join-Path $env:MP_VERIFY_STATE 'snapshot-live.json') })
    [void]$app.WaitForInputIdle(5000)
    Press @(0x24); Press @(0x10,0x23); Press @(0x08)
    Check 'legacy-draft-cleared-by-keyboard' ([ChatDeliveryDesktop]::Text($composer) -ceq '')
    Invoke-NativeInput @{kind='text'; text='Both synthetic agents, reply once.'; keys=$null}
    Check 'native-broadcast-draft' ([ChatDeliveryDesktop]::Text($composer) -ceq 'Both synthetic agents, reply once.')
    Shot 'before-send'
    Press @(0x0d)
    [void](Wait-For 'one broadcast and two scoped synthetic replies' {
        $w=Witness
        if (!$w -or @($w.rooms).Count -ne 1) { return $false }
        $events=@($w.rooms[0].events)
        @($events | Where-Object { $_.type -eq 'human' }).Count -eq 1 -and @($events | Where-Object { $_.type -eq 'agent_reply' }).Count -eq 2 -and [ChatDeliveryDesktop]::Text($composer) -ceq ''
    })
    function Check-Replies {
        $w=Witness
        $human=@($w.rooms[0].events | Where-Object { $_.type -eq 'human' })
        $replies=@($w.rooms[0].events | Where-Object { $_.type -eq 'agent_reply' })
        Check 'exactly-one-human-post' ($human.Count -eq 1 -and $human[0].text -ceq 'Both synthetic agents, reply once.')
        Check 'exactly-two-member-replies' ($replies.Count -eq 2 -and @($replies.member_id | Select-Object -Unique).Count -eq 2)
        Check 'reply-parent-binding' (@($replies | Where-Object { $_.parent_event_id -cne $human[0].id }).Count -eq 0)
        Check 'synthetic-reply-content' ((@($replies.text | Sort-Object) -join '|') -ceq 'Synthetic Alpha reply: Ready.|Synthetic Beta reply: Ready.')
        Check 'canonical-two-turns-only' (@($w.canonical_events | Where-Object { $_.event.kind -eq 'turn.started' }).Count -eq 2 -and @($w.canonical_events | Where-Object { $_.event.kind -eq 'turn.ended' }).Count -eq 2)
        Save $w (Join-Path $Evidence 'witness.json')
    }
    Check-Replies
    [void]$app.WaitForInputIdle(5000)
    Shot 'two-synthetic-replies'
    Stop-App
    Start-App
    [void](Wait-For 'reopened selected room' { Room-Window })
    [void](Wait-For 'post-restart store read' { Test-Path (Join-Path $env:MP_VERIFY_STATE 'snapshot-live.json') })
    Check-Replies
    [void]$app.WaitForInputIdle(5000)
    Shot 'two-replies-after-restart'
    $result.status='passed'
} catch {
    $result.error=$_.Exception.Message
    Save $result (Join-Path $Evidence 'result.json')
    try {
        $accountError = Join-Path $profile 'account.stderr'
        if (Test-Path $accountError) {
            $stream=[IO.File]::Open($accountError, 'Open', 'Read', 'ReadWrite')
            $buffer=New-Object byte[] 8192
            try { $length=$stream.Read($buffer, 0, $buffer.Length) } finally { $stream.Dispose() }
            $diagnostic = [Text.Encoding]::UTF8.GetString($buffer, 0, $length).Replace($profile, '<profile>').Replace($repo, '<repo>')
            $diagnostic = [regex]::Replace($diagnostic, '[A-Za-z0-9_-]{43,}', '<redacted>')
            Save @{exit_code=$(if ($accountServer -and $accountServer.HasExited) { $accountServer.ExitCode } else { $null }); error=$diagnostic.Substring(0, [Math]::Min(8000, $diagnostic.Length))} (Join-Path $Evidence 'account-error.json')
        }
    } catch {}
    try { $w=Witness; if ($w) { Save $w (Join-Path $Evidence 'witness.json') } } catch {}
    try {
        $reports = @(Get-ChildItem (Join-Path $settings 'crashes') -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(crash|freeze)-.*\.txt$' })
        $frames = @($reports | ForEach-Object {
            Get-Content $_.FullName | Where-Object { $_ -match '^(exception_code: 0x[0-9A-F]+ \([A-Z_]+\)|exception_address: 0x[0-9A-F]+|module_base: 0x[0-9A-F]+|module_offset: 0x[0-9A-F]+|exe_base: 0x[0-9A-F]+|instruction: ([a-zA-Z0-9_.]+\+0x[0-9A-F]+|unavailable)|thread_context: (captured|unavailable)|unresponsive_ms: [0-9]+|  0x[0-9A-F]+)$' }
        })
        Save $frames (Join-Path $Evidence 'crash-addresses.json')
    } catch {}
} finally {
    try {
        if ($null -ne $job) { $stopped=$job.Stop(); $result.cleanup=$stopped.ActiveProcesses; $job.Dispose() } else { $result.cleanup=0 }
        if ($null -ne $accountJob) { $stopped=$accountJob.Stop(); $result.account_cleanup=$stopped.ActiveProcesses; $accountJob.Dispose() } else { $result.account_cleanup=0 }
    } finally {
        try {
            if ($hostsChanged) { [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal) }
            if ($rootCertAdded -and $cert) { Remove-Item ("Cert:\LocalMachine\Root\" + $cert.Thumbprint) -Force }
            if ($cert) { Remove-Item ("Cert:\LocalMachine\My\" + $cert.Thumbprint) -Force }
            $result.hosts_restored=([Convert]::ToBase64String([IO.File]::ReadAllBytes($hostsFile)) -ceq [Convert]::ToBase64String($hostsOriginal))
            $result.certificate_removed=(!$cert -or (!(Test-Path ("Cert:\LocalMachine\Root\" + $cert.Thumbprint)) -and !(Test-Path ("Cert:\LocalMachine\My\" + $cert.Thumbprint))))
            if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
            $result.scratch_removed=!(Test-Path $profile)
        } finally {
            Save @($actions) (Join-Path $Evidence 'actions.json')
            Save $result (Join-Path $Evidence 'result.json')
        }
    }
}
if ($result.status -ne 'passed' -or $result.cleanup -ne 0 -or $result.account_cleanup -ne 0 -or !$result.scratch_removed -or !$result.hosts_restored -or !$result.certificate_removed) { throw 'Room preview verification failed; see result.json' }
