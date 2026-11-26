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
$script:copy_attempts = 0
$script:copy_ever_read = $false
$script:dropInstalled = $false
$planned = [ordered]@{
    '1' = 'a: Create a room on a fresh profile'
    'private' = 'Both member chats reply through the real composer'
    '2' = 'b: Add two chats'
    '2-closed' = 'b2: A closed member chat stays usable'
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
    '12-interrupted' = 'Preserve an interrupted partial answer once'
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
function Trace-Step([string]$Label) {
    Write-Host ('[rooms-trace] {0,7:N1}s {1}' -f $clock.Elapsed.TotalSeconds, $Label)
    [Console]::Out.Flush()
}
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
function Read-After([int64]$Offset) {
    $log = Read-Shared "$settings/debug.log"
    if ($log.Length -le $Offset) { return '' }
    return $log.Substring($Offset)
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
function Wait-Or([scriptblock]$Check, [int]$Seconds = 5) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $value = & $Check
        if ($value) { return $value }
        if ($null -ne $app -and $app.HasExited) { throw 'Owned desktop exited' }
        [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    return $null
}
function Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    if (-not [RoomsDesktop]::OnScreen($main)) { throw 'Doctor: desktop not visible' }
    Save @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
}
function Press([int[]]$Keys, [string]$Label) {
    Trace-Step "press start: $Label"
    Doctor
    [void](Wait-For "the owned desktop answers window messages before $Label" { [RoomsDesktop]::Responding($main, 500) } 10)
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) {
        Trace-Step "press needs the owned desktop in front: $Label"
        [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main)
    }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; seconds = $clock.Elapsed.TotalSeconds })
    [ChatDeliveryDesktop]::Chord($Keys)
    Trace-Step "press done: $Label"
}
function Type-Text([string]$Text) {
    Trace-Step "type start: $Text"
    Doctor
    [void](Wait-For 'the owned desktop answers window messages before typing' { [RoomsDesktop]::Responding($main, 500) } 10)
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing typing outside the owned app' }
    $actions.Add(@{ input = 'type'; text = $Text; seconds = $clock.Elapsed.TotalSeconds })
    foreach ($letter in $Text.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    Trace-Step "type done: $Text"
}
$journeyCommands = $null
function Invoke-JourneyCommand {
    param([string]$Name, [string]$Text, [switch]$Session)
    if ($null -eq $script:journeyCommands) {
        $catalog = & node (Join-Path $PSScriptRoot '../../../tools/journey-commands.mjs')
        if ($LASTEXITCODE -ne 0) { throw 'Journey command catalog failed' }
        $script:journeyCommands = $catalog | ConvertFrom-Json
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
        $entry = $script:journeyCommands.PSObject.Properties[$Name.ToLowerInvariant()]
        if ($null -eq $entry) { throw "Unknown journey command name: $Name" }
        $query = $entry.Value.query
        $target = [string]$entry.Value.target
    }
    $rowsPattern = '\[palette\] rows chars=' + $query.Length + ' count=\d+ ids=([^\r\n]+)'
    $confirmPattern = if ($null -eq $target) { '\[palette\] confirm target=\d+' } else { '\[palette\] confirm target=' + [regex]::Escape([string]$target) + '(?![0-9])' }
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Trace-Step "palette $attempt open: $query"
        Press @(0x1B) 'Escape: dismiss overlay before the palette command'
        $offset = (Read-Shared "$settings/debug.log").Length
        Press @(0x11, 0x4B) 'Ctrl+K: open palette'
        if (-not (Wait-Or { (Read-After $offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' } 30)) { throw "Timed out: the palette never reported ready for $query" }
        Trace-Step "palette $attempt ready: $query"
        Type-Text $query
        $ids = Wait-Or {
            $rows = [regex]::Matches((Read-After $offset), $rowsPattern)
            if ($rows.Count -eq 0) { return $null }
            $found = @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ' | Where-Object { $_ })
            if (-not $found.Count -or ($null -ne $target -and $found -notcontains $target)) { return $null }
            ,$found
        } 30
        if ($null -eq $ids) { throw "Timed out: palette rows for $query" }
        Trace-Step "palette $attempt rows: $query ids=$($ids -join ' ')"
        $index = if ($null -eq $target) { 0 } else { [Array]::IndexOf($ids, $target) }
        for ($i = 0; $i -lt $index; $i++) { Press @(0x28) "Down: row for $query" }
        Press @(0x0D) "Enter: $query"
        if (Wait-Or { (Read-After $offset) -match $confirmPattern } 20) {
            Trace-Step "palette $attempt confirmed: $query"
            return
        }
        Trace-Step "palette $attempt missed its confirm: $query"
    }
    throw "Timed out: palette confirms $query"
}
function Visible-Children([string]$Class, $Parent = $main) { [RoomsDesktop]::Children([IntPtr]$Parent, $Class) }
function Room-Window { $windows = @(Visible-Children 'MultiPromptRoomView'); if ($windows.Count -eq 1) { $windows[0] } }
function Open-Room([string]$Name) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Invoke-JourneyCommand -Text $Name
    [void](Wait-For "the room window for $Name" { Room-Window } 30)
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
    Trace-Step 'focus start: owned control'
    Doctor
    [void](Wait-For 'the owned desktop answers window messages before it takes focus' { [RoomsDesktop]::Responding($main, 500) } 10)
    if (-not [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $Control)) { throw 'Cannot focus owned control' }
    Trace-Step 'focus done: owned control'
}
function Snapshot([string]$Name) {
    Trace-Step "snapshot start: $Name"
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-snapshot.py") -Evidence $Evidence -Name ($Name + '-snapshot') -TimeoutSeconds 120
    $state = ($raw -join "`n") | ConvertFrom-Json
    Save $state "$Evidence/$Name-state.json"
    Trace-Step "snapshot done: $Name"
    return $state
}
function Room-Data($State) { ,@($State.rooms | ForEach-Object { $_.tables.rooms } | Where-Object { $_.name -ceq 'Rooms534' }) }
function Room-Events($State) { @($State.rooms | ForEach-Object { $_.tables.events } | ForEach-Object { $_.body | ConvertFrom-Json }) }
function Shot([string]$Name) {
    Trace-Step "screenshot start: $Name"
    Doctor
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $text = Invoke-ServerNative -FilePath $ocr -Arguments @("$Evidence/$Name.png", 'stdout', '--psm', '11') -Evidence $Evidence -Name ("$Name-ocr") -TimeoutSeconds 120
    $text = ($text -join ' ') -replace '\s+', ' '
    [IO.File]::WriteAllText("$Evidence/$Name-visible.txt", $text)
    Trace-Step "screenshot done: $Name"
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
            $lines = Invoke-ServerNative -FilePath $ocr -Arguments @("$Evidence/$($variant.file)", 'stdout', '--psm', [string]$variant.psm) -Evidence $Evidence -Name ("$([IO.Path]::GetFileNameWithoutExtension($variant.file))-ocr") -TimeoutSeconds 120
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
    $bounds = [RoomsDesktop]::Bounds($focus)
    $roomBounds = [RoomsDesktop]::Bounds((Room-Window))
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
    $tops = @($fields | ForEach-Object { [RoomsDesktop]::Bounds($_).Top })
    if ([RoomsDesktop]::Bounds($edit).Top -le ($tops | Measure-Object -Minimum).Minimum) { throw 'Member search is not the field below the room name' }
    $text = [ChatDeliveryDesktop]::Text($edit)
    for ($i = 0; $i -lt $text.Length; $i++) { Press @(0x08) 'Backspace: clear the earlier member query' }
    [void](Wait-For 'member search cleared before the next name' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 10)
}
function Dialog-Shot([string]$Name) {
    [void](Shot $Name)
    $roomBounds = [RoomsDesktop]::Bounds((Room-Window))
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
    $bounds = [RoomsDesktop]::Bounds($room)
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
function Read-Clipboard {
    return [RoomsDesktop]::ClipboardText(2000)
}
function Clear-Clipboard {
    return [RoomsDesktop]::ClipboardClear(2000)
}
function Copy-Chat([string]$Name, [int]$Attempts = 4, [int]$ReadSeconds = 4) {
    Trace-Step "copy start: $Name"
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        if (-not (Wait-Or { Clear-Clipboard } 10)) { throw 'Timed out: clipboard available for this copy' }
        Invoke-JourneyCommand 'chat view select all'
        Press @(0x11, 0x43) "Ctrl+C: copy visible chat messages (attempt $attempt)"
        $script:copy_attempts += 1
        Trace-Step "copy read: $Name attempt $attempt"
        $text = Wait-Or { $value = Read-Clipboard; if ($value) { $value } } $ReadSeconds
        if ($text) {
            [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
            Trace-Step "copy kept: $Name attempt $attempt"
            Press @(0x1B) 'Escape: return to composer'
            return $text
        }
        [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 250)
    }
    [IO.File]::WriteAllText("$Evidence/$Name-empty-copy.txt", "$($script:copy_attempts) bounded Ctrl+C attempts produced no clipboard text")
    Trace-Step "copy empty: $Name"
    return $null
}
function Copy-Chat-Until([string]$Name, [string]$Wanted, [scriptblock]$Check, [int]$Seconds = 45, [int]$Attempts = 4, [int]$ReadSeconds = 4) {
    Trace-Step "copy-until start: $Wanted"
    $script:copy_attempts = 0
    $script:copy_ever_read = $false
    $failure = $null
    try {
        return (Wait-For $Wanted {
            $text = Copy-Chat $Name $Attempts $ReadSeconds
            if ($null -ne $text) { $script:copy_ever_read = $true }
            if ($text -and (& $Check $text)) { $text }
        } $Seconds)
    } catch { $failure = $_ }
    if (-not $script:copy_ever_read) { throw "No chat text was ever read from $Name's Chat View; the real Ctrl+C copy produced nothing in $($script:copy_attempts) bounded attempts, so $Wanted is unjudged" }
    throw $failure
}
function Save-RoomMembers([string]$Label) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x0D) "Ctrl+Enter: $Label"
    [void](Wait-For "the app saved the room members: $Label" {
        $log = Read-Shared "$settings/debug.log"
        if ($log.Length -le $offset) { return $false }
        $log.Substring($offset) -match '(?s)\[rooms\] command finished kind=edit state=accepted.*\[rooms\] view presented room='
    } 30)
}
function Open-Member([string]$Name) {
    Trace-Step "open member start: $Name"
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
    Trace-Step "open member done: $Name"
}
function Send-Text([string]$Text, [switch]$Room, [switch]$AllowKeptDraft) {
    Trace-Step "send start: $Text"
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
            if ([ChatDeliveryDesktop]::Text($edit) -ceq '') { break }
            [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
        }
        Trace-Step "send done: $Text"
        return
    }
    [void](Wait-For 'composer clears after send' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 15)
    Trace-Step "send done: $Text"
}
function Release-Replies([string]$Marker) {
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-release.py $Marker") -Evidence $Evidence -Name ("release-$Marker") -TimeoutSeconds 120)
}
function Server-Python {
    $lines = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', 'command -v python3') -Evidence $Evidence -Name 'server-python' -TimeoutSeconds 120
    return (($lines -join "`n").Trim())
}
function Server-Drop([string]$Action, [string]$Text) {
    $arguments = @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$repo/.claude/skills/verify-multiprompt/rooms-drop-receipt.sh", $Action)
    if ($Text) { $arguments += $Text }
    $lines = Invoke-ServerNative -FilePath wsl.exe -Arguments $arguments -Evidence $Evidence -Name ("drop-receipt-$Action") -TimeoutSeconds 120
    if ($Action -ceq 'install') { $script:dropInstalled = $true }
    if ($Action -ceq 'remove') { $script:dropInstalled = $false }
    return (($lines -join "`n").Trim())
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
    Add-Type -AssemblyName System.Drawing, System.Security
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/job.cs"
    Add-Type -Path "$PSScriptRoot/rooms-desktop.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $ocr = 'C:/Program Files/Tesseract-OCR/tesseract.exe'
    if (-not (Test-Path $ocr)) { throw 'Tesseract not installed' }
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'repo-path' -TimeoutSeconds 120).Trim()
    & "$PSScriptRoot/../../../tools/verify-server-chat/start.ps1" -Profile $profile -Evidence $Evidence
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $keygen = "$env:SystemRoot/System32/OpenSSH/ssh-keygen.exe"
    $identity = "$profile/home/.ssh/id_ed25519"
    [void](Invoke-ServerNative -FilePath $keygen -Arguments @('-q', '-t', 'ed25519', '-N', '', '-C', 'rooms-journey', '-f', $identity) -Evidence $Evidence -Name 'rooms-identity' -TimeoutSeconds 120)
    $identityPublic = ((Get-Content "$identity.pub" -Raw).Trim() -split ' ' | Select-Object -First 2) -join ' '
    $identityCommand = "umask 077 && mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && if grep -qF '$identityPublic' ~/.ssh/authorized_keys; then :; else printf '%s\n' '$identityPublic' >> ~/.ssh/authorized_keys; fi"
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', $identityCommand) -Evidence $Evidence -Name 'rooms-identity-authorize' -TimeoutSeconds 120)
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
    $plain = (Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$profile/home/.ssh/config", 'remote-1', 'uname -s') -Evidence $Evidence -Name 'rooms-plain-ssh' -TimeoutSeconds 120).Trim()
    if ($plain -ne 'Linux') { throw "Plain ssh remote-1 is not usable by the room transport: $plain" }
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-seed.py $repo") -Evidence $Evidence -Name 'members-seed' -TimeoutSeconds 120)
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
    [void](Wait-For 'runner account Worker ready' { try { Invoke-RestMethod "https://$accountHost/health" -TimeoutSec 10 | Out-Null; Test-Path "$profile/account-state.json" } catch { $false } } 90)
    $secrets = Get-Content "$profile/account-state.json" -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes("$settings/account-device.dat", [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $keyLine = (Get-Content "$profile/home/.ssh/known_hosts" | Select-Object -First 1) -split ' '
    $tabs = @(@{ kind = 'tmux'; name = 'Alpha'; tmux_session = 'rooms-alpha'; csid = 'a1b2c3d4-0534-4000-8000-000000000001'; tmux_host = 0; workspace = 'Rooms check'; manual = $true }, @{ kind = 'tmux'; name = 'Bravo'; tmux_session = 'rooms-bravo'; csid = 'a1b2c3d4-0534-4000-8000-000000000002'; tmux_host = 0; workspace = 'Rooms check'; manual = $true })
    $layout = @{ schema = 1; revision = 1; workspaces = @(@{ name = 'Rooms check' }); tabs = $tabs; hosts = @(@{ slot = 0; name = 'Runner Linux'; hostname = '127.0.0.1'; port = 2222; user = 'mpverify'; host_keys = @($keyLine[1] + ' ' + $keyLine[2]) }) }
    $headers = @{ Authorization = 'Bearer ' + $secrets.admin_key; 'X-Layout-Features' = 'hosts,csid' }
    $current = Invoke-RestMethod "https://$accountHost/v1/layout" -Headers $headers -TimeoutSec 30
    Invoke-RestMethod "https://$accountHost/v1/layout" -Method Put -Headers $headers -TimeoutSec 30 -ContentType 'application/json' -Body (@{ base_revision = $current.revision; layout = $layout } | ConvertTo-Json -Depth 15) | Out-Null
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
            $match = [regex]::Match((Read-After $bridgeOffset), '\[room_bridge\] (published runtime|runtime already published) [0-9a-f]{12}')
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
            [void](Copy-Chat-Until $name "$name real private reply" { param($text) $text.Contains("$name says PRIVATE534") })
            [void](Shot "$name-private")
        }
        Save @{ status = 'PASS'; detail = 'Both chats replied through the real desktop composer, SSH, host, provider and transcript before sending a room question' } "$Evidence/preflight.json"
    }
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
        [void](Wait-For 'Bravo is the visible chat before the room edit' {
            $saved = Session-Saved
            $tabs = Saved-Tabs $saved
            if ($null -eq $saved -or -not $saved.PSObject.Properties['active_tab']) { return $false }
            $index = [int]$saved.active_tab
            $index -ge 0 -and $index -lt $tabs.Count -and $tabs[$index].name -ceq 'Bravo' -and -not (Room-Window)
        })
        Open-Room 'Rooms534'
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
        Save-RoomMembers 'save the room with both member chats'
        [void](Wait-For 'both saved members' { $s = Snapshot 'members-poll'; @($s.rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2 })
        $visible = Shot 'members-after'
        if ($visible -notmatch 'Rooms534') { throw 'Room did not reopen after saving members' }
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
        $events = @(Room-Events $state)
        $replies = @($events | Where-Object { $_.type -eq 'agent_reply' } | Sort-Object { [int]$_.seq })
        if ($replies.Count -lt 2) { throw 'Saved room contains fewer than two member replies; there is no shared reply order' }
        $problems = @()
        foreach ($member in @($state.rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 })) {
            $name = [string]$member.display_name
            $own = @($replies | Where-Object { $_.member_id -ceq $member.id -and $_.text -notlike 'No answer.*' })
            $context = @()
            $previous = 0
            foreach ($delivery in @($events | Where-Object { $_.type -eq 'human' -and @($_.recipients) -contains $member.id } | Sort-Object { [int]$_.seq })) {
                $context += @($replies | Where-Object { $_.member_id -cne $member.id -and [int]$_.seq -gt $previous -and [int]$_.seq -lt [int]$delivery.seq })
                $previous = [int]$delivery.seq
            }
            if ($replies.member_id -cnotcontains $member.id) { $problems += "$name has no saved reply in the room"; continue }
            $expected = @((@($own) + @($context)) | Sort-Object { [int]$_.seq })
            Open-Member $name
            $text = Copy-Chat-Until $name "$name chat shows its own room replies and the room context delivered to it, in room order" {
                param($text)
                $position = -1
                foreach ($reply in $expected) {
                    $next = $text.IndexOf([string]$reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
                    if ($next -lt 0) { return $null }
                    $position = $next
                }
                return $text
            } 60
            [void](Shot "$name-room-history")
            $sid = [string]$member.provider_sid
            $transcript = @($state.transcripts.PSObject.Properties | Where-Object { $_.Name -like "*/$sid.jsonl" } | ForEach-Object { $_.Value })
            $assistant = @($transcript | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
            $user = @($transcript | Where-Object { $_.type -eq 'user' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
            Save $assistant "$Evidence/$name-canonical-replies.json"
            Save @{ assistant = $assistant; user = $user } "$Evidence/$name-transcript-roles.json"
            $position = -1
            foreach ($reply in $own) {
                $next = -1
                for ($index = $position + 1; $index -lt $assistant.Count; $index++) {
                    if ($assistant[$index] -ceq [string]$reply.text) { $next = $index; break }
                }
                if ($next -lt 0) { $problems += "$name saved transcript is missing or reorders its own assistant reply '$($reply.text)'" } else { $position = $next }
            }
            $userText = $user -join "`n"
            $position = -1
            foreach ($reply in $context) {
                if ($assistant -ccontains [string]$reply.text) { $problems += "$name saved transcript records the peer reply '$($reply.text)' as its own assistant message" }
                $next = $userText.IndexOf([string]$reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
                if ($next -lt 0) { $problems += "$name saved transcript is missing the room context '$($reply.text)' delivered to it" } else { $position = $next }
            }
        }
        Open-Room 'Rooms534'
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
        $awayQuestion = @(Wait-For 'saved AWAY534 parent event' {
            $events = @(Room-Events (Snapshot 'away-question') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'AWAY534' })
            if ($events.Count -eq 1) { $events }
        } 30)
        $awayParent = [string]$awayQuestion[0].id
        Open-Member 'Alpha'
        [void](Shot 'away-before-release')
        if (Room-Window) { throw 'Driver precondition failed: the room stayed open while the away replies arrived' }
        Release-Replies 'AWAY534'
        $savedWhileAway = @(Wait-For 'both providers answered and the room store saved both replies with the room closed' {
            $state = Snapshot 'away-while-closed'
            $answered = @($state.transcripts.PSObject.Properties | ForEach-Object { $_.Value } | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text } | Where-Object { $_ -like '* says AWAY534' })
            $saved = @(Room-Events $state | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq $awayParent -and $_.text -like '* says AWAY534' })
            if ($answered.Count -eq 2 -and $saved.Count -eq 2 -and @($saved.member_id | Select-Object -Unique).Count -eq 2) { $saved }
        } 60)
        if (Room-Window) { throw 'Driver precondition failed: the room was open while the away replies were saved' }
        $result.observations += @{ fact = 'both providers answered and the room store saved both replies while the room stayed closed'; count = $savedWhileAway.Count; parent = $awayParent; members = @($savedWhileAway.member_id | Select-Object -Unique); expected = 2 }
        Open-Room 'Rooms534'
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
        Open-Room 'Rooms534'
        $visible = Shot-Room 'restart-return'
        if ($visible -notmatch 'Alpha says RESTART534' -or $visible -notmatch 'Bravo says RESTART534') { throw 'Restarted desktop lost answers to the unanswered room question' }
    }
    Case 9 '' 'The existing Android photo harness needs a companion checkout and has no Rooms read action; this Windows job has no Android client. Paired ticket MUBO-536' {}
    Case 10 '' 'The existing Android photo harness has no Rooms retry action; this Windows job has no Android client. Paired ticket MUBO-536' {}
    Case 12 '' $missingMembers {
        Open-Room 'Rooms534'
        Send-Text 'FAIL534' -Room
        [void](Wait-For 'both provider failure receipts' { @((Snapshot 'failed-turn').inputs | Where-Object { $_.marker -ceq 'FAIL534' }).Count -eq 2 })
        $question = @(Room-Events (Snapshot 'failed-turn-question') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'FAIL534' })
        if ($question.Count -ne 1) { throw 'Expected exactly one FAIL534 parent event' }
        $parent = [string]$question[0].id
        $failure = @(Wait-For 'one saved failed member turn' {
            $failed = @(Room-Events (Snapshot 'failed-turn-saved') | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq $parent -and $_.text -like 'No answer.*' })
            if ($failed.Count -eq 1) { $failed } else { $null }
        })
        $members = @((Snapshot 'failed-turn-members').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 })
        $failedMember = @($members | Where-Object { $_.id -eq $failure[0].member_id })[0]
        if ($null -eq $failedMember) { throw 'The failed member is missing from the saved room' }
        $failedName = [string]$failedMember.display_name
        [void](Wait-For 'the other member answered FAIL534 once' {
            $replies = @(Room-Events (Snapshot 'failed-turn-answers') | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq $parent -and $_.text -like '* says FAIL534' })
            $replies.Count -eq 1 -and $replies[0].member_id -ne $failure[0].member_id
        } 30)
        Send-Text "@$failedName FAIL534" -Room
        $retry = @(Wait-For 'saved retry for the failed member only' {
            $events = @(Room-Events (Snapshot 'retry-poll') | Where-Object { $_.type -eq 'human' -and $_.text -ceq "@$failedName FAIL534" })
            if ($events.Count -eq 1 -and @($events[0].recipients).Count -eq 1 -and $events[0].recipients[0] -ceq $failedMember.id) { $events }
        } 20)
        [void](Wait-For 'two saved FAIL534 answers from two members' {
            $state = Snapshot 'recovered-poll'
            $replies = @(Room-Events $state | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -in @($parent, $retry[0].id) -and $_.text -like '* says FAIL534' })
            $inputs = @($state.inputs | Where-Object { $_.marker -ceq 'FAIL534' })
            $replies.Count -eq 2 -and @($replies.member_id | Select-Object -Unique).Count -eq 2 -and
                @($replies | Where-Object { $_.parent_event_id -ceq $retry[0].id -and $_.member_id -ceq $failedMember.id }).Count -eq 1 -and
                $inputs.Count -eq 3 -and @($inputs | Where-Object { $_.sid -ceq $failedMember.provider_sid }).Count -eq 2
        } 60)
        $visible = Shot-Room 'failed-turn-recovered'
        foreach ($member in $members) {
            if ($visible -notmatch ([regex]::Escape("$($member.display_name) says FAIL534"))) { throw "The retried room question is missing $($member.display_name)'s answer on screen" }
        }
    }
    Case '12-interrupted' 'Preserve an interrupted partial answer once' $missingMembers {
        Open-Room 'Rooms534'
        Send-Text 'INTERRUPT534' -Room -AllowKeptDraft
        $interruptQuestion = @(Wait-For 'saved INTERRUPT534 parent event' {
            $events = @(Room-Events (Snapshot 'interrupt-question') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'INTERRUPT534' })
            if ($events.Count -eq 1) { $events }
        } 30)
        $interruptParent = [string]$interruptQuestion[0].id
        $bravoSid = 'a1b2c3d4-0534-4000-8000-000000000002'
        [void](Wait-For 'the interrupted member saved its partial answer before the turn ended' {
            $state = Snapshot 'interrupt-partial'
            $bravo = @($state.transcripts.PSObject.Properties | Where-Object { $_.Name -like "*/$bravoSid.jsonl" } | ForEach-Object { $_.Value })
            $texts = @($bravo | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
            $texts -ccontains 'Bravo says INTERRUPT534'
        } 60)
        Open-Member 'Bravo'
        $memberEdit = Wait-For 'one visible member composer before the interrupt' { $windows = @(Visible-Children 'Edit'); if ($windows.Count -eq 1) { $windows[0] } }
        Focus-Control $memberEdit
        [void](Wait-For 'the real host ended the interrupted turn' {
            Press @(0x1B) 'Escape: interrupt the running member turn'
            $state = Snapshot 'interrupt-ended'
            $bravoHost = @($state.hosts | Where-Object { $_.state.native_session -ceq $bravoSid })
            $bravoHost.Count -eq 1 -and $bravoHost[0].state.result.subtype -ceq 'interrupted'
        } 60)
        Open-Room 'Rooms534'
        [void](Wait-For 'exactly one saved answer from the interrupted turn' {
            $saved = @(Room-Events (Snapshot 'interrupt-replies') | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq $interruptParent -and $_.text -ceq 'Bravo says INTERRUPT534' })
            if ($saved.Count -eq 1) { $saved }
        } 60)
        $visible = Shot-Room 'interrupted-answer'
        if ($visible -notmatch 'Bravo says INTERRUPT534') { throw 'The interrupted partial answer is missing from the room view' }
        $interruptState = Snapshot 'interrupt-final'
        $interruptAnswers = @(Room-Events $interruptState | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq $interruptParent })
        if ($interruptAnswers.Count -ne 2 -or @($interruptAnswers.member_id | Select-Object -Unique).Count -ne 2) { throw "INTERRUPT534 saved $($interruptAnswers.Count) answers from $(@($interruptAnswers.member_id | Select-Object -Unique).Count) members, expected exactly one from each" }
        $interruptTranscript = @($interruptState.transcripts.PSObject.Properties | Where-Object { $_.Name -like "*/$bravoSid.jsonl" } | ForEach-Object { $_.Value } | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text } | Where-Object { $_ -ceq 'Bravo says INTERRUPT534' })
        if ($interruptTranscript.Count -ne 1) { throw "The interrupted turn transcript holds $($interruptTranscript.Count) partial answers, expected exactly one" }
        $result.observations += @{ fact = 'the real host interrupted a running turn after its partial text and the room saved that text once'; parent = $interruptParent; status = 'interrupted'; answers = $interruptAnswers.Count }
    }
    $dropBoundary = ''
    if ($hasMembers) {
        try {
            $pythonBefore = Server-Python
            if ($pythonBefore -cne '/usr/bin/python3') { $dropBoundary = "The disposable receipt boundary cannot be installed safely: the room transport resolves python3 to $pythonBefore" }
        } catch { $dropBoundary = "Could not read the room transport python3 path: $($_.Exception.Message)" }
    }
    Case 13 'Lost acknowledgement and retry' $(if (-not $hasMembers) { 'The room has fewer than two saved members' } elseif ($dropBoundary) { $dropBoundary } else { '' }) {
        [void](Server-Drop 'install')
        if ((Server-Python) -cne '/usr/local/bin/python3') { throw "The disposable receipt boundary is not on the room transport python3 path: $(Server-Python)" }
        Open-Room 'Rooms534'
        [void](Server-Drop 'arm' 'LOSTACK534')
        Send-Text 'LOSTACK534' -Room -AllowKeptDraft
        [void](Wait-For 'the disposable boundary withheld the committed receipt' {
            $entered = @((Server-Drop 'log') -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.withheld -and $_.text -ceq 'LOSTACK534' })
            $entered.Count -ge 1
        } 45)
        $journalPaths = @(Get-ChildItem $settings -Filter 'room-command-*.json' | Select-Object -ExpandProperty FullName)
        if ($journalPaths.Count -ne 1) { throw "Expected one room command journal on this profile, found $($journalPaths.Count)" }
        $journalPath = $journalPaths[0]
        $original = (Read-Shared $journalPath | ConvertFrom-Json).record
        if ($original.state -cne 'uncertain' -or $original.evidence) { throw "The withheld send was saved as $($original.state) with evidence '$($original.evidence)', expected an uncertain command without evidence" }
        $originalBody = ($original.request | ConvertFrom-Json).text
        if ($originalBody -cne 'LOSTACK534') { throw "The saved uncertain command body is '$originalBody', expected LOSTACK534" }
        $dropLog = @((Server-Drop 'log') -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        $withheld = @($dropLog | Where-Object { $_.withheld -and $_.text -ceq 'LOSTACK534' })
        if ($withheld.Count -ne 1) { throw "Expected one withheld room request for LOSTACK534, got $($withheld.Count)" }
        if ($withheld[0].command_id -cne [string]$original.command_id -or $withheld[0].room_id -cne [string]$original.room_id) { throw 'The withheld request does not carry the original room and command id' }
        $receipt = $withheld[0].reply | ConvertFrom-Json
        if (-not $receipt.ok -or $null -eq $receipt.result.event) { throw 'The withheld reply is not the real server receipt for a committed command' }
        if ([string]$receipt.result.event.room_id -cne [string]$original.room_id -or [string]$receipt.result.event.text -cne 'LOSTACK534') { throw 'The committed receipt names another room or body' }
        $committed = @(Room-Events (Snapshot 'lost-ack-committed') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'LOSTACK534' })
        if ($committed.Count -ne 1 -or [string]$committed[0].id -cne [string]$receipt.result.event.id) { throw "The server shows $($committed.Count) LOSTACK534 human rows for a single committed command" }
        [void](Shot 'lost-ack-withheld')
        $room = Room-Window
        $draftEdit = Wait-For 'one visible room composer' { $windows = @(Visible-Children 'Edit' $room); if ($windows.Count -eq 1) { $windows[0] } }
        if ([ChatDeliveryDesktop]::Text($draftEdit) -cne 'LOSTACK534') { throw "The withheld send did not keep its own draft in the room composer: '$([ChatDeliveryDesktop]::Text($draftEdit))'" }
        Focus-Control $draftEdit
        Press @(0x11, 0x41) 'Ctrl+A: select the kept uncertain draft'
        Press @(0x08) 'Backspace: clear the kept uncertain draft before the edited one'
        for ($attempt = 0; $attempt -lt 3; $attempt++) {
            $kept = [ChatDeliveryDesktop]::Text($draftEdit)
            if ($kept.Length -eq 0) { break }
            for ($i = 0; $i -lt $kept.Length; $i++) { Press @(0x08) 'Backspace: delete the kept draft one character at a time' }
        }
        [void](Wait-For 'empty room composer before the edited draft' { [ChatDeliveryDesktop]::Text($draftEdit) -ceq '' } 10)
        Type-Text 'EDITED534'
        [void](Wait-For 'the edited draft is in the room composer' { [ChatDeliveryDesktop]::Text($draftEdit) -ceq 'EDITED534' } 10)
        [void](Wait-For 'the edited room draft is saved on this computer' {
            $stores = @(Get-ChildItem $settings -Filter 'room-ui-*.json')
            @($stores | Where-Object { (Read-Shared $_.FullName) -match 'EDITED534' }).Count -ge 1
        } 20)
        Restart-Desktop
        [void](Wait-For 'the app retried the withheld command to an accepted receipt' {
            $current = (Read-Shared $journalPath | ConvertFrom-Json).record
            $current.state -ceq 'accepted'
        } 120)
        $retried = (Read-Shared $journalPath | ConvertFrom-Json).record
        if ([string]$retried.command_id -cne [string]$original.command_id) { throw 'The restart retry used a different command id than the original uncertain send' }
        if (-not [string]::Equals([string]$retried.request, [string]$original.request, [StringComparison]::Ordinal)) { throw 'The restart retry sent a different room, revision, recipients or body than the original uncertain send' }
        $accepted = $retried.evidence | ConvertFrom-Json
        if ([string]$accepted.event.id -cne [string]$receipt.result.event.id -or [string]$accepted.event.text -cne 'LOSTACK534') { throw 'The accepted receipt does not name the single human row the server committed for the original command' }
        $retryLog = @((Server-Drop 'log') -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        $attempts = @($retryLog | Where-Object { $_.text -ceq 'LOSTACK534' })
        $retryAttempts = @($attempts | Where-Object { -not $_.withheld })
        if ($retryAttempts.Count -lt 1) { throw 'The app never sent the saved command again through the real transport after the restart' }
        foreach ($attempt in $retryAttempts) {
            if ([string]$attempt.command_id -cne [string]$original.command_id -or [string]$attempt.room_id -cne [string]$original.room_id -or [string]$attempt.text -cne 'LOSTACK534') { throw 'The retry did not use the exact original room, command id and body' }
        }
        [void](Wait-For 'each member answered the replayed message exactly once' {
            $state = Snapshot 'lost-ack-replies'
            $human = @(Room-Events $state | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'LOSTACK534' })
            if ($human.Count -ne 1) { return $false }
            $replies = @(Room-Events $state | Where-Object { $_.type -eq 'agent_reply' -and $_.parent_event_id -ceq [string]$human[0].id -and $_.text -like '* says LOSTACK534' })
            $human.Count -eq 1 -and $replies.Count -eq 2 -and @($replies.member_id | Select-Object -Unique).Count -eq 2
        } 120)
        Open-Room 'Rooms534'
        $visible = Shot-Room 'lost-ack-recovered'
        if ($visible -notmatch 'LOSTACK534') { throw 'The replayed message is missing from the room view after restart recovery' }
        $room = Room-Window
        $draftEdit = Wait-For 'one visible room composer after the restart' { $windows = @(Visible-Children 'Edit' $room); if ($windows.Count -eq 1) { $windows[0] } }
        [void](Wait-For 'the edited draft survived the restart and retry' { [ChatDeliveryDesktop]::Text($draftEdit) -ceq 'EDITED534' } 15)
        if ([ChatDeliveryDesktop]::Text($draftEdit) -cne 'EDITED534') { throw "The edited draft did not survive the restart and retry: '$([ChatDeliveryDesktop]::Text($draftEdit))'" }
        Focus-Control $draftEdit
        for ($attempt = 0; $attempt -lt 3; $attempt++) {
            $kept = [ChatDeliveryDesktop]::Text($draftEdit)
            if ($kept.Length -eq 0) { break }
            for ($i = 0; $i -lt $kept.Length; $i++) { Press @(0x08) 'Backspace: clear the edited draft after the proof' }
        }
        $result.observations += @{ fact = 'a withheld acknowledgement was recovered by the real restart retry with the original room, command id and body'; withheld = $withheld.Count; retries = $retryAttempts.Count; human_rows = 1; answers = 2; edited_draft = 'EDITED534' }
        [void](Server-Drop 'remove')
        if ((Server-Python) -cne '/usr/bin/python3') { throw "The disposable receipt boundary was not removed: $(Server-Python)" }
    }
    $historyReplies = @(Room-Events (Snapshot 'before-history') | Where-Object { $_.type -eq 'agent_reply' })
    Case 14 '' $(if (-not $sent) { 'No saved room question to reload' } elseif ($historyReplies.Count -eq 0) { 'No saved replies to check for stale or missing history' } else { '' }) {
        $before = @(Room-Events (Snapshot 'history-before') | Where-Object { $_.type -eq 'agent_reply' })
        if ($before.Count -eq 0) { throw 'No saved replies exist to check for stale or missing history' }
        Open-Member 'Alpha'
        Open-Room 'Rooms534'
        $visible = Shot-Room 'history-reloaded'
        foreach ($reply in $before) {
            if ($visible -notmatch [regex]::Escape($reply.text)) { throw "Room history is missing saved reply '$($reply.text)' after reopening" }
        }
        $after = @(Room-Events (Snapshot 'history-after') | Where-Object { $_.type -eq 'agent_reply' })
        if (($before.id -join ',') -cne ($after.id -join ',')) { throw 'Saved reply identities or order changed after history load' }
    }
    Case '2-closed' '' $missingMembers {
        Open-Member 'Bravo'
        $bravoGone = { @(Saved-Tabs (Session-Saved) | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -eq 'rooms-bravo' }).Count -eq 0 }
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            if (& $bravoGone) { break }
            Press @(0x11, 0x10, 0x57) "Ctrl+Shift+W: close Bravo before the closed-chat check (attempt $attempt)"
            try { [void](Wait-For 'Bravo no longer an open tab' $bravoGone 15) } catch { if ($attempt -eq 3) { throw } }
        }
        [void](Wait-For 'Bravo is closed before the room adds it again' $bravoGone 5)
        [void](Shot 'closed-bravo-gone')
        Open-Room 'Rooms534'
        Invoke-JourneyCommand 'Edit room'
        [void](Wait-For 'room editor' { Room-Window })
        Press @(0x09) 'Tab: search member chats'
        Clear-Member-Search
        Type-Text 'Bravo'
        if ((Picker-Shot 'closed-bravo') -notmatch '\bBravo\b') { throw 'A chat whose tab is closed is missing from the room member list' }
        Press @(0x0D) 'Enter: deselect Bravo before adding it back'
        Save-RoomMembers 'save the room without Bravo'
        [void](Wait-For 'one member after removing the closed chat' { @((Snapshot 'closed-removed').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 1 })
        Invoke-JourneyCommand 'Edit room'
        [void](Wait-For 'room editor for the closed-chat add' { Room-Window })
        Press @(0x09) 'Tab: search member chats'
        Clear-Member-Search
        Type-Text 'Bravo'
        if ((Picker-Shot 'closed-bravo-add') -notmatch '\bBravo\b') { throw 'A chat whose tab is closed is missing from the room member list when it is added' }
        Press @(0x0D) 'Enter: select the closed chat'
        Save-RoomMembers 'save the room with the closed chat added back'
        [void](Wait-For 'two members after adding the closed chat' { @((Snapshot 'closed-added').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2 })
        Send-Text '@Bravo CLOSED534' -Room
        [void](Wait-For 'saved answer from the closed member chat' { @(Room-Events (Snapshot 'closed-reply-poll') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -ceq 'Bravo says CLOSED534' }).Count -eq 1 } 60)
        $visible = Shot-Room 'closed-member-reply'
        if ($visible -notmatch 'Bravo says CLOSED534') { throw 'The room did not show the closed member chat answer' }
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
        Open-Room 'Rooms534'
        [void](Wait-For 'discovered existing room view' { Room-Window })
        $visible = Shot-Room 'fresh-discovery'
        if ($visible -notmatch 'Rooms534') { throw 'Existing room is missing on a fresh install of the same account' }
        if ($sent -and $visible -notmatch 'BROADCAST534') { throw 'Freshly discovered room has stale or empty saved history' }
    }
    if (@($result.cases | Where-Object { $_.status -ne 'PASS' -and $_.step -notin @('9', '10') }).Count -eq 0 -and $result.driverErrors.Count -eq 0) { $result.status = 'passed' }
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
        if ($script:dropInstalled) { [void](Server-Drop 'remove') }
    } catch { $result.driverErrors += $_.ToString(); $result.status = 'failed' }
    try {
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'wsl-terminate' -TimeoutSeconds 60)
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
