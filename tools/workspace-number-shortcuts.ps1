param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output, [switch]$Standalone)
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
$profile = Join-Path $env:RUNNER_TEMP "workspace-numbers-$PID"
$settings = "$profile/roaming/ZigShell"
$job = $null
$video = $null
$result = @{passed=$false; error=$null; cleanup='pending'; actions=@(); sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 30) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Description"
}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Session {
    try { Get-Content -LiteralPath "$settings/session.json" -Raw | ConvertFrom-Json } catch { $null }
}
function Focus {
    [void](Wait-For 'owned app foreground' {
        $target = [ChatDeliveryDesktop]::Composer($main)
        if ($target -eq [IntPtr]::Zero) { $target = $main }
        [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $target)
    })
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Output/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Press([int[]]$Keys, [string]$Label) {
    Focus
    $result.actions += @{at=[DateTime]::UtcNow.ToString('o'); label=$Label; keys=$Keys}
    [ChatDeliveryDesktop]::Chord($Keys)
}
function Selected([string]$Name) {
    $state = Session
    $null -ne $state -and $state.tabs[$state.active_tab].name -ceq $Name
}
function Select-Number([int]$Number, [string]$Name, [string]$View) {
    Press @(0x11, (0x30 + $Number)) "$View Ctrl+$Number -> $Name"
    [void](Wait-For "$View Ctrl+$Number selects $Name" { Selected $Name })
    Shot "$View-ctrl-$Number"
    Save (Session) "$Output/$View-ctrl-$Number.json"
}
try {
    New-Item -ItemType Directory -Force $settings, "$profile/local", "$profile/home" | Out-Null
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'; $env:IGSH_246 = '0'; $env:ZIGSHELL_DEBUG = '1'
    $tabs = @(
        @{kind='cmd'; name='First recent'; manual=$true; cv=$false; pid=0; workspace=0; favorite=$true},
        @{kind='cmd'; name='Second recent'; manual=$true; cv=$false; pid=0; workspace=0; favorite=$true},
        @{kind='cmd'; name='Pinned first'; manual=$true; cv=$false; pid=0; workspace=0; favorite=$true; pinned_top=$true},
        @{kind='cmd'; name='Other first'; manual=$true; cv=$false; pid=0; workspace=1},
        @{kind='cmd'; name='Other second'; manual=$true; cv=$false; pid=0; workspace=1},
        @{kind='cmd'; name='Other pinned'; manual=$true; cv=$false; pid=0; workspace=1; pinned_top=$true}
    )
    if ($Standalone) { $tabs = @($tabs[0..2]) }
    Save @{active_tab=1; single_window=(-not $Standalone); active_workspace=0; workspace_count=2; workspaces=@(@{name='Other'; wid='numbers-home'}, @{name='Second'; wid='numbers-second'}); chat_active=$false; amoled_theme=$true; tabs=$tabs} "$settings/session.json"
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Output/stdout.log", "$Output/stderr.log", $(if ($Standalone) { '--no-window-restore' } else { '--single-window --no-window-restore' }))
    $main = Wait-For 'owned visible application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'published startup sessions' {
        try {
            $live = Get-Content -LiteralPath "$settings/inbox-default.json" -Raw | ConvertFrom-Json
            @($live.shells).Count -eq $(if ($Standalone) { 3 } else { 6 })
        } catch { $false }
    })
    Focus
    $start = [Diagnostics.ProcessStartInfo]::new('ffmpeg', "-y -f gdigrab -framerate 8 -i desktop -an -c:v libx264 -preset ultrafast -pix_fmt yuv420p `"$Output/shortcuts.mp4`"")
    $start.UseShellExecute = $false; $start.RedirectStandardInput = $true; $start.CreateNoWindow = $true
    $video = [Diagnostics.Process]::Start($start)
    Select-Number 1 'Pinned first' 'home'
    Select-Number 3 'Second recent' 'home'
    Press @(0x11, 0x39) 'home Ctrl+9 -> unchanged'
    $until = [DateTime]::UtcNow.AddMilliseconds(1000)
    [void](Wait-For 'missing position leaves selection unchanged' { if (-not (Selected 'Second recent')) { throw 'Missing position changed selection' }; [DateTime]::UtcNow -ge $until })
    Shot 'home-missing-position'
    if (-not $Standalone) {
    Press @(0x12, 0x33) 'Alt+3 -> second workspace'
    [void](Wait-For 'second workspace selected' { $s = Session; $null -ne $s -and $s.active_workspace -eq 1 })
    Select-Number 1 'Other pinned' 'second'
    Select-Number 3 'Other second' 'second'
    Press @(0x12, 0x31) 'Alt+1 -> Starred'
    [void](Wait-For 'Starred selected' { $s = Session; $null -ne $s -and $s.PSObject.Properties['starred_view'] -and $s.starred_view })
    Select-Number 1 'First recent' 'starred'
    Select-Number 3 'Pinned first' 'starred'
    Press @(0x11, 0x39) 'Starred Ctrl+9 -> unchanged'
    $until = [DateTime]::UtcNow.AddMilliseconds(1000)
    [void](Wait-For 'missing Starred position leaves selection unchanged' { if (-not (Selected 'Pinned first')) { throw 'Missing Starred position changed selection' }; [DateTime]::UtcNow -ge $until })
    Shot 'starred-missing-position'
    }
    $result.passed = $true
} catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    if ($null -ne $video) {
        $video.StandardInput.WriteLine('q'); $video.StandardInput.Close()
        if (-not $video.WaitForExit(15000)) { $video.Kill(); $video.WaitForExit(); $result.passed=$false; $result.error='Recording did not finish' }
        if ($video.ExitCode -ne 0 -or -not (Test-Path "$Output/shortcuts.mp4")) { $result.passed=$false; $result.error='Recording failed' }
        $video.Dispose()
    }
    if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() }
    foreach ($name in @('session.json', 'debug.log', 'inbox-default.json')) { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } }
    Save $result "$Output/result.json"
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
}
if (-not $result.passed -or $result.cleanup -ne 0) { throw 'Workspace number shortcut journey failed; see result.json' }
Write-Host 'WORKSPACE_NUMBER_JOURNEY_OK'
