[void](Wait-For 'initial history loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$hostDir = "$profile/home/.local/state/multiprompt/agent-host"
$hostLog = Wait-For 'production host log' { $f = @(Get-ChildItem "$hostDir/*.events.log" -ErrorAction SilentlyContinue); if ($f.Count -eq 1 -and (Read-Shared $f[0].FullName) -match 'model_effort_settings_applied') { $f[0].FullName } } 60
$configPath = @(Get-ChildItem "$hostDir/*.config.json")[0].FullName
function Model-Palette([string]$Query, [string]$Screenshot) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) "Ctrl+K: $Query"
    [void](Wait-For 'palette opened' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $actions.Add(@{case=$plan.name; input='type palette query'; text=$Query})
    foreach ($letter in $Query.ToCharArray()) { Doctor; [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For "palette $Query" { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=1 target=\d+') })
    Shot $Screenshot
    Press @(0x0D) "Enter: $Query"
}
function Plus-Rows([string]$Screenshot, [string]$Page = 'models') {
    $offset = (Read-Shared "$settings/debug.log").Length
    Model-Palette 'plus attach file' "palette-$Screenshot"
    [void](Wait-For 'plus menu open' { [ChatDeliveryDesktop]::PlusMenu($main) -ne [IntPtr]::Zero } 10)
    $rootLog = Wait-For 'four plus menu rows logged' {
        $fresh = (Read-Shared "$settings/debug.log").Substring($offset)
        if ($fresh -match '\[chat\] plus menu permissions rect=') { $fresh }
    } 10
    $rootRects = @{}
    foreach ($found in [regex]::Matches($rootLog, '\[chat\] plus menu (\w+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
        $rootRects[$found.Groups[1].Value] = @([int]$found.Groups[2].Value, [int]$found.Groups[3].Value, [int]$found.Groups[4].Value, [int]$found.Groups[5].Value)
    }
    if ((($rootRects.Keys | Sort-Object) -join ',') -cne 'ai,efforts,models,permissions') { throw 'Plus menu must have exactly AI, Model, Effort and Permission level' }
    Shot "$Screenshot-root"
    $rect = $rootRects[$Page]
    $menu = [ChatDeliveryDesktop]::PlusMenu($main)
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing plus menu page input: owned app is not foreground' }
    $offset = (Read-Shared "$settings/debug.log").Length
    $actions.Add(@{case=$plan.name; input='open plus menu page'; text=$Page})
    [ChatDeliveryDesktop]::PressClient($menu, $app.Id, [int](($rect[0] + $rect[2]) / 2), [int](($rect[1] + $rect[3]) / 2))
    $first = @{models='model_fable'; efforts='effort_high'; permissions='mode_bypass'}[$Page]
    $logged = Wait-For 'plus menu choices logged' {
        $fresh = (Read-Shared "$settings/debug.log").Substring($offset)
        if ($fresh -match ('\[chat\] plus menu ' + $first + ' rect=')) { $fresh }
    } 10
    $rects = @{}
    foreach ($found in [regex]::Matches($logged, '\[chat\] plus menu (\w+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
        $rects[$found.Groups[1].Value] = @([int]$found.Groups[2].Value, [int]$found.Groups[3].Value, [int]$found.Groups[4].Value, [int]$found.Groups[5].Value)
    }
    [void](Wait-For 'plus choices visible' { [ChatDeliveryDesktop]::PlusMenu($main) -ne [IntPtr]::Zero } 10)
    Shot $Screenshot
    return $rects
}
function Plus-Cell([hashtable]$Rects, [string]$Item) {
    if (-not $Rects.ContainsKey($Item)) { throw "Plus menu did not show $Item" }
    $rect = $Rects[$Item]
    if ($rect[3] -le $rect[1]) { throw "Plus menu row $Item has no height" }
    return @{left=$rect[0]; top=$rect[1]; right=$rect[2]; bottom=$rect[3]}
}
function Plus-Click([string]$Item, [string]$Screenshot) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $page = if ($Item.StartsWith('model_')) { 'models' } elseif ($Item.StartsWith('effort_')) { 'efforts' } else { 'permissions' }
        $rects = Plus-Rows $Screenshot $page
        $cell = Plus-Cell $rects $Item
        $menu = [ChatDeliveryDesktop]::PlusMenu($main)
        if ($menu -eq [IntPtr]::Zero) { throw 'Plus menu window disappeared before the click' }
        $x = [int](($cell.left + $cell.right) / 2)
        $y = [int](($cell.top + $cell.bottom) / 2)
        Doctor
        if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer) }
        if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing plus menu input: owned app is not foreground' }
        $actions.Add(@{case=$plan.name; input='choose plus menu row'; text=$Item; attempt=$attempt; x=$x; y=$y})
        [ChatDeliveryDesktop]::PressClient($menu, $app.Id, $x, $y)
        $closed = $true
        try { [void](Wait-For "plus menu closed after $Item" { [ChatDeliveryDesktop]::PlusMenu($main) -eq [IntPtr]::Zero } 5) } catch { $closed = $false }
        if ($closed) { return }
        if ($attempt -eq 3) { throw "Plus menu stayed open after clicking $Item" }
        Press @(0x1B) "Escape: back to plus menu after $Item"
        Press @(0x1B) "Escape: close plus menu after $Item"
        [void](Wait-For "plus menu closed after escape $Item" { [ChatDeliveryDesktop]::PlusMenu($main) -eq [IntPtr]::Zero } 5)
    }
}
function Model-Copy([string]$Stage) {
    [void](Wait-For 'model app is foreground for the copy' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer) } 10)
    [Windows.Forms.Clipboard]::Clear()
    $copied = Wait-For "history selected and copied at $Stage" {
        [ChatSwitchObserver]::CopyTranscript($app.Id, $main)
        try {
            $text = [Windows.Forms.Clipboard]::GetText()
            if ($text.Contains('The fake session is ready.')) { $text }
        } catch [Runtime.InteropServices.ExternalException] { $null }
    } 15
    [IO.File]::WriteAllText("$caseDir/$Stage-history.txt", $copied)
    if (-not $copied.Contains('start the fake session')) { throw "History missing at $Stage" }
    Press @(0x1B) 'Escape: clear history selection'
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
Model-Copy 'before'
Type-Composer $plan.text
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Draft setup failed' }
Shot 'model-before'
$choices = @(
    @{item='model_haiku'; model='haiku'; effort='default'; name='haiku'},
    @{item='effort_low'; model='haiku'; effort='low'; name='low'},
    @{item='effort_medium'; model='haiku'; effort='medium'; name='medium'},
    @{item='effort_high'; model='haiku'; effort='high'; name='high'}
)
foreach ($choice in $choices) {
    $oldLog = (Read-Shared $hostLog).Length
    $oldArgs = (Read-Shared "$state/model-argv.jsonl").Length
    $wantModel = $choice.model
    $wantEffort = $choice.effort
    $tries = 0
    $retry = $true
    while ($retry) {
        $tries++
        $retry = $false
        Plus-Click $choice.item "model-plus-$($choice.name)"
        try {
            [void](Wait-For "host config shows $($choice.name)" {
                $config = Read-Shared $configPath | ConvertFrom-Json
                $effort = ''
                if ($config.PSObject.Properties['effort']) { $effort = [string]$config.effort }
                $config.model -ceq $wantModel -and ($wantEffort -eq 'default' -or $effort -ceq $wantEffort)
            } 20)
        } catch {
            if ($tries -ge 2) { throw }
            $retry = $true
        }
    }
    [void](Wait-For "production host applied $($choice.name)" {
        $config = Read-Shared $configPath | ConvertFrom-Json
        $lines = @((Read-Shared $hostLog).Substring($oldLog) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        $args = @((Read-Shared "$state/model-argv.jsonl").Substring($oldArgs) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        $applied = @($lines | Where-Object { $_.event -eq 'model_effort_settings_applied' -and $_.detail.model -eq $choice.model -and $_.detail.effort -eq $choice.effort })
        $invoked = @($args | Where-Object { $a = @($_.argv); $m = [array]::IndexOf($a, '--model'); $e = [array]::IndexOf($a, '--effort'); $m -ge 0 -and $a[$m + 1] -ceq $choice.model -and (($choice.effort -eq 'default' -and $e -lt 0) -or ($e -ge 0 -and $a[$e + 1] -ceq $choice.effort)) })
        $modelProperty = $config.PSObject.Properties['model']
        $effortProperty = $config.PSObject.Properties['effort']
        $modelProperty -and $modelProperty.Value -ceq $choice.model -and ($choice.effort -eq 'default' -or ($effortProperty -and $effortProperty.Value -ceq $choice.effort)) -and $applied.Count -gt 0 -and $invoked.Count -gt 0
    } 60)
    if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw "Draft changed after $($choice.name)" }
    Copy-Item $configPath "$caseDir/config-$($choice.name).json"
    Copy-Item $hostLog "$caseDir/host-$($choice.name).jsonl"
    Copy-Item "$state/model-argv.jsonl" "$caseDir/argv-$($choice.name).jsonl"
    Shot "model-after-$($choice.name)"
}
$plusRows = [Collections.Generic.List[object]]::new()
$plusActive = @('model_haiku', 'effort_high')
$config = Read-Shared $configPath | ConvertFrom-Json
$mode = if ($config.PSObject.Properties['permission_mode']) { [string]$config.permission_mode } else { 'manual' }
$plusActive += @{manual='mode_ask'; default='mode_ask'; auto='mode_auto'; bypassPermissions='mode_bypass'}[$mode]
foreach ($page in @('models', 'efforts', 'permissions')) {
    $plusRects = Plus-Rows "model-plus-menu-active-$page" $page
    if ($page -eq 'models') { Shot 'model-plus-menu-active' }
    $plusMenu = [ChatDeliveryDesktop]::PlusMenu($main)
    $plusBox = New-Object ChatDeliveryDesktop+Rect
    [void][ChatDeliveryDesktop]::GetWindowRect($plusMenu, [ref]$plusBox)
    $plusWidth = $plusBox.Right - $plusBox.Left
    $plusHeight = $plusBox.Bottom - $plusBox.Top
    $plusShot = [Drawing.Bitmap]::new($plusWidth, $plusHeight)
    $plusGraphics = [Drawing.Graphics]::FromImage($plusShot)
    try { $plusGraphics.CopyFromScreen($plusBox.Left, $plusBox.Top, 0, 0, $plusShot.Size) } finally { $plusGraphics.Dispose() }
    foreach ($item in $plusRects.Keys) {
        $rect = $plusRects[$item]
        $left = $rect[0]; $right = $rect[2]; $top = $rect[1]; $bottom = $rect[3]
        $background = $plusShot.GetPixel([Math]::Min($right - 6, $plusWidth - 1), [Math]::Min([int](($top + $bottom) / 2), $plusHeight - 1))
        $accent = 0
        $mark = 0
        for ($y = $top + 3; $y -lt $bottom - 3; $y++) {
            if ($y -ge $plusHeight) { break }
            for ($x = $left + 10; $x -lt $right - 10; $x++) {
                if ($x -ge $plusWidth) { break }
                $pixel = $plusShot.GetPixel($x, $y)
                if ($pixel.B -ge 150 -and ($pixel.B - $pixel.R) -ge 70) { $accent++ }
                if ($x -ge $right - 40 -and $x -lt $right - 14 -and ([Math]::Abs($pixel.R - $background.R) + [Math]::Abs($pixel.G - $background.G) + [Math]::Abs($pixel.B - $background.B)) -gt 90) { $mark++ }
            }
        }
        $plusRows.Add(@{item=$item; accent=$accent; mark=$mark})
    }
    $plusShot.Dispose()
    Press @(0x1B) 'Escape: back to plus menu'
    Press @(0x1B) 'Escape: close plus menu'
}
$plusFailures = [Collections.Generic.List[string]]::new()
foreach ($row in $plusRows) {
    if ($plusActive -contains $row.item -and $row.accent -lt 10) { $plusFailures.Add("$($row.item) is not drawn in the active style") }
    if ($row.mark -gt 0) { $plusFailures.Add("$($row.item) shows a check mark") }
}
foreach ($name in $plusActive) { if (-not (@($plusRows | Where-Object { $_.item -eq $name }).Count)) { $plusFailures.Add("$name row is not in the menu") } }
Save @{rows=$plusRows.ToArray(); expected_active=$plusActive; failures=$plusFailures.ToArray(); window=@{width=$plusWidth; height=$plusHeight}} "$caseDir/plus-active.json"
if ($plusFailures.Count) { throw ('Plus menu active rows: ' + ($plusFailures -join '; ')) }
Model-Copy 'after'
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Draft changed after history copy' }
$observation.draft = [ChatDeliveryDesktop]::Text($composer)
Shot 'model-after'
