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
Snapshot 'after'
