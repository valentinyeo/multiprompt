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
function Plus-Rows([string]$Screenshot) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Model-Palette 'plus attach file' "palette-$Screenshot"
    [void](Wait-For 'plus menu open' { [ChatDeliveryDesktop]::PlusMenu($main) -ne [IntPtr]::Zero } 10)
    $logged = Wait-For 'plus menu rows logged' {
        $t = (Read-Shared "$settings/debug.log")
        if ($t.Length -gt $offset) {
            $fresh = $t.Substring($offset)
            if ($fresh -match '\[chat\] plus menu model_opus rect=-?\d+,-?\d+,-?\d+,-?\d+') { $fresh }
        }
    } 10
    $rects = @{}
    foreach ($found in [regex]::Matches($logged, '\[chat\] plus menu (\w+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
        $rects[$found.Groups[1].Value] = @([int]$found.Groups[2].Value, [int]$found.Groups[3].Value, [int]$found.Groups[4].Value, [int]$found.Groups[5].Value)
    }
    Shot $Screenshot
    return $rects
}
function Plus-Cell([hashtable]$Rects, [string]$Item) {
    $anchors = @{
        model_opus = @{first='model_opus'; index=0}; model_sonnet = @{first='model_opus'; index=1};
        model_haiku = @{first='model_opus'; index=2}; model_fable = @{first='model_opus'; index=3};
        effort_low = @{first='effort_low'; index=0}; effort_medium = @{first='effort_low'; index=1}; effort_high = @{first='effort_low'; index=2};
        mode_ask = @{first='mode_ask'; index=0}; mode_edits = @{first='mode_ask'; index=1}; mode_plan = @{first='mode_ask'; index=2}; mode_bypass = @{first='mode_ask'; index=3}
    }
    if (-not $anchors.ContainsKey($Item)) { throw "Unknown plus menu row $Item" }
    $spec = $anchors[$Item]
    if (-not $Rects.ContainsKey($spec.first)) { throw "Plus menu did not show $($spec.first), so $Item cannot be chosen" }
    $rect = $Rects[$spec.first]
    $height = $rect[3] - $rect[1]
    if ($height -le 0) { throw "Plus menu row $($spec.first) has no height" }
    $top = $rect[1] + ($spec.index * $height)
    return @{left=$rect[0]; top=$top; right=$rect[2]; bottom=$top + $height}
}
function Plus-Click([string]$Item, [string]$Screenshot) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $rects = Plus-Rows $Screenshot
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
$plusOffset = (Read-Shared "$settings/debug.log").Length
Model-Palette 'plus attach file' 'model-palette-active'
$plusLog = Wait-For 'plus menu opened for active rows' { $t = (Read-Shared "$settings/debug.log").Substring($plusOffset); if ($t -match '\[chat\] plus menu model_opus rect=') { $t } }
$plusRects = @{}
foreach ($found in [regex]::Matches($plusLog, '\[chat\] plus menu (\w+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
    $plusRects[$found.Groups[1].Value] = @([int]$found.Groups[2].Value, [int]$found.Groups[3].Value, [int]$found.Groups[4].Value, [int]$found.Groups[5].Value)
}
$plusMenu = Wait-For 'plus menu window' { $h = [ChatDeliveryDesktop]::PlusMenu($main); if ($h -ne [IntPtr]::Zero) { $h } } 10
$plusBox = New-Object ChatDeliveryDesktop+Rect
[void][ChatDeliveryDesktop]::GetWindowRect($plusMenu, [ref]$plusBox)
Start-Sleep -Milliseconds 600
Shot 'model-plus-menu-active'
$plusWidth = $plusBox.Right - $plusBox.Left
$plusHeight = $plusBox.Bottom - $plusBox.Top
$plusShot = [Drawing.Bitmap]::new($plusWidth, $plusHeight)
$plusGraphics = [Drawing.Graphics]::FromImage($plusShot)
try { $plusGraphics.CopyFromScreen($plusBox.Left, $plusBox.Top, 0, 0, $plusShot.Size) } finally { $plusGraphics.Dispose() }
$plusRows = [Collections.Generic.List[object]]::new()
$plusGroups = @(
    @{first='model_opus'; names=@('model_opus', 'model_sonnet', 'model_haiku', 'model_fable')},
    @{first='effort_low'; names=@('effort_low', 'effort_medium', 'effort_high')},
    @{first='mode_ask'; names=@('mode_ask', 'mode_edits', 'mode_plan', 'mode_bypass')}
)
foreach ($group in $plusGroups) {
    if (-not $plusRects.ContainsKey($group.first)) { continue }
    $rect = $plusRects[$group.first]
    $rowHeight = $rect[3] - $rect[1]
    for ($i = 0; $i -lt $group.names.Count; $i++) {
        $left = $rect[0]; $right = $rect[2]; $top = $rect[1] + $i * $rowHeight; $bottom = $top + $rowHeight
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
        $plusRows.Add(@{item=$group.names[$i]; accent=$accent; mark=$mark})
    }
}
$plusShot.Dispose()
$plusActive = @('model_haiku', 'effort_high')
if ($plusRects.ContainsKey('mode_ask')) { $plusActive += 'mode_ask' }
$plusFailures = [Collections.Generic.List[string]]::new()
foreach ($row in $plusRows) {
    if ($plusActive -contains $row.item -and $row.accent -lt 10) { $plusFailures.Add("$($row.item) is not drawn in the active style") }
    if ($row.mark -gt 0) { $plusFailures.Add("$($row.item) shows a check mark") }
}
foreach ($name in $plusActive) { if (-not (@($plusRows | Where-Object { $_.item -eq $name }).Count)) { $plusFailures.Add("$name row is not in the menu") } }
Save @{rows=$plusRows.ToArray(); expected_active=$plusActive; failures=$plusFailures.ToArray(); window=@{width=$plusWidth; height=$plusHeight}} "$caseDir/plus-active.json"
Press @(0x1B) 'Escape: close plus menu'
if ($plusFailures.Count) { throw ('Plus menu active rows: ' + ($plusFailures -join '; ')) }
Model-Copy 'after'
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Draft changed after history copy' }
$observation.draft = [ChatDeliveryDesktop]::Text($composer)
Shot 'model-after'
