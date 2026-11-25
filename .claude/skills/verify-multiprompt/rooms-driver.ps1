param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/../../../tools/verify-server-chat/native.ps1"
$Exe = (Resolve-Path $Exe).Path
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
$profile = Join-Path $env:RUNNER_TEMP ('rooms-' + [guid]::NewGuid().ToString('N'))
$settings = "$profile/roaming/ZigShell"
$mainSettings = $settings
$actions = [Collections.Generic.List[object]]::new()
$planned = [ordered]@{
    '1' = 'a: Create a room on a fresh profile'
    'private' = 'Both member chats reply through the real composer'
    '2' = 'b: Add two chats, including a closed chat'
    '2-open' = 'Diagnostic: add both reopened chats'
    '3' = 'Persist a plain send'
    '4' = 'c: Exactly two broadcast replies'
    '5' = 'd: Mention the displayed name'
    '6' = 'Same reply order in all views'
    '7' = 'e: Replies received while away'
    '8' = 'f: Restart with an unanswered question'
    '9' = 'g: Phone reads the same room'
    '10' = 'h: Phone retry does not duplicate'
    '11' = 'Discover existing rooms on a fresh install'
    '12' = 'Recover a failed member turn'
    '13' = 'Lost acknowledgement and retry'
    '14' = 'History stays complete after reload'
}
$result = @{ feature = 'rooms'; status = 'failed'; cases = @(); driverErrors = @(); observations = @(); version = $ExpectedVersion; sha256 = $ExpectedHash; boundary = 'Runner-owned account Worker, real SSH/tmux and production room/host/reader. Only paid Claude is replaced by a deterministic stream-json process.' }
$app = $null
$job = $null
$serviceJob = $null
$cert = $null
$hostsFile = "$env:SystemRoot/System32/drivers/etc/hosts"
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$watcher = $null
$clock = [Diagnostics.Stopwatch]::StartNew()
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false)) }
function Copy-Debug([string]$Name) {
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/$Name-debug.log" -Force -ErrorAction SilentlyContinue }
}
function Read-Shared([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $readDeadline = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try { $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)); break }
        catch {
            $cause = $_.Exception.GetBaseException()
            if ($cause -is [IO.FileNotFoundException] -or $cause -is [IO.DirectoryNotFoundException]) { return '' }
            if ($cause -isnot [IO.IOException] -or ($cause.HResult -band 0xffff) -notin @(32, 33) -or $readDeadline.Elapsed.TotalSeconds -ge 5) { throw }
            [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
        }
    }
    try { $reader = [IO.StreamReader]::new($stream); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
}
function Wait-For([string]$ConditionName, [scriptblock]$Check, [int]$Seconds = 45) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $value = & $Check
        if ($value) { return $value }
        if ($null -ne $app -and $app.HasExited) { throw 'Owned desktop exited' }
        [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $ConditionName"
}
function Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    $element = [Windows.Automation.AutomationElement]::FromHandle($main)
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id) { throw 'Doctor: desktop not visible' }
    Save @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
}
function Press([int[]]$Keys, [string]$Label) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; seconds = $clock.Elapsed.TotalSeconds })
    [ChatDeliveryDesktop]::Chord($Keys)
}
function Type-Text([string]$Text) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing typing outside the owned app' }
    $actions.Add(@{ input = 'type'; text = $Text; seconds = $clock.Elapsed.TotalSeconds })
    foreach ($letter in $Text.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
}
$journeyCommands = $null
function Invoke-JourneyCommand {
    param([string]$Name, [string]$Text, [switch]$Session)
    if ($null -eq $journeyCommands) {
        $catalog = & node (Join-Path $PSScriptRoot '../../../tools/journey-commands.mjs')
        if ($LASTEXITCODE -ne 0) { throw 'Journey command catalog failed' }
        $journeyCommands = $catalog | ConvertFrom-Json
    }
    if ($Text) {
        $query = $Text
        $target = $null
    } elseif ($Session) {
        $tabs = Saved-Tabs (Session-Saved)
        $matching = @(for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq $Name) { $i } })
        if ($matching.Count -ne 1) { throw "Journey session name must be unique: $Name" }
        $query = $Name
        $target = [string]$matching[0]
    } else {
        $entry = $journeyCommands.PSObject.Properties[$Name.ToLowerInvariant()]
        if ($null -eq $entry) { throw "Unknown journey command name: $Name" }
        $query = $entry.Value.query
        $target = [string]$entry.Value.target
    }
    Press @(0x1B) 'Escape: dismiss overlay before the palette command'
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open palette'
    [void](Wait-For 'empty palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text $query
    $rowsPattern = '\[palette\] rows chars=' + $query.Length + ' count=\d+ ids=([^\r\n]+)'
    $ids = Wait-For "palette rows for $query" {
        $rows = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), $rowsPattern)
        if ($rows.Count -eq 0) { return $null }
        $found = @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ' | Where-Object { $_ })
        if (-not $found.Count -or ($null -ne $target -and $found -notcontains $target)) { return $null }
        ,$found
    }
    $index = if ($null -eq $target) { 0 } else { [Array]::IndexOf($ids, $target) }
    for ($i = 0; $i -lt $index; $i++) { Press @(0x28) "Down: row for $query" }
    Press @(0x0D) "Enter: $query"
    [void](Wait-For "palette confirms $query" { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] confirm target=\d+' })
}
function Visible-Children([string]$Class, $Parent = $main) {
    $element = [Windows.Automation.AutomationElement]::FromHandle([IntPtr]$Parent)
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty, $Class)
    @($element.FindAll([Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen } | ForEach-Object { [IntPtr]$_.Current.NativeWindowHandle })
}
function Room-Window { $windows = @(Visible-Children 'MultiPromptRoomView'); if ($windows.Count -eq 1) { $windows[0] } }
function Open-Room([string]$Name) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Invoke-JourneyCommand -Text $Name
    $settle = [Diagnostics.Stopwatch]::StartNew()
    while ($settle.Elapsed.TotalSeconds -lt 5) {
        if (-not (Room-Window)) { break }
        $state = Read-Shared "$settings/debug.log"
        if ($state.Length -gt $offset -and $state.Substring($offset) -match '\[rooms\] bridge reply received') { break }
        [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
    }
    if (-not (Room-Window)) { throw "Opening $Name did not show its room view" }
}
function Focus-Control([IntPtr]$Control) {
    Doctor
    if (-not [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $Control)) { throw 'Cannot focus owned control' }
}
function Snapshot([string]$Name) {
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-snapshot.py") -Evidence $Evidence -Name ($Name + '-snapshot')
    $state = ($raw -join "`n") | ConvertFrom-Json
    Save $state "$Evidence/$Name-state.json"
    return $state
}
function Room-Data($State) { ,@($State.rooms | ForEach-Object { $_.tables.rooms } | Where-Object { $_.name -ceq 'Rooms534' }) }
function Room-Events($State) { @($State.rooms | ForEach-Object { $_.tables.events } | ForEach-Object { $_.body | ConvertFrom-Json }) }
function Shot([string]$Name) {
    Doctor
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $text = Invoke-ServerNative -FilePath $ocr -Arguments @("$Evidence/$Name.png", 'stdout', '--psm', '11') -Evidence $Evidence -Name ("$Name-ocr")
    $text = ($text -join ' ') -replace '\s+', ' '
    [IO.File]::WriteAllText("$Evidence/$Name-visible.txt", $text)
    return $text
}
function Save-Variant([Drawing.Bitmap]$Source, [int]$Skip, [int]$Scale, [int]$Threshold, [bool]$Light) {
    $crop = $Source
    try {
        if ($Skip -gt 0 -and $Skip -lt ($Source.Width - 8)) {
            $crop = $Source.Clone([Drawing.Rectangle]::new($Skip, 0, $Source.Width - $Skip, $Source.Height), $Source.PixelFormat)
        }
        $bitmap = [Drawing.Bitmap]::new([Math]::Max(1, $crop.Width * $Scale), [Math]::Max(1, $crop.Height * $Scale), [Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $attributes = [Drawing.Imaging.ImageAttributes]::new()
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $matrix = [Drawing.Imaging.ColorMatrix]::new()
            if ($Threshold -lt 0) {
                $matrix.Matrix00 = 1; $matrix.Matrix11 = 1; $matrix.Matrix22 = 1; $matrix.Matrix33 = 1; $matrix.Matrix44 = 1
            } elseif ($Threshold -gt 0) {
                $slope = 255 / 16
                $bias = 0.5 - $slope * $Threshold / 255
                $weights = @(0.299, 0.587, 0.114)
                for ($channel = 0; $channel -lt 3; $channel++) {
                    for ($column = 0; $column -lt 3; $column++) { $matrix[$column, $channel] = $weights[$column] * $slope }
                    $matrix[4, $channel] = $bias
                }
            } elseif ($Light) {
                $matrix.Matrix00 = 2.392; $matrix.Matrix10 = 4.696; $matrix.Matrix20 = 0.912; $matrix.Matrix40 = -5.772
                $matrix.Matrix01 = 2.392; $matrix.Matrix11 = 4.696; $matrix.Matrix21 = 0.912; $matrix.Matrix41 = -5.772
                $matrix.Matrix02 = 2.392; $matrix.Matrix12 = 4.696; $matrix.Matrix22 = 0.912; $matrix.Matrix42 = -5.772
            } else {
                $matrix.Matrix00 = -0.897; $matrix.Matrix10 = -1.761; $matrix.Matrix20 = -0.342; $matrix.Matrix40 = 2.3
                $matrix.Matrix01 = -0.897; $matrix.Matrix11 = -1.761; $matrix.Matrix21 = -0.342; $matrix.Matrix41 = 2.3
                $matrix.Matrix02 = -0.897; $matrix.Matrix12 = -1.761; $matrix.Matrix22 = -0.342; $matrix.Matrix42 = 2.3
            }
            $attributes.SetColorMatrix($matrix)
            $graphics.DrawImage($crop, [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height), 0, 0, $crop.Width, $crop.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
        } finally { $attributes.Dispose(); $graphics.Dispose() }
        return $bitmap
    } finally { if (-not [Object]::ReferenceEquals($crop, $Source)) { $crop.Dispose() } }
}
function Read-Crop([string]$Path, [string]$Name, [int]$Skip = 0, [switch]$Light) {
    $source = [Drawing.Bitmap]::new($Path)
    $variants = @()
    try {
        $factor = [int][Math]::Min(6, [Math]::Max(1, [Math]::Ceiling(1600 / [Math]::Max(1, ($source.Width - $Skip)))))
        if ($Skip -gt 0) {
            $variants += @{ skip = $Skip; scale = $factor; threshold = 160; psm = 11; light = $false; file = "$Name-readable.png" }
            $variants += @{ skip = 0; scale = 6; threshold = 160; psm = 6; light = $false; file = "$Name-variant-2.png" }
            $variants += @{ skip = 0; scale = 1; threshold = -1; psm = 11; light = $false; file = "$Name-variant-3.png" }
        } else {
            $variants += @{ skip = 0; scale = $factor; threshold = 0; psm = 11; light = $Light.IsPresent; file = "$Name-readable.png" }
            $variants += @{ skip = 0; scale = 6; threshold = 160; psm = 6; light = $Light.IsPresent; file = "$Name-variant-2.png" }
            $variants += @{ skip = 0; scale = 1; threshold = -1; psm = 11; light = $false; file = "$Name-variant-3.png" }
        }
        $readings = @()
        foreach ($variant in $variants) {
            $bitmap = $null
            try {
                $bitmap = Save-Variant $source $variant.skip $variant.scale $variant.threshold $variant.light
                $bitmap.Save("$Evidence/$($variant.file)", [Drawing.Imaging.ImageFormat]::Png)
            } finally { if ($null -ne $bitmap) { $bitmap.Dispose() } }
            $lines = Invoke-ServerNative -FilePath $ocr -Arguments @("$Evidence/$($variant.file)", 'stdout', '--psm', [string]$variant.psm) -Evidence $Evidence -Name ("$([IO.Path]::GetFileNameWithoutExtension($variant.file))-ocr")
            $readings += @{ variant = "skip=$($variant.skip) scale=$($variant.scale) threshold=$($variant.threshold) psm=$($variant.psm)"; text = (($lines -join ' ') -replace '\s+', ' ').Trim() }
        }
    } finally { $source.Dispose() }
    [IO.File]::WriteAllText("$Evidence/$Name-variants.txt", (($readings | ForEach-Object { "$($_.variant) => $($_.text)" }) -join "`n"))
    return (($readings | ForEach-Object { $_.text }) -join ' ') -replace '\s+', ' '
}
function Picker-Shot([string]$Name) {
    [void](Shot $Name)
    $focus = [IntPtr]([ChatDeliveryDesktop]::Focus($main)[1])
    if ([ChatDeliveryDesktop]::Class($focus) -ne 'Edit') { throw 'Member search is not focused' }
    $bounds = [Windows.Automation.AutomationElement]::FromHandle($focus).Current.BoundingRectangle
    $roomBounds = [Windows.Automation.AutomationElement]::FromHandle((Room-Window)).Current.BoundingRectangle
    $scale = $bounds.Height / 32
    $top = [int]($bounds.Bottom + 12 * $scale)
    $height = [int][Math]::Min(250 * $scale, $roomBounds.Bottom - $top - 84 * $scale)
    if ($height -lt 1) { throw 'Member result list has no readable area' }
    $source = [Drawing.Bitmap]::new("$Evidence/$Name.png")
    try {
        $crop = $source.Clone([Drawing.Rectangle]::new([int]$bounds.Left, $top, [int]$bounds.Width, $height), $source.PixelFormat)
        try { $crop.Save("$Evidence/$Name-list.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $crop.Dispose() }
    } finally { $source.Dispose() }
    $text = Read-Crop "$Evidence/$Name-list.png" "$Name-list" -Skip ([int](44 * $scale))
    [IO.File]::WriteAllText("$Evidence/$Name-list-visible.txt", $text)
    return $text
}
function Clear-Member-Search {
    $room = Room-Window
    if (-not $room) { throw 'No room dialog to clear the member search in' }
    $fields = @(Visible-Children 'Edit' $room)
    $edit = [IntPtr]([ChatDeliveryDesktop]::Focus($main)[1])
    if ($fields.Count -lt 2 -or [ChatDeliveryDesktop]::Class($edit) -ne 'Edit') { throw 'Member search is not focused' }
    $tops = @($fields | ForEach-Object { [Windows.Automation.AutomationElement]::FromHandle($_).Current.BoundingRectangle.Top })
    if ([Windows.Automation.AutomationElement]::FromHandle($edit).Current.BoundingRectangle.Top -le ($tops | Measure-Object -Minimum).Minimum) { throw 'Member search is not the field below the room name' }
    $text = [ChatDeliveryDesktop]::Text($edit)
    for ($i = 0; $i -lt $text.Length; $i++) { Press @(0x08) 'Backspace: clear the earlier member query' }
    [void](Wait-For 'member search cleared before the next name' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 10)
}
function Dialog-Shot([string]$Name) {
    [void](Shot $Name)
    $roomBounds = [Windows.Automation.AutomationElement]::FromHandle((Room-Window)).Current.BoundingRectangle
    $top = [int]($roomBounds.Bottom - 0.22 * $roomBounds.Height)
    $height = [int](0.12 * $roomBounds.Height)
    $left = [int]($roomBounds.Left + 0.5 * $roomBounds.Width)
    if ($height -lt 1 -or $roomBounds.Right -le $left) { throw 'Room dialog footer has no readable area' }
    $source = [Drawing.Bitmap]::new("$Evidence/$Name.png")
    try {
        $crop = $source.Clone([Drawing.Rectangle]::new($left, $top, [int]($roomBounds.Right - $left), $height), $source.PixelFormat)
        try { $crop.Save("$Evidence/$Name-footer.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $crop.Dispose() }
    } finally { $source.Dispose() }
    $text = Read-Crop "$Evidence/$Name-footer.png" "$Name-footer" -Light
    [IO.File]::WriteAllText("$Evidence/$Name-footer-visible.txt", $text)
    return $text
}
function Read-Room([string]$Name, [switch]$Existing) {
    if (-not $Existing.IsPresent) { [void](Shot $Name) }
    $room = Room-Window
    if (-not $room) { throw 'No visible room to read' }
    $bounds = [Windows.Automation.AutomationElement]::FromHandle($room).Current.BoundingRectangle
    $source = [Drawing.Bitmap]::new("$Evidence/$Name.png")
    try {
        $crop = $source.Clone([Drawing.Rectangle]::new([int]$bounds.Left, [int]$bounds.Top, [int]$bounds.Width, [int]$bounds.Height), $source.PixelFormat)
        try { $crop.Save("$Evidence/$Name-room.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $crop.Dispose() }
    } finally { $source.Dispose() }
    return Read-Crop "$Evidence/$Name-room.png" "$Name-room"
}
function Wait-RoomPresented([string]$Name) {
    $state = Snapshot "$Name-presented"
    $room = @(Room-Data $state)[0]
    if ($null -eq $room) { return }
    $roomId = [string]$room.id
    $count = @(Room-Events $state | Where-Object { ($_.type -eq 'human' -or $_.type -eq 'agent_reply') -and $_.room_id -eq $roomId }).Count
    if ($count -le 0) { return }
    $pattern = '\[rooms\] view presented room=' + [regex]::Escape($roomId) + ' after=\d+ messages=(\d+)'
    [void](Wait-For "room view presents all $count saved room messages" {
        $log = Read-Shared "$settings/debug.log"
        $open = $log.LastIndexOf('[rooms] view opened')
        if ($open -lt 0) { $open = 0 }
        $rows = [regex]::Matches($log.Substring($open), $pattern)
        if ($rows.Count -eq 0) { return $false }
        ([int]$rows[$rows.Count - 1].Groups[1].Value -ge $count)
    } 30)
}
function Shot-Room([string]$Name) {
    Doctor
    $room = Room-Window
    if (-not $room) { throw 'No visible room to read' }
    Wait-RoomPresented $Name
    [RoomsDesktop]::Wheel($main, $room, $app.Id, 7200)
    $pages = @()
    $previous = ''
    for ($page = 0; $page -lt 16; $page++) {
        $shot = Shot "$Name-page-$page"
        $text = (($shot + ' ' + (Read-Room "$Name-page-$page" -Existing)) -replace '\s+', ' ').Trim()
        [IO.File]::WriteAllText("$Evidence/$Name-page-$page-visible.txt", $text)
        if ($page -gt 0 -and $text -ceq $previous) { break }
        $pages += $text
        $previous = $text
        $actions.Add(@{ input = 'wheel room history'; delta = -480; seconds = $clock.Elapsed.TotalSeconds })
        [RoomsDesktop]::Wheel($main, $room, $app.Id, -480)
    }
    $text = $pages -join ' '
    [IO.File]::WriteAllText("$Evidence/$Name-all-visible.txt", $text)
    return $text
}
function Case([string]$Step, [string]$Name, [string]$Missing, [scriptblock]$Body) {
    $Name = $planned[$Step]
    $case = @{ step = $Step; name = $Name; status = 'UNREACHABLE'; symptom = $Missing; seconds = $clock.Elapsed.TotalSeconds; screenshot = "step-$Step.png" }
    if (-not $Missing) {
        try { & $Body; $case.status = 'PASS'; $case.symptom = 'Visible UI and saved state agree' }
        catch { $case.status = 'FAIL'; $case.symptom = $_.Exception.Message }
    }
    try { [void](Shot "step-$Step"); [void](Snapshot "step-$Step"); Copy-Debug "step-$Step" } catch { $result.driverErrors += $_.ToString() }
    $case.seconds = $clock.Elapsed.TotalSeconds
    $result.cases += $case
    Save $result "$Evidence/result.json"
    Write-Host ("STEP $Step $Name $($case.status): $($case.symptom)")
}
function Session-Saved {
    $text = Read-Shared "$settings/session.json"
    if (-not $text) { return $null }
    try { return ($text | ConvertFrom-Json) } catch { return $null }
}
function Saved-Tabs($Saved) {
    if ($null -eq $Saved -or -not $Saved.PSObject.Properties['tabs']) { return @() }
    return @($Saved.tabs)
}
function Copy-Chat([string]$Name) {
    [void](Wait-For 'clipboard available for this copy' { try { [Windows.Forms.Clipboard]::Clear(); $true } catch { $false } } 10)
    Invoke-JourneyCommand 'chat view select all'
    Press @(0x11, 0x43) 'Ctrl+C: copy visible chat messages'
    $text = Wait-For 'copied chat text' { try { $value = [Windows.Forms.Clipboard]::GetText(); if ($value) { $value } } catch { $null } } 10
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
    Press @(0x1B) 'Escape: return to composer'
    return $text
}
function Open-Member([string]$Name) {
    Invoke-JourneyCommand $Name -Session
    if (-not @(Visible-Children 'ZigShellChatTranscript').Count) { Press @(0x12, 0x43) 'Alt+C: open member Chat View' }
    [void](Wait-For 'member composer' { $windows = @(Visible-Children 'Edit'); if ($windows.Count -eq 1) { $windows[0] } })
    [void](Wait-For "$Name hosted chat identity hydrated" {
        $saved = Session-Saved
        $tabs = Saved-Tabs $saved
        if ($null -eq $saved -or -not $saved.PSObject.Properties['active_tab']) { return $false }
        $index = [int]$saved.active_tab
        if ($index -lt 0 -or $index -ge $tabs.Count) { return $false }
        $tab = $tabs[$index]
        $tab.PSObject.Properties['name'] -and $tab.name -ceq $Name -and $tab.PSObject.Properties['ai_agent'] -and $tab.ai_agent -eq 1 -and $tab.PSObject.Properties['csid'] -and $tab.csid -like 'a1b2c3d4-0534-*'
    })
}
function Send-Text([string]$Text, [switch]$Room, [switch]$AllowKeptDraft) {
    $parent = if ($Room) { Room-Window } else { $main }
    $edit = Wait-For 'one visible composer' { $windows = @(Visible-Children 'Edit' $parent); if ($windows.Count -eq 1) { $windows[0] } }
    Focus-Control $edit
    Press @(0x11, 0x41) 'Ctrl+A: replace any earlier unsent draft'
    Press @(0x08) 'Backspace: clear earlier draft before this independent send'
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $kept = [ChatDeliveryDesktop]::Text($edit)
        if ($kept.Length -eq 0) { break }
        for ($i = 0; $i -lt $kept.Length; $i++) { Press @(0x08) 'Backspace: delete the kept draft one character at a time' }
    }
    [void](Wait-For 'empty composer before typing' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 10)
    Type-Text $Text
    [void](Wait-For 'exact typed composer text' { [ChatDeliveryDesktop]::Text($edit) -ceq $Text })
    Press @(0x1B) 'Escape: dismiss mention suggestions'
    Press @(0x0D) 'Enter: send message'
    if ($AllowKeptDraft) {
        $sendDeadline = [Diagnostics.Stopwatch]::StartNew()
        while ($sendDeadline.Elapsed.TotalSeconds -lt 5) {
            if ([ChatDeliveryDesktop]::Text($edit) -ceq '') { return }
            [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
        }
        return
    }
    [void](Wait-For 'composer clears after send' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 15)
}
function Release-Replies([string]$Marker) {
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-release.py $Marker") -Evidence $Evidence -Name ("release-$Marker"))
}
function Await-Replies([string]$Marker) {
    [void](Wait-For "exactly two saved $Marker replies" { @(Room-Events (Snapshot "$Marker-poll") | Where-Object { $_.type -eq 'agent_reply' -and $_.text -like "* says $Marker" }).Count -eq 2 } 60)
}
function Restart-Desktop {
    [void](Shot 'before-restart')
    Copy-Item "$settings/debug.log" "$Evidence/before-restart-debug.log" -ErrorAction SilentlyContinue
    $cleanup = $job.Stop()
    if ($cleanup.ActiveProcesses -ne 0) { throw 'Owned desktop did not stop' }
    $job.Dispose()
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, "$Evidence/restart-stdout.log", "$Evidence/restart-stderr.log", '--single-window')
    $script:main = Wait-For 'restarted owned desktop window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::MoveWindow($main, 0, 0, [ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1), $true)
    Doctor
}
try {
    if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use GitHub Windows only' }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Security, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/job.cs"
    Add-Type -Path "$PSScriptRoot/rooms-desktop.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $ocr = 'C:/Program Files/Tesseract-OCR/tesseract.exe'
    if (-not (Test-Path $ocr)) { throw 'Tesseract not installed' }
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'repo-path').Trim()
    & "$PSScriptRoot/../../../tools/verify-server-chat/start.ps1" -Profile $profile -Evidence $Evidence
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $keygen = "$env:SystemRoot/System32/OpenSSH/ssh-keygen.exe"
    $identity = "$profile/home/.ssh/id_ed25519"
    [void](Invoke-ServerNative -FilePath $keygen -Arguments @('-q', '-t', 'ed25519', '-N', '', '-C', 'rooms-journey', '-f', $identity) -Evidence $Evidence -Name 'rooms-identity')
    $identityPublic = ((Get-Content "$identity.pub" -Raw).Trim() -split ' ' | Select-Object -First 2) -join ' '
    $identityCommand = "umask 077 && mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && if grep -qF '$identityPublic' ~/.ssh/authorized_keys; then :; else printf '%s\n' '$identityPublic' >> ~/.ssh/authorized_keys; fi"
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', $identityCommand) -Evidence $Evidence -Name 'rooms-identity-authorize')
    $plainConfig = @"
Host remote-1
  HostName 127.0.0.1
  Port 2222
  User mpverify
  IdentityFile "$($identity.Replace('\', '/'))"
  IdentitiesOnly yes
  IdentityAgent none
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile "$((Join-Path $profile 'home/.ssh/known_hosts').Replace('\', '/'))"
"@
    [IO.File]::WriteAllText("$profile/home/.ssh/config", $plainConfig)
    $plain = (Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$profile/home/.ssh/config", 'remote-1', 'uname -s') -Evidence $Evidence -Name 'rooms-plain-ssh').Trim()
    if ($plain -ne 'Linux') { throw "Plain ssh remote-1 is not usable by the room transport: $plain" }
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-seed.py $repo") -Evidence $Evidence -Name 'members-seed')
    $watcher = [IO.FileSystemWatcher]::new($profile)
    $watcher.IncludeSubdirectories = $true
    $accountHost = 'account.multiprompt.dev'
    $cert = New-SelfSignedCertificate -DnsName $accountHost -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(1)
    $password = [guid]::NewGuid().ToString('N')
    $secure = ConvertTo-SecureString $password -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath "$profile/account.pfx" -Password $secure | Out-Null
    Export-Certificate -Cert $cert -FilePath "$profile/account.cer" | Out-Null
    Import-Certificate -FilePath "$profile/account.cer" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    [IO.File]::AppendAllText($hostsFile, "`r`n127.0.0.1 $accountHost`r`n")
    $serviceJob = [VerifyJob]::new()
    $service = $serviceJob.Start((Get-Command node.exe).Source, $env:GITHUB_WORKSPACE, "$profile/service.log", "$profile/service.err.log", "service/journey/server.mjs --port=443 --pfx=$profile/account.pfx --pfxpass=$password --state=$profile/account-state.json")
    [void](Wait-For 'runner account Worker ready' { try { Invoke-RestMethod "https://$accountHost/health" | Out-Null; Test-Path "$profile/account-state.json" } catch { $false } } 90)
    $secrets = Get-Content "$profile/account-state.json" -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes("$settings/account-device.dat", [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $keyLine = (Get-Content "$profile/home/.ssh/known_hosts" | Select-Object -First 1) -split ' '
    $tabs = @(@{ kind = 'tmux'; name = 'Alpha'; tmux_session = 'rooms-alpha'; csid = 'a1b2c3d4-0534-4000-8000-000000000001'; tmux_host = 0; workspace = 'Rooms check'; manual = $true }, @{ kind = 'tmux'; name = 'Bravo'; tmux_session = 'rooms-bravo'; csid = 'a1b2c3d4-0534-4000-8000-000000000002'; tmux_host = 0; workspace = 'Rooms check'; manual = $true })
    $layout = @{ schema = 1; revision = 1; workspaces = @(@{ name = 'Rooms check' }); tabs = $tabs; hosts = @(@{ slot = 0; name = 'Runner Linux'; hostname = '127.0.0.1'; port = 2222; user = 'mpverify'; host_keys = @($keyLine[1] + ' ' + $keyLine[2]) }) }
    $headers = @{ Authorization = 'Bearer ' + $secrets.admin_key; 'X-Layout-Features' = 'hosts,csid' }
    $current = Invoke-RestMethod "https://$accountHost/v1/layout" -Headers $headers
    Invoke-RestMethod "https://$accountHost/v1/layout" -Method Put -Headers $headers -ContentType 'application/json' -Body (@{ base_revision = $current.revision; layout = $layout } | ConvertTo-Json -Depth 15) | Out-Null
    Save $layout "$Evidence/fixture-layout.json"
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:USERPROFILE = "$profile/home"
    $env:HOME = "$profile/home"
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    Remove-Item Env:\MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = Wait-For 'owned desktop window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::MoveWindow($main, 0, 0, [ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1), $true)
    [void](Wait-For 'two account-owned chats imported' { $saved = Read-Shared "$settings/session.json"; $saved.Contains('rooms-alpha') -and $saved.Contains('rooms-bravo') } 90)
    $createRoom = {
        $bridgeOffset = (Read-Shared "$settings/debug.log").Length
        Invoke-JourneyCommand 'New room'
        $room = Wait-For 'new room view' { Room-Window }
        $edit = [IntPtr]([ChatDeliveryDesktop]::Focus($main)[1])
        if ([ChatDeliveryDesktop]::Class($edit) -ne 'Edit') { throw 'New room did not focus its name field' }
        Type-Text 'Rooms534'
        [void](Wait-For 'room name typed' { [ChatDeliveryDesktop]::Text($edit) -ceq 'Rooms534' })
        Press @(0x09) 'Tab: find the first room member'
        Type-Text 'Alpha'
        [void](Wait-For 'Alpha available in the creation member results' { (Picker-Shot 'create-alpha') -match '\bAlpha\b' })
        Press @(0x0D) 'Enter: select Alpha as the first member'
        [void](Wait-For 'one selected creation member' { (Dialog-Shot 'create-selected') -match 'Create\s*[^0-9]{0,3}1\b' })
        [void](Shot 'create-before')
        Press @(0x11, 0x0D) 'Ctrl+Enter: create the room with its first member'
        [void](Wait-For 'room persisted' { (Room-Data (Snapshot 'create-poll')).Count -eq 1 })
        if ((Shot 'create-after') -notmatch 'Rooms534') { throw 'Saved room is not shown in its room view' }
        $published = Wait-For 'the room create published the shared chat helper on this host' {
            $match = [regex]::Match((Read-Shared "$settings/debug.log").Substring($bridgeOffset), '\[room_bridge\] (published runtime|runtime already published) [0-9a-f]{12}')
            if (-not $match.Success) { return $null }
            $match.Value
        }
        [IO.File]::WriteAllText("$Evidence/room-bridge-published.txt", $published)
        $result.observations += @{ fact = 'the room create published the shared chat helper on this host'; line = $published }
    }
    Case 1 '' '' $createRoom
    Case 'private' '' '' {
        Press @(0x1B) 'Escape: close any open room editor before private chats'
        foreach ($name in @('Alpha', 'Bravo')) {
            Open-Member $name
            Send-Text 'PRIVATE534'
            [void](Wait-For "$name real private reply" { (Copy-Chat "$name-private").Contains("$name says PRIVATE534") })
            [void](Shot "$name-private")
        }
        Save @{ status = 'PASS'; detail = 'Both chats replied through the real desktop composer, SSH, host, provider and transcript before sending a room question' } "$Evidence/preflight.json"
    }
    $closedBravo = $false
    $hasRoom = (Room-Data (Snapshot 'after-create')).Count -eq 1
    $result.observations += @{ fact = 'fresh-profile create reached the room service'; store_created = (@((Snapshot 'after-create').rooms).Count -gt 0) }
    if (-not $hasRoom) {
        $planned['1-warm'] = 'Diagnostic: retry creation from an open member chat'
        $warmCreate = {
            try { Open-Member 'Bravo' } catch { $result.driverErrors += "Warm retry could not open Bravo: $($_.Exception.Message)" }
            & $createRoom
        }
        Case '1-warm' '' '' $warmCreate
        $hasRoom = (Room-Data (Snapshot 'after-warm-create')).Count -eq 1
    }
    Case 2 'Add two member chats' $(if (-not $hasRoom) { 'No saved Rooms534 room was created' } else { '' }) {
        Open-Member 'Bravo'
        [void](Wait-For 'Bravo is the visible chat before closing it' {
            $saved = Session-Saved
            $tabs = Saved-Tabs $saved
            if ($null -eq $saved -or -not $saved.PSObject.Properties['active_tab']) { return $false }
            $index = [int]$saved.active_tab
            $index -ge 0 -and $index -lt $tabs.Count -and $tabs[$index].name -ceq 'Bravo' -and -not (Room-Window)
        })
        $bravoGone = { @(Saved-Tabs (Session-Saved) | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -eq 'rooms-bravo' }).Count -eq 0 }
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            if (& $bravoGone) { break }
            Press @(0x11, 0x10, 0x57) "Ctrl+Shift+W: close Bravo before the room picker (attempt $attempt)"
            try { [void](Wait-For 'Bravo no longer an open tab' $bravoGone 15) } catch { if ($attempt -eq 3) { throw } }
        }
        [void](Shot 'bravo-closed')
        [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', 'tmux has-session -t rooms-bravo') -Evidence $Evidence -Name 'closed-bravo-still-on-server')
        $script:closedBravo = $true
        Invoke-JourneyCommand -Text 'Rooms534'
        Invoke-JourneyCommand 'Edit room'
        $room = Wait-For 'room editor' { Room-Window }
        Press @(0x09) 'Tab: search member chats'
        Clear-Member-Search
        Type-Text 'Alpha'
        [void](Wait-For 'Alpha visible in member results' { (Picker-Shot 'members-alpha') -match '\bAlpha\b' })
        $alpha = @((Snapshot 'members-before').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 -and $_.display_name -ceq 'Alpha' })
        if ($alpha.Count -eq 0) { Press @(0x0D) 'Enter: select Alpha' }
        Clear-Member-Search
        Type-Text 'Bravo'
        [void](Wait-For 'Bravo visible in member list' { (Picker-Shot 'members-bravo') -match '\bBravo\b' })
        Press @(0x0D) 'Enter: select Bravo'
        Press @(0x11, 0x0D) 'Ctrl+Enter: save room members'
        [void](Wait-For 'both saved members' { $s = Snapshot 'members-poll'; @($s.rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2 })
        $visible = Shot 'members-after'
        if ($visible -notmatch 'Rooms534') { throw 'Room did not reopen after saving members' }
    }
    Case '2-open' '' $(if (-not $hasRoom) { 'No saved room' } else { '' }) {
        $edits = { $room = Room-Window; if ($room) { @(Visible-Children 'Edit' $room).Count } else { 0 } }
        for ($attempt = 0; $attempt -lt 3 -and (& $edits) -gt 1; $attempt++) {
            Press @(0x1B) 'Escape: close the room editor before the palette reopen'
            [void](Wait-For 'room editor closed' { (& $edits) -le 1 } 10)
        }
        if ((& $edits) -gt 1) { throw 'The room editor stayed open, so the reopened chat cannot be reached' }
        if ($closedBravo) { Invoke-JourneyCommand 'Reopen closed tab' }
        Open-Member 'Bravo'
        Send-Text 'PRIVATE534'
        [void](Wait-For 'reopened Bravo real private reply' { (Copy-Chat 'Bravo-reopened').Contains('Bravo says PRIVATE534') })
        Invoke-JourneyCommand -Text 'Rooms534'
        Invoke-JourneyCommand 'Edit room'
        [void](Wait-For 'room editor' { Room-Window })
        Press @(0x09) 'Tab: member search'
        foreach ($name in @('Alpha', 'Bravo')) {
            Clear-Member-Search
            Type-Text $name
            [void](Wait-For "$name listed" { (Picker-Shot "reopened-picker-$name") -match ([regex]::Escape($name)) })
            $members = @((Snapshot 'reopened-members').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 -and $_.display_name -ceq $name })
            if ($members.Count -eq 0) { Press @(0x0D) "Enter: select $name" }
        }
        Press @(0x11, 0x0D) 'Ctrl+Enter: save reopened members'
        [void](Wait-For 'two members after reopening' { @((Snapshot 'reopened-poll').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2 })
    }
    $hasMembers = @((Snapshot 'after-members').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2
    Case 3 'Send a room message' $(if (-not $hasRoom) { 'No saved room' } else { '' }) {
        Open-Room 'Rooms534'
        Send-Text 'BROADCAST534' -Room -AllowKeptDraft
        try { [void](Wait-For 'saved human room event' { @(Room-Events (Snapshot 'send-poll') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'BROADCAST534' }).Count -eq 1 } 20) }
        catch { throw "The room did not accept a plain send; room shows: $((Shot 'send-refused'))" }
        if ((Read-Room 'send-after') -notmatch 'BROADCAST534') { throw 'Saved room message is not visible in the room' }
    }
    $sent = @(Room-Events (Snapshot 'after-send') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'BROADCAST534' }).Count -eq 1
    Case 4 'Every member replies in the room' $(if (-not $sent) { 'No saved BROADCAST534 room message' } elseif (-not $hasMembers) { 'The room has fewer than two saved members' } else { '' }) {
        [void](Wait-For 'one room reply from each member' { $events = @(Room-Events (Snapshot 'replies-poll') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -match 'BROADCAST534' }); $events.Count -eq 2 -and @($events.member_id | Select-Object -Unique).Count -eq 2 } 90)
        [void](Wait-For 'both broadcast turns finished' { $s = Snapshot 'broadcast-settled'; $s.hosts.Count -ge 2 -and @($s.hosts | Where-Object { $_.inflight -or $_.queued }).Count -eq 0 })
        $final = @(Room-Events (Snapshot 'broadcast-final') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -match 'BROADCAST534' })
        if ($final.Count -ne 2) { throw "Plain send produced $($final.Count) replies, expected exactly 2" }
        $visible = Shot-Room 'replies-after'
        if ($visible -notmatch 'Alpha says BROADCAST534' -or $visible -notmatch 'Bravo says BROADCAST534') { throw 'Saved member replies are not both visible in the room' }
    }
    Case 5 'Mention only Alpha' $(if (-not $hasMembers) { 'The room has fewer than two saved members' } else { '' }) {
        Open-Room 'Rooms534'
        Send-Text '@Alpha TARGET534' -Room -AllowKeptDraft
        $accepted = $true
        try { [void](Wait-For 'saved @Alpha room message' { @(Room-Events (Snapshot 'mention-poll') | Where-Object { $_.type -eq 'human' -and $_.text -ceq '@Alpha TARGET534' }).Count -eq 1 } 20) }
        catch { $accepted = $false }
        $visible = Shot-Room 'mention-after'
        if (-not $accepted) { throw "The room did not accept '@Alpha TARGET534' typed with the displayed chat name; room shows: $visible" }
        [void](Wait-For 'one saved Alpha reply to the mention' { $t = Snapshot 'mention-reply'; $replies = @(Room-Events $t | Where-Object { $_.type -eq 'agent_reply' -and $_.text -match 'TARGET534' }); $replies.Count -eq 1 -and $replies[0].text -ceq 'Alpha says TARGET534' } 45)
        $t = Snapshot 'mention-after'
        $inputs = @($t.inputs | Where-Object { $_.marker -ceq 'TARGET534' })
        if ($inputs.Count -ne 1 -or $inputs[0].sid -notlike '*0001') { throw 'Mention reached a member other than Alpha, or reached it more than once' }
        $visible = Shot-Room 'mention-visible'
        if ($visible -notmatch 'Alpha says TARGET534' -or $visible -match 'Bravo says TARGET534') { throw 'The room does not show only the mentioned member replying' }
    }
    $savedReplies = @(Room-Events (Snapshot 'before-order') | Where-Object { $_.type -eq 'agent_reply' })
    Case 6 'Same replies in room and both member views' $(if (-not $sent) { 'No saved room question' } elseif ($savedReplies.Count -lt 2) { 'Fewer than two saved replies; shared reply order cannot be compared' } else { '' }) {
        $state = Snapshot 'order-before'
        $replies = @(Room-Events $state | Where-Object { $_.type -eq 'agent_reply' })
        if ($replies.Count -lt 2) { throw 'Saved room contains fewer than two member replies; there is no shared reply order' }
        $problems = @()
        foreach ($name in @('Alpha', 'Bravo')) {
            Open-Member $name
            $copied = Copy-Chat "$name-room-history"
            [void](Shot "$name-room-history")
            $sid = if ($name -ceq 'Alpha') { 'a1b2c3d4-0534-4000-8000-000000000001' } else { 'a1b2c3d4-0534-4000-8000-000000000002' }
            $canonical = @($state.transcripts.PSObject.Properties | Where-Object { $_.Name -like "*/$sid.jsonl" } | ForEach-Object { $_.Value } | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text })
            Save $canonical "$Evidence/$name-canonical-replies.json"
            $canonicalPosition = -1
            foreach ($reply in $replies) {
                $next = -1
                for ($index = $canonicalPosition + 1; $index -lt $canonical.Count; $index++) {
                    if ($canonical[$index] -ceq $reply.text) { $next = $index; break }
                }
                if ($next -lt 0) { $problems += "$name saved transcript is missing or reorders assistant reply '$($reply.text)'" } else { $canonicalPosition = $next }
            }
            $position = -1
            foreach ($reply in $replies) {
                $next = $copied.IndexOf($reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
                if ($next -lt 0) { $problems += "$name chat is missing or reorders '$($reply.text)'" } else { $position = $next }
            }
        }
        Invoke-JourneyCommand -Text 'Rooms534'
        $visible = Shot-Room 'room-order'
        $position = -1
        foreach ($reply in $replies) {
            $next = $visible.IndexOf($reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
            if ($next -lt 0) { $problems += "Room view is missing or reorders '$($reply.text)'" } else { $position = $next }
        }
        Save @{ roomSequence = $replies; differences = $problems } "$Evidence/order-comparison.json"
        if ($problems.Count) { throw ($problems -join '; ') }
    }
    $missingMembers = if (-not $hasRoom) { 'No saved room' } elseif (-not $hasMembers) { 'Fewer than two saved members' } else { '' }
    Case 7 'e: Replies received while away' $missingMembers {
        Open-Room 'Rooms534'
        Send-Text 'AWAY534' -Room
        [void](Wait-For 'both providers holding unanswered away question' { @((Snapshot 'away-held').inputs | Where-Object { $_.marker -ceq 'AWAY534' }).Count -eq 2 })
        Open-Member 'Alpha'
        [void](Shot 'away-before-release')
        Release-Replies 'AWAY534'
        [void](Wait-For 'both providers answered while the room was closed' { @((Snapshot 'away-answered').inputs | Where-Object { $_.marker -ceq 'AWAY534' }).Count -eq 2 } 30)
        $savedWhileAway = @(Room-Events (Snapshot 'away-while-closed') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -like '* says AWAY534' }).Count
        $result.observations += @{ fact = 'saved room replies while the room was closed'; count = $savedWhileAway; expected = 2 }
        Invoke-JourneyCommand -Text 'Rooms534'
        [void](Wait-For 'both away replies saved after returning to the room' { @(Room-Events (Snapshot 'away-return-poll') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -like '* says AWAY534' }).Count -eq 2 } 60)
        $visible = Shot-Room 'away-return'
        if ($visible -notmatch 'Alpha says AWAY534' -or $visible -notmatch 'Bravo says AWAY534') { throw 'Replies that arrived while away are missing after returning to the room' }
    }
    Case 8 'f: Restart with an unanswered question' $missingMembers {
        Open-Room 'Rooms534'
        Send-Text 'RESTART534' -Room
        [void](Wait-For 'both providers holding restart question' { @((Snapshot 'restart-held').inputs | Where-Object { $_.marker -ceq 'RESTART534' }).Count -eq 2 })
        if (@(Room-Events (Snapshot 'restart-unanswered') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -like '* says RESTART534' }).Count) { throw 'Driver gate released the restart reply too early' }
        Open-Member 'Alpha'
        Restart-Desktop
        [void](Wait-For 'private chat restored without opening room' { @(Visible-Children 'ZigShellChatTranscript').Count -gt 0 })
        if (Room-Window) { throw 'Driver precondition failed: restart reopened the room' }
        Release-Replies 'RESTART534'
        Await-Replies 'RESTART534'
        [void](Shot 'restart-replies-with-room-closed')
        Invoke-JourneyCommand -Text 'Rooms534'
        $visible = Shot-Room 'restart-return'
        if ($visible -notmatch 'Alpha says RESTART534' -or $visible -notmatch 'Bravo says RESTART534') { throw 'Restarted desktop lost answers to the unanswered room question' }
    }
    Case 9 '' 'The existing Android photo harness needs a companion checkout and has no Rooms read action; this Windows job has no Android client. Paired ticket MUBO-536' {}
    Case 10 '' 'The existing Android photo harness has no Rooms retry action; this Windows job has no Android client. Paired ticket MUBO-536' {}
    Case 12 '' $missingMembers {
        Open-Room 'Rooms534'
        Send-Text 'FAIL534' -Room
        [void](Wait-For 'both provider failure receipts' { @((Snapshot 'failed-turn').inputs | Where-Object { $_.marker -ceq 'FAIL534' }).Count -eq 2 })
        [void](Wait-For 'visible failed member turn' { (Shot 'failed-turn') -match 'Restart|failed|unavailable|error' })
        Press @(0x10, 0x09) 'Shift+Tab: focus failed member Restart'
        Press @(0x0D) 'Enter: restart failed member'
        Await-Replies 'FAIL534'
        $visible = Shot-Room 'failed-turn-recovered'
        if ($visible -notmatch 'Alpha says FAIL534' -or $visible -notmatch 'Bravo says FAIL534') { throw 'Failed room question remains unanswered after using Restart' }
    }
    Case 13 '' 'No controllable lost-acknowledgement boundary in the desktop harness; retry safety is not proven by an ordinary send' {}
    $historyReplies = @(Room-Events (Snapshot 'before-history') | Where-Object { $_.type -eq 'agent_reply' })
    Case 14 '' $(if (-not $sent) { 'No saved room question to reload' } elseif ($historyReplies.Count -eq 0) { 'No saved replies to check for stale or missing history' } else { '' }) {
        $before = @(Room-Events (Snapshot 'history-before') | Where-Object { $_.type -eq 'agent_reply' })
        if ($before.Count -eq 0) { throw 'No saved replies exist to check for stale or missing history' }
        Open-Member 'Alpha'
        Invoke-JourneyCommand -Text 'Rooms534'
        $visible = Shot-Room 'history-reloaded'
        foreach ($reply in $before) {
            if ($visible -notmatch [regex]::Escape($reply.text)) { throw "Room history is missing saved reply '$($reply.text)' after reopening" }
        }
        $after = @(Room-Events (Snapshot 'history-after') | Where-Object { $_.type -eq 'agent_reply' })
        if (($before.id -join ',') -cne ($after.id -join ',')) { throw 'Saved reply identities or order changed after history load' }
    }
    Case 11 '' $(if (-not $hasRoom) { 'No existing saved room to discover' } else { '' }) {
        $fresh = "$profile/fresh"
        New-Item -ItemType Directory -Force "$fresh/roaming/ZigShell", "$fresh/local", "$fresh/home/.ssh" | Out-Null
        foreach ($file in @('account-device.dat', 'ssh-path.txt')) { Copy-Item "$settings/$file" "$fresh/roaming/ZigShell/$file" }
        Copy-Item "$settings/ssh-key" "$fresh/roaming/ZigShell/ssh-key" -Recurse
        foreach ($file in @('known_hosts', 'config', 'id_ed25519', 'id_ed25519.pub')) { if (Test-Path "$profile/home/.ssh/$file") { Copy-Item "$profile/home/.ssh/$file" "$fresh/home/.ssh/$file" } }
        $env:APPDATA = "$fresh/roaming"
        $env:LOCALAPPDATA = "$fresh/local"
        $env:USERPROFILE = "$fresh/home"
        $env:HOME = "$fresh/home"
        Restart-Desktop
        $script:settings = "$fresh/roaming/ZigShell"
        [void](Wait-For 'account chats imported on fresh install' { (Read-Shared "$settings/session.json").Contains('rooms-alpha') } 90)
        Invoke-JourneyCommand -Text 'Rooms534'
        [void](Wait-For 'discovered existing room view' { Room-Window })
        $visible = Shot-Room 'fresh-discovery'
        if ($visible -notmatch 'Rooms534') { throw 'Existing room is missing on a fresh install of the same account' }
        if ($sent -and $visible -notmatch 'BROADCAST534') { throw 'Freshly discovered room has stale or empty saved history' }
    }
    if (@($result.cases | Where-Object { $_.status -ne 'PASS' -and $_.step -notin @('9', '10', '13') }).Count -eq 0 -and $result.driverErrors.Count -eq 0) { $result.status = 'passed' }
} catch {
    $result.driverErrors += $_.ToString()
    if ($null -ne $app -and -not $app.HasExited) { try { [void](Shot 'driver-failure') } catch {} }
} finally {
    if ($null -ne $job) { $cleanup = $job.Stop(); $result.cleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $job.Dispose() }
    if ($null -ne $serviceJob) { $cleanup = $serviceJob.Stop(); $result.serviceCleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $serviceJob.Dispose() }
    if (Test-Path "$mainSettings/debug.log") { Copy-Item "$mainSettings/debug.log" "$Evidence/debug.log" -Force }
    if ($settings -cne $mainSettings -and (Test-Path "$settings/debug.log")) { Copy-Item "$settings/debug.log" "$Evidence/fresh-debug.log" -Force }
    if (Test-Path $settings) {
        New-Item -ItemType Directory -Force "$Evidence/data" | Out-Null
        Get-ChildItem $settings -File | Where-Object { $_.Name -match '^(session.*\.json|room.*)$' } | Copy-Item -Destination "$Evidence/data"
    }
    foreach ($name in @('service.log', 'service.err.log')) { if (Test-Path "$profile/$name") { Copy-Item "$profile/$name" "$Evidence/$name" } }
    [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal)
    if ($null -ne $cert) { Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue; Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue }
    if ($null -ne $watcher) { $watcher.Dispose() }
    try {
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'wsl-terminate')
        Remove-Item $profile -Recurse -Force
        $result.scratchRemoved = -not (Test-Path $profile)
    } catch { $result.driverErrors += $_.ToString(); $result.status = 'failed' }
    foreach ($step in $planned.Keys) {
        if (-not @($result.cases | Where-Object { $_.step -eq $step }).Count) {
            $result.cases += @{ step = $step; name = $planned[$step]; status = 'UNREACHABLE'; symptom = 'Driver setup or evidence collection failed before this step; see driverErrors'; seconds = $clock.Elapsed.TotalSeconds; screenshot = $(if (Test-Path "$Evidence/driver-failure.png") { 'driver-failure.png' } else { $null }) }
        }
    }
    Save $actions "$Evidence/actions.json"
    Save $result "$Evidence/result.json"
}
if ($result.status -ne 'passed') { throw 'Rooms journey failed; inspect result.json for all independent step results and driverErrors' }
