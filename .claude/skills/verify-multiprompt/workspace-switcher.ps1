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

function Select-WorkspaceCard([int]$Workspace, [string]$Shot) {
    $card = Open-WorkspaceCard ($Shot + '-open')
    $state = Read-Session
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    $windows = @($registry.windows)
    $target = -1
    for ($index = 0; $index -lt $windows.Count; $index++) {
        if ($windows[$index].id -ceq $state.workspaces[$Workspace].wid) { $target = $index + 1 }
    }
    if ($target -lt 1) { throw 'Target workspace missing from the card registry' }
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($card, [ref]$rect)) { throw 'Card rectangle unavailable' }
    if ($rect.Bottom -lt (19 + ($windows.Count + 2) * 28)) { throw 'Fixture requires all workspace rows visible' }
    Record ('Click named workspace row ' + $state.workspaces[$Workspace].name)
    [VerifyNative]::ClickClient($card, 50, (6 + $target * 28 + 14))
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq $Workspace -and -not (Read-Session).starred_view } 'card closed and chosen workspace saved'
    Snapshot $Shot
    Save-Json (Read-Session) ($Shot + '.session.json')
}

if ((Read-Session).workspace_count -ne 1) { throw 'Identity round-trip requires one initial workspace' }
Focus-Palette 'single window' 6207
Press @(0x0D) 'Enter: leave single-window mode with one workspace'
Wait-Until { $state = Read-Session; $null -ne $state -and -not ($state.PSObject.Properties['single_window'] -and $state.single_window) } 'standalone mode saved'
Focus-Palette 'single window' 6207
Press @(0x0D) 'Enter: return to single-window mode'
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
    $expectedHeight = 19 + (@($registry.windows).Count + 2) * 28
    if ($look.height -ne $expectedHeight) { throw "Workspace card must hug compact rows: $($look.height), expected $expectedHeight" }
    Save-Json $look ("workspace-$theme-card-look.json")
    Record 'Escape closes workspace card without switching'
    [VerifyNative]::Chord(@(0x1B))
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero } 'workspace card dismissed'
    if ((Read-Session).active_workspace -ne $created) { throw 'Dismissing card changed workspace' }
    $result.checks += @{ name = 'workspace-card-theme'; theme = $theme; fill = $look.fill; screenshot = "workspace-$theme-card.png" }
}

$card = Open-WorkspaceCard 'workspace-keyboard-open'
$state = Read-Session
$registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$windows = @($registry.windows)
$currentRow = -1
$targetRow = -1
for ($index = 0; $index -lt $windows.Count; $index++) {
    if ($windows[$index].id -ceq $state.workspaces[$created].wid) { $currentRow = $index + 1 }
    if ($windows[$index].id -ceq $state.workspaces[0].wid) { $targetRow = $index + 1 }
}
if ($currentRow -lt 1 -or $targetRow -lt 1) { throw 'Keyboard fixture workspaces missing' }
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
$registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$newRow = @($registry.windows).Count + 1
$count = (Read-Session).workspace_count
Record 'Click New workspace in workspace card'
[VerifyNative]::ClickClient($card, 50, (6 + $newRow * 28 + 7 + 14))
Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).workspace_count -eq $count + 1 } 'card created one workspace and closed'
$result.checks += @{ name = 'workspace-card-create'; workspacesBefore = $count; workspacesAfter = (Read-Session).workspace_count }

function Rename-DeleteFixture([string]$Name) {
    Focus-Palette 'rename workspace' 7000
    Press @(0x0D) 'Enter: rename the current synthetic workspace'
    Wait-Until { [VerifyNative]::Class([VerifyNative]::GetFocusedWindow($script:window)) -eq 'Edit' } 'workspace rename input focused'
    Type-Text $Name
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
    Focus-Palette 'delete workspace' 6201
    Press @(0x0D) 'Enter: open Delete workspace'
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
    $ownedTabs = @($saved.tabs | Where-Object { $_.PSObject.Properties['workspace'] -and $_.workspace -eq $slot })
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
        Record 'Mouse: select the sole matching workspace delete row'
        [VerifyNative]::ClickClient($script:window, [int]($rect.Right / 2), ($top + 72 + 39 + 19))
        Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match '\[confirm\].*target=64\d\d' } 'delete confirmation armed by mouse'
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
    Snapshot ('workspace-delete-' + $Name.Replace(' ', '-').ToLower() + '-after')
    Save-Json (Read-Session) ('workspace-delete-' + $Name.Replace(' ', '-').ToLower() + '.session.json')
    Press @(0x1B) 'Escape: close delete list'
    $result.checks += @{ name = 'workspace-delete'; workspace = $Name; identity = $identity; mouse = $Mouse; closedPids = $ownedPids }
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
