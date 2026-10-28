
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'A real CMD prints a fenced code block that Chat View formats from console text; diff previews only come from an agent transcript, so their rows are proven by the branch painter image' }
            $cells = 40
            $sizeCheck = @{ name = 'IGSH-678 code cell size'; passed = $false; cells = $cells }
            $faceCheck = @{ name = 'IGSH-678 code font face and size'; passed = $false }
            $edgeCheck = @{ name = 'IGSH-678 code edges'; passed = $false }
            $painterCheck = @{ name = 'IGSH-678 diff rows smooth on green and red'; passed = $false }
            $result.checks += $sizeCheck
            $result.checks += $faceCheck
            $result.checks += $edgeCheck
            $result.checks += $painterCheck
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist default UI size before Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial tab before Chat View'
            $baseline = Read-Session
            if ($baseline.PSObject.Properties['ui_scale'] -and $baseline.ui_scale -ne 100) { throw 'Chat code font baseline UI size is not 100' }
            Save-Json $baseline 'session-before.json'
            $defaultSource = Get-Content (Join-Path $PSScriptRoot '../../../src/app_state.zig') -Raw
            if ($defaultSource -notmatch 'CHAT_FONT_DEFAULT_PT: i32 = (\d+);') { throw 'Default Chat View text size not found in source' }
            $chatPt = if ($baseline.PSObject.Properties['chat_font_pt']) { [int]$baseline.chat_font_pt } else { [int]$Matches[1] }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            if ($dpi -eq 0) { throw 'Main window DPI unavailable' }
            $expectedEm = [int][Math]::Floor([Math]::Max(8, $chatPt - 3) * 100 * $dpi / 9600)
            $previousEm = [int][Math]::Floor([Math]::Max(8, $chatPt - 1) * 100 * $dpi / 9600)
            $bodyEm = [int][Math]::Floor($chatPt * 100 * $dpi / 9600)
            $expectedAdvance = [int][Math]::Floor($expectedEm * 600 / 1000 + 0.5)
            $previousAdvance = [int][Math]::Floor($previousEm * 600 / 1000 + 0.5)
            $sizeCheck.chatPt = $chatPt
            $sizeCheck.dpi = $dpi
            $sizeCheck.expectedEm = $expectedEm
            $sizeCheck.previousEm = $previousEm
            $sizeCheck.bodyEm = $bodyEm
            $sizeCheck.expectedAdvance = $expectedAdvance
            $sizeCheck.previousAdvance = $previousAdvance
            $command = 'powershell -nop -c "''Body text for the code size check'';([string][char]96)*3;''a''+([string][char]0x2588)*' + $cells + ';''let answer = 42;'';([string][char]96)*3"'
            $command += ' && echo code-ready>"' + (Join-Path $scratch 'code-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print a fenced code block in the real CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'code-ready.txt') } 'real console code block command completed'
            Snapshot 'action'
            Press @(0x12, 0x43) 'Alt+C: open Chat View on the code block'
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View enabled in app-written session'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                $script:transcript = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
                $script:transcript.Count -eq 1
            } 'visible native Chat View transcript control'
            Save-Json (Read-Session) 'session-opened.json'
            $frame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Window rectangle unavailable' }
            $bounds = $script:transcript[0].Current.BoundingRectangle
            $area = @{ left = [int]$bounds.Left - $frame.Left; top = [int]$bounds.Top - $frame.Top; right = [int]$bounds.Right - $frame.Left; bottom = [int]$bounds.Bottom - $frame.Top }
            Wait-Until {
                Snapshot 'after'
                $script:codeBar = [CodeFontProof]::Bar((Join-Path $Evidence 'after.png'), $area.left, $area.top, $area.right, $area.bottom, $cells)
                $true
            } 'IGSH-678 fenced code block painted and measurable in Chat View' 20 1000
            $bar = $script:codeBar
            $measuredAdvance = $bar.width / $cells
            $sizeCheck.bar = $bar
            $sizeCheck.measuredAdvance = $measuredAdvance
            $cropTop = $bar.top - 3 * $expectedEm
            $cropBottom = $bar.top + 3 * $expectedEm
            $cropRight = $bar.right + 16
            [CodeFontProof]::Crop((Join-Path $Evidence 'after.png'), (Join-Path $Evidence 'code-crop-4x.png'), ($bar.left - 16), $cropTop, $cropRight, $cropBottom, 4)
            $textTop = $bar.top + $bar.rows + 1
            $edges = [CodeFontProof]::Edges((Join-Path $Evidence 'after.png'), $bar.left, $textTop, ($bar.left + 16 * $previousAdvance), ($textTop + [int](1.6 * $previousEm)))
            $edgeCheck.crop = 'code-crop-4x.png'
            $edgeCheck.textRow = @{ left = $bar.left; top = $textTop; right = $bar.left + 16 * $previousAdvance; bottom = $textTop + [int](1.6 * $previousEm) }
            $edgeCheck.measurement = $edges
            $edgeCheck.passed = $edges.partialPixels -gt 0 -and $edges.inkPixels -gt 0
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logText = if (Test-Path $log) { (Get-Content $log -Raw) -join '' } else { '' }
            $codeLines = @([regex]::Matches($logText, '\[chatcode\] face=(.+?) em=(\d+) advance=(\d+) body_em=(\d+) pt=(\d+)'))
            $faceCheck.logLines = $codeLines.Count
            if ($codeLines.Count -gt 0) {
                $last = $codeLines[$codeLines.Count - 1].Groups
                $faceCheck.face = $last[1].Value
                $faceCheck.em = [int]$last[2].Value
                $faceCheck.advance = [int]$last[3].Value
                $faceCheck.bodyEm = [int]$last[4].Value
                $faceCheck.chatPt = [int]$last[5].Value
            }
            $faceCheck.expectedFace = 'Nordwand Mono MP SemiBold'
            $faceCheck.expectedEm = $expectedEm
            $faceCheck.previousEm = $previousEm
            $proofPath = Join-Path $Evidence 'chat-code-proof-summary.json'
            if ($env:RELEASE_TAG) {
                $painterCheck.skipped = 'Release executables are verified live only; the painter image is built from branch source'
            } elseif (Test-Path $proofPath) {
                $painter = Get-Content $proofPath -Raw | ConvertFrom-Json
                $painterCheck.summary = $painter
                $painterCheck.passed = $painter.passed -eq $true
            } else {
                $painterCheck.error = 'Branch painter proof summary missing'
            }
            if ([Math]::Abs($bar.width - $cells * $expectedAdvance) -gt 3) {
                $sizeCheck.error = "Code cells measure $measuredAdvance px; expected $expectedAdvance px for $expectedEm px Nordwand Mono (previous size $previousEm px draws $previousAdvance px cells)"
                throw ('IGSH-678 code size: ' + $sizeCheck.error)
            }
            $sizeCheck.passed = $true
            if ($codeLines.Count -eq 0) {
                $faceCheck.error = 'The app logged no selected Chat View code font'
                throw ('IGSH-678 code font: ' + $faceCheck.error)
            }
            if ($faceCheck.face -cne $faceCheck.expectedFace -or $faceCheck.em -ne $expectedEm -or $faceCheck.em -ne $previousEm - 2 -or $faceCheck.em -ge $faceCheck.bodyEm -or $faceCheck.advance -ne $expectedAdvance) {
                $faceCheck.error = "Selected $($faceCheck.face) at $($faceCheck.em) px with $($faceCheck.advance) px cells and $($faceCheck.bodyEm) px body text"
                throw ('IGSH-678 code font: ' + $faceCheck.error)
            }
            $faceCheck.passed = $true
            if (-not $edgeCheck.passed) { throw 'IGSH-678 code edges: no antialiased code pixels in the Chat View crop' }
            if (-not $env:RELEASE_TAG -and -not $painterCheck.passed) { throw 'IGSH-678 diff rows: branch painter proof did not pass' }
        