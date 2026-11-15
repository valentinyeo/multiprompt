Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class HarnessGrid {
    delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint thread, ref Gui info);
    [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr target, int x, int y, int width, int height, IntPtr source, int sourceX, int sourceY, int operation);
    struct Rect { public int Left, Top, Right, Bottom; }
    struct Point { public int X, Y; }
    struct Gui {
        public int cbSize, flags;
        public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret;
        public Rect caret;
    }
    static System.Collections.Generic.List<IntPtr> visible = new System.Collections.Generic.List<IntPtr>();
    public static IntPtr Find(IntPtr parent) {
        visible.Clear();
        EnumChildWindows(parent, delegate(IntPtr hwnd, IntPtr data) {
            StringBuilder name = new StringBuilder(64);
            GetClassName(hwnd, name, name.Capacity);
            if (name.ToString() == "MPTerminal" && IsWindowVisible(hwnd)) visible.Add(hwnd);
            return true;
        }, IntPtr.Zero);
        if (visible.Count == 0) return IntPtr.Zero;
        uint pid;
        Gui info = new Gui();
        info.cbSize = System.Runtime.InteropServices.Marshal.SizeOf(typeof(Gui));
        if (GetGUIThreadInfo(GetWindowThreadProcessId(parent, out pid), ref info)) {
            foreach (IntPtr hwnd in visible) if (hwnd == info.hwndFocus) return hwnd;
        }
        IntPtr best = visible[0];
        int bestArea = 0;
        foreach (IntPtr hwnd in visible) {
            int area = Width(hwnd) * Height(hwnd);
            if (area > bestArea) { bestArea = area; best = hwnd; }
        }
        return best;
    }
    public static int Width(IntPtr hwnd) { Rect rect; if (!GetClientRect(hwnd, out rect)) return 0; return rect.Right - rect.Left; }
    public static int Height(IntPtr hwnd) { Rect rect; if (!GetClientRect(hwnd, out rect)) return 0; return rect.Bottom - rect.Top; }
    public static long Sample(IntPtr hwnd) {
        int width = Width(hwnd);
        int height = System.Math.Min(72, Height(hwnd));
        if (width < 8 || height < 8) return 0;
        Point origin = new Point();
        if (!ClientToScreen(hwnd, ref origin)) return 0;
        using (var bitmap = new System.Drawing.Bitmap(width, height, System.Drawing.Imaging.PixelFormat.Format32bppRgb))
        using (var graphics = System.Drawing.Graphics.FromImage(bitmap)) {
            IntPtr screen = GetDC(IntPtr.Zero);
            IntPtr target = graphics.GetHdc();
            try {
                if (!BitBlt(target, 0, 0, width, height, screen, origin.X, origin.Y, 0x00CC0020)) return 0;
            } finally {
                graphics.ReleaseHdc(target);
                ReleaseDC(IntPtr.Zero, screen);
            }
            var bits = bitmap.LockBits(new System.Drawing.Rectangle(0, 0, width, height), System.Drawing.Imaging.ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
            try {
                int count = System.Math.Abs(bits.Stride) * height;
                byte[] raw = new byte[count];
                System.Runtime.InteropServices.Marshal.Copy(bits.Scan0, raw, 0, count);
                long hash = 1469598103934665603;
                for (int i = 0; i < raw.Length; i += 4) hash = (hash ^ raw[i]) * 1099511628211;
                return hash;
            } finally { bitmap.UnlockBits(bits); }
        }
    }
}
"@

function Get-MatrixRows {
    $part = if ($env:HARNESS_MATRIX_PART) { $env:HARNESS_MATRIX_PART } else { 'all' }
    $json = & node (Join-Path $PSScriptRoot '../../../tools/harness-matrix.js') journeys $part
    if ($LASTEXITCODE -ne 0 -or -not $json) { throw 'Could not generate harness matrix journeys' }
    return @($json | ConvertFrom-Json)
}

function Get-LatestSize([string]$HostName) {
    $path = Join-Path $env:HARNESS_MATRIX_LOG ($HostName + '-size.jsonl')
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $lines = @(Get-Content -LiteralPath $path | Where-Object { $_ })
    if ($lines.Count -eq 0) { return $null }
    return ($lines[-1] | ConvertFrom-Json)
}

function Open-PaletteRow([string]$Query, [int]$Target) {
    Palette $Query "$Target"
    Press @(0x0D) ("Enter: " + $Query)
}

function Assert-SharedConnection {
    if ($script:sharedOn) { return }
    Wait-Until {
        (Get-Content -LiteralPath (Join-Path $scratch 'roaming/ZigShell/session.json') -Raw) -match '"shared_server_connection"\s*:\s*true'
    } 'saved session keeps the shared server connection on' 10
    $script:sharedOn = $true
}

function Wait-RealSize([string]$HostName) {
    Wait-Until {
        $size = Get-LatestSize $HostName
        $null -ne $size -and -not ($size.rows -eq 24 -and $size.cols -eq 80)
    } ("shell on " + $HostName + " reports a window-sized grid") 20
    return (Get-LatestSize $HostName)
}

function Get-PaletteIds([string]$Query) {
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $start = (Get-Content -LiteralPath $log -Raw).Length
    Palette $Query
    Wait-Until {
        ((Get-Content -LiteralPath $log -Raw).Substring($start)) -match '\[palette\] rows chars=\d+ count=\d+ ids='
    } ("palette rows for " + $Query) 10
    $trace = (Get-Content -LiteralPath $log -Raw).Substring($start)
    $match = [regex]::Match($trace, '\[palette\] rows chars=\d+ count=\d+ ids=([0-9 ]*)')
    if (-not $match.Success) { throw ("palette rows missing for " + $Query) }
    $ids = @()
    foreach ($part in $match.Groups[1].Value.Split(' ')) { if ($part) { $ids += [int]$part } }
    Press @(0x1B) ("close palette after " + $Query)
    return $ids
}

function Add-MatrixResult($Row, [bool]$Pass, [string]$Detail) {
    Snapshot $Row.id
    $script:matrixResults += [ordered]@{ id = $Row.id; pass = $Pass; detail = $Detail; screenshot = $Row.screenshot; journey = $Row.journey; evidence = $Row.evidence }
    Save-Json @{ id = $Row.id; pass = $Pass; detail = $Detail; journey = $Row.journey; passCondition = $Row.pass } $Row.evidence
}

$script:matrixResults = @()
Snapshot 'action'
$rows = Get-MatrixRows
$script:sharedOn = $false
$shellRows = @($rows | Where-Object { $_.kind -eq 'shell' })
if ($shellRows.Count -gt 0) {
    $script:shellOpenError = $null
    try {
        Assert-SharedConnection
        Open-PaletteRow 'Open shell on VPS 1' 2003
        $shellReady = Wait-RealSize 'vps1'
    } catch {
        $shellReady = $null
        $script:shellOpenError = $_.Exception.Message
    }
    foreach ($row in $shellRows) {
        $detail = ''
        $pass = $false
        try {
            if ($script:shellOpenError) { throw $script:shellOpenError }
            $terminal = [HarnessGrid]::Find($script:window)
            if ($terminal -eq [IntPtr]::Zero) { throw 'shell tab has no terminal window' }
            if ($row.id -eq 'fit_on_resize') {
                $before = Get-LatestSize 'vps1'
                $beforeWidth = [HarnessGrid]::Width($terminal)
                [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1500, 900, $true)
                $script:resized = $null
                Wait-Until {
                    $script:resized = Get-LatestSize 'vps1'
                    $null -ne $script:resized -and $script:resized.cols -ne $before.cols
                } 'cols change after resize' 15
                $afterWidth = [HarnessGrid]::Width([HarnessGrid]::Find($script:window))
                if ($script:resized.rows -eq 24 -and $script:resized.cols -eq 80) { throw 'grid stayed 80x24' }
                $ratio = [math]::Abs(($script:resized.cols / $before.cols) - ($afterWidth / [math]::Max($beforeWidth, 1)))
                if ($ratio -gt 0.25) { throw ("cols did not follow the window: " + $ratio) }
                $detail = "cols $($before.cols) to $($script:resized.cols), width $beforeWidth to $afterWidth"
            } elseif ($row.id -eq 'font_change_changes_grid') {
                $before = Get-LatestSize 'vps1'
                $beforeWidth = [HarnessGrid]::Width($terminal)
                foreach ($step in 1..4) { Press @(0x11, 0xBB) ("Ctrl+Plus " + $step) }
                $script:resized = $null
                Wait-Until {
                    $script:resized = Get-LatestSize 'vps1'
                    $null -ne $script:resized -and ($script:resized.cols -ne $before.cols -or $script:resized.rows -ne $before.rows)
                } 'grid changes after the console font change' 15
                $afterWidth = [HarnessGrid]::Width([HarnessGrid]::Find($script:window))
                if ([math]::Abs($afterWidth - $beforeWidth) -gt 8) { throw 'window width changed during the font check' }
                $detail = "grid $($before.cols)x$($before.rows) to $($script:resized.cols)x$($script:resized.rows)"
            } else {
                [void][VerifyNative]::ClickClient($terminal, 12, 12)
                $samples = @()
                foreach ($ch in 'abcdefghijklmnopqrstuvwxyz0123456789abcd'.ToCharArray()) {
                    $beforeHash = [HarnessGrid]::Sample($terminal)
                    $clock = [Diagnostics.Stopwatch]::StartNew()
                    $vk = if ($ch -ge '0' -and $ch -le '9') { 0x30 + ([int][char]$ch - 48) } else { 0x41 + ([int][char]$ch - [int][char]'a') }
                    [VerifyNative]::KeyDown($vk)
                    [VerifyNative]::KeyUp($vk)
                    $echo = $null
                    $deadline = [DateTime]::UtcNow.AddMilliseconds(500)
                    do {
                        if ([HarnessGrid]::Sample($terminal) -ne $beforeHash) { $echo = $clock.Elapsed.TotalMilliseconds; break }
                        Start-Sleep -Milliseconds 1
                    } while ([DateTime]::UtcNow -lt $deadline)
                    if ($null -eq $echo) { $echo = 500 }
                    $samples += [math]::Round($echo, 1)
                }
                $sorted = @($samples | Sort-Object)
                $p95 = $sorted[[math]::Ceiling($sorted.Count * 0.95) - 1]
                $detail = "p95 $p95 ms, $($samples.Count) keys, min $($sorted[0]) max $($sorted[-1])"
                if ($p95 -gt 50) { throw $detail }
            }
            $pass = $true
        } catch {
            $detail = $_.Exception.Message
            $pass = $false
        }
        Add-MatrixResult $row $pass $detail
    }
}

foreach ($row in @($rows | Where-Object { $_.kind -eq 'cells' })) {
    $detail = ''
    $pass = $false
    try {
        if ($row.mode -eq 'live_chat') {
            $problems = @()
            $sshLog = Join-Path $env:HARNESS_MATRIX_LOG ("ssh-" + $row.host + ".log")
            $sshBefore = if (Test-Path -LiteralPath $sshLog) { (Get-Item -LiteralPath $sshLog).Length } else { 0 }
            Open-PaletteRow $row.live_query ([int]$row.live_target)
            try {
                Wait-Until {
                    (Test-Path -LiteralPath $sshLog) -and (Get-Item -LiteralPath $sshLog).Length -gt $sshBefore -and (Get-Content -LiteralPath $sshLog -Raw) -match 'python3'
                } ("chat opens on " + $row.host) 12
            } catch {
                $problems += $_.Exception.Message
            }
            Type-Text 'reply with the word pong'
            Press @(0x0D) 'send pong'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $start = (Get-Content -LiteralPath $log -Raw).Length
            try {
                Wait-Until {
                    $slice = ((Get-Content -LiteralPath $log -Raw).Substring($start))
                    $slice -match 'pong' -and $slice -notmatch 'reply with the word pong'
                } 'reply contains pong' 12
            } catch {
                $problems += $_.Exception.Message
            }
            try {
                $ids = @(Get-PaletteIds 'Chat View: Model')
                $known = @(12003, 12004, 12005, 12011, 12012, 12013, 12014, 12015)
                $shown = @($ids | Where-Object { $known -contains $_ })
                $required = @()
                if ($null -ne $row.model_ids) { $required = @($row.model_ids) }
                if ($required.Count -eq 0) {
                    if ($shown.Count -lt 1) { throw 'model picker listed no models for this harness' }
                } else {
                    $missing = @($required | Where-Object { $shown -notcontains $_ })
                    if ($missing.Count -gt 0) { throw ("model picker missing " + ($missing -join ',')) }
                }
            } catch {
                $problems += $_.Exception.Message
            }
            if ([int]$row.pick_target -gt 0) {
                try {
                    Open-PaletteRow ("Chat View: Model " + $row.pick_model) ([int]$row.pick_target)
                    Type-Text 'reply with the word pong'
                    Press @(0x0D) 'send on the picked model'
                    $mark = (Get-Content -LiteralPath $log -Raw).Length
                    $modelName = [string]$row.pick_model
                    $hostLog = Join-Path $env:HARNESS_MATRIX_LOG (($row.host) + '-version.jsonl')
                    $hostBefore = if (Test-Path -LiteralPath $hostLog) { Get-Content -LiteralPath $hostLog -Raw } else { '' }
                    Wait-Until {
                        $slice = (Get-Content -LiteralPath $log -Raw).Substring($mark)
                        $header = $slice -match [regex]::Escape($modelName) -and $slice -notmatch 'Chat View: Model' -and $slice -notmatch 'reply with the word pong'
                        $hostNamed = $false
                        if (Test-Path -LiteralPath $hostLog) {
                            $hostText = Get-Content -LiteralPath $hostLog -Raw
                            $hostNamed = $hostText.Length -gt $hostBefore.Length -and $hostText.Substring($hostBefore.Length) -match [regex]::Escape($modelName)
                        }
                        $header -or $hostNamed
                    } ("reply ran on " + $modelName) 12
                } catch {
                    $problems += $_.Exception.Message
                }
            } elseif ($row.models.Count -eq 0) {
                $problems += 'model picker has no model to pick for this harness'
            }
            if ($row.skills) {
                try {
                    $skillIds = @(Get-PaletteIds 'skills')
                    $entries = @($skillIds | Where-Object { $_ -ge 4100 -and $_ -lt 4612 })
                    if ($entries.Count -lt 1) { throw 'skill list has no entries' }
                } catch {
                    $problems += $_.Exception.Message
                }
            }
            if ($problems.Count -gt 0) { throw ($problems -join '; ') }
            $detail = 'pong, model, and skills checked'
        } else {
            Assert-SharedConnection
            Open-PaletteRow $row.shell_query ([int]$row.shell_target)
            $size = Wait-RealSize $row.host
            $terminal = [HarnessGrid]::Find($script:window)
            if ($terminal -eq [IntPtr]::Zero) { throw 'shell tab has no terminal window' }
            $width = [HarnessGrid]::Width($terminal)
            if ($width -gt 700 -and $size.cols -le 80) { throw ("cols $($size.cols) do not match window width $width") }
            Type-Text ([string]$row.version_command)
            Press @(0x0D) 'version command'
            $versionLog = Join-Path $env:HARNESS_MATRIX_LOG (($row.host) + '-version.jsonl')
            Wait-Until { (Test-Path -LiteralPath $versionLog) -and ((Get-Content -LiteralPath $versionLog -Raw) -match '\d+\.\d+') } 'version line appears' 10
            $detail = "cols $($size.cols) rows $($size.rows)"
        }
        $pass = $true
    } catch {
        $detail = $_.Exception.Message
        $pass = $false
    }
    Add-MatrixResult $row $pass $detail
}

Snapshot 'after'
$matrixPath = Join-Path $Evidence 'matrix-results.json'
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText($matrixPath, (ConvertTo-Json -InputObject @($script:matrixResults) -Depth 6), $utf8)
$reportPath = Join-Path $Evidence 'report.md'
$reportLines = @(& node (Join-Path $PSScriptRoot '../../../tools/harness-matrix.js') report $matrixPath)
if ($LASTEXITCODE -ne 0) { throw 'Could not generate the harness matrix report' }
$report = ((@($reportLines) | ForEach-Object { "$_" }) -join "`n") + "`n"
[IO.File]::WriteAllText($reportPath, $report, $utf8)
if ($env:GITHUB_STEP_SUMMARY) { Get-Content -LiteralPath $reportPath -Raw | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY }
$failed = @($script:matrixResults | Where-Object { -not $_.pass })
if ($failed.Count -gt 0) { throw ("harness matrix failed: " + (($failed | ForEach-Object { $_.id }) -join ', ')) }
