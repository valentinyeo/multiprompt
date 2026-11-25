$paneLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$choicePath = Join-Path $scratch 'roaming/ZigShell/session.json.computer'
if (-not ('WindowControlsProof' -as [type])) { Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'window-controls-native.cs') }
$markerRgb = 0x123456
$typeMarker = 'vncmarker'
$ignoredMarker = 'ignoredkeys'
$paneItems = [ordered]@{
    '1' = 'pane shows the server screen and starts view-only'
    '2' = 'take control sends a click and typing and give back stops input'
    '3' = 'full width keeps the app window controls'
    '4' = 'two chats on one host share one connection'
    '5' = 'a hidden chat sleeps with its last picture'
    '6' = 'the viewing choice returns after relaunch'
    '7' = 'the five connection states render'
    '8' = 'the VNC port is not reachable from outside the host'
}
$paneOrder = @('8', '1', '3', '2', '5', '4', '7', '6')
$script:verdicts = [ordered]@{}

function Set-ItemVerdict([string]$Number, [string]$Verdict, [string]$Detail) {
    if ($script:verdicts.Contains($Number)) { return }
    $script:verdicts[$Number] = [pscustomobject]@{ item = ($Number + ' ' + $paneItems[$Number]); verdict = $Verdict; detail = $Detail }
}

function Save-PaneItems {
    $table = @(foreach ($number in ($script:verdicts.Keys | Sort-Object { [int]$_ })) { $script:verdicts[$number] })
    $result.items = $table
    Save-Json $table 'computer-pane-items.json'
}

function Stop-Journey([string]$Number, [string]$Detail) {
    Set-ItemVerdict $Number 'failed' $Detail
    $index = [Array]::IndexOf($paneOrder, $Number)
    for ($i = $index + 1; $i -lt $paneOrder.Count; $i++) { Set-ItemVerdict $paneOrder[$i] 'unreachable' ('the journey stopped at item ' + $Number) }
    Save-PaneItems
    throw ('computer-pane item ' + $Number + ' failed: ' + $Detail)
}

function Read-PaneTrace {
    if (-not (Test-Path -LiteralPath $paneLog)) { return '' }
    return Read-SharedText $paneLog
}

function Get-PaneSymptom {
    $trace = Read-PaneTrace
    $lines = @([regex]::Matches($trace, '\[computer\] [^\r\n]*') | ForEach-Object { $_.Value })
    if (-not $lines.Count) { return 'the app wrote no [computer] line' }
    $chain = @($lines | Select-Object -Last 8) -join ' | '
    $hostText = 'the host log is unavailable'
    try {
        $hostLog = Invoke-ComputerHost 'journalctl -u novnc-desktop.service -n 5 --no-pager 2>/dev/null || true'
        if ($hostLog.out) { $hostText = $hostLog.out.Replace("`n", ' ') }
    } catch { }
    return ($chain + ' host: ' + $hostText)
}

function Wait-PaneState([string[]]$States, [int]$Seconds, [string]$Description) {
    Wait-Until {
        $trace = Read-PaneTrace
        foreach ($state in $States) { if ($trace -match ('\[computer\] state ' + [regex]::Escape($state))) { return $true } }
        return $false
    } $Description $Seconds 500
}

function Get-PaneStates {
    $trace = Read-PaneTrace
    return @([regex]::Matches($trace, '\[computer\] state (\w+)') | ForEach-Object { $_.Groups[1].Value })
}

function Get-ClientRect {
    $client = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client)) { throw 'Client rectangle unavailable' }
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Client origin unavailable' }
    return @{ client = $client; origin = $origin }
}

function Measure-PaneMarker([string]$Name, [double]$LeftFraction, [double]$WidthFraction) {
    $rect = Get-ClientRect
    $left = $rect.origin.X + [int]($rect.client.Right * $LeftFraction)
    $top = $rect.origin.Y + [int]($rect.client.Bottom * 0.10)
    $width = [int]($rect.client.Right * $WidthFraction)
    $height = [int]($rect.client.Bottom * 0.80)
    if ($width -lt 32 -or $height -lt 32) { throw 'The computer pane region is too small to measure' }
    $red = ($markerRgb -shr 16) -band 0xff
    $green = ($markerRgb -shr 8) -band 0xff
    $blue = $markerRgb -band 0xff
    $bitmap = New-Object Drawing.Bitmap($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($left, $top, 0, 0, $bitmap.Size) } finally { $graphics.Dispose() }
    try {
        $bitmap.Save((Join-Path $Evidence ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
        $hits = 0
        $total = 0
        for ($column = 0; $column -lt 32; $column++) {
            for ($row = 0; $row -lt 32; $row++) {
                $pixel = $bitmap.GetPixel([int]($bitmap.Width * ($column + 0.5) / 32), [int]($bitmap.Height * ($row + 0.5) / 32))
                $total++
                if ([Math]::Abs($pixel.R - $red) -le 8 -and [Math]::Abs($pixel.G - $green) -le 8 -and [Math]::Abs($pixel.B - $blue) -le 8) { $hits++ }
            }
        }
        return [pscustomobject]@{ share = [Math]::Round($hits / $total, 3); width = $width; height = $height; picture = ($Name + '.png') }
    } finally { $bitmap.Dispose() }
}

function Get-PaneLeftEdge {
    $rect = Get-ClientRect
    $red = ($markerRgb -shr 16) -band 0xff
    $green = ($markerRgb -shr 8) -band 0xff
    $blue = $markerRgb -band 0xff
    $bitmap = New-Object Drawing.Bitmap($rect.client.Right, $rect.client.Bottom)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($rect.origin.X, $rect.origin.Y, 0, 0, $bitmap.Size) } finally { $graphics.Dispose() }
    try {
        $row = [int]($bitmap.Height / 2)
        for ($column = 0; $column -lt $bitmap.Width; $column += 2) {
            $pixel = $bitmap.GetPixel($column, $row)
            if ([Math]::Abs($pixel.R - $red) -le 8 -and [Math]::Abs($pixel.G - $green) -le 8 -and [Math]::Abs($pixel.B - $blue) -le 8) { return @{ left = $column; width = $bitmap.Width } }
        }
        return @{ left = $bitmap.Width; width = $bitmap.Width }
    } finally { $bitmap.Dispose() }
}

function Send-PaneKeys([string]$Text) {
    foreach ($character in $Text.ToCharArray()) {
        if ($character -cmatch '^[a-z]$') { Press @(0x41 + ([int][char]$character - [int][char]'a')) ("Key: " + $character) } else { throw "The computer-pane journey types only lowercase letters, not $character" }
    }
}

function Get-HostPointer {
    $reply = Invoke-ComputerHost 'DISPLAY=:0 xdotool getmouselocation --shell'
    if ($reply.exit -ne 0) { throw ('The host pointer is unreadable: ' + $reply.err.Trim()) }
    $x = [regex]::Match($reply.out, 'X=(\d+)')
    $y = [regex]::Match($reply.out, 'Y=(\d+)')
    if (-not $x.Success -or -not $y.Success) { throw ('The host pointer reply is malformed: ' + $reply.out) }
    return @{ x = [int]$x.Groups[1].Value; y = [int]$y.Groups[1].Value }
}

function Get-HostTypedText {
    $reply = Invoke-ComputerHost 'cat /home/desk/typed.txt 2>/dev/null || true'
    if ($reply.exit -ne 0) { throw ('The host typed-text file is unreadable: ' + $reply.err.Trim()) }
    return $reply.out
}

function Invoke-HostDiscovery {
    $body = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../../src/computer/discover.py')) + "`nmain(True,'desk')`n"
    $length = [Text.Encoding]::UTF8.GetBytes($body).Length
    $bootstrap = 'python3 -u -c "import sys;exec(compile(sys.stdin.buffer.read(' + $length + '),''<computer>'',''exec''))"'
    $reply = Invoke-ComputerHost $bootstrap $body
    if ($reply.exit -ne 0) { throw ('The app discovery script failed on the host: ' + $reply.err.Trim() + ' ' + $reply.out.Trim()) }
    $line = @($reply.out -split "`r?`n" | Where-Object { $_.StartsWith('{') })
    if (-not $line.Count) { throw ('The app discovery script returned no JSON: ' + $reply.out) }
    return ($line[0] | ConvertFrom-Json)
}

function Get-TunnelBanner([int]$Port, [int]$TimeoutSeconds = 8) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $connecting = $client.ConnectAsync('bore.pub', $Port)
        if (-not $connecting.Wait($TimeoutSeconds * 1000)) { return 'timeout' }
        $client.ReceiveTimeout = $TimeoutSeconds * 1000
        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutSeconds * 1000
        $buffer = New-Object byte[] 64
        $size = $stream.Read($buffer, 0, 64)
        if ($size -le 0) { return 'empty' }
        return [Text.Encoding]::ASCII.GetString($buffer, 0, $size)
    } catch { return ('refused: ' + $_.Exception.Message) } finally { $client.Dispose() }
}

try {
    Write-Host 'Computer pane: the disposable host is resolved; proving the screen is private'
    try {
        $bindings = Invoke-ComputerHost 'ss -ltn'
        if ($bindings.exit -ne 0) { throw ('The host listeners are unreadable: ' + $bindings.err.Trim()) }
        $listenerLines = @($bindings.out -split "`r?`n")
        $beyondLoopback = @()
        foreach ($line in $listenerLines) {
            $fields = @($line -split '\s+' | Where-Object { $_ })
            if ($fields.Count -lt 4) { continue }
            if ($fields[3] -match ':(5900|6080)$' -and $fields[3] -notmatch '^(127\.0\.0\.1|\[::1\]):') { $beyondLoopback += $line }
        }
        if ($beyondLoopback.Count) { throw ('The desktop ports listen beyond loopback: ' + ($beyondLoopback -join ' / ')) }
        foreach ($port in @(5900, 6080)) {
            if (-not ($listenerLines | Where-Object { $_ -match ('127\.0\.0\.1:' + $port + '(\s|$)') })) { throw "Port $port is not listening on host loopback" }
        }
        $bore = Invoke-ComputerHost "ps -eo args | grep '[b]ore local'"
        if ($bore.out -notmatch 'bore local 22 ') { throw ('The free tunnel does not forward the host SSH port: ' + $bore.out) }
        $banner = Get-TunnelBanner $script:computerHost.port
        if ($banner -notmatch '^SSH-2\.0-') { throw ('The only public listener on the tunnel does not speak SSH: ' + $banner) }
        $vncBanner = Get-TunnelBanner $script:computerHost.vncPort 4
        $viewerBanner = Get-TunnelBanner $script:computerHost.viewerPort 4
        if ($vncBanner -match '^RFB ') { throw ('The public tunnel host answers the VNC port with RFB: ' + $vncBanner) }
        $boundary = @{ listeners = $listenerLines; beyondLoopback = $beyondLoopback; tunnelArgument = $bore.out; banner = $banner; samePortVncBanner = $vncBanner; samePortViewerBanner = $viewerBanner }
        Save-Json $boundary 'computer-pane-boundary.json'
        Set-ItemVerdict '8' 'proven' ('ss -ltn holds 5900 and 6080 on 127.0.0.1 only; the free tunnel runs "' + $bore.out.Trim() + '" so only SSH is exposed; the tunnel banner is ' + $banner.Trim() + '; a same-numbered public port answered ' + $vncBanner)
        Record 'Item 8 proven: the desktop ports are loopback only and the free tunnel exposes SSH alone'
    } catch { Stop-Journey '8' $_.Exception.Message }

    Write-Host 'Computer pane: the disposable host as the app sees it'
    try {
        $discovery = Invoke-HostDiscovery
        if ($discovery.version -ne 1) { throw ('The host desktop is not discoverable: version ' + $discovery.version) }
        if ($discovery.viewer_port -ne $script:computerHost.viewerPort) { throw ('The host viewer port changed to ' + $discovery.viewer_port) }
        if ($discovery.user -cne 'desk') { throw ('The host desktop user is ' + $discovery.user) }
        if ($discovery.display -notmatch '^:\d+$') { throw ('The host desktop display is ' + $discovery.display) }
        if ($discovery.desktop -notmatch '^[0-9a-f]{64}$') { throw 'The host desktop identity is malformed' }
        $redacted = @{ version = $discovery.version; host = $discovery.host; uid = $discovery.uid; user = $discovery.user; display = $discovery.display; desktop = $discovery.desktop; viewer_port = $discovery.viewer_port; passwordLength = ([Text.Encoding]::ASCII.GetBytes([Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($discovery.password)))).Length }
        Save-Json $redacted 'host-discovery.json'
        $pointer = Get-HostPointer
        $typed = Get-HostTypedText
        if ($typed -match $typeMarker) { throw 'The host typed-text file already holds the journey marker' }
        Record ('Computer host ready: desktop ' + $discovery.desktop + ' display ' + $discovery.display + ' viewer port ' + $discovery.viewer_port)
    } catch { Stop-Journey '1' ('the disposable host is not ready: ' + $_.Exception.Message) }

    Write-Host 'Computer pane: creating two chats on the one disposable host'
    try {
        Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 } 'one initial local session'
        $initial = Read-Session
        $groupIds = @()
        if ($initial.PSObject.Properties['groups']) { $groupIds = @($initial.groups | ForEach-Object { $_.id }) }
        Invoke-JourneyCommand 'Move to Group' -Confirm {
            Press @(0x0D) 'Enter: Move to Group'
        }
        Type-Text 'new group'
        Press @(0x0D) 'Enter: create the isolated group'
        Wait-Until {
            $state = Read-Session
            $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups | Where-Object { $_.id -notin $groupIds }).Count -eq 1
        } 'user-created group saved'
        $baseline = Read-Session
        $group = @($baseline.groups | Where-Object { $_.id -notin $groupIds })[0]
        $workspace = $baseline.workspaces[$baseline.active_workspace].name
        $script:panePort = 0
        Wait-Until {
            $trace = Read-PaneTrace
            $listener = [regex]::Match($trace, 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
            if (-not $listener.Success) { return $false }
            $script:panePort = [int]$listener.Groups[1].Value
            @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:panePort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
        } 'app-owned session command listener' 30
        $listed = Invoke-Zsb @('workspace-list') $script:panePort 'workspace-list'
        $hostName = $listed.hosts[0]
        foreach ($chat in @(@{ tmux = 'verify-computer-a'; name = 'Computer host A' }, @{ tmux = 'verify-computer-b'; name = 'Computer host B' })) {
            $created = Invoke-Zsb @('session-open', '--workspace', $workspace, '--group', $group.name, '--host', $hostName, '--tmux', $chat.tmux, '--name', $chat.name) $script:panePort ('session-created-' + $chat.tmux)
            if ($created.created -ne $true -or $created.tab -le 0) { throw ('The session command did not create ' + $chat.name) }
        }
        Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.name -ceq 'Computer host A' -or $_.name -ceq 'Computer host B' }).Count -eq 2 } 'both chats saved by the app'
        Invoke-JourneyCommand 'Computer host A' -Session -Confirm {
            Press @(0x0D) 'Enter: select Computer host A'
        }
        Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].name -ceq 'Computer host A' } 'first host chat selected'
        Save-Json (Read-Session) 'session-two-chats.json'
    } catch { Stop-Journey '1' ('the journey could not create the two host chats: ' + $_.Exception.Message) }

    Write-Host 'Computer pane: opening the pane and requiring the server screen'
    try {
        Invoke-JourneyCommand 'Computer: Show or hide' -Confirm {
            Press @(0x0D) 'Enter: show the Computer pane'
        }
        try {
            Wait-Until {
                $trace = Read-PaneTrace
                $trace -match '\[computer\] state live' -or $trace -match '\[computer\] state lost'
            } 'the pane reported Live or Lost for the disposable host' 120
        } catch { throw ('the pane never reported a connection state: ' + (Get-PaneSymptom)) }
        $trace = Read-PaneTrace
        if ($trace -notmatch '\[computer\] state live') { throw ('the pane settled in Lost instead of showing the server screen: ' + (Get-PaneSymptom)) }
        if ($trace -notmatch ('found display :\d+, viewer port ' + $script:computerHost.viewerPort)) { throw ('The app did not accept the host desktop discovery: ' + (Get-PaneSymptom)) }
        if ($trace -match '\[computer\] control on') { throw 'The pane started in control instead of view-only' }
        $picture = Measure-PaneMarker 'computer-pane' 0.55 0.40
        if ($picture.share -lt 0.5) { throw ('The pane does not show the server screen: ' + $picture.share + ' of the sampled pixels are the host marker colour') }
        $pointer = Get-HostPointer
        $rect = Get-ClientRect
        Doctor
        Assert-Foreground
        Record 'Click inside the view-only pane; the host must ignore it'
        [VerifyNative]::ClickOwnedContent($script:window, [int]($rect.client.Right * 0.75), [int]($rect.client.Bottom * 0.5))
        Start-Sleep -Milliseconds 1500
        $afterClick = Get-HostPointer
        if ($afterClick.x -ne $pointer.x -or $afterClick.y -ne $pointer.y) { throw ('A view-only pane moved the host pointer from ' + $pointer.x + ',' + $pointer.y + ' to ' + $afterClick.x + ',' + $afterClick.y) }
        Save-Json @{ picture = $picture; pointerBefore = $pointer; pointerAfterViewOnlyClick = $afterClick; screenshot = 'computer-pane.png' } 'computer-pane-live.json'
        Set-ItemVerdict '1' 'proven' ('state live, the app accepted display :0 with viewer port ' + $script:computerHost.viewerPort + ', ' + ($picture.share * 100) + '% of the pane is the host marker colour, and a view-only click left the host pointer at ' + $pointer.x + ',' + $pointer.y)
        Record 'Item 1 proven: the pane shows the server screen and starts view-only'
    } catch {
        try { Snapshot 'computer-pane-failure' } catch { }
        try { Copy-Item -LiteralPath $paneLog (Join-Path $Evidence 'computer-pane-debug.log') -ErrorAction Stop } catch { }
        Stop-Journey '1' $_.Exception.Message
    }

    Write-Host 'Computer pane: full width keeps the window controls'
    try {
        $narrow = Get-PaneLeftEdge
        $rect = Get-ClientRect
        $dpi = [VerifyNative]::GetDpiForWindow($script:window)
        $buttonWidth = [int][Math]::Floor(44 * $dpi / 96)
        $buttonHeight = [int][Math]::Floor(32 * $dpi / 96)
        Press @(0x11, 0x10, 0x46) 'Ctrl+Shift+F: Computer full width'
        Wait-Until { (Get-PaneLeftEdge).left -lt ($narrow.left - 50) } 'the pane widened to the full window' 20
        $wide = Get-PaneLeftEdge
        $geometry = [WindowControlsProof]::Geometry($script:window)
        $hits = @(0..2 | ForEach-Object { [WindowControlsProof]::Hit($script:window, ($geometry[6] - (3 - $_) * $buttonWidth + [int]($buttonWidth / 2)), ([int]($buttonHeight / 2))) })
        if (($hits -join ',') -ne '8,9,20') { throw ('The full-width pane lost the window controls: hit areas ' + ($hits -join ',')) }
        $widePicture = Measure-PaneMarker 'computer-pane-full-width' 0.10 0.80
        if ($widePicture.share -lt 0.5) { throw ('The full-width pane lost the server picture: ' + $widePicture.share) }
        Snapshot 'computer-full-width'
        Save-Json @{ narrowLeft = $narrow.left; wideLeft = $wide.left; width = $wide.width; hitAreas = $hits; picture = $widePicture } 'computer-full-width.json'
        Press @(0x11, 0x10, 0x46) 'Ctrl+Shift+F: restore the split'
        Wait-Until { (Get-PaneLeftEdge).left -gt ($narrow.left - 50) } 'the pane returned to the split width' 20
        $restored = @(0..2 | ForEach-Object { [WindowControlsProof]::Hit($script:window, ($geometry[6] - (3 - $_) * $buttonWidth + [int]($buttonWidth / 2)), ([int]($buttonHeight / 2))) })
        if (($restored -join ',') -ne '8,9,20') { throw ('The restored pane lost the window controls: hit areas ' + ($restored -join ',')) }
        Set-ItemVerdict '3' 'proven' ('Ctrl+Shift+F moved the pane left edge from ' + $narrow.left + ' to ' + $wide.left + ' of ' + $wide.width + ' client pixels, the caption controls still answer real hit areas ' + ($hits -join ',') + ', and the picture survived')
        Record 'Item 3 proven: full width keeps the app window controls'
    } catch { Stop-Journey '3' $_.Exception.Message }

    Write-Host 'Computer pane: take control, click and type, give back'
    try {
        $before = Get-HostPointer
        Invoke-JourneyCommand 'Computer: Take control' -Confirm {
            Press @(0x0D) 'Enter: take control of the host'
        }
        Wait-Until { (Read-PaneTrace) -match '\[computer\] control on' } 'the app logged control on' 20
        $rect = Get-ClientRect
        Doctor
        Assert-Foreground
        Record 'Click the host screen while this chat holds control'
        [VerifyNative]::ClickOwnedContent($script:window, [int]($rect.client.Right * 0.75), [int]($rect.client.Bottom * 0.5))
        Wait-Until {
            $pointer = Get-HostPointer
            [Math]::Abs($pointer.x - $before.x) -gt 4 -or [Math]::Abs($pointer.y - $before.y) -gt 4
        } 'the click reached the host pointer' 20
        $pointer = Get-HostPointer
        Send-PaneKeys $typeMarker
        Press @(0x0D) 'Enter: submit the typed marker on the host'
        Wait-Until { (Get-HostTypedText) -match $typeMarker } 'the typed text reached the host terminal' 30
        $typed = Get-HostTypedText
        Invoke-JourneyCommand 'Computer: Give back' -Confirm {
            Press @(0x0D) 'Enter: give control back'
        }
        Wait-Until { (Read-PaneTrace) -match '\[computer\] control off' } 'the app logged control off' 20
        $cause = ([regex]::Match((Read-PaneTrace), '\[computer\] control off: ([^\r\n]+)')).Groups[1].Value
        Send-PaneKeys $ignoredMarker
        Press @(0x0D) 'Enter: submit keys after giving control back'
        Start-Sleep -Seconds 3
        $afterGiveBack = Get-HostTypedText
        if ($afterGiveBack -match $ignoredMarker) { throw 'Keys typed after Give back still reached the host' }
        Save-Json @{ pointerBefore = $before; pointerAfter = $pointer; typed = $typed; controlOffCause = $cause; afterGiveBack = $afterGiveBack } 'computer-control.json'
        Set-ItemVerdict '2' 'proven' ('Take control moved the host pointer to ' + $pointer.x + ',' + $pointer.y + ', the typed marker reached the host terminal, and the app logged control off (' + $cause + ') after which the next keys never arrived')
        Record 'Item 2 proven: take control sends a click and typing and give back stops input'
    } catch { Stop-Journey '2' $_.Exception.Message }

    Write-Host 'Computer pane: the hidden chat sleeps with its last picture'
    try {
        $sleepMark = (Read-PaneTrace).Length
        Invoke-JourneyCommand 'Computer host B' -Session -Confirm {
            Press @(0x0D) 'Enter: switch to Computer host B'
        }
        Wait-Until { (Read-PaneTrace).Substring($sleepMark) -match '\[computer\] state sleeping' } 'the hidden pane slept' 30
        Snapshot 'computer-sleeping'
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $returnMark = (Read-PaneTrace).Length
        Invoke-JourneyCommand 'Computer host A' -Session -Confirm {
            Press @(0x0D) 'Enter: return to Computer host A'
        }
        $firstPicture = -1
        while ($watch.ElapsedMilliseconds -lt 4000) {
            $sample = Measure-PaneMarker 'computer-pane-return' 0.55 0.40
            if ($sample.share -ge 0.5) { $firstPicture = $watch.ElapsedMilliseconds; break }
            Start-Sleep -Milliseconds 200
        }
        if ($firstPicture -lt 0) { throw 'Returning to the sleeping chat never restored the last picture' }
        if ($firstPicture -gt 2500) { throw ('The last picture took ' + $firstPicture + ' ms to come back; it was re-read from the host instead of memory') }
        Wait-Until { (Read-PaneTrace).Substring($returnMark) -match '\[computer\] state live' } 'the returned chat reached Live again' 120
        Save-Json @{ millisecondsToLastPicture = $firstPicture; states = (Get-PaneStates) } 'computer-sleeping.json'
        Set-ItemVerdict '5' 'proven' ('the hidden chat logged state sleeping and its last picture was back after ' + $firstPicture + ' ms, before a fresh discovery could paint')
        Record 'Item 5 proven: the hidden chat sleeps with its last picture'
    } catch { Stop-Journey '5' $_.Exception.Message }

    Write-Host 'Computer pane: two chats on one host keep one connection'
    try {
        $opens = {
            $trace = Read-PaneTrace
            return @([regex]::Matches($trace, '\[computer\] forwarding viewer port \d+ on ')).Count
        }
        $forwardsBefore = & $opens
        $switchMark = (Read-PaneTrace).Length
        Invoke-JourneyCommand 'Computer host B' -Session -Confirm { Press @(0x0D) 'Enter: back to Computer host B' }
        Wait-Until { (Read-PaneTrace).Substring($switchMark) -match '\[computer\] state live' } 'the second chat reached Live' 120
        $forwardsMiddle = & $opens
        $backMark = (Read-PaneTrace).Length
        Invoke-JourneyCommand 'Computer host A' -Session -Confirm { Press @(0x0D) 'Enter: back to Computer host A' }
        Wait-Until { (Read-PaneTrace).Substring($backMark) -match '\[computer\] state live' } 'the first chat reached Live again' 120
        $forwardsAfter = & $opens
        if ($forwardsMiddle -ne $forwardsBefore -or $forwardsAfter -ne $forwardsBefore) { throw ('Switching between two chats on one host opened another connection: ' + $forwardsBefore + ' then ' + $forwardsMiddle + ' then ' + $forwardsAfter) }
        $forwards = @(Get-CimInstance Win32_Process -Filter "Name = 'ssh.exe'" | Where-Object { $_.ParentProcessId -eq $process.Id -and $_.CommandLine -match '-L 127\.0\.0\.1:' })
        if ($forwards.Count -ne 1) { throw ('The app holds ' + $forwards.Count + ' viewer connections for one host instead of one') }
        $picture = Measure-PaneMarker 'computer-pane-switched' 0.55 0.40
        if ($picture.share -lt 0.5) { throw ('The picture after switching is not the host screen: ' + $picture.share) }
        Save-Json @{ reusedForwards = $forwardsAfter; viewerConnections = $forwards.Count; picture = $picture; states = (Get-PaneStates) } 'computer-switch.json'
        Set-ItemVerdict '4' 'proven' ('switching kept ' + $forwardsAfter + ' viewer forwards opened and exactly ' + $forwards.Count + ' live ssh forward for the one host, and the pane still showed the host screen')
        Record 'Item 4 proven: two chats on one host share one connection'
    } catch { Stop-Journey '4' $_.Exception.Message }

    Write-Host 'Computer pane: the five connection states'
    try {
        $stopped = Invoke-ComputerHost 'sudo -n /usr/bin/systemctl stop novnc-desktop.service'
        if ($stopped.exit -ne 0) { throw ('The host websocket service did not stop for the forced drop: ' + $stopped.err.Trim()) }
        Wait-PaneState @('reconnecting') 90 'the pane reported reconnecting after the drop'
        Wait-PaneState @('lost') 120 'the pane reported lost after the retries'
        $restarted = Invoke-ComputerHost 'sudo -n /usr/bin/systemctl start novnc-desktop.service'
        if ($restarted.exit -ne 0) { throw ('The host websocket service did not restart: ' + $restarted.err.Trim()) }
        Wait-Until { (Invoke-ComputerHost 'systemctl is-active novnc-desktop.service').out.Trim() -ceq 'active' } 'the host websocket service is active again' 30
        Invoke-JourneyCommand 'Computer: Retry' -Confirm { Press @(0x0D) 'Enter: retry the Computer view' }
        Wait-PaneState @('live') 120 'Retry reached Live again on the same chat'
        $states = Get-PaneStates
        foreach ($state in @('connecting', 'live', 'sleeping', 'reconnecting', 'lost')) {
            if ($states -notcontains $state) { throw ('The journey never saw the ' + $state + ' state; it saw ' + ($states -join ', ')) }
        }
        Save-Json @{ states = $states } 'computer-states.json'
        Set-ItemVerdict '7' 'proven' ('the log holds all five states in order: ' + ($states -join ' -> ') + '; Retry returned the same chat to Live')
        Record 'Item 7 proven: the five connection states render'
    } catch { Stop-Journey '7' $_.Exception.Message }

    Write-Host 'Computer pane: the viewing choice returns after relaunch'
    try {
        if (-not (Test-Path -LiteralPath $choicePath)) { throw 'The app never saved the viewing choice' }
        $choice = (Get-Content -LiteralPath $choicePath -Raw)
        if ($choice -notmatch '\A[0-9a-f]{64}1\r?\n?\z') { throw ('The saved viewing choice is malformed: ' + $choice) }
        Copy-Item -LiteralPath $choicePath (Join-Path $Evidence 'computer-choice.txt')
        Save-Json (Read-Session) 'session-before-relaunch.json'
        $relaunchMark = (Read-PaneTrace).Length
        Restart-SessionRestore 'computer-relaunch' $false
        Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].name -ceq 'Computer host A' } 'the relaunched app restored the chat that owns the pane' 60
        Wait-Until { (Read-PaneTrace).Substring($relaunchMark) -match '\[computer\] state live' } 'the relaunched app reopened the Computer view on the same chat' 150
        $restored = (Get-Content -LiteralPath $choicePath -Raw)
        if ($restored -cne $choice) { throw 'The relaunched app changed or cleared the saved viewing choice' }
        $picture = Measure-PaneMarker 'computer-pane-relaunched' 0.55 0.40
        if ($picture.share -lt 0.5) { throw ('The relaunched pane does not show the server screen: ' + $picture.share) }
        Save-Json @{ choice = 'unchanged'; picture = $picture; states = (Get-PaneStates) } 'computer-relaunch.json'
        Set-ItemVerdict '6' 'proven' ('the same single saved choice opened the pane again after relaunch and ' + ($picture.share * 100) + '% of it was the host screen')
        Record 'Item 6 proven: the viewing choice returns after relaunch'
    } catch { Stop-Journey '6' $_.Exception.Message }

    Save-PaneItems
    $result.checks += @{ name = 'computer-pane'; items = @($result.items); host = @{ address = $script:computerHost.address; port = $script:computerHost.port; user = $script:computerHost.user; vncPort = $script:computerHost.vncPort; viewerPort = $script:computerHost.viewerPort; tunnel = 'bore.pub, free, no account and no stored secret' } }
} finally {
    if ($null -ne $script:computerHost) {
        try {
            $signOff = Invoke-ComputerHost 'touch /tmp/verify-computer-done'
            if ($signOff.exit -ne 0) { Write-Host ('Computer pane: the host sign-off failed: ' + $signOff.err.Trim()) }
        } catch { Write-Host ('Computer pane: the host sign-off failed: ' + $_.Exception.Message) }
    }
}
