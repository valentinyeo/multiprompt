$fixtures = @(
    @{ name = 'user-quote-message'; marker = 'very  urgent bug fix emergenyc or not?' },
    @{ name = 'pasted-quote-message'; marker = 'very urgent bug fix emergency or not?' }
)
foreach ($entry in $fixtures) {
    $fixture = $entry.name
    $marker = $entry.marker
    $source = (Resolve-Path "$PSScriptRoot/../fixtures/MUBO-237/$fixture.txt").Path
    $offset = (Read-Shared "$settings/debug.log").Length
    Shell-Run @('user-quote', $source)
    [void](Wait-For "MUBO-237 $fixture transcript load" {
        (Read-Shared "$settings/debug.log").Substring($offset) -match '\[chat\] transcript load shell=\d+ ok'
    })
    Bind-Transcript
    $script:quoteCopied = ''
    [void](Wait-For "MUBO-237 $fixture reaches the displayed transcript" {
        $paletteOffset = (Read-Shared "$settings/debug.log").Length
        Press @(0x11, 0x4B) 'Ctrl+K: select the quote transcript'
        [void](Wait-For 'quote palette ready' {
            (Read-Shared "$settings/debug.log").Substring($paletteOffset) -match '\[palette\] ready chars=0 count=\d+ target=\d+'
        })
        $query = 'chat view select all'
        foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
        [void](Wait-For 'select-all command ready for the quote transcript' {
            (Read-Shared "$settings/debug.log").Substring($paletteOffset) -match ('\[palette\] ready chars=' + $query.Length + ' count=[1-9]\d* target=\d+')
        })
        Press @(0x0D) 'Enter: select the quote transcript'
        [Windows.Forms.Clipboard]::Clear()
        Press @(0x11, 0x43) 'Ctrl+C: read the displayed quote transcript'
        $script:quoteCopied = [Windows.Forms.Clipboard]::GetText()
        Press @(0x1B) 'Esc: clear quote transcript selection'
        $script:quoteCopied.Contains('The fix itself is small.') -and $script:quoteCopied.Contains($marker)
    } 30)
    [IO.File]::WriteAllText("$caseDir/$fixture-copied.txt", $script:quoteCopied)
    $view = [IntPtr]$views[0].Current.NativeWindowHandle
    $actions.Add(@{case=$plan.name; input='wheel to newest user quote'; fixture=$fixture})
    [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $view, -12000)
    Start-Sleep -Milliseconds 300
    Doctor
    Shot "MUBO-237-$fixture"
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
