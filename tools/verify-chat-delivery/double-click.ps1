$view = [IntPtr]$views[0].Current.NativeWindowHandle
foreach ($stage in @('double-click-added', 'double-click-removed')) {
    Doctor
    $offset = if ($stage -eq 'double-click-added') { 0 } else { 40 }
    $x = [int]($point.x + $offset - $bounds.Left)
    $y = [int]($point.y - $bounds.Top)
    $actions.Add(@{case=$plan.name; input=$stage; screenX=$point.x + $offset; screenY=$point.y; clicks=2})
    [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, $view, $x, $y)
    [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, $view, $x, $y)
    [void](Wait-For $stage {
        Shot ('reactions-' + $stage)
        $ErrorActionPreference = 'Continue'
        & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame $stage 2> "$caseDir/oracle-$stage-stderr.log"
        $LASTEXITCODE -eq 0
    })
    [void](Wait-For 'one queued thumbs up and no removal submission' { @((Fake-State).queue).Count -eq 1 })
    $observation[$stage] = @{queueCount=@((Fake-State).queue).Count; composerText=[ChatDeliveryDesktop]::Text($composer)}
    if ($observation[$stage].composerText -cne $plan.text) { throw 'Double-click changed the composer draft' }
}
Shell-Run @('idle')
[void](Wait-For 'one attachment consumed after removing the badge' {
    $events = @(Get-Content -LiteralPath $transcript | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
    @($events | Where-Object { $_.type -eq 'attachment' }).Count -eq 1
})
[void](Wait-For 'removed badge stays hidden after delivery' {
    Shot 'reactions-double-click-delivered'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame double-click-delivered 2> "$caseDir/oracle-double-click-delivered-stderr.log"
    $LASTEXITCODE -eq 0
})
[void](Wait-For 'delivered reaction restores the untouched remote draft' { (Fake-State).box -ceq $plan.text })
$observation.doubleClickDelivered = $true
