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
function Model-Copy([string]$Stage) {
    Model-Palette 'chat view select all' "model-$Stage-copy-palette"
    Press @(0x11, 0x43) 'Ctrl+C: copy history'
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$caseDir/$Stage-history.txt", $copied)
    if (-not $copied.Contains('start the fake session') -or -not $copied.Contains('The fake session is ready.')) { throw "History missing at $Stage" }
    Press @(0x1B) 'Escape: clear history selection'
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
Model-Copy 'before'
Type-Composer $plan.text
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Draft setup failed' }
Shot 'model-before'
$choices = @(
    @{query='model haiku'; model='haiku'; effort='default'; name='haiku'},
    @{query='effort low'; model='haiku'; effort='low'; name='low'},
    @{query='effort medium'; model='haiku'; effort='medium'; name='medium'},
    @{query='effort high'; model='haiku'; effort='high'; name='high'}
)
foreach ($choice in $choices) {
    $oldLog = (Read-Shared $hostLog).Length
    $oldArgs = (Read-Shared "$state/model-argv.jsonl").Length
    if ($choice.name -eq 'haiku') {
        $plusOffset = (Read-Shared "$settings/debug.log").Length
        Model-Palette 'chat view plus menu' 'model-palette-haiku'
        [void](Wait-For 'plus menu opened' { (Read-Shared "$settings/debug.log").Substring($plusOffset) -match '\[chat\] plus menu model_opus rect=' })
        Shot 'model-plus-menu'
        foreach ($step in 1..4) { Press @(0x28) "Down: plus menu row $step" }
        Press @(0x0D) 'Enter: plus menu Haiku'
    } else {
        Model-Palette $choice.query "model-palette-$($choice.name)"
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
Model-Copy 'after'
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Draft changed after history copy' }
$observation.draft = [ChatDeliveryDesktop]::Text($composer)
Shot 'model-after'
