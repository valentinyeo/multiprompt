param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Hosted Windows only' }
if (!$env:ROOMS_PROOF_CREDENTIAL) { throw 'Disposable room account credential required' }
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
$credential = $env:ROOMS_PROOF_CREDENTIAL | ConvertFrom-Json
Remove-Item Env:ROOMS_PROOF_CREDENTIAL
$secret = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token=$credential.desktop_refresh_token } | ConvertTo-Json -Compress))
[IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), [Security.Cryptography.ProtectedData]::Protect($secret, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
[Array]::Clear($secret, 0, $secret.Length)
$credential = $null
$logPath = Join-Path $settings 'debug.log'
$checks = [Collections.Generic.List[object]]::new()
$actions = [Collections.Generic.List[object]]::new()
$result = @{status='failed'; cleanup='pending'; checks=$checks; error=$null; boundary='Live disposable account; SSH/provider/POSIX ownership stand-ins; legacy-peer UI only'}
$job = $null
$app = $null
$main = [IntPtr]::Zero
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($timer.Elapsed.TotalSeconds -lt 90)
    throw "Timed out: $Name"
}
function Check([string]$Name, [bool]$Condition) {
    $checks.Add(@{name=$Name; passed=$Condition})
    if (!$Condition) { throw "Failed: $Name" }
}
function Log {
    if (!(Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Press([int[]]$Keys) {
    if ($app.HasExited -or [ChatDeliveryDesktop]::Window([uint32]$app.Id) -ne $main -or [ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App does not own keyboard' }
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind='keys'; keys=$Keys})
    $opensPalette = $Keys.Count -eq 2 -and $Keys[0] -eq 0x11 -and $Keys[1] -eq 0x4b
    $offset = if ($opensPalette) { (Log).Length } else { 0 }
    [VerifyNative]::Chord($Keys)
    if ($opensPalette) { [void](Wait-For 'palette opened' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=[1-9]\d*' }) }
}
function Query([string]$Text, [int]$Target) {
    $offset = (Log).Length
    [VerifyNative]::Text($Text)
    [void](Wait-For 'palette selection' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match ("\[palette\] ready chars="+$Text.Length+" count=[1-9]\d* target="+$Target+"(?:\r?\n|$)") })
}
function Focus {
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$app.Id, $main) })
}
function Room-Window {
    if ($app.HasExited) { throw ('App exited: '+$app.ExitCode) }
    try {
        $root = [Windows.Automation.AutomationElement]::FromHandle($main)
        $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptRoomView')
        $node = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($node -and !$node.Current.IsOffscreen) { return [IntPtr]$node.Current.NativeWindowHandle }
    } catch [System.Management.Automation.MethodInvocationException] {
        if ($_.Exception.InnerException -isnot [Windows.Automation.ElementNotAvailableException]) { throw }
    } catch [Windows.Automation.ElementNotAvailableException] {}
}
function Witness {
    $path = Join-Path $env:MP_VERIFY_STATE 'witness.json'
    if (Test-Path $path) { return Get-Content $path -Raw | ConvertFrom-Json }
    return $null
}
function Shot([string]$Name) {
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind='screenshot'; name=$Name})
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Start-App {
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
    [VerifyNative]::Text('Product sync')
    Press @(0x09)
    Press @(0x0d); Press @(0x28); Press @(0x0d)
    Shot 'create-members'
    Press @(0x11,0x0d)
    [void](Wait-For 'room saved through remote store' { $w=Witness; $w -and @($w.rooms).Count -eq 1 -and @($w.rooms[0].members).Count -eq 2 })
    $room = Wait-For 'room composer' { $h=Room-Window; if ($h -and [ChatDeliveryDesktop]::Composer($h) -ne [IntPtr]::Zero) { $h } }
    $composer = [ChatDeliveryDesktop]::Composer($room)
    [void](Wait-For 'composer owns focus' { [ChatDeliveryDesktop]::Focus($main)[1] -eq $composer.ToInt64() })
    Shot 'created'
    [VerifyNative]::Text('Keep this draft on old peers')
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
    $result.status='passed'
} catch {
    $result.error=$_.Exception.Message
    try { $w=Witness; if ($w) { Save $w (Join-Path $Evidence 'witness.json') } } catch {}
    try {
        $reports = @(Get-ChildItem (Join-Path $settings 'crashes') -Filter 'crash-*.txt' -ErrorAction SilentlyContinue)
        $frames = @($reports | ForEach-Object {
            Get-Content $_.FullName | Where-Object { $_ -match '^(exception_code: 0x[0-9A-F]+ \([A-Z_]+\)|exception_address: 0x[0-9A-F]+|module_base: 0x[0-9A-F]+|module_offset: 0x[0-9A-F]+|exe_base: 0x[0-9A-F]+|  0x[0-9A-F]+)$' }
        })
        Save $frames (Join-Path $Evidence 'crash-addresses.json')
    } catch {}
    try { Shot 'failure' } catch {}
} finally {
    if ($null -ne $job) { $stopped=$job.Stop(); $result.cleanup=$stopped.ActiveProcesses; $job.Dispose() } else { $result.cleanup=0 }
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
    $result.scratch_removed=!(Test-Path $profile)
    Save @($actions) (Join-Path $Evidence 'actions.json')
    Save $result (Join-Path $Evidence 'result.json')
}
if ($result.status -ne 'passed' -or $result.cleanup -ne 0 -or !$result.scratch_removed) { throw 'Room legacy-peer verification failed; see result.json' }
