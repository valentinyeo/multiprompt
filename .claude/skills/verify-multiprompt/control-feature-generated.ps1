$rows = Get-Content (Join-Path $PSScriptRoot 'generated-journeys.json') -Raw | ConvertFrom-Json
$selectedRows = @($rows | Where-Object { $_.feature -ceq $Feature })
if ($selectedRows.Count -ne 1) { throw "Expected one generated row for $Feature" }
$row = $selectedRows[0]

if ($row.shape -eq 'theme-color') {
    $baseline = if ($row.saved -eq 'light') { 'dark' } else { 'light' }
    Select-Theme $baseline 'generated-baseline'
    Snapshot 'before'
    Select-Theme $row.query 'action' $row.saved
    Wait-Until {
        Snapshot 'after'
        $rgb = Sidebar-Dominant 'after'
        [Math]::Abs($rgb.r - $row.rgb) -le 4 -and [Math]::Abs($rgb.g - $row.rgb) -le 4 -and [Math]::Abs($rgb.b - $row.rgb) -le 4
    } ("generated " + $row.id + ': rendered sidebar color')
    $saved = (Get-Content (Join-Path $scratch 'roaming/ZigShell/theme-mode.txt') -Raw).Trim()
    if ($saved -cne $row.saved) { throw "Generated theme did not persist $($row.saved)" }
    $result.checks += @{ name = $row.id; shape = $row.shape; saved = $saved; rgb = (Sidebar-Dominant 'after'); expectedRgb = $row.rgb }
} elseif ($row.shape -in @('sidebar-cycle', 'sidebar-expand')) {
    function Assert-GeneratedSidebar([string]$Step, [bool]$Hidden, [bool]$Collapsed) {
        Wait-Until {
            $state = Read-Session
            $null -ne $state -and [bool]($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -eq $Hidden -and
                [bool]($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed) -eq $Collapsed
        } ("generated " + $row.id + ": $Step sidebar saved")
        Wait-WorkspaceSurface $sidebarWorkspace $sidebarTab $false
        $console = [VerifyNative]::GetForegroundWindow()
        $rect = New-Object VerifyNative+Rect
        if (-not [VerifyNative]::GetWindowRect($console, [ref]$rect) -or -not [VerifyNative]::IsWindowVisible($console)) { throw 'Generated sidebar has no visible console rectangle' }
        $state = Read-Session
        Snapshot $Step
        $result.checks += @{ name = $row.id; step = $Step; hidden = $Hidden; collapsed = $Collapsed; consoleHwnd = $console.ToInt64(); consoleRect = $rect; saved = $state }
        return $rect.Left
    }
    Invoke-JourneyCommand 'Sidebar: expand'
    $initial = Read-Session
    $sidebarWorkspace = [int]$initial.active_workspace
    $sidebarTab = [int]$initial.active_tab
    $open = Assert-GeneratedSidebar 'before' $false $false
    $chord = if ($row.shape -eq 'sidebar-cycle') { [int[]]$row.keys } else { @(0x11, 0x10, 0x42) }
    Press $chord 'Ctrl+Shift+B: collapse sidebar'
    $collapsed = Assert-GeneratedSidebar 'collapsed' $false $true
    if ($collapsed -ge $open) { throw 'Collapsed sidebar did not give the console more room' }
    Press $chord 'Ctrl+Shift+B: hide sidebar'
    $hidden = Assert-GeneratedSidebar 'hidden' $true $false
    if ($hidden -ge $collapsed) { throw 'Hidden sidebar did not give the console more room' }
    Snapshot 'action'
    if ($row.shape -eq 'sidebar-cycle') { Press $chord 'Ctrl+Shift+B: expand sidebar' }
    else { Invoke-JourneyCommand $row.command }
    $restored = Assert-GeneratedSidebar 'after' $false $false
    if ([Math]::Abs($restored - $open) -gt 1) { throw 'Expanded sidebar did not restore the console edge' }
} else {
    throw "No live assertion for generated shape $($row.shape)"
}
