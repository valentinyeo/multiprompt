param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$profile = Join-Path $env:RUNNER_TEMP "shared-sidebar-$PID"
$settings = "$profile/roaming/ZigShell"
$job = $null
$result = @{passed=$false; error=$null; cleanup='pending'; comparisons=@(); actions=@()}
function Wait-For([string]$Name, [scriptblock]$Check) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt 30)
    throw "Timed out: $Name"
}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Flag($Value, [string]$Name) { $property = $Value.PSObject.Properties[$Name]; $null -ne $property -and $property.Value -eq $true }
function Chat-On { $s = Session; Flag $s.tabs[$s.active_tab] 'cv' }
function Session { Get-Content "$settings/session.json" -Raw | ConvertFrom-Json }
function Focus { [void](Wait-For 'owned main foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }) }
function Capture([string]$Name) {
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    $bitmap = [Drawing.Bitmap]::new(299, 320)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $bitmap.Save("$Output/$Name.png")
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    (Get-FileHash "$Output/$Name.png" -Algorithm SHA256).Hash
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Output/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Compare-Views([string]$Name) {
    Focus
    $selected = (Session).active_tab
    $before = Capture "$Name-shell-sidebar"
    Shot "$Name-shell"
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
    [void](Wait-For 'Chat View visible' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero -and (Chat-On) })
    Focus
    Shot "$Name-chat"
    $hash = Wait-For 'sidebar unchanged across shell and chat' { $h = Capture "$Name-chat-sidebar"; if ($h -eq $before) { $h } }
    if ((Session).active_tab -ne $selected) { throw 'View toggle changed selection' }
    $result.comparisons += @{name=$Name; shell=$before; chat=$hash; selected=$selected}
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
    [void](Wait-For 'shell view restored' { -not (Chat-On) })
    Focus
    [void](Wait-For 'return sidebar unchanged' { (Capture "$Name-return-sidebar") -eq $before })
}
try {
    New-Item -ItemType Directory -Force $settings, "$profile/local", "$profile/home" | Out-Null
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'; $env:IGSH_246 = '0'; $env:ZIGSHELL_DEBUG = '1'
    $tabs = @('First shell', 'Second shell', 'Third shell') | ForEach-Object { @{kind='cmd'; name=$_; manual=$true; cv=$false; pid=0} }
    Save @{active_tab=0; single_window=$false; chat_active=$false; amoled_theme=$true; tabs=@($tabs)} "$settings/session.json"
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Output/stdout.log", "$Output/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'three restored sessions' { (Session).tabs.Count -eq 3 })
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    [void](Wait-For 'console previews published' {
        if (-not (Test-Path "$settings/inbox-default.json")) { return $false }
        $inbox = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json
        @($inbox.shells | Where-Object { $_.pv }).Count -eq 3
    })
    Compare-Views 'expanded'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 120, 171)
    [void](Wait-For 'sidebar click selects second session' { (Session).active_tab -eq 1 })
    $result.actions += 'sidebar-select'
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    Compare-Views 'selected'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, 64)
    [void](Wait-For 'Recents collapsed' { (Flag (Session) 'recents_section_collapsed') })
    $result.actions += 'section-collapse'
    Focus
    [Windows.Forms.Cursor]::Position = [Drawing.Point]::new(900, 500)
    Compare-Views 'section-collapsed'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 100, 64)
    [void](Wait-For 'Recents reopened' { -not (Flag (Session) 'recents_section_collapsed') })
    $result.actions += 'section-expand'
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, 285, 229)
    [void](Wait-For 'sidebar close removes third session' { (Session).tabs.Count -eq 2 })
    if (@((Session).tabs | Where-Object { $_.name -eq 'Third shell' }).Count -ne 0) { throw 'Wrong session closed' }
    $result.actions += 'sidebar-close'
    $result.passed = $true
} catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() }
    foreach ($name in @('session.json', 'debug.log', 'inbox-default.json')) { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } }
    Save $result "$Output/result.json"
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
}
if (-not $result.passed -or $result.cleanup -ne 0) { throw 'Shared sidebar journey failed; see result.json' }
Write-Host 'SHARED_SIDEBAR_JOURNEY_OK'
