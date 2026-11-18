$hashDll = Join-Path $scratch 'workspace-registry-hash.dll'
& zig build-lib -dynamic -O ReleaseFast -target x86_64-windows-gnu (Join-Path $PSScriptRoot '../../../tools/verify-workspace-menu/hash.zig') "-femit-bin=$hashDll"
if ($LASTEXITCODE -ne 0) { throw 'Workspace registry hash fixture failed to compile' }
$native = (Get-Content (Join-Path $PSScriptRoot '../../../tools/verify-workspace-menu/native.cs') -Raw).Replace('__HASH_DLL__', $hashDll.Replace('\', '\\'))
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition $native

function Get-MenuRows {
    $registry = Get-Content (Join-Path $scratch 'roaming/ZigShell/windows.json') -Raw | ConvertFrom-Json
    return @($registry.windows | Where-Object { -not ($_.PSObject.Properties['archived'] -and $_.archived) })
}

function Find-MenuRow([string]$Identity) {
    $rows = @(Get-MenuRows)
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].id -ceq $Identity) { return $i + 1 }
    }
    throw 'Workspace identity missing from the menu registry'
}

function Open-MeasuredMenu([int]$CurrentRow, [string]$Name) {
    Doctor
    Activate-OwnedFrame
    $state = Read-Session
    if ([VerifyNative]::GetDpiForWindow($script:window) -ne 96 -or ($state.PSObject.Properties['ui_scale'] -and $state.ui_scale -ne 100)) { throw 'Menu pixel proof requires 100% scale' }
    $top = if ($state.hide_pills) { 0 } else { 34 }
    Record ('Click workspace menu ' + $Name)
    $clock = [Diagnostics.Stopwatch]::StartNew()
    [VerifyNative]::ClickClient($script:window, 80, ($top + 26))
    $card = [WorkspaceMenuProof]::WaitPaint($script:window, [uint32]$process.Id, $CurrentRow, [int][Math]::Max(1, (200 - $clock.ElapsedMilliseconds)))
    $elapsed = $clock.Elapsed.TotalMilliseconds
    if ($elapsed -gt 200) { throw "Menu first paint exceeded 200 ms: $elapsed" }
    $script:menuMeasurements += @{ name = $Name; firstPaintMs = $elapsed; currentRow = $CurrentRow }
    Snapshot $Name
    return $card
}

function AssertHighlight([IntPtr]$Card, [int]$Selected, [int]$Unselected, [string]$Name) {
    Wait-Until { [WorkspaceMenuProof]::Highlighted($Card, $Selected) -and -not [WorkspaceMenuProof]::Highlighted($Card, $Unselected) } $Name 2 1 -Tight
    Snapshot $Name
    $result.checks += @{ name = $Name; selectedRow = $Selected; unselectedRow = $Unselected; screenshot = "$Name.png" }
}

Select-Theme 'dark' 'workspace-menu-dark' 'dark'
$initial = Read-Session
if ($initial.workspace_count -ne 1 -or @($initial.tabs).Count -ne 1) { throw 'Menu proof requires one initial CMD workspace' }
Press @(0x11, 0x4E) 'Ctrl+N: create a second workspace with its own CMD session'
Wait-Until { $state = Read-Session; $state.workspace_count -eq 2 -and @($state.tabs).Count -eq 2 -and $state.active_workspace -eq 1 } 'two real in-process workspaces saved'
$created = Read-Session
$identities = @($created.workspaces | ForEach-Object { $_.wid })
$currentRow = Find-MenuRow $identities[1]
$targetRow = Find-MenuRow $identities[0]
$script:menuMeasurements = @()
$registryPath = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'ZigShell\windows.json'))
$lastWrite = [IO.File]::GetLastWriteTimeUtc($registryPath)

$card = Open-MeasuredMenu $currentRow 'menu-uncontended'
[VerifyNative]::Chord(@(0x1B))
Wait-Until { [WorkspaceMenuProof]::Card($script:window) -eq [IntPtr]::Zero } 'uncontended menu dismissed'
$holder = [WorkspaceMenuProof]::HoldRegistry($registryPath)
try {
    Save-Json @{ mutex = $holder.MutexName; boundary = 'A separate thread owns the actual production registry mutex; no workspace data or settings are injected.' } 'registry-contention.json'
    foreach ($attempt in 1..5) {
        $card = Open-MeasuredMenu $currentRow ("menu-contended-$attempt")
        $responses = [WorkspaceMenuProof]::AssertResponsive($script:window, $card)
        Save-Json $responses ("menu-responses-$attempt.json")
        Record 'Move the real mouse onto the other workspace row'
        [VerifyNative]::MoveClient($card, 50, (6 + $targetRow * 28 + 14))
        AssertHighlight $card $targetRow $currentRow ("menu-hover-$attempt")
        [VerifyNative]::Chord(@(0x28))
        AssertHighlight $card ($targetRow + 1) $targetRow ("menu-arrow-down-$attempt")
        [VerifyNative]::Chord(@(0x26))
        AssertHighlight $card $targetRow ($targetRow + 1) ("menu-arrow-up-$attempt")
        [VerifyNative]::Chord(@(0x1B))
        Wait-Until { [WorkspaceMenuProof]::Card($script:window) -eq [IntPtr]::Zero } 'Escape dismisses the contended menu'
    }
} finally { $holder.Dispose() }

$reader = [IO.File]::Open($registryPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
try {
    $card = Open-MeasuredMenu $currentRow 'menu-file-busy'
    $responses = [WorkspaceMenuProof]::AssertResponsive($script:window, $card)
    Save-Json $responses 'menu-file-busy-responses.json'
    [VerifyNative]::Chord(@(0x1B))
    Wait-Until { [WorkspaceMenuProof]::Card($script:window) -eq [IntPtr]::Zero } 'busy-file menu dismissed'
} finally { $reader.Dispose() }
if ([IO.File]::GetLastWriteTimeUtc($registryPath) -ne $lastWrite) { throw 'Opening unchanged workspace menus rewrote the registry' }
Save-Json $script:menuMeasurements 'menu-latency.json'
$result.checks += @{ name = 'workspace-menu-first-paint'; samples = $script:menuMeasurements; limitMs = 200; responsiveWhileRegistryHeld = $true; unchangedRegistryWriteTime = $true }

$card = Open-MeasuredMenu $currentRow 'menu-switch-open'
Record 'Click the other workspace using real mouse input'
[VerifyNative]::ClickClient($card, 50, (6 + $targetRow * 28 + 14))
Wait-Until { [WorkspaceMenuProof]::Card($script:window) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq 0 } 'menu closed and clicked workspace saved'
$card = Open-MeasuredMenu $targetRow 'menu-return-open'
[VerifyNative]::MoveClient($card, 50, (6 + $currentRow * 28 + 14))
AssertHighlight $card $currentRow $targetRow 'menu-return-hover'
[VerifyNative]::Chord(@(0x0D))
Wait-Until { [WorkspaceMenuProof]::Card($script:window) -eq [IntPtr]::Zero -and (Read-Session).active_workspace -eq 1 } 'Enter activates the hovered workspace'
$after = Read-Session
if ((@($after.workspaces | ForEach-Object { $_.wid }) -join ',') -cne ($identities -join ',') -or @($after.tabs).Count -ne 2) { throw 'Opening or switching the menu lost an in-process workspace or session' }
Save-Json $after 'menu-preserved.session.json'
$result.checks += @{ name = 'workspace-menu-preserves-workspaces'; identities = $identities; sessions = @($after.tabs).Count; mouseSwitch = $true; hoverEnterReturn = $true }
$log = Read-SharedText (Join-Path $scratch 'roaming/ZigShell/debug.log')
$openTimes = @([regex]::Matches($log, 'workspace-menu open ready elapsed_ms=(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
if ($openTimes.Count -eq 0 -or @($openTimes | Where-Object { $_ -gt 200 }).Count -ne 0) { throw 'Menu-open log shows no measured opens or a gap over 200 ms' }
Save-Json $openTimes 'menu-log-open-ms.json'
$result.checks += @{ name = 'workspace-menu-log-budget'; elapsedMs = $openTimes; limitMs = 200 }
Snapshot 'action'
Snapshot 'after'
