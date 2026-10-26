[void][ChatDeliveryDesktop]::ShowWindow($main, 9)
[void][ChatDeliveryDesktop]::MoveWindow($main, 10, 10, 1000, 650, $true)
[void](Wait-For 'production reader applied the provider transcript' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
$root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
$condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
$views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
$windowBounds = $root.Current.BoundingRectangle
$bounds = $views[0].Current.BoundingRectangle
$area = @{left=[int]($bounds.Left-$windowBounds.Left); top=[int]($bounds.Top-$windowBounds.Top); right=[int]($bounds.Right-$windowBounds.Left); bottom=[int]($bounds.Bottom-$windowBounds.Top)}
Save $area "$Evidence/working-area.json"
$probe = {
    param($name, $mode)
    $image = [Drawing.Bitmap]::new([int]$windowBounds.Width, [int]$windowBounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($image)
    try {
        $graphics.CopyFromScreen([int]$windowBounds.Left, [int]$windowBounds.Top, 0, 0, $image.Size)
        $image.Save("$Evidence/$name.png", [Drawing.Imaging.ImageFormat]::Png)
        $image.Save("$Evidence/$name.bmp", [Drawing.Imaging.ImageFormat]::Bmp)
    } finally { $graphics.Dispose(); $image.Dispose() }
    & node "$PSScriptRoot/../chat-working-proof.mjs" "$Evidence/$name.bmp" "$Evidence/working-area.json" "$Evidence/$name.json" $mode "$Evidence/working-0.json"
    $LASTEXITCODE -eq 0
}
& $Exe --notify 'ACTIVE:Verify agent'
[void](Wait-For 'inline dots in the next agent reply slot' { & $probe 'working-0' 'busy' } 30)
Copy-Item "$Evidence/working-0.png" "$Evidence/action.png"
Copy-Item "$Evidence/working-0.png" "$Evidence/before.png"
$first = Get-Content "$Evidence/working-0.json" -Raw | ConvertFrom-Json
[void](Wait-For 'animated dots change frame' {
    if (-not (& $probe 'working-1' 'busy')) { return $false }
    $next = Get-Content "$Evidence/working-1.json" -Raw | ConvertFrom-Json
    ($first.dots | ConvertTo-Json -Compress) -cne ($next.dots | ConvertTo-Json -Compress)
} 30)
$second = Get-Content "$Evidence/working-1.json" -Raw | ConvertFrom-Json
$reply = @{type='assistant'; uuid='reply-924'; sessionId=$sid; timestamp=[DateTime]::UtcNow.ToString('o'); message=@{role='assistant'; id='message-924'; content=@(@{type='text'; text='Ready.'})}}
[IO.File]::AppendAllText($transcript, (($reply | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
Shell-Run @('idle')
& $Exe --notify 'DONE:Verify agent'
[void](Wait-For 'the real reader exposes the new reply through public Copy' {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: select all conversation text'
    [void](Wait-For 'public command palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'Select All command selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: select every rendered message'
    Press @(0x11, 0x43) 'Ctrl+C: copy actual rendered messages'
    $copied = [Windows.Forms.Clipboard]::GetText()
    Save @{text=$copied; replyVisible=($copied -match '\bReady\.')} "$Evidence/working-copy.json"
    Press @(0x1B) 'Esc: clear transcript selection'
    $copied -match '\bReady\.'
} 45)
[void](Wait-For 'reply replaces dots in the real message flow' { & $probe 'working-after' 'idle' } 30)
Copy-Item "$Evidence/working-after.json" "$Evidence/after.json"
Save @{name='inline-working-dots'; passed=$true; frames=@($first,$second)} "$Evidence/working-proof.json"
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

$referencePath = Join-Path $env:TEMP 'inline-working-reference.png'
Invoke-WebRequest 'https://screencast2.com/h9mN1.png' -OutFile $referencePath -UseBasicParsing
$reference = [Drawing.Bitmap]::FromFile($referencePath)
$working = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'working-0.png'))
$comparison = New-Object Drawing.Bitmap(($working.Width + 400), ($working.Height + 40))
$graphics = [Drawing.Graphics]::FromImage($comparison)
$font = New-Object Drawing.Font('Arial', 14)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(20, 20, 20))
    $graphics.DrawString('Multiprompt: working', $font, [Drawing.Brushes]::White, 10, 8)
    $graphics.DrawImage($working, 0, 40, $working.Width, $working.Height)
    $graphics.DrawString('Grok reference', $font, [Drawing.Brushes]::White, ($working.Width + 10), 8)
    $target = New-Object Drawing.Rectangle(($working.Width + 10), 60, 370, 61)
    $source = New-Object Drawing.Rectangle(447, 918, 303, 50)
    $graphics.DrawImage($reference, $target, $source, [Drawing.GraphicsUnit]::Pixel)
    $comparison.Save((Join-Path $Evidence 'working-comparison.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $font.Dispose()
    $graphics.Dispose()
    $comparison.Dispose()
    $working.Dispose()
    $reference.Dispose()
    Remove-Item $referencePath
}
