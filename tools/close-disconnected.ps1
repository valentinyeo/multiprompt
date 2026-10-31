param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output, [switch]$Negative, [ValidateSet('palette', 'sidebar')][string]$Entry = 'palette')
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$fixtureRoot = Join-Path $env:RUNNER_TEMP "close-disconnected-$PID"
$settings = "$fixtureRoot/roaming/ZigShell"
$job = $null
$result = @{passed=$false; error=$null; cleanup='pending'; profileRemoved=$false; negative=[bool]$Negative; entry=$Entry; expectedCounts=@{initial=3; beforeBulk=2; afterBulk=0}; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 30) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Description"
}
function Session { try { Get-Content -LiteralPath "$settings/session.json" -Raw | ConvertFrom-Json } catch { $null } }
function Log { try { [IO.File]::ReadAllText("$settings/debug.log") } catch { '' } }
function Log-Tail([int]$Offset) { $log = Log; if ($Offset -gt $log.Length) { return '' }; $log.Substring($Offset) }
function Focus {
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
}
function Press([int[]]$Keys) { Focus; [ChatDeliveryDesktop]::Chord($Keys) }
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Output/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Palette([string]$Query, [int]$Target) {
    $offset = (Log).Length
    Press @(0x11, 0x4B)
    [void](Wait-For 'palette opened' { (Log-Tail $offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($char in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Character($char) }
    [void](Wait-For "palette target $Target" { (Log-Tail $offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=[1-9]\d* target=' + $Target + '(?:\r?\n|$)') })
}
function Select-Session([string]$Name, [int]$Index) {
    Palette $Name $Index
    Press @(0x0D)
    [void](Wait-For "select $Name" { $s = Session; $s -and $s.tabs[$s.active_tab].name -ceq $Name })
}
function Context-Action([string]$Screenshot, [bool]$Execute) {
    $found = $false
    for ($y = 70; $y -le 430 -and !$found; $y += 12) {
        Focus
        $offset = (Log).Length
        [ChatDeliveryDesktop]::RightClickClient($main, $app.Id, 50, $y)
        Start-Sleep -Milliseconds 300
        if ((Log-Tail $offset) -notmatch '\[palette\] ready chars=0 count=\d+ target=\d+') { continue }
        foreach ($char in 'close all disconnected sessions'.ToCharArray()) { [ChatDeliveryDesktop]::Character($char) }
        Start-Sleep -Milliseconds 500
        $found = (Log-Tail $offset) -match '\[palette\] ready chars=31 count=[1-9]\d* target=7185(?:\r?\n|$)'
        if ($found) { Shot $Screenshot }
        if ($found -and $Execute) {
            $confirmOffset = (Log).Length
            Press @(0x0D)
            [void](Wait-For 'context action confirmed' { (Log-Tail $confirmOffset) -match '\[confirm\] sel=\d+ count=\d+ target=7185 ' })
        } else {
            Press @(0x1B)
        }
    }
    if (!$found) { throw 'Sidebar disconnected action not found' }
}
try {
    New-Item -ItemType Directory -Force $settings, "$fixtureRoot/local", "$fixtureRoot/home" | Out-Null
    $env:APPDATA = "$fixtureRoot/roaming"; $env:LOCALAPPDATA = "$fixtureRoot/local"; $env:USERPROFILE = "$fixtureRoot/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'; $env:IGSH_246 = '0'; $env:ZIGSHELL_DEBUG = '1'
    $names = @('Dead Single', 'Dead Pinned', 'Dead Unpinned', 'Live Pinned', 'Live Recent')
    $tabs = for ($i = 0; $i -lt 5; $i++) { @{kind='cmd'; name=$names[$i]; manual=$true; cv=$false; pid=0; workspace=0; pinned_top=($i -lt 4)} }
    Save @{active_tab=0; single_window=$false; chat_active=$false; tabs=@($tabs)} "$settings/session.json"
    Save (Session) "$Output/seed.json"
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $fixtureRoot, "$Output/stdout.log", "$Output/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned application' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } } 90
    [void](Wait-For 'five started sessions' { $s = Session; $s -and @($s.tabs).Count -eq 5 -and @($s.tabs | Where-Object { $_.pid -gt 0 -and $_.shell_id -gt 0 }).Count -eq 5 } 90)
    $state = Session
    Save $state "$Output/started.json"
    if (@($state.tabs | ForEach-Object { $_.shell_id } | Sort-Object -Unique).Count -ne 5) { throw 'Fixture IDs are not unique' }
    $deadIds = @($state.tabs | Where-Object { $_.name -in $names[0..2] } | ForEach-Object { $_.shell_id } | Sort-Object)
    $live = @($state.tabs | Where-Object { $_.name -in $names[3..4] })
    if ($deadIds.Count -ne 3 -or $live.Count -ne 2) { throw 'Invalid original fixtures' }
    $killCount = if ($Negative) { 1 } else { 3 }
    for ($i = 0; $i -lt $killCount; $i++) {
        $tab = @($state.tabs | Where-Object { $_.name -ceq $names[$i] })
        if ($tab.Count -ne 1 -or !$tab[0].pinned_top) { throw "Invalid pinned fixture $i" }
        $proc = Get-Process -Id $tab[0].pid
        $native = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)"
        if (!$job.Contains($proc) -or $native.ParentProcessId -ne $app.Id -or $proc.ProcessName -ine 'cmd') { throw "Fixture process ownership mismatch $i" }
        Stop-Process -Id $proc.Id -Force
        $id = $tab[0].shell_id
        [void](Wait-For "pinned exit $id" { (Log) -match ("WM_APP_SHELL_EXITED id=$id kind=cmd reason=preserve") })
        [void](Wait-For "preserved $($names[$i])" { $s = Session; $row = @($s.tabs | Where-Object { $_.name -ceq $names[$i] }); $row.Count -eq 1 -and !$row[0].pid -and $row[0].pinned_top })
    }
    Shot 'disconnected'
    if (-not $Negative) {
        Context-Action 'sidebar-count-three' $false
        Select-Session 'Dead Unpinned' 2
        Palette 'unpin from top' 6293
        Press @(0x0D)
        [void](Wait-For 'dead session unpinned' { $s = Session; $row = @($s.tabs | Where-Object { $_.name -ceq 'Dead Unpinned' }); $row.Count -eq 1 -and !$row[0].pinned_top -and !$row[0].pid })
    }
    Select-Session 'Dead Single' 0
    Save (Session) "$Output/before-single.json"
    Shot 'before-single-close'
    Press @(0x11, 0x57)
    [void](Wait-For 'pinned ordinary close' { $s = Session; $s -and @($s.tabs | Where-Object { $_.name -ceq 'Dead Single' }).Count -eq 0 } 12)
    Save (Session) "$Output/after-single.json"
    Shot 'after-single-close'
    if (-not $Negative) {
        $beforeBulk = Session
        Save $beforeBulk "$Output/before-bulk.json"
        $singleId = @($state.tabs | Where-Object { $_.name -ceq 'Dead Single' })[0].shell_id
        $beforeIds = @($beforeBulk.tabs | ForEach-Object { $_.shell_id } | Sort-Object)
        $expectedBefore = @($state.tabs | Where-Object { $_.shell_id -ne $singleId } | ForEach-Object { $_.shell_id } | Sort-Object)
        if ($beforeIds.Count -ne 4 -or ($beforeIds -join ',') -cne ($expectedBefore -join ',')) { throw 'Single close removed unexpected IDs' }
        if ($Entry -eq 'palette') {
            Palette 'close all disconnected sessions' 6386
            Start-Sleep -Milliseconds 500
            Shot 'palette-count-two'
            Press @(0x0D)
        } else {
            Context-Action 'sidebar-count-two' $true
        }
        [void](Wait-For 'bulk leaves two sessions' { $s = Session; $s -and @($s.tabs).Count -eq 2 })
        $final = Session
        Save $final "$Output/after-bulk.json"
        $finalIds = @($final.tabs | ForEach-Object { $_.shell_id } | Sort-Object)
        $liveIds = @($live | ForEach-Object { $_.shell_id } | Sort-Object)
        $removedIds = @($state.tabs | Where-Object { $_.shell_id -notin $finalIds } | ForEach-Object { $_.shell_id } | Sort-Object)
        if (($beforeIds.Count - $finalIds.Count) -ne 2 -or ($finalIds -join ',') -cne ($liveIds -join ',') -or ($removedIds -join ',') -cne ($deadIds -join ',')) { throw 'Unexpected bulk survivors or removed IDs' }
        foreach ($original in $live) {
            $row = @($final.tabs | Where-Object { $_.shell_id -eq $original.shell_id })
            if ($row.Count -ne 1 -or $row[0].pid -ne $original.pid -or $row[0].pinned_top -ne $original.pinned_top) { throw 'Live fixture identity or pin changed' }
            $proc = Get-Process -Id $original.pid
            if (!$job.Contains($proc) -or $proc.HasExited) { throw 'Live session process missing' }
        }
        Shot 'after-bulk'
        if ($Entry -eq 'palette') {
            Palette 'close all disconnected sessions' 6386
            Start-Sleep -Milliseconds 500
            Shot 'palette-count-zero'
            Press @(0x1B)
        } else {
            Context-Action 'sidebar-count-zero' $false
        }
    }
    $result.passed = $true
} catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    try { Shot 'failure' } catch { Write-Host $_ }
} finally {
    if ($job) { try { $result.cleanup = $job.Stop().ActiveProcesses } finally { $job.Dispose() } }
    foreach ($name in @('session.json', 'debug.log', 'inbox-default.json')) { if (Test-Path "$settings/$name") { Copy-Item "$settings/$name" "$Output/$name" } }
    if (Test-Path $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    $result.profileRemoved = !(Test-Path $fixtureRoot)
    Save $result "$Output/result.json"
}
if (!$result.passed -or $result.cleanup -ne 0 -or !$result.profileRemoved) { throw 'Close disconnected journey failed; see result.json' }
