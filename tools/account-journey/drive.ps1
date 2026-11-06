param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
$Exe = (Resolve-Path $Exe).Path
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.Security } catch {}
Add-Type -Path "$repo/tools/verify-reconnect/desktop.cs"
[ReconnectDesktop]::StartSpy()
[void][ReconnectDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$work = Join-Path $env:RUNNER_TEMP ('account-journey-' + [guid]::NewGuid().ToString('N'))
$settings = "$work/roaming/ZigShell"
$log = "$settings/debug.log"
$hostName = 'account.multiprompt.dev'
$app = $null
$appB = $null
$main = [IntPtr]::Zero
$mainB = [IntPtr]::Zero
$server = $null
$cert = $null
$rootCertAdded = $false
$failure = $null
$stage = 'setup'
. "$PSScriptRoot/diagnostics.ps1"
. "$PSScriptRoot/foreground.ps1"
$results = [ordered]@{ native_roundtrip = @{ verdict = 'fail' } }
$hostsFile = "$env:SystemRoot/System32/drivers/etc/hosts"
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$originalEnv = @{}
foreach ($envName in @('APPDATA', 'LOCALAPPDATA', 'ZIGSHELL_DEBUG', 'MULTIPROMPT_NO_LOGIN', 'NODE_EXTRA_CA_CERTS', 'MULTIPROMPT_KEY')) {
    $originalEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process')
}
function Read-Log([string]$LogPath = $log) {
    if (!(Test-Path $LogPath)) { return '' }
    for ($retry = 0; $retry -lt 100; $retry++) {
        $stream = $null
        $reader = $null
        try {
            $stream = [IO.File]::Open($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $reader = [IO.StreamReader]::new($stream)
            return $reader.ReadToEnd()
        } catch [IO.IOException] {
            if ($retry -eq 99) { throw }
            Start-Sleep -Milliseconds 10
        } finally {
            if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
        }
    }
}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 90) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 100 } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Shot([string]$Name, [IntPtr]$Window = $main, [int]$ProcessId = $app.Id) {
    Start-Sleep -Milliseconds 2000
    Set-JourneyForeground $Window $ProcessId
    Assert-Window $Window $ProcessId
    $bitmap = [Drawing.Bitmap]::new([ReconnectDesktop]::GetSystemMetrics(0), [ReconnectDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Output/$Name.png", [Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
    @{ capture = $Name; pid = $ProcessId; hwnd = $Window.ToInt64() } | ConvertTo-Json | Set-Content "$Output/$Name.json"
}
function Show-Workspace([string]$Name, [IntPtr]$Window = $main, [int]$ProcessId = $app.Id, [string]$SessionPath = "$settings/session-journey-a.json") {
    $state = Get-Content $SessionPath -Raw | ConvertFrom-Json
    $matches = @(for ($i = 0; $i -lt @($state.workspaces).Count; $i++) { if ($state.workspaces[$i].name -ceq $Name) { $i } })
    if ($matches.Count -ne 1 -or $matches[0] -gt 7) { throw "Could not switch to workspace $Name in saved session" }
    $slot = [int]$matches[0]
    Set-JourneyForeground $Window $ProcessId
    Assert-Window $Window $ProcessId
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        [ReconnectDesktop]::Key(0x12, $false)
        try {
            if ([ReconnectDesktop]::GetForegroundWindow() -eq $Window -or $attempt -eq 1) {
                Assert-Window $Window $ProcessId
                [ReconnectDesktop]::Key([ushort](0x32 + $slot), $false)
                [ReconnectDesktop]::Key([ushort](0x32 + $slot), $true)
                break
            }
        } finally { [ReconnectDesktop]::Key(0x12, $true) }
        Set-JourneyForeground $Window $ProcessId
        Assert-Window $Window $ProcessId
    }
    $selection = @{ readable = $false; active_slot = -1; starred = $false; name_match = $false }
    try {
        [void](Wait-For 'selected workspace session' {
            $selection.readable = $false
            $selection.active_slot = -1
            $selection.starred = $false
            $selection.name_match = $false
            try {
                $current = Get-Content $SessionPath -Raw | ConvertFrom-Json
                $selection.readable = $true
                if ($null -ne $current.active_workspace) { $selection.active_slot = [int]$current.active_workspace }
                $selection.starred = [bool]$current.starred_view
                $selection.name_match = $slot -lt @($current.workspaces).Count -and $current.workspaces[$slot].name -ceq $Name
                $selection.active_slot -eq $slot -and !$selection.starred -and $selection.name_match
            } catch { $false }
        } 10)
    } catch {
        if ($_.Exception.Message -cne 'Timed out: selected workspace session') { throw }
        $original = $_
        $focus = @(-1L, -1L)
        try { $focus = [ReconnectDesktop]::Focus($Window) } catch {}
        $message = "Timed out: selected workspace session; expected_window=$($Window.ToInt64()) expected_pid=$ProcessId expected_slot=$slot foreground=$($focus[0]) focus=$($focus[1]) session_readable=$($selection.readable) active_slot=$($selection.active_slot) starred=$($selection.starred) expected_name_match=$($selection.name_match)"
        $exception = [System.Exception]::new($message, $original.Exception)
        $exception.Data['original_script_stack'] = $original.ScriptStackTrace
        throw $exception
    }
}
function Assert-Focus([IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    Assert-Window $Window $ProcessId
    $focusState = [ReconnectDesktop]::Focus($Window)
    if ($focusState[0] -ne $Window.ToInt64() -or $focusState[1] -ne $Expected.ToInt64() -or [ReconnectDesktop]::Owner($Expected) -ne $ProcessId -or [ReconnectDesktop]::GetAncestor($Expected, 2) -ne $Window) { throw 'Unexpected input focus' }
}
function Type-Ascii([string]$Value, [IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    foreach ($character in $Value.ToCharArray()) {
        Assert-Focus $Window $ProcessId $Expected
        $vk = if ($character -eq ' ') { 0x20 } else { [int][char]::ToUpperInvariant($character) }
        [ReconnectDesktop]::Type([ushort]$vk)
    }
}
function Open-Rename([IntPtr]$Window, [int]$ProcessId, [string]$ExpectedName) {
    Set-JourneyForeground $Window $ProcessId
    Assert-Window $Window $ProcessId
    $paletteLog = if ($ProcessId -eq $app.Id) { $log } elseif ($appB -and $ProcessId -eq $appB.Id) { $logB } else { throw 'Unknown app process' }
    $offset = (Read-Log $paletteLog).Length
    [ReconnectDesktop]::Key(0x11, $false)
    [ReconnectDesktop]::Type(0x4B)
    [ReconnectDesktop]::Key(0x11, $true)
    [void](Wait-For 'palette ready and focused' {
        $trace = Read-Log $paletteLog
        $f = [ReconnectDesktop]::Focus($Window)
        $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' -and $f[0] -eq $Window.ToInt64() -and $f[1] -eq $Window.ToInt64()
    } 10)
    Type-Ascii 'rename workspace' $Window $ProcessId $Window
    [void](Wait-For 'rename workspace palette selection' {
        $trace = Read-Log $paletteLog
        $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=16 count=\d+ target=7000(?:\r?\n|$)'
    } 10)
    Assert-Focus $Window $ProcessId $Window
    $beforeEnter = Read-Log $paletteLog
    $enterOffset = $beforeEnter.Length
    [ReconnectDesktop]::Type(0x0D)
    $state = @{ foreground = 0L; focus = 0L; owner = 0; root = 0L; edit_class = $false; expected_name_match = $false }
    try {
        $edit = Wait-For 'workspace rename edit' {
            $f = [ReconnectDesktop]::Focus($Window)
            $candidate = [IntPtr]$f[1]
            $state.foreground = [long]$f[0]
            $state.focus = [long]$f[1]
            $state.owner = if ($candidate -ne [IntPtr]::Zero) { [ReconnectDesktop]::Owner($candidate) } else { 0 }
            $state.root = if ($candidate -ne [IntPtr]::Zero) { [ReconnectDesktop]::GetAncestor($candidate, 2).ToInt64() } else { 0L }
            $state.edit_class = $candidate -ne [IntPtr]::Zero -and [ReconnectDesktop]::Class($candidate) -eq 'Edit'
            $state.expected_name_match = $candidate -ne $Window -and $state.owner -eq $ProcessId -and $state.root -eq $Window.ToInt64() -and $state.edit_class -and [ReconnectDesktop]::Text($candidate) -ceq $ExpectedName
            if ($candidate -ne [IntPtr]::Zero -and $candidate -ne $Window -and $state.owner -eq $ProcessId -and $state.root -eq $Window.ToInt64() -and $state.edit_class -and $state.expected_name_match) { $candidate }
        } 10
    } catch {
        if ($_.Exception.Message -cne 'Timed out: workspace rename edit') { throw }
        $original = $_
        $confirmed = $false
        try {
            $trace = Read-Log $paletteLog
            if ($trace.Length -ge $enterOffset) {
                $fresh = $trace.Substring($enterOffset)
                if ($enterOffset -gt 0 -and $beforeEnter[$enterOffset - 1] -ne "`n") { $fresh = 'partial' + $fresh }
                $confirmed = @((Get-SafePaletteRecords $fresh) | Where-Object { $_ -ceq '[palette] confirm target=7000' }).Count -gt 0
            }
        } catch {}
        $ownedEdit = @{ exists = $false; focused = $false; expected_name_match = $false; hwnd = 0L; probe_failed = $false }
        try {
            $candidate = [ReconnectDesktop]::Composer($Window)
            if ($candidate -ne [IntPtr]::Zero -and $candidate -ne $Window -and [ReconnectDesktop]::Owner($candidate) -eq $ProcessId -and [ReconnectDesktop]::GetAncestor($candidate, 2) -eq $Window -and [ReconnectDesktop]::Class($candidate) -eq 'Edit') {
                $nameMatch = [ReconnectDesktop]::Text($candidate) -ceq $ExpectedName
                $focus = [ReconnectDesktop]::Focus($Window)
                $ownedEdit.exists = $true
                $ownedEdit.focused = $focus[1] -eq $candidate.ToInt64()
                $ownedEdit.expected_name_match = $nameMatch
                $ownedEdit.hwnd = $candidate.ToInt64()
            }
        } catch { $ownedEdit.probe_failed = $true }
        $message = "Timed out: workspace rename edit; expected_window=$($Window.ToInt64()) expected_pid=$ProcessId foreground=$($state.foreground) focus=$($state.focus) owner=$($state.owner) root=$($state.root) edit_class=$($state.edit_class) expected_name_match=$($state.expected_name_match) confirm_target_7000=$confirmed owned_edit_exists=$($ownedEdit.exists) owned_edit_focused=$($ownedEdit.focused) owned_edit_expected_name_match=$($ownedEdit.expected_name_match) owned_edit_hwnd=$($ownedEdit.hwnd) owned_edit_probe_failed=$($ownedEdit.probe_failed)"
        $exception = [System.Exception]::new($message, $original.Exception)
        $exception.Data['original_script_stack'] = $original.ScriptStackTrace
        throw $exception
    }
    Assert-Focus $Window $ProcessId $edit
    return $edit
}
function Session-Has([string]$SessionPath, [string]$Name, [string]$Absent) {
    try {
        $snapshot = Get-Content $SessionPath -Raw | ConvertFrom-Json
        $names = @($snapshot.workspaces | ForEach-Object { $_.name })
        return (@($names | Where-Object { $_ -ceq $Name }).Count -eq 1 -and @($names | Where-Object { $_ -ceq $Absent }).Count -eq 0)
    } catch { return $false }
}
function Tab-Count([string]$Text) {
    $found = [regex]::Matches($Text, 'account-sync: applied workspaces=\S* tabs=(\d+)')
    if ($found.Count) { [int]$found[$found.Count - 1].Groups[1].Value } else { -1 }
}
function Invoke-Layout([string]$Key, [string[]]$Arguments) {
    $env:MULTIPROMPT_KEY = $Key
    $text = (& node "$repo/tools/mp-layout.mjs" @Arguments 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    Remove-Item Env:MULTIPROMPT_KEY
    @{code=$code; text=$text}
}
try {
    New-Item -ItemType Directory -Force $settings, "$work/local" | Out-Null
    $password = ConvertTo-SecureString -String ([guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $cert = New-SelfSignedCertificate -DnsName $hostName -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(2)
    $pfx = "$work/service.pfx"
    $cer = "$work/service.cer"
    [void](Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $password)
    [void](Export-Certificate -Cert $cert -FilePath $cer)
    $rootCertAdded = $true
    [void](Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root)
    $pem = "$work/service.pem"
    $b64 = [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks')
    [IO.File]::WriteAllText($pem, "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----`n")
    [IO.File]::AppendAllText($hostsFile, "`r`n127.0.0.1 $hostName`r`n")
    $env:NODE_EXTRA_CA_CERTS = $pem
    $state = "$work/service-state.json"
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    $server = Start-Process node -ArgumentList "`"$repo/service/journey/server.mjs`"", '--port=443', '--second-device=true', "--pfx=`"$pfx`"", "--pfxpass=$plain", "--state=`"$state`"" -PassThru -RedirectStandardOutput "$work/service.log" -RedirectStandardError "$work/service.err.log"
    $plain = $null
    [void](Wait-For 'test account service' { Test-Path $state } 60)
    $secrets = Get-Content $state -Raw | ConvertFrom-Json
    $probe = & curl.exe -s "https://$hostName/v1/layout"
    if ($probe -notmatch 'device_required') { throw 'Service not reachable under the real hostname' }
    $results.service_probe = 'device_required over https with the real hostname'

    $credential = [Text.Encoding]::UTF8.GetBytes((@{refresh_token=$secrets.refresh_token} | ConvertTo-Json -Compress))
    $protected = [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes("$settings/account-device.dat", $protected)
    $env:APPDATA = "$work/roaming"
    $env:LOCALAPPDATA = "$work/local"
    $env:ZIGSHELL_DEBUG = '1'
    Remove-Item Env:MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $stage = 'first app launch'
    $app = Start-Process $Exe -ArgumentList '--single-window', '--name', 'journey-a', '--no-window-restore' -PassThru
    $results.app_a_pid = $app.Id
    $main = Wait-For 'app window' { $h = [ReconnectDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Set-JourneyForeground $main $app.Id
    [void](Wait-For 'first layout from the account service' { (Read-Log) -match 'account-sync: applied workspaces=Work\|Notes' } 60)
    Start-Sleep -Seconds 3
    $baseTabs = Tab-Count (Read-Log)
    Show-Workspace 'Work'
    Shot 'desktop-before'
    $results.before = "desktop shows Work with runner sessions, $baseTabs tabs in total"

    $stage = 'legacy CLI journey'
    $listed = Invoke-Layout $secrets.admin_key @('list')
    if ($listed.code -ne 0 -or $listed.text -notmatch 'runner-3') { throw "admin list failed: $($listed.text)" }

    $offset = (Read-Log).Length
    $start = [DateTime]::UtcNow
    $moved = Invoke-Layout $secrets.admin_key @('move', '--to', 'Runners', '--create', '--match', 'runner-*')
    if ($moved.code -ne 0 -or $moved.text -notmatch 'moved 3 sessions to Runners') { throw "admin move failed: $($moved.text)" }
    [void](Wait-For 'desktop shows the new section' { (Read-Log).Substring($offset) -match 'account-sync: applied workspaces=\S*Runners' } 30)
    $seen = [DateTime]::UtcNow
    $elapsed = ($seen - $start).TotalSeconds
    Show-Workspace 'Runners'
    Shot 'desktop-after'
    $results.admin_move = 'moved 3 sessions to Runners'
    $results.desktop_seconds_to_show_new_section = [Math]::Round($elapsed, 2)
    if ($elapsed -gt 10) { throw "Desktop took $elapsed seconds to show the new section" }

    $scoped = Invoke-Layout $secrets.workspace_key @('list')
    if ($scoped.code -ne 0 -or $scoped.text -match 'runner-' -or $scoped.text -notmatch 'notes-a') { throw "workspace key list is wrong: $($scoped.text)" }
    $own = Invoke-Layout $secrets.workspace_key @('open', 'notes-new', '--no-tmux')
    if ($own.code -ne 0) { throw "workspace key could not open in its own workspace: $($own.text)" }
    $refused = Invoke-Layout $secrets.workspace_key @('move', '--to', 'Work', 'notes-a')
    if ($refused.code -eq 0 -or $refused.text -notmatch 'refused|not found') { throw "workspace key was not refused: $($refused.text)" }
    $other = Invoke-Layout $secrets.other_key @('list')
    if ($other.code -eq 0) { throw 'a key for another workspace was accepted' }
    $results.workspace_list = 'pass'
    $results.workspace_refusal = 'pass'
    $results.other_workspace = 'pass'

    Start-Sleep -Seconds 8
    $tabsBeforeOpen = Tab-Count (Read-Log)
    $offset = (Read-Log).Length
    $start = [DateTime]::UtcNow
    $opened = Invoke-Layout $secrets.admin_key @('open', 'fresh-session', '--workspace', 'Runners', '--title', 'Fresh session', '--no-tmux')
    if ($opened.code -ne 0) { throw "open failed: $($opened.text)" }
    [void](Wait-For 'desktop shows the opened session' { (Tab-Count (Read-Log).Substring($offset)) -eq ($tabsBeforeOpen + 1) } 30)
    $openSeconds = ([DateTime]::UtcNow - $start).TotalSeconds
    Shot 'desktop-opened'
    $results.open = 'pass'
    $results.desktop_seconds_to_show_opened_session = [Math]::Round($openSeconds, 2)
    if ($openSeconds -gt 10) { throw "Desktop took $openSeconds seconds to show the opened session" }

    $stage = 'named live chat account import'
    $liveSession = 'live-0123456789ab8def81230123456789ab'
    $liveSid = '01234567-89ab-8def-8123-0123456789ab'
    $start = [DateTime]::UtcNow
    $liveOpened = Invoke-Layout $secrets.admin_key @('open', $liveSession, '--workspace', 'Runners', '--title', 'Named live chat', '--no-tmux')
    if ($liveOpened.code -ne 0) { throw 'Could not publish the live account tab' }
    $groupHeaders = @{ Authorization = "Bearer $($secrets.admin_key)"; 'X-Layout-Features' = 'groups' }
    $groupSnapshot = Invoke-RestMethod -Uri "https://$hostName/v1/layout" -Headers $groupHeaders
    $groupTab = @($groupSnapshot.layout.tabs | Where-Object { $_.tmux_session -ceq $liveSession })
    if ($groupTab.Count -ne 1) { throw 'Expected one live tab before grouping' }
    $groupTab[0] | Add-Member -NotePropertyName group -NotePropertyValue 'Lead runners' -Force
    $groupBody = @{ base_revision = $groupSnapshot.revision; layout = $groupSnapshot.layout } | ConvertTo-Json -Depth 20 -Compress
    [void](Invoke-RestMethod -Method Put -Uri "https://$hostName/v1/layout" -Headers $groupHeaders -ContentType 'application/json' -Body $groupBody)
    [void](Wait-For 'native import saves live identity, Chat View, and group' {
        try {
            $snapshot = Get-Content "$settings/session-journey-a.json" -Raw | ConvertFrom-Json
            $tabs = @($snapshot.tabs | Where-Object { $_.tmux_session -ceq $liveSession })
            $groups = @($snapshot.groups | Where-Object { $_.name -ceq 'Lead runners' -and $_.id -eq $tabs[0].group_id })
            $tabs.Count -eq 1 -and $tabs[0].csid -ceq $liveSid -and $tabs[0].cv -eq $true -and $tabs[0].name -ceq 'Named live chat' -and $groups.Count -eq 1
        } catch { $false }
    } 15)
    $liveSeconds = ([DateTime]::UtcNow - $start).TotalSeconds
    if ($liveSeconds -gt 10) { throw "Native live import took $liveSeconds seconds" }
    $results.named_live_import = @{ verdict = 'pass'; seconds = [Math]::Round($liveSeconds, 2); group = 'Lead runners'; boundary = 'real account import; no remote host or phone' }
    Shot 'desktop-live-grouped'

    $stage = 'second device authentication'
    $tokenBody = @{ grant_type = 'refresh_token'; refresh_token = $secrets.second_refresh_token } | ConvertTo-Json -Compress
    $tokenB = Invoke-RestMethod -Method Post -Uri "https://$hostName/oauth/token" -ContentType 'application/json' -Body $tokenBody
    if ($tokenB.device_id -cne 'journey-device-b' -or !$tokenB.access_token -or !$tokenB.refresh_token -or $tokenB.expires_in -lt 300) { throw 'Invalid second device authentication' }
    $headersB = @{ Authorization = "Bearer $($tokenB.access_token)" }
    $devices = Invoke-RestMethod -Uri "https://$hostName/v1/devices" -Headers $headersB
    if ($devices.device_id -cne 'journey-device-b' -or @($devices.devices | Where-Object { $_.id -ceq 'journey-device' -and !$_.revoked }).Count -ne 1 -or @($devices.devices | Where-Object { $_.id -ceq 'journey-device-b' -and !$_.revoked }).Count -ne 1) { throw 'Device membership mismatch' }
    $settingsB = "$work/roaming-b/ZigShell"
    $sessionA = "$settings/session-journey-a.json"
    $sessionB = "$settingsB/session-journey-b.json"
    $logB = "$settingsB/debug.log"
    New-Item -ItemType Directory -Force $settingsB, "$work/local-b" | Out-Null
    $credentialB = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $tokenB.refresh_token } | ConvertTo-Json -Compress))
    $protectedB = [Security.Cryptography.ProtectedData]::Protect($credentialB, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes("$settingsB/account-device.dat", $protectedB)
    $env:APPDATA = "$work/roaming-b"
    $env:LOCALAPPDATA = "$work/local-b"
    $stage = 'second app launch'
    $appB = Start-Process $Exe -ArgumentList '--single-window', '--name', 'journey-b', '--no-window-restore' -PassThru
    $results.app_b_pid = $appB.Id
    $mainB = Wait-For 'second app window' { $h = [ReconnectDesktop]::Window($appB.Id); if ($h -ne [IntPtr]::Zero) { $h } } 60
    [void](Wait-For 'second app baseline apply' { (Read-Log $logB) -match 'account-sync: applied workspaces=\S*Runners' } 60)
    $newName = 'saved' + [guid]::NewGuid().ToString('N').Substring(0, 16)
    $stage = 'native baseline A session'
    [void](Wait-For 'A baseline session' { Session-Has $sessionA 'Runners' $newName } 30)
    $stage = 'native baseline B session'
    [void](Wait-For 'B baseline session' { Session-Has $sessionB 'Runners' $newName } 30)
    $stage = 'native baseline B workspace'
    Show-Workspace 'Runners' $mainB $appB.Id $sessionB
    $stage = 'native baseline B rename'
    $editB = Open-Rename $mainB $appB.Id 'Runners'
    Shot 'native-b-before' $mainB $appB.Id
    Assert-Focus $mainB $appB.Id $editB
    [ReconnectDesktop]::Type(0x1B)
    $stage = 'native baseline A workspace'
    Show-Workspace 'Runners' $main $app.Id $sessionA
    $stage = 'native baseline A rename'
    $editA = Open-Rename $main $app.Id 'Runners'
    Shot 'native-a-before' $main $app.Id
    Assert-Focus $main $app.Id $editA
    $stage = 'native baseline service'
    $baseline = Invoke-RestMethod -Uri "https://$hostName/v1/layout" -Headers $headersB
    $baselineNames = @($baseline.layout.workspaces | ForEach-Object { $_.name })
    if (@($baselineNames | Where-Object { $_ -ceq 'Runners' }).Count -ne 1 -or @($baselineNames | Where-Object { $_ -ceq $newName }).Count -ne 0) { throw 'Service baseline mismatch' }
    $baselineRevision = [long]$baseline.revision
    $app.Refresh()
    $appB.Refresh()
    if ($app.HasExited -or $appB.HasExited -or !(Session-Has $sessionA 'Runners' $newName) -or !(Session-Has $sessionB 'Runners' $newName)) { throw 'Both native baselines are required' }
    $offsetB = (Read-Log $logB).Length
    $nativeStart = [DateTime]::UtcNow
    $stage = 'native rename'
    Set-JourneyForeground $main $app.Id
    Assert-Focus $main $app.Id $editA
    if ([ReconnectDesktop]::Text($editA) -cne 'Runners') { throw 'Rename edit changed unexpectedly' }
    [ReconnectDesktop]::Key(0x11, $false)
    [ReconnectDesktop]::Type(0x41)
    [ReconnectDesktop]::Key(0x11, $true)
    Type-Ascii $newName $main $app.Id $editA
    Assert-Focus $main $app.Id $editA
    if ([ReconnectDesktop]::Text($editA) -cne $newName) { throw 'Rename input mismatch' }
    [ReconnectDesktop]::Type(0x0D)
    $stage = 'A local save'
    [void](Wait-For 'A local rename' { Session-Has $sessionA $newName 'Runners' } 60)
    $stage = 'service publication'
    $published = Wait-For 'B authenticated published layout' {
        $reply = Invoke-RestMethod -Uri "https://$hostName/v1/layout" -Headers $headersB
        $names = @($reply.layout.workspaces | ForEach-Object { $_.name })
        if ([long]$reply.revision -gt $baselineRevision -and @($names | Where-Object { $_ -ceq $newName }).Count -eq 1 -and @($names | Where-Object { $_ -ceq 'Runners' }).Count -eq 0) { $reply }
    } 90
    $stage = 'B native apply'
    [void](Wait-For 'B native post-baseline apply' {
        $currentLog = Read-Log $logB
        $appB.Refresh()
        !$appB.HasExited -and $currentLog.Length -ge $offsetB -and $currentLog.Substring($offsetB) -match ('account-sync: applied workspaces=\S*' + [regex]::Escape($newName) + '(\|| )') -and (Session-Has $sessionB $newName 'Runners')
    } 90)
    $stage = 'native final displays'
    Show-Workspace $newName $main $app.Id $sessionA
    $editA = Open-Rename $main $app.Id $newName
    Shot 'native-a-after' $main $app.Id
    Assert-Focus $main $app.Id $editA
    [ReconnectDesktop]::Type(0x1B)
    Show-Workspace $newName $mainB $appB.Id $sessionB
    $editB = Open-Rename $mainB $appB.Id $newName
    Shot 'native-b-after' $mainB $appB.Id
    Assert-Focus $mainB $appB.Id $editB
    [ReconnectDesktop]::Type(0x1B)
    $app.Refresh()
    $appB.Refresh()
    if ($app.HasExited -or $appB.HasExited -or !(Session-Has $sessionA $newName 'Runners') -or !(Session-Has $sessionB $newName 'Runners')) { throw 'Both final native sessions are required' }
    $results.native_roundtrip = [ordered]@{ verdict = 'pass'; device_ids = @('journey-device', 'journey-device-b'); instances = @('journey-a', 'journey-b'); pids = @($app.Id, $appB.Id); hwnds = @($main.ToInt64(), $mainB.ToInt64()); workspace = $newName; baseline_revision = $baselineRevision; published_revision = [long]$published.revision; seconds = [Math]::Round(([DateTime]::UtcNow - $nativeStart).TotalSeconds, 2) }
    $results.verdict = 'pass'
} catch {
    $failure = $_
    $results.verdict = 'fail'
    $results.failed_stage = $stage
    $message = $_.Exception.Message
    $results.failure_message = if ($message.StartsWith('Timed out:') -or $message.StartsWith('Could not switch to workspace')) { $message } else { $_.Exception.GetType().FullName }
    $results.error = Get-JourneyError $_
} finally {
    foreach ($entry in @(@{ path = $log; name = 'desktop-a.log' }, @{ path = $logB; name = 'desktop-b.log' })) {
        if ($entry.path -and (Test-Path $entry.path)) {
            try {
                $text = Read-Log $entry.path
                $safe = @(Get-SafePaletteRecords $text)
                @('[other log lines suppressed]') + $safe | Set-Content (Join-Path $Output $entry.name)
            } catch {}
        }
    }
    foreach ($ownedProcess in @($appB, $app, $server)) {
        if ($ownedProcess) {
            try {
                $ownedProcess.Refresh()
                if (!$ownedProcess.HasExited) {
                    & taskkill.exe /PID $ownedProcess.Id /T /F 2>&1 | Out-Null
                    if (!$ownedProcess.WaitForExit(10000)) { throw 'Owned process did not exit' }
                }
            } catch { if (!$failure) { $failure = $_; $results.failed_stage = 'cleanup'; $results.error = Get-JourneyError $_ }; $results.cleanup = 'failed' }
        }
    }
    try { [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal) } catch { if (!$failure) { $failure = $_; $results.failed_stage = 'cleanup'; $results.error = Get-JourneyError $_ }; $results.cleanup = 'failed' }
    foreach ($envName in $originalEnv.Keys) { [Environment]::SetEnvironmentVariable($envName, $originalEnv[$envName], 'Process') }
    if ($cert) {
        try {
            if ($rootCertAdded -and (Test-Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)")) { Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -ErrorAction Stop }
            if (Test-Path "Cert:\LocalMachine\My\$($cert.Thumbprint)") { Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -ErrorAction Stop }
        } catch { if (!$failure) { $failure = $_; $results.failed_stage = 'cleanup'; $results.error = Get-JourneyError $_ }; $results.cleanup = 'failed' }
    }
    try { if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction Stop } } catch { if (!$failure) { $failure = $_; $results.failed_stage = 'cleanup'; $results.error = Get-JourneyError $_ }; $results.cleanup = 'failed' }
    if ($failure) { $results.verdict = 'fail'; $results.native_roundtrip.verdict = 'fail' }
    $results | ConvertTo-Json -Depth 8 | Set-Content "$Output/result.json"
}
if ($failure) {
    if ($results.error.redacted) { throw 'Account journey failed; sensitive exception details were redacted' }
    throw $failure
}
