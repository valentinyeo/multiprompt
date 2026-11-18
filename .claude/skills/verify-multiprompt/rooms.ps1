param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use the hosted Windows Rooms journey' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, WindowsBase, System.Drawing, System.Security
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'control-native.cs')
$Exe = (Resolve-Path $Exe).Path
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('multiprompt-rooms-' + [guid]::NewGuid().ToString('N'))
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$fixture = Join-Path $scratch 'fixture'
$settings = Join-Path $scratch 'roaming/ZigShell'
$script:window = [IntPtr]::Zero
$script:actions = New-Object Collections.ArrayList
$process = $null
$job = $null
$server = $null
$serviceJob = $null
$certificate = $null
$hostsPath = "$env:SystemRoot/System32/drivers/etc/hosts"
$hostsBytes = [IO.File]::ReadAllBytes($hostsPath)
$original = @{}
$result = [ordered]@{ feature='rooms'; status='failed'; productPassed=$false; checks=@(); findings=@(); scratchRemoved=$false; failureKind='infrastructure' }
. (Join-Path $PSScriptRoot 'control-library.ps1')

function Read-RoomStore {
    $output = & python (Join-Path $PSScriptRoot 'rooms-fixture.py') inspect
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the Rooms fixture store' }
    return @((($output -join "`n") | ConvertFrom-Json))
}
function Room-Window {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptRoomView')
    $node = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -ne $node -and -not $node.Current.IsOffscreen) { return [IntPtr]$node.Current.NativeWindowHandle }
    return [IntPtr]::Zero
}
function Focused-RoomEdit {
    $edit = [VerifyNative]::GetFocusedWindow($script:window)
    [uint32]$owner = 0
    [void][VerifyNative]::GetWindowThreadProcessId($edit, [ref]$owner)
    if ($owner -ne $process.Id -or [VerifyNative]::Class($edit) -ine 'Edit') { throw 'Room input is not focused' }
    $room = Room-Window
    if ($room -eq [IntPtr]::Zero -or [VerifyNative]::GetAncestor($edit, 2) -ne $script:window) { throw 'Room input is not owned by this app' }
    return $edit
}
function Audit-Step([string]$Name, [scriptblock]$Action, [string]$Prerequisite = '') {
    Doctor
    $start = [DateTime]::UtcNow
    $entry = [ordered]@{ name=$Name; startedAt=$start.ToString('o'); endedAt=$null; status='failed'; detail=''; screenshot="$Name.png" }
    try {
        if ($Prerequisite) { $entry.status='blocked'; throw $Prerequisite }
        Record "Rooms action: $Name"
        & $Action
        $entry.status='passed'
    } catch { $entry.detail=$_.Exception.Message }
    $entry.endedAt = [DateTime]::UtcNow.ToString('o')
    Snapshot $Name
    $result.checks += $entry
    Save-Json $result.checks 'rooms-steps.json'
    return
}
function Open-RoomByName([string]$Name) {
    $logStart = (Read-SharedText "$settings/debug.log").Length
    Press @(0x11,0x4B) 'Ctrl+K: find a room by name'
    Type-Text $Name
    Wait-Until { (Read-SharedText "$settings/debug.log").Substring($logStart) -match ('\[palette\] ready chars=' + $Name.Length + ' count=1 ') } 'one exact room palette result'
    Snapshot ('select-' + $Name.Replace(' ','-'))
    Press @(0x0D) 'Enter: open the named room'
    Wait-Until { (Room-Window) -ne [IntPtr]::Zero } 'visible room view'
    $manifest = Get-Content "$fixture/manifest.json" -Raw | ConvertFrom-Json
    $expected = @($manifest.rooms | Where-Object name -eq $Name)[0]
    Wait-Until {
        $files = @(Get-ChildItem $settings -Filter 'room-ui-*.json')
        if ($files.Count -ne 1) { return $false }
        $saved = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
        $saved.record.selected.room_id -ceq $expected.id -and $saved.record.selected_front
    } 'the selected room identity persisted'
    Wait-Until {
        $file = "$fixture/$($expected.id).observed.json"
        if (-not (Test-Path $file)) { return $false }
        (Get-Content $file -Raw | ConvertFrom-Json).next_after -ge $expected.events
    } 'all seeded room events delivered through the production bridge' 30
}
try {
    foreach ($name in @('APPDATA','LOCALAPPDATA','USERPROFILE','HOME','MULTIPROMPT_NO_LOGIN','ZIGSHELL_DEBUG','IGSH_246','MP_ROOMS_FIXTURE','MP_VERIFY_PYTHON','MP_VERIFY_BOUNDARY','NODE_EXTRA_CA_CERTS')) { $original[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
    foreach ($directory in @($settings, "$scratch/local", "$scratch/home")) { New-Item -ItemType Directory -Force $directory | Out-Null }
    $env:APPDATA="$scratch/roaming"; $env:LOCALAPPDATA="$scratch/local"; $env:USERPROFILE="$scratch/home"; $env:HOME="$scratch/home"
    $env:MULTIPROMPT_NO_LOGIN=$null; $env:ZIGSHELL_DEBUG='1'; $env:IGSH_246='0'
    $env:MP_ROOMS_FIXTURE=$fixture
    $env:MP_VERIFY_PYTHON=(Get-Command python.exe).Source
    $env:MP_VERIFY_BOUNDARY=Join-Path $PSScriptRoot 'rooms-fixture.py'
    & python $env:MP_VERIFY_BOUNDARY seed
    if ($LASTEXITCODE -ne 0) { throw 'Rooms real-size seed failed' }
    Copy-Item "$fixture/manifest.json" "$Evidence/seed.json"
    Copy-Item "$fixture/session.json" "$settings/session.json"
    [IO.File]::WriteAllText("$settings/ssh-path.txt", (Join-Path (Split-Path $Exe) 'rooms-ssh.exe'))
    $passwordText = [guid]::NewGuid().ToString('N')
    $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
    $certificate = New-SelfSignedCertificate -DnsName 'account.multiprompt.dev' -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(1)
    Export-PfxCertificate -Cert $certificate -FilePath "$scratch/account.pfx" -Password $password | Out-Null
    Export-Certificate -Cert $certificate -FilePath "$scratch/account.cer" | Out-Null
    Import-Certificate -FilePath "$scratch/account.cer" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    $pem = "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($certificate.RawData,'InsertLineBreaks') + "`n-----END CERTIFICATE-----`n"
    [IO.File]::WriteAllText("$scratch/account.pem",$pem)
    $env:NODE_EXTRA_CA_CERTS="$scratch/account.pem"
    [IO.File]::AppendAllText($hostsPath,"`r`n127.0.0.1 account.multiprompt.dev`r`n")
    $serviceJob = New-Object VerifyJob
    $server = $serviceJob.Start((Get-Command node.exe).Source, $repo, "$scratch/account.stdout.log", "$scratch/account.stderr.log", ('"' + "$repo/service/journey/server.mjs" + '" --port=443 --pfx="' + "$scratch/account.pfx" + '" --pfxpass=' + $passwordText + ' --state="' + "$scratch/account.json" + '"'))
    $passwordText=$null
    Wait-Until { Test-Path "$scratch/account.json" } 'private account Worker fixture ready' 90
    $account = Get-Content "$scratch/account.json" -Raw | ConvertFrom-Json
    $headers = @{ Authorization="Bearer $($account.admin_key)"; 'X-Layout-Features'='hosts,host_removal,groups' }
    $current = Invoke-RestMethod 'https://account.multiprompt.dev/v1/layout' -Headers $headers
    $layout = Get-Content "$fixture/layout.json" -Raw | ConvertFrom-Json
    $body = @{base_revision=$current.revision; layout=$layout} | ConvertTo-Json -Depth 12
    Invoke-RestMethod 'https://account.multiprompt.dev/v1/layout' -Method Put -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
    $credential=[Text.Encoding]::UTF8.GetBytes((@{refresh_token=$account.refresh_token} | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes("$settings/account-device.dat", [Security.Cryptography.ProtectedData]::Protect($credential,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser))
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch' }
    $job=New-Object VerifyJob
    $process=$job.Start($Exe,$scratch,"$Evidence/stdout.log","$Evidence/stderr.log",'--single-window')
    Wait-Until { $process.Refresh(); $script:window=$process.MainWindowHandle; $script:window -ne [IntPtr]::Zero -and $null -ne (Read-Inbox) } 'owned desktop and published state' 90
    Wait-Until { (Read-SharedText "$settings/debug.log") -match 'account-sync: applied' } 'account layout applied' 90
    [void][VerifyNative]::ShowWindow($script:window,9)
    [void][VerifyNative]::MoveWindow($script:window,10,10,1000,650,$true)
    [VerifyNative]::BringToForeground($script:window)
    Doctor
    Snapshot 'before'
    $script:createdRoom=$null
    Audit-Step 'create-room' {
        Press @(0x11,0x10,0x4E) 'Ctrl+Shift+N: New room'
        Wait-Until { (Room-Window) -ne [IntPtr]::Zero } 'New room dialog'
        $edit=Focused-RoomEdit
        if ([VerifyNative]::GetForegroundWindow() -ne $script:window) { throw 'New room did not take foreground from the hidden session console' }
        Type-Text 'Rooms audit created'
        if ([VerifyNative]::EditText($edit) -cne 'Rooms audit created') { throw 'New room name did not accept typing' }
    }
    Audit-Step 'add-agents' {
        [void](Focused-RoomEdit)
        Press @(0x09) 'Tab: Search agents'
        Type-Text 'Rooms agent 00'
        if ([VerifyNative]::EditText((Focused-RoomEdit)) -cne 'Rooms agent 00') { throw 'Agent search did not accept the first exact name' }
        Start-Sleep -Seconds 12
        Snapshot 'agent-search-first'
        Press @(0x0D) 'Enter: select first agent'
        Press @(0x11,0x41) 'Ctrl+A: replace agent search'
        Type-Text 'Rooms agent 01'
        if ([VerifyNative]::EditText((Focused-RoomEdit)) -cne 'Rooms agent 01') { throw 'Ctrl+A did not replace the agent search with the second exact name' }
        Start-Sleep -Seconds 2
        Press @(0x0D) 'Enter: select second agent'
        Snapshot 'agents-selected'
        Snapshot 'action'
        Press @(0x11,0x0D) 'Ctrl+Enter: create room with the selected agents'
        Wait-Until { $script:createdRoom=@(Read-RoomStore | Where-Object name -eq 'Rooms audit created') | Select-Object -First 1; $null -ne $script:createdRoom } 'created room persisted' 15
        if (@($script:createdRoom.members).Count -ne 2) { throw 'Room was not created with exactly the two selected agents' }
        Wait-Until {
            $root = [System.Windows.Automation.AutomationElement]::FromHandle((Room-Window))
            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
            $visible = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
            $visible.Count -eq 1 -and (Focused-RoomEdit) -ne [IntPtr]::Zero
        } 'the room composer is ready after creation'
    }
    $roomBlocked = if ($null -eq $script:createdRoom) { 'Blocked by room creation or agent selection; no room was persisted' } else { '' }
    Audit-Step 'send-message' {
        [void](Focused-RoomEdit)
        Type-Text 'ROOMS AUDIT FIRST MESSAGE'
        Press @(0x0D) 'Enter: send room message'
        Wait-Until { $room=@(Read-RoomStore | Where-Object id -eq $script:createdRoom.id)[0]; @($room.events | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'ROOMS AUDIT FIRST MESSAGE' }).Count -eq 1 } 'one persisted human message' 20
    } $roomBlocked
    Audit-Step 'replies-in-order' {
        Wait-Until { $room=@(Read-RoomStore | Where-Object id -eq $script:createdRoom.id)[0]; @($room.events | Where-Object type -eq 'agent_reply').Count -eq 2 } 'both attributed agent replies' 30
        $room=@(Read-RoomStore | Where-Object id -eq $script:createdRoom.id)[0]
        $replies=@($room.events | Where-Object type -eq 'agent_reply')
        if ($replies[0].parent_event_id -ne $replies[1].parent_event_id -or $replies[0].member_id -eq $replies[1].member_id -or $replies[0].seq -ge $replies[1].seq) { throw 'Replies are duplicated, misattributed, or out of sequence' }
        Snapshot 'visible-reply-order-review'
    } $roomBlocked
    Audit-Step 'switch-rooms' {
        Press @(0x1B) 'Escape: dismiss any room dialog'
        Open-RoomByName 'Rooms history 00'
        if ([VerifyNative]::Title((Room-Window)) -cne 'Rooms history 00') { throw 'Switching rooms did not publish the selected title' }
        Snapshot 'long-seeded-room'
        Open-RoomByName 'Rooms history 01'
        Snapshot 'second-seeded-room'
        Open-RoomByName 'Rooms history 00'
        Snapshot 'long-room-return'
        $stateFiles=@(Get-ChildItem $settings -Filter 'room-ui-*.json')
        if ($stateFiles.Count -ne 1) { throw 'Room selection was not persisted under this account' }
        $selected=Get-Content $stateFiles[0].FullName -Raw
        $seed=Get-Content "$fixture/manifest.json" -Raw | ConvertFrom-Json
        if (-not $selected.Contains($seed.rooms[0].id)) { throw 'Returning selected the wrong room identity' }
    }
    Audit-Step 'leave-or-close' {
        Press @(0x11,0x10,0x49) 'Ctrl+Shift+I: leave room for Inbox'
        Wait-Until { (Room-Window) -eq [IntPtr]::Zero } 'room view hidden after leaving'
        Open-RoomByName 'Rooms history 00'
        $seed=Get-Content "$fixture/manifest.json" -Raw | ConvertFrom-Json
        $room=@(Read-RoomStore | Where-Object id -eq $seed.rooms[0].id)[0]
        if (@($room.events).Count -ne $seed.largestRoomEvents) { throw 'Leaving or reopening changed the seeded history' }
    }
    Audit-Step 'to-one-and-everyone' {
        Press @(0x1B) 'Escape: clear any interrupted palette or dialog'
        Open-RoomByName 'Rooms history 01'
        $recipient=@(Read-RoomStore | Where-Object name -eq 'Rooms history 01')[0].members[0].id
        Invoke-JourneyCommand 'Room recipients'
        Press @(0x28) 'Down: enter native menu keyboard navigation'
        Press @(0x24) 'Home: everyone'
        Press @(0x28) 'Down: first session'
        Press @(0x0D) 'Enter: target just that session'
        Snapshot 'to-one-selected'
        [void](Focused-RoomEdit)
        Type-Text 'ROOMS TO ONE SESSION'
        Press @(0x0D) 'Enter: send to one without adding a mention'
        Wait-Until {
            $room=@(Read-RoomStore | Where-Object name -eq 'Rooms history 01')[0]
            $sent=@($room.events | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'ROOMS TO ONE SESSION' })
            $sent.Count -eq 1 -and @($sent[0].recipients).Count -eq 1 -and $sent[0].recipients[0] -ceq $recipient
        } 'one delivery for the selected session'
        Invoke-JourneyCommand 'Room recipients'
        Press @(0x28) 'Down: enter native menu keyboard navigation'
        Press @(0x24) 'Home: everyone'
        Press @(0x0D) 'Enter: everyone'
        Type-Text 'ROOMS TO EVERYONE @ordinary-text'
        Press @(0x0D) 'Enter: send to everyone regardless of punctuation'
        Wait-Until {
            $room=@(Read-RoomStore | Where-Object name -eq 'Rooms history 01')[0]
            $sent=@($room.events | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'ROOMS TO EVERYONE @ordinary-text' })
            $sent.Count -eq 1 -and @($sent[0].recipients).Count -eq 2
        } 'everyone selected by the To chip'
        Snapshot 'to-everyone'
    }
    Audit-Step 'leave-and-undo' {
        Press @(0x1B) 'Escape: clear any interrupted palette or dialog'
        Open-RoomByName 'Rooms history 01'
        $before=@(Read-RoomStore | Where-Object name -eq 'Rooms history 01')[0]
        Invoke-JourneyCommand 'Leave room'
        Wait-Until { (Room-Window) -eq [IntPtr]::Zero } 'left room hidden'
        Wait-Until {
            $file=@(Get-ChildItem $settings -Filter 'room-ui-*.json')[0]
            $saved=Get-Content $file.FullName -Raw | ConvertFrom-Json
            @($saved.record.left | Where-Object room_id -eq $before.id).Count -eq 1
        } 'left room durably hidden for this account'
        Invoke-JourneyCommand 'Undo leave room'
        Wait-Until { (Room-Window) -ne [IntPtr]::Zero -and [VerifyNative]::Title((Room-Window)) -ceq 'Rooms history 01' } 'undo reopens the same room'
        $after=@(Read-RoomStore | Where-Object id -eq $before.id)[0]
        if (@($after.members).Count -ne 2 -or @($after.events).Count -lt @($before.events).Count) { throw 'Leave or undo removed sessions or history' }
        Snapshot 'leave-undone'
    }
    Audit-Step 'delete-confirmation' {
        Press @(0x1B) 'Escape: clear any interrupted palette or dialog'
        Open-RoomByName 'Rooms history 02'
        $target=@(Read-RoomStore | Where-Object name -eq 'Rooms history 02')[0]
        $sessionIds=@((Read-Inbox).shells | ForEach-Object sid | Sort-Object)
        Invoke-JourneyCommand 'Delete room'
        Snapshot 'delete-confirmation-open'
        Press @(0x1B) 'Escape: cancel deletion'
        if (@(Read-RoomStore | Where-Object id -eq $target.id).Count -ne 1) { throw 'Cancel deleted the room' }
        Invoke-JourneyCommand 'Delete room'
        Press @(0x27) 'Right: select Delete room instead of Cancel'
        Press @(0x0D) 'Enter: confirm room deletion'
        Wait-Until { @(Read-RoomStore | Where-Object id -eq $target.id).Count -eq 0 } 'only the confirmed room deleted'
        if (@(Read-RoomStore | Where-Object name -eq 'Rooms history 00').Count -ne 1) { throw 'Deletion removed another room' }
        $remainingIds=@((Read-Inbox).shells | ForEach-Object sid | Sort-Object)
        if (($sessionIds -join ',') -cne ($remainingIds -join ',')) { throw 'Deleting the Room changed its real session rows' }
        Snapshot 'room-deleted'
    }
    Audit-Step 'send-while-away' {
        Press @(0x1B) 'Escape: clear any interrupted palette or dialog'
        Open-RoomByName 'Rooms history 03'
        Wait-Until { (Focused-RoomEdit) -ne [IntPtr]::Zero } 'the seeded Room composer is ready'
        Type-Text 'ROOMS CONTINUE WHILE AWAY'
        Press @(0x0D) 'Enter: send while the SSH receipt is deliberately delayed'
        Press @(0x11,0x10,0x49) 'Ctrl+Shift+I: leave the conversation before its receipt returns'
        Wait-Until { (Room-Window) -eq [IntPtr]::Zero } 'conversation hidden during delivery'
        Wait-Until {
            if ((Room-Window) -ne [IntPtr]::Zero) { throw 'Background delivery reopened the Room' }
            $room=@(Read-RoomStore | Where-Object name -eq 'Rooms history 03')[0]
            $sent=@($room.events | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'ROOMS CONTINUE WHILE AWAY' })
            if ($sent.Count -ne 1) { return $false }
            @($room.events | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -eq $sent[0].id }).Count -eq 2
        } 'both replies progress without opening the Room again' 30
        Snapshot 'background-replies'
    }
    Audit-Step 'sidebar-real-session-row' {
        Press @(0x1B) 'Escape: clear any interrupted palette or dialog'
        Open-RoomByName 'Rooms history 00'
        $room=@(Read-RoomStore | Where-Object name -eq 'Rooms history 00')[0]
        Wait-Until {
            $path="$fixture/$($room.id).metadata.json"
            (Test-Path $path) -and (Get-Content $path -Raw | ConvertFrom-Json).memberCount -eq 2
        } 'first Room member metadata observed on both master and candidate'
        $state=Read-Session
        if (-not $state.single_window -or -not $state.hide_pills -or ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed) -or ($state.PSObject.Properties['ui_scale'] -and $state.ui_scale -ne 100)) { throw 'Real-row click requires the isolated default expanded sidebar' }
        $member=@((Read-Inbox).shells | Where-Object name -ceq $room.members[0].display_name)
        if ($member.Count -ne 1) { throw 'Room member does not identify exactly one real session' }
        Snapshot 'sidebar-groups'
        Doctor
        Assert-Foreground
        Record 'Click the first real member row below the first Room heading'
        $scale=[double][VerifyNative]::GetDpiForWindow($script:window)/96.0
        [VerifyNative]::ClickClient($script:window, [int](150*$scale), [int](131*$scale))
        Wait-Until { (Room-Window) -eq [IntPtr]::Zero -and (Read-Inbox).active_shell_id -eq $member[0].sid } 'Room member row opens its real session rather than another Room'
        Snapshot 'sidebar-session-open'
    }
    Snapshot 'after'
    $result.findings=@($result.checks | Where-Object status -ne 'passed')
    $result.productPassed=$result.findings.Count -eq 0
    $result.failureKind=$null
    $result.status='passed'
    $result.visualReviewRequired=@('visible-reply-order-review.png','long-seeded-room.png','second-seeded-room.png','long-room-return.png')
    & python (Join-Path $PSScriptRoot 'rooms-fixture.py') inspect | Set-Content -Encoding UTF8 "$Evidence/room-store-after.json"
    if ($LASTEXITCODE -ne 0) { throw 'Rooms final store evidence could not be retained' }
    if (-not $result.productPassed) { throw ('Rooms regression failed: ' + (($result.findings | ForEach-Object name) -join ', ')) }
} catch { $result.status='failed'; $result.error=$_.Exception.Message; if ($script:window -ne [IntPtr]::Zero) { try { Snapshot 'failure' } catch {} } }
finally {
    try {
        if ($null -ne $process -and -not $process.HasExited) { [void]$process.CloseMainWindow(); [void]$process.WaitForExit(10000) }
        if ($null -ne $job) { $stopped=$job.Stop(); Save-Json @{activeAfterStop=$stopped.ActiveProcesses;totalProcesses=$stopped.TotalProcesses} 'process-tree.json'; if ($stopped.ActiveProcesses -ne 0) { throw 'Owned app processes remain' } }
        if ($null -ne $serviceJob) { $stoppedService=$serviceJob.Stop(); if ($stoppedService.ActiveProcesses -ne 0) { throw 'Owned account fixture processes remain' } }
        if (Test-Path $settings) {
            New-Item -ItemType Directory -Force "$Evidence/data" | Out-Null
            Get-ChildItem $settings -File | Where-Object { $_.Extension -in @('.json','.log') -and $_.Name -notmatch 'account|key|auth' } | Copy-Item -Destination "$Evidence/data"
        }
        if (Test-Path "$fixture/rooms.sqlite3") { Copy-Item "$fixture/rooms.sqlite3" "$Evidence/rooms.sqlite3" }
        Release-ScratchConsoleFonts $scratch
        Remove-ScratchPath $scratch
        $result.scratchRemoved=-not (Test-Path $scratch)
        if (-not $result.scratchRemoved) { throw 'Rooms scratch was not removed' }
    } catch { $result.status='failed'; $result.cleanupError=$_.Exception.Message }
    finally {
        [IO.File]::WriteAllBytes($hostsPath,$hostsBytes)
        if ($null -ne $certificate) {
            foreach ($store in @('My','Root')) { $path="Cert:\LocalMachine\$store\$($certificate.Thumbprint)"; if (Test-Path $path) { Remove-Item $path } }
        }
        foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name,$original[$name],'Process') }
        foreach ($owned in @($process,$job,$server,$serviceJob)) { if ($null -ne $owned) { $owned.Dispose() } }
        Save-Json $result 'result.json'
    }
}
if ($result.status -ne 'passed') { throw $result.error }
Write-Output 'Rooms creation, recipient selection, send, replies, switching, leave/undo and delete/cancel journeys passed. Review the recorded sidebar and chips for visual acceptance.'
