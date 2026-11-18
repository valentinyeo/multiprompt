$script:tabLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$script:tabAuditLog = Join-Path $scratch 'roaming/ZigShell/session-audit.log'
$script:tabInputs = @()
$script:tabSteps = @()
$script:tabSequence = 0
$catalog = & node (Join-Path $PSScriptRoot 'tab-actions.test.cjs') --catalog
if ($LASTEXITCODE -ne 0) { throw 'Tab action routing catalog failed' }
$script:tabTargets = $catalog | ConvertFrom-Json

function Get-ActionTab([long]$Id) {
    $matches = @((Read-Session).tabs | Where-Object { $_.chat_id -eq $Id })
    if ($matches.Count -ne 1) { throw "Expected one saved tab for identity $Id" }
    return $matches[0]
}
function Get-ActionValue($Tab, [string]$Field) {
    if ($Tab.PSObject.Properties[$Field]) { return $Tab.$Field }
    return 0
}
function Get-ActionPoint([long]$Id) {
    $tabs = @((Read-Session).tabs)
    $index = -1
    for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].chat_id -eq $Id) { $index = $i } }
    if ($index -lt 0) { throw 'Sidebar target no longer exists' }
    $placement = if (Get-ActionValue $tabs[$index] 'pinned_top') { 'pinned' } else { 'expanded' }
    $pattern = '\[photo-proof\] ' + $placement + ' target=' + $index + ' rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)'
    Wait-Until { [regex]::Matches((Read-SharedText $script:tabLog), $pattern).Count -gt 0 } 'real sidebar avatar geometry for the target'
    $rects = [regex]::Matches((Read-SharedText $script:tabLog), $pattern)
    $rect = $rects[$rects.Count - 1]
    return @([int](0.5 * ([int]$rect.Groups[1].Value + [int]$rect.Groups[3].Value)), [int](0.5 * ([int]$rect.Groups[2].Value + [int]$rect.Groups[4].Value)))
}
function Open-ActionPalette([string]$Route, [long]$Id) {
    $offset = (Read-SharedText $script:tabLog).Length
    $script:tabPaletteOffset = $offset
    if ($Route -eq 'context') {
        $point = Get-ActionPoint $Id
        Doctor
        Wait-Foreground
        Record "Right-click saved tab identity $Id"
        [VerifyNative]::RightClickClient($script:window, $point[0], $point[1])
    } else {
        Press @(0x11, 0x4B) 'Ctrl+K: open global tab actions'
    }
    Wait-Until { (Read-SharedText $script:tabLog).Substring($offset) -match '\[palette\] rows chars=0 count=\d+ ids=' } 'fresh native palette rows'
}
function Confirm-ActionRow([int]$Target, [string]$Query = '') {
    $offset = (Read-SharedText $script:tabLog).Length
    if ($Query) { Type-Text $Query }
    $pattern = '\[palette\] rows chars=' + $Query.Length + ' count=\d+ ids=([^\r\n]+)'
    Wait-Until {
        $rows = [regex]::Matches((Read-SharedText $script:tabLog).Substring($script:tabPaletteOffset), $pattern)
        $rows.Count -gt 0 -and @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ') -contains [string]$target
    } "native menu contains target $Target"
    $rows = [regex]::Matches((Read-SharedText $script:tabLog).Substring($script:tabPaletteOffset), $pattern)
    $rowIds = @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ')
    $ids = @($rowIds | Where-Object { $_ -notmatch '^h\d+$' })
    $paintOffset = (Read-SharedText $script:tabLog).Length
    Press @(0x24) 'Home: first visible action'
    for ($i = 0; $i -lt [Array]::IndexOf($ids, [string]$target); $i++) {
        $paintOffset = (Read-SharedText $script:tabLog).Length
        Press @(0x28) 'Down: scroll requested action into view'
    }
    $selection = @{ rows = '' }
    $clickRow = {
        param([int]$Since)
        Doctor
        Wait-Foreground
        Record "Click painted native palette target $Target"
        $point = @{}
        Wait-Until {
            $log = Read-SharedText $script:tabLog
            $fresh = $log.Substring($script:tabPaletteOffset)
            $currentRows = [regex]::Matches($fresh, '\[palette\] rows chars=(\d+) count=\d+ ids=([^\r\n]+)')
            if ($currentRows.Count -eq 0 -or [int]$currentRows[$currentRows.Count - 1].Groups[1].Value -ne $Query.Length) { return $false }
            $currentIds = $currentRows[$currentRows.Count - 1].Groups[2].Value.Trim()
            if (@($currentIds -split ' ') -notcontains [string]$Target) { return $false }
            $start = [Math]::Max($Since, $script:tabPaletteOffset + $currentRows[$currentRows.Count - 1].Index + $currentRows[$currentRows.Count - 1].Length)
            $paint = [regex]::Matches($log.Substring($start), ('\[palette-row\] target=' + $Target + ' session=[01] left=(-?\d+) top=(-?\d+) height=(\d+) text=(-?\d+)'))
            if ($paint.Count -eq 0 -or [int]$paint[$paint.Count - 1].Groups[3].Value -le 0) { return $false }
            $point.x = [int]$paint[$paint.Count - 1].Groups[4].Value
            $point.y = [int]$paint[$paint.Count - 1].Groups[2].Value + [int][Math]::Floor([int]$paint[$paint.Count - 1].Groups[3].Value / 2)
            $point.rows = $currentIds
            return $true
        } 'fresh painted target row in the current native menu'
        $selection.rows = $point.rows
        Assert-Foreground
        [VerifyNative]::ClickClient($script:window, $point.x, $point.y)
    }
    $nextOffset = (Read-SharedText $script:tabLog).Length
    & $clickRow $paintOffset
    $confirmation = @{ retried = $false }
    Wait-Until {
        $log = Read-SharedText $script:tabLog
        $trace = $log.Substring($offset)
        if ($trace -match ('\[palette\] confirm target=' + $target + '(?:\s|$)')) { return $true }
        $refresh = $log.Substring($nextOffset)
        $newRows = [regex]::Matches($refresh, '\[palette\] rows chars=(\d+) count=\d+ ids=([^\r\n]+)')
        $ready = [regex]::Matches($refresh, '\[palette\] ready chars=(\d+) count=\d+ target=(\d+)')
        # A refresh can invalidate a queued click. Reconfirm only an unchanged row, never an accepted action.
        if (-not $confirmation.retried -and $trace -notmatch '\[palette\] confirm target=' -and $newRows.Count -gt 0 -and $ready.Count -gt 0 -and
            [int]$newRows[$newRows.Count - 1].Groups[1].Value -eq $Query.Length -and $newRows[$newRows.Count - 1].Groups[2].Value.Trim() -ceq $selection.rows -and
            [int]$ready[$ready.Count - 1].Groups[1].Value -eq $Query.Length -and [int]$ready[$ready.Count - 1].Groups[2].Value -eq $target) {
            $confirmation.retried = $true
            & $clickRow $nextOffset
        }
        return $false
    } 'production palette confirms the selected routing ID'
    $script:tabPaletteOffset = $nextOffset
    return (Read-SharedText $script:tabLog).Substring($offset)
}
function Select-ActionRow([string]$Symbol, [string]$Query = '', [int]$Choice = 0) {
    $property = $script:tabTargets.PSObject.Properties[$Symbol]
    if ($null -eq $property) { throw "Unknown tab action symbol $Symbol" }
    $target = [int]$property.Value + $Choice
    $trace = Confirm-ActionRow $target $Query
    $script:tabInputs += @{ symbol=$Symbol; choice=$Choice; target=$target; query=$Query; trace=$trace }
    Save-Json @($script:tabInputs) 'tab-inputs.json'
}
function Select-ActionTab([long]$Id) {
    $tabs = @((Read-Session).tabs)
    $indices = @(for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].chat_id -eq $Id) { $i } })
    if ($indices.Count -ne 1) { throw "Expected one saved tab for identity $Id" }
    Open-ActionPalette 'global' $Id
    [void](Confirm-ActionRow $indices[0])
    Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].chat_id -eq $Id } 'selected saved chat identity'
    Press @(0x12, 0x4D) 'Alt+M: return input to the selected console'
    $state = Read-Session
    Wait-WorkspaceSurface $state.active_workspace $state.active_tab $false
}
function Rename-ActionTab([string]$Name) {
    Wait-Until { $h = [VerifyNative]::GetFocusedWindow($script:window); [VerifyNative]::Class($h) -ceq 'Edit' -and [VerifyNative]::GetAncestor($h, 2) -eq $script:window } 'owned native rename editor'
    $editor = [VerifyNative]::GetFocusedWindow($script:window)
    # The app already selected the rename text; clicking would discard that selection.
    Type-Text $Name
    Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -eq $editor -and [VerifyNative]::EditText($editor) -ceq $Name } 'native rename editor received the requested name'
    Press @(0x0D) 'Enter: save the native rename'
}
function New-ActionTab([string]$Name) {
    $before = @((Read-Session).tabs | ForEach-Object { $_.shell_id })
    Invoke-JourneyCommand 'new cmd shell'
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.shell_id -notin $before }).Count -eq 1 } 'one user-created local CMD tab'
    Open-ActionPalette 'global' 0
    Select-ActionRow 'SEARCH_TABCTX_COPY_ID' 'copy chat id'
    Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].chat_id -gt 0 } 'native Copy chat ID initialized a persistent local identity'
    $state = Read-Session
    $id = [long]$state.tabs[$state.active_tab].chat_id
    Select-ActionTab $id
    Press @(0x71) 'F2: name the disposable local tab'
    Rename-ActionTab $Name
    Wait-Until { (Get-ActionTab $id).name -ceq $Name } 'new tab name saved'
    return $id
}
function Start-ActionStep([string]$Name, [long]$Id, [string]$Route) {
    $script:tabSequence++
    $script:tabStep = @{ name=$Name; id=$Id; route=$Route; pid=$process.Id; stem=('tab-{0:D3}' -f $script:tabSequence) }
    Save-Json (Read-Session) ($script:tabStep.stem + '-before.session.json')
}
function Complete-ActionStep([bool]$Quiet = $true, $Extra = @{}) {
    $state = Read-Session
    $before = Get-Content (Join-Path $Evidence ($script:tabStep.stem + '-before.session.json')) -Raw | ConvertFrom-Json
    if ($Quiet -and ($state.tabs[$state.active_tab].chat_id -ne $before.tabs[$before.active_tab].chat_id -or $state.active_workspace -ne $before.active_workspace)) { throw 'An inactive tab action changed the active tab or workspace' }
    Save-Json $state ($script:tabStep.stem + '-after.session.json')
    Save-Json (Read-Inbox) ($script:tabStep.stem + '-after.inbox.json')
    Snapshot $script:tabStep.stem
    Copy-Item (Join-Path $Evidence 'doctor.json') (Join-Path $Evidence ($script:tabStep.stem + '-doctor.json'))
    $script:tabStep.extra = $Extra
    $script:tabSteps += $script:tabStep
    Save-Json @($script:tabSteps) 'tab-steps.json'
}
function Invoke-ActionMarker([string]$Name) {
    Select-ActionTab $script:controlId
    $state = Read-Session
    Wait-WorkspaceSurface $state.active_workspace $state.active_tab $false
    $file = Join-Path $Evidence ($Name + '.txt')
    Type-Text ('echo ' + $Name + '>"' + $file + '"')
    Press @(0x0D) 'Enter: independent control console marker'
    Wait-Until { (Test-Path $file) -and (Get-Content $file -Raw).Trim() -ceq $Name } 'only the surviving owned CMD writes its receiving marker'
}
function Invoke-ActionToggle([string]$Name, [string]$Symbol, [string]$Query, [string]$Field, [int]$Expected, [string]$Route) {
    if ($Route -eq 'global') { Select-ActionTab $script:targetId } else { Select-ActionTab $script:controlId }
    Start-ActionStep $Name $script:targetId $Route
    Open-ActionPalette $Route $script:targetId
    Select-ActionRow $Symbol $Query
    Wait-Until { [int](Get-ActionValue (Get-ActionTab $script:targetId) $Field) -eq $Expected } "$Name saved the expected field"
    Complete-ActionStep
}

Invoke-JourneyCommand 'UI Size: Reset'
Wait-Until { $state = Read-Session; $state -and @($state.tabs).Count -eq 1 } 'one fresh local tab'
$state = Read-Session
if (-not $state.single_window) { Invoke-JourneyCommand 'Single-Window Mode' }
Wait-Until { (Read-Session).single_window } 'single-window mode selected through the app'
Press @(0x71) 'F2: name the surviving control CMD'
Rename-ActionTab 'Batch control'
Open-ActionPalette 'global' 0
Select-ActionRow 'SEARCH_TABCTX_COPY_ID' 'copy chat id'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].chat_id -gt 0 } 'control identity saved by the real Copy action'
$script:controlId = [long](Read-Session).tabs[(Read-Session).active_tab].chat_id
$script:targetId = New-ActionTab 'Batch target'
$peerId = New-ActionTab 'Batch peer'
Select-ActionTab $script:controlId
Save-Json @{ control=$script:controlId; target=$script:targetId; peer=$peerId; boundary='Real local CMD processes; no seeded profile, account, provider or SSH stand-ins' } 'tab-identities.json'
Invoke-ActionMarker 'control-before'
Snapshot 'before'

foreach ($route in @('context', 'global', 'keyboard')) {
    if ($route -eq 'context') { Select-ActionTab $script:controlId } else { Select-ActionTab $script:targetId }
    Start-ActionStep ('rename-' + $route) $script:targetId $route
    if ($route -eq 'keyboard') { Press @(0x71) 'F2: rename the selected tab' } else {
        Open-ActionPalette $route $script:targetId
        Select-ActionRow 'SEARCH_TABCTX_RENAME' 'rename'
    }
    $name = 'Batch target ' + $route
    Rename-ActionTab $name
    Wait-Until { (Get-ActionTab $script:targetId).name -ceq $name } 'rename affected only the requested identity'
    Complete-ActionStep
}
foreach ($route in @('global', 'context')) {
    Select-ActionTab $script:controlId
    $copyId = if ($route -eq 'global') { $script:controlId } else { $script:targetId }
    Start-ActionStep ('copy-' + $route) $copyId $route
    Open-ActionPalette $route $copyId
    Select-ActionRow 'SEARCH_TABCTX_COPY_ID' 'copy chat id'
    $expected = 'session:#{0:x16}' -f $copyId
    Wait-Until { (Get-Clipboard -Raw) -ceq $expected } 'native clipboard equals the saved chat identity, not its title'
    Complete-ActionStep $true @{ clipboard=(Get-Clipboard -Raw) }
}
foreach ($route in @('context', 'global', 'keyboard')) {
    if ($route -eq 'context') { Select-ActionTab $script:controlId } else { Select-ActionTab $script:targetId }
    Start-ActionStep ('unread-' + $route) $script:targetId $route
    if ($route -eq 'keyboard') { Press @(0x12, 0x55) 'Alt+U: mark active session unread' } else {
        Open-ActionPalette $route $script:targetId
        Select-ActionRow 'SEARCH_TABCTX_UNREAD' 'mark as unread'
    }
    Wait-Until { $sid = (Get-ActionTab $script:targetId).shell_id; @((Read-Inbox).shells | Where-Object { $_.sid -eq $sid -and $_.att }).Count -eq 1 } 'published Inbox confirms unread on the intended tab'
    Complete-ActionStep
}
Invoke-ActionToggle 'pin-context' 'SEARCH_TABCTX_PIN_TOP' 'pin' 'pinned_top' 1 'context'
Invoke-ActionToggle 'unpin-context' 'SEARCH_TABCTX_PIN_TOP' 'unpin' 'pinned_top' 0 'context'
Invoke-ActionToggle 'pin-global' 'SEARCH_TABCTX_PIN_TOP' 'pin' 'pinned_top' 1 'global'
Invoke-ActionToggle 'unpin-global' 'SEARCH_TABCTX_PIN_TOP' 'unpin' 'pinned_top' 0 'global'
Invoke-ActionToggle 'inbox-exclude' 'SEARCH_INBOX_EXCLUDE_OFFSET' 'exclude' 'inbox_excluded' 1 'global'
Invoke-ActionToggle 'inbox-include' 'SEARCH_INBOX_EXCLUDE_OFFSET' 'exclude' 'inbox_excluded' 0 'global'
Invoke-ActionToggle 'favorite-context' 'SEARCH_TABCTX_FAVORITE' 'favorite' 'favorite' 1 'context'
Invoke-ActionToggle 'favorite-global' 'SEARCH_FAVORITE_OFFSET' 'favorite' 'favorite' 0 'global'
foreach ($expected in @(1, 0)) {
    Select-ActionTab $script:targetId
    Start-ActionStep ('favorite-keyboard-' + $expected) $script:targetId 'keyboard'
    Press @(0x12, 0x53) 'Alt+S: toggle favorite'
    Wait-Until { [int](Get-ActionValue (Get-ActionTab $script:targetId) 'favorite') -eq $expected } 'favorite keyboard route saved'
    Complete-ActionStep
}
foreach ($field in @('face', 'color')) {
    $symbol = if ($field -eq 'face') { 'SEARCH_TABCTX_BOT_FACE' } else { 'SEARCH_TABCTX_BOT_COLOR' }
    $choices = if ($field -eq 'face') { 'SEARCH_BOT_FACE_OFFSET' } else { 'SEARCH_BOT_COLOR_OFFSET' }
    Select-ActionTab $script:controlId
    Start-ActionStep ($field + '-back') $script:targetId 'context'
    Open-ActionPalette 'context' $script:targetId
    Select-ActionRow $symbol ('bot ' + $field)
    Select-ActionRow 'SEARCH_TABCTX_BACK'
    Press @(0x1B) 'Escape: close unchanged appearance menu'
    Complete-ActionStep
    foreach ($choice in @(2, 0, 1)) {
        Select-ActionTab $script:controlId
        Start-ActionStep ($field + '-' + $choice) $script:targetId 'context'
        Open-ActionPalette 'context' $script:targetId
        Select-ActionRow $symbol ('bot ' + $field)
        Select-ActionRow $choices '' $choice
        Wait-Until { $tab = Get-ActionTab $script:targetId; if ($choice -eq 0) { -not $tab.PSObject.Properties[$field] } else { $tab.PSObject.Properties[$field] -and $tab.$field -eq $choice - 1 } } 'built-in appearance or Auto saved on the target'
        Complete-ActionStep
    }
}
Select-ActionTab $script:controlId
Start-ActionStep 'group-back' $script:targetId 'context'
Open-ActionPalette 'context' $script:targetId
Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'
Select-ActionRow 'SEARCH_GROUPMOVE_BACK_OFFSET'
Press @(0x1B) 'Escape: close group menu after Back'
Complete-ActionStep
Start-ActionStep 'group-new' $script:targetId 'context'
Open-ActionPalette 'context' $script:targetId
Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'
Select-ActionRow 'SEARCH_GROUPMOVE_NEW_OFFSET' 'new group'
Press @(0x1B) 'Escape: keep the app-generated group name'
Wait-Until { (Get-ActionValue (Get-ActionTab $script:targetId) 'group_id') -gt 0 } 'new group membership saved'
$groupId = [int](Get-ActionTab $script:targetId).group_id
$groupName = @((Read-Session).groups | Where-Object { $_.id -eq $groupId })[0].name
Complete-ActionStep
Select-ActionTab $peerId
Start-ActionStep 'group-peer' $peerId 'global'
Open-ActionPalette 'global' $peerId
Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'
$groups = @((Read-Session).groups)
$groupIndex = 0
for ($i = 0; $i -lt $groups.Count; $i++) { if ($groups[$i].id -eq $groupId) { $groupIndex = $i } }
Select-ActionRow 'SEARCH_GROUPMOVE_GROUP_OFFSET' $groupName $groupIndex
Wait-Until { (Get-ActionTab $peerId).group_id -eq $groupId } 'peer keeps the app-created group alive during removal'
Complete-ActionStep
Select-ActionTab $script:controlId
foreach ($entry in @(@{name='group-none'; symbol='SEARCH_GROUPMOVE_NONE_OFFSET'; query='no group'}, @{name='group-existing'; symbol='SEARCH_GROUPMOVE_GROUP_OFFSET'; query=$groupName})) {
    Start-ActionStep $entry.name $script:targetId 'context'
    Open-ActionPalette 'context' $script:targetId
    Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'
    $groupIndex = if ($entry.name -eq 'group-existing') { $groups = @((Read-Session).groups); for ($i = 0; $i -lt $groups.Count; $i++) { if ($groups[$i].id -eq $groupId) { $i } } } else { 0 }
    Select-ActionRow $entry.symbol $entry.query $groupIndex
    $expected = if ($entry.name -eq 'group-none') { 0 } else { $groupId }
    Wait-Until { (Get-ActionValue (Get-ActionTab $script:targetId) 'group_id') -eq $expected } 'group membership changed through the submenu'
    Complete-ActionStep
}

Press @(0x11, 0x4E) 'Ctrl+N: create the destination workspace through the app'
Wait-Until { (Read-Session).workspace_count -ge 2 } 'two workspaces saved'
Open-ActionPalette 'global' 0
Select-ActionRow 'SEARCH_TABCTX_COPY_ID' 'copy chat id'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].chat_id -gt 0 } 'new workspace CMD has its own persistent identity'
$workspacePeerId = [long](Read-Session).tabs[(Read-Session).active_tab].chat_id
Select-ActionTab $workspacePeerId
Press @(0x71) 'F2: stabilize the destination-workspace peer name'
Rename-ActionTab 'Batch workspace peer'
Wait-Until { (Get-ActionTab $workspacePeerId).name -ceq 'Batch workspace peer' } 'workspace peer has a saved manual name'
Press @(0x12, 0x32) 'Alt+2: return to home workspace'
Select-ActionTab $script:controlId
Start-ActionStep 'workspace-back' $script:targetId 'context'
Open-ActionPalette 'context' $script:targetId
Select-ActionRow 'SEARCH_TABCTX_WSMOVE' 'move to workspace'
Select-ActionRow 'SEARCH_WORKSPACE_BACK_OFFSET'
Press @(0x1B) 'Escape: close workspace menu after Back'
Complete-ActionStep
Start-ActionStep 'workspace-new' $script:targetId 'context'
Open-ActionPalette 'context' $script:targetId
Select-ActionRow 'SEARCH_TABCTX_WSMOVE' 'move to workspace'
Select-ActionRow 'SEARCH_WSMOVE_NEW_OFFSET' 'move to new workspace'
Wait-Until { (Get-ActionTab $script:targetId).workspace -ne 0 -and (Get-ActionValue (Get-ActionTab $script:targetId) 'group_id') -eq 0 } 'inactive target moved into a new workspace and ungrouped'
$destination = [int](Get-ActionTab $script:targetId).workspace
Complete-ActionStep
Press @((0x12), (0x32 + $destination)) 'Alt+number: visit the destination workspace'
Select-ActionTab $script:targetId
Start-ActionStep 'workspace-existing' $script:targetId 'context'
Open-ActionPalette 'context' $script:targetId
Select-ActionRow 'SEARCH_TABCTX_WSMOVE' 'move to workspace'
Select-ActionRow 'SEARCH_WSMOVE_OFFSET' '' 0
Wait-Until { (Get-ActionValue (Get-ActionTab $script:targetId) 'workspace') -eq 0 -and (Read-Session).active_workspace -eq 0 } 'active target returned to the existing home workspace'
Complete-ActionStep $false
Select-ActionTab $script:controlId
Invoke-ActionMarker 'control-after-moves'

foreach ($route in @('context', 'global')) {
    $victim = New-ActionTab ('Disconnected ' + $route)
    $victimPid = [int](Get-ActionTab $victim).pid
    $victimProcess = Get-Process -Id $victimPid
    Open-ActionPalette 'global' $victim
    Select-ActionRow 'SEARCH_TABCTX_PIN_TOP' 'pin'
    Wait-Until { (Get-ActionTab $victim).pinned_top } 'pin keeps the exited local tab available for cleanup'
    Select-ActionTab $victim
    $exitOffset = (Read-SharedText $script:tabAuditLog).Length
    Type-Text 'exit'
    Press @(0x0D) 'Enter: exit only the disposable pinned CMD'
    Wait-Until { $victimProcess.HasExited -and (Read-SharedText $script:tabAuditLog).Substring($exitOffset) -match 'pinned-local-session-exited-preserved' } 'real CMD exits and the app preserves its pinned disconnected row'
    Select-ActionTab $script:controlId
    Start-ActionStep ('disconnected-' + $route) $victim $route
    Open-ActionPalette $route $victim
    $symbol = if ($route -eq 'context') { 'SEARCH_TABCTX_CLOSE_DISCONNECTED' } else { 'SEARCH_CLOSE_DISCONNECTED_OFFSET' }
    Select-ActionRow $symbol 'close all disconnected sessions'
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.chat_id -eq $victim }).Count -eq 0 } 'cleanup removes the disconnected pinned tab without closing live tabs'
    Complete-ActionStep $true @{ pid=$victimPid; exited=$victimProcess.HasExited }
    $victimProcess.Dispose()
    Invoke-ActionMarker ('control-after-disconnected-' + $route)
}

foreach ($case in @(@{name='archive-context'; route='context'; symbol='SEARCH_TABCTX_ARCHIVE'; query='archive chat'}, @{name='delete-context'; route='context'; symbol='SEARCH_TABCTX_END_TMUX'; query='delete session'}, @{name='delete-global'; route='global'; symbol='SEARCH_TABCTX_END_TMUX'; query='delete session'}, @{name='delete-keyboard'; route='keyboard'; symbol=''; query=''})) {
    $victim = New-ActionTab ('Victim ' + $case.name)
    $victimPid = [int](Get-ActionTab $victim).pid
    $victimProcess = Get-Process -Id $victimPid
    if ($victimProcess.ProcessName -ine 'cmd') { throw 'Saved victim PID is not its actual CMD process' }
    if ($case.route -eq 'context') { Select-ActionTab $script:controlId }
    Start-ActionStep $case.name $victim $case.route
    if ($case.route -eq 'keyboard') { Press @(0x11, 0x10, 0x57) 'Ctrl+Shift+W: delete the disposable local session' } else {
        Open-ActionPalette $case.route $victim
        Select-ActionRow $case.symbol $case.query
    }
    Wait-Until { @((Read-Session).tabs | Where-Object { $_.chat_id -eq $victim }).Count -eq 0 -and $victimProcess.HasExited } 'only the disposable CMD and its saved tab closed'
    Complete-ActionStep ($case.route -eq 'context') @{ pid=$victimPid; exited=$victimProcess.HasExited }
    $victimProcess.Dispose()
    Invoke-ActionMarker ('control-after-' + $case.name)
}

Select-ActionTab $script:controlId
Save-Json (Read-Session) 'tab-layout-before-restart.json'
Snapshot 'action'
Restart-SessionRestore 'tab-actions-restart' $false
Wait-Until { @((Read-Session).tabs | Where-Object { $_.chat_id -eq $script:controlId }).Count -eq 1 -and @((Read-Session).tabs | Where-Object { $_.chat_id -eq $script:targetId }).Count -eq 1 } 'original local chat identities restored'
Save-Json (Read-Session) 'tab-layout-after-restart.json'
Invoke-ActionMarker 'control-after-restart'
Select-ActionTab $script:targetId
Open-ActionPalette 'global' $script:targetId
Select-ActionRow 'SEARCH_TABCTX_COPY_ID' 'copy chat id'
if ((Get-Clipboard -Raw) -cne ('session:#{0:x16}' -f $script:targetId)) { throw 'Restart changed the copied chat identity' }
Save-Json @{ clipboard=(Get-Clipboard -Raw) } 'tab-restarted-identity.json'
Snapshot 'after'
Copy-Item $script:tabLog (Join-Path $Evidence 'tab-actions-debug.log')
Copy-Item $script:tabAuditLog (Join-Path $Evidence 'tab-actions-session-audit.log')
& node (Join-Path $PSScriptRoot 'tab-actions.test.cjs') --evidence $Evidence
if ($LASTEXITCODE -ne 0) { throw 'Independent tab action evidence did not match the live journey' }
$result.checks += @{ name='tab-actions-native'; steps=$script:tabSteps.Count; selections=$script:tabInputs.Count; boundary='Real local CMD processes and app-written saved state; no remote provider or account synchronization claimed' }
