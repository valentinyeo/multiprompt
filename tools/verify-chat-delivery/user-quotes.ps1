foreach ($fixture in @('user-quote-message', 'pasted-quote-message')) {
    $source = (Resolve-Path "$PSScriptRoot/../fixtures/MUBO-237/$fixture.txt").Path
    $offset = (Read-Shared "$settings/debug.log").Length
    Shell-Run @('user-quote', $source)
    [void](Wait-For 'MUBO-237 fixture reaches the native transcript' {
        (Read-Shared "$settings/debug.log").Substring($offset) -match '\[chat\] transcript load shell=\d+ ok'
    })
    Bind-Transcript
    Press @(0x11, 0x4B) 'Ctrl+K: select the quote transcript'
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready for the quote transcript' {
        (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+')
    })
    Press @(0x0D) 'Enter: select the quote transcript'
    Press @(0x11, 0x43) 'Ctrl+C: read the displayed quote transcript'
    $copied = [Windows.Forms.Clipboard]::GetText()
    if (-not $copied.Contains('The fix itself is small.') -or -not $copied.Contains('very urgent bug fix emergency or not?') -and $fixture -eq 'pasted-quote-message') {
        throw 'MUBO-237 quote fixture did not reach the displayed transcript'
    }
    [IO.File]::WriteAllText("$caseDir/$fixture-copied.txt", $copied)
    Press @(0x1B) 'Esc: clear quote transcript selection'
    $view = [IntPtr]$views[0].Current.NativeWindowHandle
    $actions.Add(@{case=$plan.name; input='wheel to newest user quote'; fixture=$fixture})
    [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $view, -12000)
    Doctor
    Shot "MUBO-237-$fixture"
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
