Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WorkspaceSwitcherProof {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
}
'@

function Get-WorkspaceCard {
    $card = [WorkspaceSwitcherProof]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptWorkspaceSwitcher', 'Workspaces')
    if ($card -ne [IntPtr]::Zero -and [VerifyNative]::IsWindowVisible($card)) { return $card }
    return [IntPtr]::Zero
}

function Open-WorkspaceCard([string]$Shot) {
    $state = Read-Session
    if (($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -or ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)) { throw 'Workspace header must be expanded and visible' }
    $top = if ($state.hide_pills) { 0 } else { 34 }
    Record 'Click workspace name above the sessions'
    [VerifyNative]::ClickClient($script:window, 80, ($top + 26))
    Wait-Until { (Get-WorkspaceCard) -ne [IntPtr]::Zero } 'native workspace card visible'
    Snapshot $Shot
    return Get-WorkspaceCard
}

function Get-SavedTabWorkspace($Tab) {
    if ($Tab.PSObject.Properties['workspace']) { return [int]$Tab.workspace }
    return 0
}

function Get-PaletteRowIds([string]$Trace, [int]$Chars) {
    $found = [regex]::Matches($Trace, ('\[palette\] rows chars=' + $Chars + ' count=\d+ ids=([0-9 ]+)'))
    if ($found.Count -eq 0) { return $null }
    return $found[$found.Count - 1].Groups[1].Value.Trim()
}

function Test-EmptyHomeCardRow([int]$Index, $State) {
    $workspace = $State.workspaces[$Index]
    if ($workspace.wid -cne 'default') { return $false }
    if ($State.active_workspace -eq $Index) { return $false }
    return (@($State.tabs | Where-Object { (Get-SavedTabWorkspace $_) -eq $Index }).Count -eq 0)
}

function Get-WorkspaceCardRow([int]$Workspace) {
    $state = Read-Session
    $row = 1
    for ($index = 0; $index -lt $state.workspace_count; $index++) {
        if ($state.workspaces[$index].PSObject.Properties['archived'] -and $state.workspaces[$index].archived) { continue }
        if (Test-EmptyHomeCardRow $index $state) { continue }
        if ($index -eq $Workspace) { return $row }
        $row++
    }
    throw 'Target workspace missing from visible card rows'
}

function Get-VisibleWorkspaceCardRows() {
    $state = Read-Session
    $count = 0
    for ($index = 0; $index -lt $state.workspace_count; $index++) {
        if ($state.workspaces[$index].PSObject.Properties['archived'] -and $state.workspaces[$index].archived) { continue }
        if (Test-EmptyHomeCardRow $index $state) { continue }
        $count++
    }
    return $count
}

function Select-WorkspaceCard([int]$Workspace, [string]$Shot) {
    $card = Open-WorkspaceCard ($Shot + '-open')
    $state = Read-Session
    $target = Get-WorkspaceCardRow $Workspace
    $visibleRows = Get-VisibleWorkspaceCardRows
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($card, [ref]$rect)) { throw 'Card rectangle unavailable' }
    if ($rect.Bottom -lt (19 + ($visibleRows + 2) * 28)) { throw 'Fixture requires all workspace rows visible' }
    Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'main window foreground before workspace card row click'
    Record ('Click named workspace row ' + $state.workspaces[$Workspace].name)
    [VerifyNative]::ClickOwnedChildClient($card, $script:window, 50, (6 + $target * 28 + 14))
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq $Workspace -and -not (Read-Session).starred_view } 'card closed and chosen workspace saved'
    Snapshot $Shot
    Save-Json (Read-Session) ($Shot + '.session.json')
}

if ((Read-Session).workspace_count -ne 1) { throw 'Identity round-trip requires one initial workspace' }
Invoke-JourneyCommand 'Single-Window Mode' -Confirm {
    Press @(0x0D) 'Enter: leave single-window mode with one workspace'
}
Wait-Until { $state = Read-Session; $null -ne $state -and -not ($state.PSObject.Properties['single_window'] -and $state.single_window) } 'standalone mode saved'
Invoke-JourneyCommand 'Single-Window Mode' -Confirm {
    Press @(0x0D) 'Enter: return to single-window mode'
}
Wait-Until {
    $state = Read-Session
    $null -ne $state -and $state.PSObject.Properties['single_window'] -and $state.single_window -and $state.workspace_count -eq 1 -and $state.workspaces[0].wid -ceq 'default'
} 'home workspace keeps the containing window identity'
Save-Json (Read-Session) 'workspace-window-identity.session.json'
$result.checks += @{ name = 'workspace-window-identity'; id = 'default'; setup = 'real single-window mode round trip' }

$before = (Read-Session).workspace_count
Snapshot 'action'
Press @(0x11, 0x4E) 'Ctrl+N: create workspace'
Wait-Until { (Read-Session).workspace_count -eq $before + 1 } 'workspace and CMD tab persisted'
$created = (Read-Session).active_workspace
Snapshot 'created'
Select-WorkspaceCard 0 'workspace-first'
Select-WorkspaceCard $created 'workspace-created'
$result.checks += @{ name = 'workspace-card-mouse-switch'; first = 0; created = $created; hiddenNumberedPills = (Read-Session).hide_pills }

Press @(0x12, 0x32) 'Alt+2: return to the home workspace'
Wait-Until { (Read-Session).active_workspace -eq 0 -and -not (Read-Session).starred_view } 'home keyboard shortcut still works'
Press @(0x12, 0x33) 'Alt+3: return to the created workspace'
Wait-Until { (Read-Session).active_workspace -eq $created -and -not (Read-Session).starred_view } 'created workspace keyboard shortcut still works'
Snapshot 'workspace-shortcut-return'
$result.checks += @{ name = 'workspace-number-shortcuts'; home = 0; created = $created }

foreach ($theme in @('dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system')) {
    $query = if ($theme -eq 'edgegray') { 'edge grey' } else { $theme }
    Select-Theme $query ("workspace-$theme-theme") $theme
    Snapshot ("workspace-$theme-header")
    $card = Open-WorkspaceCard ("workspace-$theme-card")
    $look = [VerifyNative]::MenuLook($card)
    $expected = if ($theme -eq 'light') { 'F9F9F9' } elseif ($theme -eq 'system') { $null } elseif ($theme -eq 'multiprompt') { '0F1011' } else { '262626' }
    if ($null -ne $expected -and $look.fill -cne $expected) { throw "Workspace card unreadable fill in ${theme}: $($look.fill)" }
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $expectedHeight = 19 + (@($registry.windows | Where-Object { -not ($_.PSObject.Properties['archived'] -and $_.archived) }).Count + 2) * 28
    if ($look.height -ne $expectedHeight) { throw "Workspace card must hug compact rows: $($look.height), expected $expectedHeight" }
    Save-Json $look ("workspace-$theme-card-look.json")
    Press @(0x1B) 'Escape closes workspace card without switching'
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero } 'workspace card dismissed'
    if ((Read-Session).active_workspace -ne $created) { throw 'Dismissing card changed workspace' }
    $result.checks += @{ name = 'workspace-card-theme'; theme = $theme; fill = $look.fill; screenshot = "workspace-$theme-card.png" }
}

$card = Open-WorkspaceCard 'workspace-keyboard-open'
$currentRow = Get-WorkspaceCardRow $created
$targetRow = Get-WorkspaceCardRow 0
Record 'Arrow Up and Down preserve selection, then arrows select first workspace'
[VerifyNative]::Chord(@(0x26))
[VerifyNative]::Chord(@(0x28))
$arrow = if ($targetRow -lt $currentRow) { 0x26 } else { 0x28 }
for ($index = 0; $index -lt [Math]::Abs($targetRow - $currentRow); $index++) { [VerifyNative]::Chord(@($arrow)) }
Snapshot 'workspace-keyboard-selected'
[VerifyNative]::Chord(@(0x0D))
Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq 0 -and -not (Read-Session).starred_view } 'Enter activates arrow-selected workspace'
$result.checks += @{ name = 'workspace-card-arrow-enter'; workspace = 0 }
Select-WorkspaceCard $created 'workspace-keyboard-return'
$result.checks += @{ name = 'workspace-card-theme-unavailable'; theme = 'Graphite 2'; reason = 'Not a shipped theme; Edge Grey is separate' }

$card = Open-WorkspaceCard 'workspace-new-open'
$newRow = Get-VisibleWorkspaceCardRows + 1
$count = (Read-Session).workspace_count
Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'main window foreground before workspace card new row click'
Record 'Click New workspace in workspace card'
[VerifyNative]::ClickOwnedChildClient($card, $script:window, 50, (6 + $newRow * 28 + 7 + 14))
Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).workspace_count -eq $count + 1 } 'card created one workspace and closed'
$result.checks += @{ name = 'workspace-card-create'; workspacesBefore = $count; workspacesAfter = (Read-Session).workspace_count }

function Rename-DeleteFixture([string]$Name) {
    Invoke-JourneyCommand 'Rename workspace' -Confirm {
        Press @(0x0D) 'Enter: rename the current synthetic workspace'
    }
    Wait-Until { [VerifyNative]::Class([VerifyNative]::GetFocusedWindow($script:window)) -eq 'Edit' } 'workspace rename input focused'
    Press @(0x11, 0x41) 'Ctrl+A: select the whole workspace rename text'
    Type-Text $Name
    Wait-Until { [VerifyNative]::EditText([VerifyNative]::GetFocusedWindow($script:window)) -ceq $Name } 'complete synthetic workspace name visible before commit'
    Press @(0x0D) 'Enter: save synthetic workspace name'
    Wait-Until { $saved = Read-Session; $saved.workspaces[$saved.active_workspace].name -ceq $Name } 'workspace rename saved'
}

function Begin-WorkspaceDelete([string]$Name) {
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $rows = @($registry.windows)
    $target = -1
    for ($index = 0; $index -lt $rows.Count; $index++) {
        if ($rows[$index].name -ceq $Name) { $target = 6400 + $index }
    }
    if ($target -lt 6400) { throw 'Synthetic delete target missing from registry' }
    Invoke-JourneyCommand 'Delete workspace' -Confirm {
        Press @(0x0D) 'Enter: open Delete workspace'
    }
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $start = ((Get-Content $log -Raw) -join '').Length
    Type-Text $Name
    Wait-Until {
        ((Get-Content $log -Raw) -join '').Substring($start) -match ('\[palette\] ready chars=' + $Name.Length + ' count=2 target=' + $target + '(?:\r?\n|$)')
    } 'one matching workspace selected after Back'
}

function Delete-WorkspaceFixture([string]$Name, [bool]$Mouse) {
    $saved = Read-Session
    $slot = $saved.active_workspace
    $identity = $saved.workspaces[$slot].wid
    $ownedTabs = @($saved.tabs | Where-Object { (Get-SavedTabWorkspace $_) -eq $slot })
    if ($ownedTabs.Count -lt 1) { throw 'Delete fixture must contain a real session' }
    $ownedPids = @($ownedTabs | ForEach-Object { if ($_.PSObject.Properties['pid']) { [int]$_.pid } })
    if ($ownedPids.Count -lt 1 -or @($ownedPids | Where-Object { $_ -le 0 -or $null -eq (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -ne 0) { throw 'Delete fixture sessions must be running' }
    Begin-WorkspaceDelete $Name
    Snapshot ('workspace-delete-' + $Name.Replace(' ', '-').ToLower() + '-before')
    if ($Mouse) {
        if ([VerifyNative]::GetDpiForWindow($script:window) -ne 96) { throw 'Mouse delete fixture requires 100% scale' }
        $rect = New-Object VerifyNative+Rect
        if (-not [VerifyNative]::GetClientRect($script:window, [ref]$rect)) { throw 'Delete palette client rectangle unavailable' }
        $top = [Math]::Max(8, [Math]::Min(120, $rect.Bottom - (72 + 2 * 39 + 44) - 8))
        $confirmLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
        $confirmStart = ((Get-Content $confirmLog -Raw) -join '').Length
        Record 'Mouse: select the sole matching workspace delete row'
        [VerifyNative]::ClickClient($script:window, [int]($rect.Right / 2), ($top + 72 + 39 + 19))
        Wait-Until { ((Get-Content $confirmLog -Raw) -join '').Substring($confirmStart) -match '\[palette\] confirm target=64\d\d' } 'delete confirmation armed by mouse'
        Snapshot 'workspace-delete-mouse-confirm'
        Record 'Mouse: confirm deletion on the same workspace row'
        [VerifyNative]::ClickClient($script:window, [int]($rect.Right / 2), ($top + 72 + 39 + 19))
    } else {
        Press @(0x0D) 'Enter: arm workspace deletion'
        Snapshot 'workspace-delete-keyboard-confirm'
        Press @(0x0D) 'Enter again: delete workspace and its sessions'
    }
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and $state.workspace_count -eq $saved.workspace_count - 1 -and @($state.workspaces | Where-Object { $_.wid -ceq $identity }).Count -eq 0
    } 'deleted workspace removed from saved slots'
    Wait-Until {
        $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
        @($registry.windows | Where-Object { $_.id -ceq $identity }).Count -eq 0 -and @($ownedPids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -eq 0
    } 'deleted registry identity gone and owned session processes closed'
    $paintedLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $paintedLine = @(Select-String -Path $paintedLog -Pattern '\[palette\] delete-visible ' | Select-Object -Last 1)
    if ($paintedLine.Count -lt 1) { throw 'Delete list did not record its painted rows' }
    $paintedText = [string]$paintedLine[0].Line
    $marker = 'delete-visible '
    $paintedNames = @(($paintedText.Substring($paintedText.LastIndexOf($marker) + $marker.Length).Trim()) -split '\|' | ForEach-Object { $_.Trim() })
    if ($paintedNames -contains $Name) { throw "Deleted workspace is still painted in the delete list: $Name" }
    $removedPath = Join-Path $scratch 'roaming/ZigShell/removed-workspaces.json'
    Wait-Until {
        if (-not (Test-Path $removedPath)) { return $false }
        $recorded = @((Get-Content $removedPath -Raw | ConvertFrom-Json).names)
        $recorded -contains $Name
    } 'deleted workspace name recorded so a stored layout cannot recreate it'
    Snapshot ('workspace-delete-' + $Name.Replace(' ', '-').ToLower() + '-after')
    Save-Json (Read-Session) ('workspace-delete-' + $Name.Replace(' ', '-').ToLower() + '.session.json')
    Press @(0x1B) 'Escape: close delete list'
    $result.checks += @{ name = 'workspace-delete'; workspace = $Name; identity = $identity; mouse = $Mouse; closedPids = $ownedPids; removalRecorded = $true }
}

Rename-DeleteFixture 'Workspace 9'
Delete-WorkspaceFixture 'Workspace 9' $true
Select-WorkspaceCard $created 'workspace-delete-select-ceo'
Rename-DeleteFixture 'CEO Runners'
Delete-WorkspaceFixture 'CEO Runners' $false

$registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$base = @($registry.windows | Where-Object { $_.id -ceq 'default' })
if ($base.Count -ne 1) { throw 'Main identity must remain after deleting both synthetic workspaces' }
Begin-WorkspaceDelete $base[0].name
Press @(0x0D) 'Enter: arm Main deletion refusal'
Press @(0x0D) 'Enter again: show Main cannot be deleted'
Wait-Until { [VerifyNative]::Class([VerifyNative]::GetForegroundWindow()) -eq 'MultiPromptDialog' } 'persistent refusal dialog foreground'
Snapshot 'workspace-delete-main-refused'
$refusalDeadline = [DateTime]::UtcNow.AddSeconds(6)
Wait-Until { [DateTime]::UtcNow -ge $refusalDeadline } 'wait beyond the old transient notice lifetime' 10
if ([VerifyNative]::Class([VerifyNative]::GetForegroundWindow()) -ne 'MultiPromptDialog') { throw 'Refusal disappeared without dismissal' }
Snapshot 'workspace-delete-main-still-visible'
Record 'Enter dismisses the persistent refusal'
[VerifyNative]::Chord(@(0x0D))
Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'refusal explicitly dismissed'
Press @(0x1B) 'Escape: close delete list after Main refusal'
$deleteLog = Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw
if (@([regex]::Matches($deleteLog, 'workspace-delete attempt')).Count -lt 3 -or @([regex]::Matches($deleteLog, 'workspace-delete result=deleted')).Count -lt 2 -or $deleteLog -notmatch 'workspace-delete result=refused reason=Main cannot be deleted') { throw 'Every deletion and Main refusal must be logged' }
$result.checks += @{ name = 'workspace-delete-main-protected'; persistentSeconds = 6; dismissedByKeyboard = $true }
Snapshot 'workspace-delete-complete'
Snapshot 'after'

Select-WorkspaceCard $created 'archive-before'
$archiveBefore = Read-Session
$archiveId = [string]$archiveBefore.workspaces[$created].wid
$archiveRegistry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$archiveName = [string](@($archiveRegistry.windows | Where-Object { $_.id -ceq $archiveId })[0].name)
$archiveTabs = @($archiveBefore.tabs | Where-Object { (Get-SavedTabWorkspace $_) -eq $created })
if ($archiveId.Length -eq 0 -or $archiveName.Length -eq 0 -or $archiveTabs.Count -eq 0) { throw 'Archive fixture needs a named workspace and a real session' }
$archiveCount = $archiveBefore.workspace_count
Invoke-JourneyCommand 'Archive workspace' -Confirm {
    Press @(0x0D) 'Enter: choose workspace to archive'
}
$archivePickStart = (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Length
Type-Text $archiveName
Wait-Until { (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Substring($archivePickStart) -match ('\[palette\] ready chars=' + $archiveName.Length + ' count=2 target=65[0-9]+(?:\r?\n|$)') } 'one archive workspace matches by name'
Snapshot 'archive-selected'
Press @(0x0D) 'Enter: archive selected workspace'
Wait-Until {
    $saved = Read-Session
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $entry = @($registry.windows | Where-Object { $_.id -ceq $archiveId })
    $saved.workspace_count -eq $archiveCount - 1 -and @($saved.workspaces | Where-Object { $_.wid -ceq $archiveId }).Count -eq 0 -and $entry.Count -eq 1 -and $entry[0].archived -eq $true
} 'archived workspace removed from saved strip and marked in registry'
$snapshotPath = Join-Path $scratch ("roaming/ZigShell/session-$archiveId.json")
$savedArchive = Get-Content $snapshotPath -Raw | ConvertFrom-Json
if (@($savedArchive.tabs).Count -ne $archiveTabs.Count) { throw 'Archive lost saved sessions' }
Save-Json $savedArchive 'archive-snapshot.json'
Wait-Until { @((Read-Inbox).shells | Where-Object { $_.sid -in @($archiveTabs.shell_id) }).Count -eq 0 } 'archived sessions absent from published Inbox'
Snapshot 'archive-hidden'
$card = Open-WorkspaceCard 'archive-card-hidden'
$look = [VerifyNative]::MenuLook($card)
$registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
if ($look.height -ne (19 + (@($registry.windows | Where-Object { -not ($_.PSObject.Properties['archived'] -and $_.archived) }).Count + 2) * 28)) { throw 'Archived workspace still occupies a card row' }
Press @(0x1B) 'Escape: close workspace card'
Invoke-JourneyCommand 'Open workspace' -Confirm {
    Press @(0x0D) 'Enter: open workspace list'
}
$archiveLogStart = (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Length
Type-Text $archiveName
Wait-Until {
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $windows = @($registry.windows)
    $index = -1
    for ($i = 0; $i -lt $windows.Count; $i++) {
        if ($windows[$i].id -ceq $archiveId) { $index = $i }
    }
    if ($index -lt 0 -or -not ($windows[$index].PSObject.Properties['archived'] -and $windows[$index].archived)) { return $false }
    $trace = (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Substring($archiveLogStart)
    $ids = Get-PaletteRowIds $trace $archiveName.Length
    if ($null -eq $ids) { return $false }
    $banned = [string](6500 + $index)
    return -not ((@($ids -split ' +')) -contains $banned)
} 'archived workspace absent from normal Ctrl+K open list'
Snapshot 'archive-open-list-hidden'
Press @(0x1B) 'Escape: leave workspace list'
Press @(0x1B) 'Escape: close palette'
Invoke-JourneyCommand 'Archived workspaces' -Confirm {
    Press @(0x0D) 'Enter: list archived workspaces'
}
$archivePickStart = (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Length
Type-Text $archiveName
Wait-Until { (Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')).Substring($archivePickStart) -match ('\[palette\] ready chars=' + $archiveName.Length + ' count=2 target=65[0-9]+(?:\r?\n|$)') } 'archived workspace available to restore'
Snapshot 'archive-restore-selected'
Press @(0x0D) 'Enter: restore archived workspace'
Wait-Until {
    $saved = Read-Session
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $entry = @($registry.windows | Where-Object { $_.id -ceq $archiveId })
    $saved.workspace_count -eq $archiveCount -and $saved.workspaces[$saved.active_workspace].wid -ceq $archiveId -and $entry.Count -eq 1 -and -not ($entry[0].PSObject.Properties['archived'] -and $entry[0].archived)
} 'restored workspace active with original identity'
$restored = Read-Session
$restoredTabs = @($restored.tabs | Where-Object { (Get-SavedTabWorkspace $_) -eq $restored.active_workspace })
if ($restoredTabs.Count -ne $archiveTabs.Count) { throw 'Restore changed the session count' }
for ($i = 0; $i -lt $archiveTabs.Count; $i++) {
    if ($restoredTabs[$i].name -cne $archiveTabs[$i].name -or $restoredTabs[$i].kind -cne $archiveTabs[$i].kind) { throw 'Restore changed saved session names or kinds' }
}
Save-Json $restored 'archive-restored.session.json'
$result.checks += @{ name = 'workspace-archive-restore'; id = $archiveId; workspace = $archiveName; sessions = $restoredTabs.Count; hiddenFromStrip = $true; hiddenFromCard = $true; hiddenFromOpenPalette = $true; hiddenFromInbox = $true; serverBoundary = 'local CMD only; remote preservation covered by hibernate path tests' }
Snapshot 'archive-restored'

$deletedNames = @('Workspace 9', 'CEO Runners')
Restart-SessionRestore 'workspace-delete-relaunch' $false
Wait-Until {
    $state = Read-Session
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $null -ne $state -and @($state.workspaces | Where-Object { $_.name -in $deletedNames }).Count -eq 0 -and
        @($registry.windows | Where-Object { $_.name -in $deletedNames }).Count -eq 0 -and
        @($state.workspaces | Where-Object { $_.wid -ceq $archiveId }).Count -eq 1
} 'deleted workspaces stay gone after a relaunch and keep the restored workspace'
Save-Json (Read-Session) 'workspace-delete-relaunch.session.json'
$relaunchCard = Open-WorkspaceCard 'workspace-delete-relaunch-card'
$relaunchLook = [VerifyNative]::MenuLook($relaunchCard)
$relaunchRegistry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$relaunchRows = @($relaunchRegistry.windows | Where-Object { -not ($_.PSObject.Properties['archived'] -and $_.archived) })
if ($relaunchLook.height -ne (19 + ($relaunchRows.Count + 2) * 28)) { throw 'Relaunched workspace card does not match the stored workspaces' }
Snapshot 'workspace-delete-relaunch-card'
Press @(0x1B) 'Escape closes the relaunched workspace card'
Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero } 'relaunched workspace card dismissed'
$result.checks += @{ name = 'workspace-delete-relaunch'; deleted = $deletedNames; restoredWorkspaceKept = $archiveId }
Snapshot 'workspace-delete-relaunch-complete'
