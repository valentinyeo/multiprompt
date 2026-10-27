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
    if ($rect.Bottom -lt (44 + ($windows.Count + 2) * 36)) { throw 'Fixture requires all workspace rows visible' }
    Record ('Click named workspace row ' + $state.workspaces[$Workspace].name)
    [VerifyNative]::ClickClient($card, 50, (36 + $target * 36 + 18))
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq $Workspace -and -not (Read-Session).starred_view } 'card closed and chosen workspace saved'
    Snapshot $Shot
    Save-Json (Read-Session) ($Shot + '.session.json')
}

$before = (Read-Session).workspace_count
Snapshot 'action'
Press @(0x11, 0x4E) 'Ctrl+N: create workspace'
Wait-Until { (Read-Session).workspace_count -eq $before + 1 } 'workspace and CMD tab persisted'
$created = (Read-Session).active_workspace
Snapshot 'created'
Select-WorkspaceCard 0 'workspace-first'
Select-WorkspaceCard $created 'workspace-created'
$result.checks += @{ name = 'workspace-card-mouse-switch'; first = 0; created = $created; hiddenNumberedPills = (Read-Session).hide_pills }

foreach ($theme in @('dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system')) {
    $query = if ($theme -eq 'edgegray') { 'edge grey' } else { $theme }
    Select-Theme $query ("workspace-$theme-theme") $theme
    Snapshot ("workspace-$theme-header")
    $card = Open-WorkspaceCard ("workspace-$theme-card")
    $look = [VerifyNative]::MenuLook($card)
    $expected = if ($theme -eq 'light') { 'FAFAFB' } elseif ($theme -eq 'system') { $null } else { '181818' }
    if ($null -ne $expected -and $look.fill -cne $expected) { throw "Workspace card unreadable fill in ${theme}: $($look.fill)" }
    Save-Json $look ("workspace-$theme-card-look.json")
    Record 'Escape closes workspace card without switching'
    [VerifyNative]::Chord(@(0x1B))
    Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero } 'workspace card dismissed'
    if ((Read-Session).active_workspace -ne $created) { throw 'Dismissing card changed workspace' }
    $result.checks += @{ name = 'workspace-card-theme'; theme = $theme; fill = $look.fill; screenshot = "workspace-$theme-card.png" }
}

$card = Open-WorkspaceCard 'workspace-new-open'
$registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
$newRow = @($registry.windows).Count + 1
$count = (Read-Session).workspace_count
Record 'Click New workspace in workspace card'
[VerifyNative]::ClickClient($card, 50, (36 + $newRow * 36 + 18))
Wait-Until { (Get-WorkspaceCard) -eq [IntPtr]::Zero -and (Read-Session).workspace_count -eq $count + 1 } 'card created one workspace and closed'
$result.checks += @{ name = 'workspace-card-create'; workspacesBefore = $count; workspacesAfter = (Read-Session).workspace_count }
Snapshot 'after'
