
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'The fresh offline CMD has no signed-in agent or received conversation; the separate native painter proof uses a synthetic envelope without seeding app state' }
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist default UI size before Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial tab before Chat View'
            $baseline = Read-Session
            if ($baseline.PSObject.Properties['ui_scale'] -and $baseline.ui_scale -ne 100) { throw 'Chat View baseline UI size is not 100' }
            Save-Json $baseline 'session-before.json'
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View enabled in app-written session'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count -eq 1
            } 'visible native Chat View transcript control'
            Save-Json (Read-Session) 'session-opened.json'
            Snapshot 'action'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before closing'
            Press @(0x12, 0x43) 'Alt+C: close Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                -not $state.tabs[$state.active_tab].PSObject.Properties['cv'] -or $state.tabs[$state.active_tab].cv -eq $false
            } 'Chat View disabled in app-written session'
            Save-Json (Read-Session) 'session-closed.json'
            Snapshot 'closed'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before reopening'
            Press @(0x12, 0x43) 'Alt+C: reopen Chat View'
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View re-enabled in app-written session'
            $after = Read-Session
            if ($after.active_tab -ne $baseline.active_tab -or @($after.tabs).Count -ne @($baseline.tabs).Count) { throw 'Chat View changed the selected tab or tab count' }
            Save-Json $after 'session-after.json'
            Snapshot 'after'
            $result.checks += @{ name = 'chat-view-open-close-reopen'; activeTab = $after.active_tab; tabCount = @($after.tabs).Count; savedChatView = $after.tabs[$after.active_tab].cv; entry = 'Alt+C' }
            $greyCheck = @{ name = 'grey-buttons'; passed = $false; reason = 'not reached' }
            $result.checks += $greyCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $localAgent = Join-Path (Split-Path $Exe) 'claude.exe'
            if (-not (Test-Path $localAgent)) { throw 'Local Claude console stand-in is missing' }
            if ($Feature -eq 'chat-view') {
                $menuCheck = @{ name = 'message-menu'; passed = $false; reason = 'not reached' }
                $selectionCheck = @{ name = 'selection-enter-reply'; ticket = 'IGSH-717'; passed = $false; reason = 'not reached' }
                $result.checks += $selectionCheck
                $result.checks += $menuCheck
                $typedCheck = @{ name = 'local-route-typed'; passed = $false; entry = 'Chat View Enter'; receivedBytes = $null; queued = $false }
                $suggestionCheck = @{ name = 'local-route-suggestion'; passed = $false; entry = 'Chat View Ctrl+Enter'; received = '' }
                $result.checks += $typedCheck
                $result.checks += $suggestionCheck
                $outboxPath = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
                $typedPrefix = Join-Path $scratch 'local-route-typed'
                $typedMessage = 'local route typed must stay queued'
                try {
                    foreach ($mode in @('typed', 'suggestion')) {
                        $beforeLocal = Read-Session
                        Palette 'new cmd'
                        Press @(0x0D) 'Enter: create local console for direct-route check'
                        Wait-Until {
                            $state = Read-Session
                            @($state.tabs).Count -eq @($beforeLocal.tabs).Count + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
                        } 'new local CMD session saved'
                        $localState = Read-Session
                        $localTab = $localState.active_tab
                        if ($localState.tabs[$localTab].PSObject.Properties['cv'] -and $localState.tabs[$localTab].cv) {
                            Press @(0x12, 0x43) 'Alt+C: show new local console'
                        }
                        Wait-WorkspaceSurface $localState.active_workspace $localTab $false
                        $prefix = Join-Path $scratch ('local-route-' + $mode)
                        Type-Text ('"' + $localAgent + '" ' + $mode + ' "' + $prefix + '"')
                        Press @(0x0D) 'Enter: launch console-backed Claude stand-in'
                        Wait-Until {
                            if (-not (Test-Path ($prefix + '-ready.json'))) { return $false }
                            $script:localReady = Get-Content ($prefix + '-ready.json') -Raw | ConvertFrom-Json
                            $script:localReady.chars.Count -eq 32 -and $script:localReady.attributes.Count -eq 32
                        } 'stand-in rendered prompt and recorded console attributes'
                        $ready = $script:localReady
                        if ($ready.chars[0] -ne 0x276F -or $ready.chars[1] -ne 32) { throw 'Stand-in did not render the Claude prompt glyph and separator' }
                        if ($mode -eq 'suggestion' -and (($ready.attributes[2] -band 0x4000) -eq 0 -or ($ready.attributes[3] -band 0xF) -ne 8)) { throw 'Real console did not retain the suggestion cursor and gray foreground' }
                        Wait-Until {
                            $inbox = Read-Inbox
                            @($inbox.shells | Where-Object { $_.sid -eq $localState.tabs[$localTab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
                        } 'local claude.exe detected as Claude for the direct input route' -Seconds 45
                        Press @(0x12, 0x43) 'Alt+C: open local agent Chat View'
                        Wait-Until {
                            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                            $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                            $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle
                        } 'owned local Chat View composer focused'
                        $message = if ($mode -eq 'typed') { $typedMessage } else { 'local route suggestion delivered' }
                        Type-Text $message
                        if ($mode -eq 'suggestion') {
                            Record 'Shift+Enter: insert a newline without sending'
                            Assert-Foreground
                            $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                            if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Newline proof lost the owned composer' }
                            [VerifyNative]::KeyDown(0x10)
                            try {
                                [VerifyNative]::Chord(@(0x0D))
                                Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq ($message + "`r`n") } 'Shift+Enter keeps the complete draft and adds one newline'
                            } finally { [VerifyNative]::KeyUp(0x10) }
                            if ((Get-Item ($prefix + '-stdin.bin')).Length -ne 0) { throw 'Shift+Enter sent the draft' }
                            Snapshot 'ctrl-enter-newline'
                            Press @(0x08) 'Backspace: remove the newline before sending'
                            Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq $message } 'original message restored after newline proof'
                            Press @(0x11, 0x0D) 'Ctrl+Enter: send through normal Chat View outbox'
                        } else {
                            Press @(0x0D) 'Enter: send through normal Chat View outbox'
                        }
                        if ($mode -eq 'typed') {
                            Wait-Until {
                                if (-not (Test-Path $outboxPath)) { return $false }
                                $outbox = Get-Content $outboxPath -Raw | ConvertFrom-Json
                                @($outbox.queues.messages | Where-Object { $_.t -ceq $typedMessage -and $_.s -eq 0 -and $_.x -eq 0 }).Count -eq 1
                            } 'typed prompt keeps the Chat View message queued without starting a write'
                            $typedCheck.console = $ready
                            Snapshot 'local-route-typed'
                        } else {
                            $suggestionCheck.console = $ready
                            $wireMessage = ([string][char]27) + '[200~' + $message + ([string][char]27) + '[201~' + "`r"
                            $suggestionCheck.expected = $wireMessage
                            Wait-Until {
                                $stdin = [IO.File]::Open($prefix + '-stdin.bin', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                                try {
                                    $buffer = New-Object IO.MemoryStream
                                    try {
                                        $stdin.CopyTo($buffer)
                                        $receivedBytes = $buffer.ToArray()
                                    } finally { $buffer.Dispose() }
                                } finally { $stdin.Dispose() }
                                $received = [Text.Encoding]::ASCII.GetString($receivedBytes)
                                $suggestionCheck.received = $received
                                $received -ceq $wireMessage
                            } 'local suggestion prompt receives the Chat View message and Enter on stdin'
                            $suggestionCheck.passed = $true
                            Snapshot 'local-route-suggestion'
                            try {
                                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                                $transcripts = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $process.Id })
                                if ($transcripts.Count -ne 1) { throw 'Expected exactly one visible owned transcript for the message menu' }
                                $transcript = [IntPtr]$transcripts[0].Current.NativeWindowHandle
                                Wait-Until {
                                    $script:messagePoint = [VerifyNative]::MessageBubblePoint($transcript)
                                    $true
                                } 'painted message bubble after suggestion delivery'
                                $menuLinesBefore = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' }).Count
                                Doctor
                                Record 'Real SendInput right-click inside the owned transcript message bubble'
                                [VerifyNative]::RightClickTranscript($transcript, $process.Id, $script:window, $script:messagePoint)
                                Wait-Until {
                                    $lines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' })
                                    $lines.Count -gt $menuLinesBefore
                                } 'app logged the opened message menu'
                                $menuLines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] message menu items=' })
                                if ($menuLines.Count -ne $menuLinesBefore + 1 -or $menuLines[-1] -cnotmatch '\[chat\] message menu items=Reply,Copy$') { throw ('Unexpected message menu: ' + $menuLines[-1]) }
                                $menuCheck.items = 'Reply,Copy'
                                Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 1 } 'owned native message popup visible'
                                $menuWindow = @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible })[0]
                                $menuLook = [VerifyNative]::MenuLook([IntPtr]::new([int64]$menuWindow.handle))
                                $menuCheck.look = $menuLook
                                Snapshot 'message-menu'
                                if ($menuLook.cornerShown) { throw 'IGSH-892: message menu corner is still drawn, so the menu is square' }
                                if ($menuLook.leftEdge -ne $menuLook.fill -or $menuLook.rightEdge -ne $menuLook.fill) { throw ('IGSH-892: message menu has a border: edges ' + $menuLook.leftEdge + ' and ' + $menuLook.rightEdge + ' differ from fill ' + $menuLook.fill) }
                                Press @(0x1B) 'Esc: dismiss message menu'
                                Wait-Until { @([VerifyNative]::DesktopWindows() | Where-Object { $_.pid -eq $process.Id -and $_.class -eq '#32768' -and $_.visible }).Count -eq 0 } 'no visible owned native popup after Esc'
                                $menuCheck.passed = $true
                                $menuCheck.reason = ''
                            } catch {
                                $menuCheck.reason = $_.Exception.Message
                                throw
                            }
                            try {
                                $quoteLinesBefore = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' }).Count
                                $stdinBytesBeforeReply = (Get-Item ($prefix + '-stdin.bin')).Length
                                Doctor
                                Record 'IGSH-717: genuine SendInput drag over only part of the owned user bubble text'
                                $selectionCheck.points = @([VerifyNative]::SelectTranscriptText($transcript, $process.Id, $script:window))
                                Snapshot 'selection-enter-reply-selected'
                                Wait-Until {
                                    $selectionCheck.selectionPixels = [VerifyNative]::TranscriptSelectionPixels($transcript, $selectionCheck.points)
                                    $selectionCheck.selectionPixels -ge ($selectionCheck.points[1].X - $selectionCheck.points[0].X)
                                } 'IGSH-717 drag paints a visible transcript selection before Enter'
                                Press @(0x0D) 'IGSH-717: Enter quotes the transcript selection instead of sending'
                                Wait-Until {
                                    @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' }).Count -gt $quoteLinesBefore
                                } 'IGSH-717 Enter creates a reply quote'
                                $quoteLines = @(Get-Content $debugLog | Where-Object { $_ -match '\[chat\] reply quote chars=' })
                                if ($quoteLines.Count -ne $quoteLinesBefore + 1 -or $quoteLines[-1] -cnotmatch '\[chat\] reply quote chars=(\d+)$') { throw 'Expected exactly one observable quote after selection Enter' }
                                $quoteChars = [int]$Matches[1]
                                if ($quoteChars -le 0 -or $quoteChars -ge $message.Length) { throw 'Enter did not quote only a nonempty part of the message' }
                                Wait-Until {
                                    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                                    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                                    $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                                    $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle -and [VerifyNative]::EditText([IntPtr]$composer.Current.NativeWindowHandle) -ceq ''
                                } 'IGSH-717 quote leaves the empty composer focused'
                                Snapshot 'selection-enter-reply'
                                if ((Get-Item ($prefix + '-stdin.bin')).Length -ne $stdinBytesBeforeReply) { throw 'Selection Enter sent input instead of only quoting' }
                                $selectionCheck.quoteChars = $quoteChars
                                $selectionCheck.messageChars = $message.Length
                                $selectionCheck.passed = $true
                                $selectionCheck.reason = ''
                                Press @(0x1B) 'Esc: cancel the selection reply quote'
                            } catch {
                                $selectionCheck.reason = $_.Exception.Message
                                throw
                            }
                        }
                    }
                } finally {
                    if ($typedCheck.ContainsKey('console')) {
                        $typedCheck.receivedBytes = (Get-Item ($typedPrefix + '-stdin.bin')).Length
                        $outbox = Get-Content $outboxPath -Raw | ConvertFrom-Json
                        $typedCheck.queued = @($outbox.queues.messages | Where-Object { $_.t -ceq $typedMessage -and $_.s -eq 0 -and $_.x -eq 0 }).Count -eq 1
                        $typedCheck.passed = $typedCheck.receivedBytes -eq 0 -and $typedCheck.queued
                        if (-not $typedCheck.passed) { throw 'Chat View overwrote a local typed draft or stopped keeping its message queued' }
                    }
                }
            }
            $stopCheck = @{ name = 'stop-in-box'; passed = $false; entry = 'Chat View working composer'; reason = 'not reached' }
            $result.checks += $stopCheck
            $debugLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $stopPrefix = Join-Path $scratch 'local-route-working'
            $readStopFrame = {
                $frame = @{ card = $null; size = 0; send = $null; stop = $null; attach = $null; mic = $null; anyStop = $null }
                if (-not (Test-Path $debugLog)) { return $frame }
                foreach ($line in @((Get-Content $debugLog -Raw) -split "`r?`n")) {
                    if ($line -match '\[chat\] composer card (-?\d+),(-?\d+),(-?\d+),(-?\d+) size=(\d+)') {
                        $frame.card = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                        $frame.size = [int]$Matches[5]
                        $frame.send = $null
                        $frame.stop = $null
                        $frame.attach = $null
                        $frame.mic = $null
                    } elseif ($line -match '\[chat\] (attach|mic) rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame[$Matches[1]] = @([int]$Matches[2], [int]$Matches[3], [int]$Matches[4], [int]$Matches[5])
                    } elseif ($line -match '\[chat\] send rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame.send = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                    } elseif ($line -match '\[chat\] stop rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)') {
                        $frame.stop = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
                        $frame.anyStop = $frame.stop
                    }
                }
                return $frame
            }
            $insideCard = { param($rect, $card) $rect[0] -ge $card[0] -and $rect[1] -ge $card[1] -and $rect[2] -le $card[2] -and $rect[3] -le $card[3] }
            try {
                $beforeStop = Read-Session
                Palette 'new cmd'
                Press @(0x0D) 'Enter: create local console for the in-box Stop check'
                Wait-Until {
                    $state = Read-Session
                    @($state.tabs).Count -eq @($beforeStop.tabs).Count + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
                } 'new local CMD session saved for the in-box Stop check'
                $stopState = Read-Session
                $stopTab = $stopState.active_tab
                if ($stopState.tabs[$stopTab].PSObject.Properties['cv'] -and $stopState.tabs[$stopTab].cv) {
                    Press @(0x12, 0x43) 'Alt+C: show new working console'
                }
                Wait-WorkspaceSurface $stopState.active_workspace $stopTab $false
                Type-Text ('"' + $localAgent + '" working "' + $stopPrefix + '"')
                Press @(0x0D) 'Enter: launch working Claude stand-in'
                Wait-Until {
                    if (-not (Test-Path ($stopPrefix + '-ready.json'))) { return $false }
                    $script:stopReady = Get-Content ($stopPrefix + '-ready.json') -Raw | ConvertFrom-Json
                    $script:stopReady.chars.Count -eq 32
                } 'working stand-in rendered its status line and empty prompt'
                if ($script:stopReady.chars[0] -ne 0x276F -or $script:stopReady.chars[1] -ne 32) { throw 'Working stand-in did not render the Claude prompt glyph and separator' }
                Wait-Until {
                    $inbox = Read-Inbox
                    @($inbox.shells | Where-Object { $_.sid -eq $stopState.tabs[$stopTab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
                } 'working claude.exe detected as Claude' -Seconds 45
                Press @(0x12, 0x43) 'Alt+C: open working agent Chat View'
                Wait-Until {
                    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                    $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                    $null -ne $composer -and $composer.Current.ProcessId -eq $process.Id -and -not $composer.Current.IsOffscreen -and [System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -eq $composer.Current.NativeWindowHandle
                } 'owned working Chat View composer focused'
                Wait-Until { $null -ne (& $readStopFrame).anyStop } 'app painted a Stop control for the working agent' -Seconds 45
                $empty = & $readStopFrame
                $stopCheck.empty = $empty
                if ($null -eq $empty.card) { throw ('No composer card logged; Stop rect ' + ($empty.anyStop -join ',') + ' is not inside the message box') }
                if ($null -eq $empty.stop) { throw 'Latest composer frame has no Stop while the agent is working' }
                $stopW = $empty.stop[2] - $empty.stop[0]
                $stopH = $empty.stop[3] - $empty.stop[1]
                if ($empty.size -le 0 -or $stopW -ne $empty.size -or $stopH -ne $empty.size) { throw ('Stop rect is ' + $stopW + 'x' + $stopH + ', expected the ' + $empty.size + ' px send size') }
                if (-not (& $insideCard $empty.stop $empty.card)) { throw ('Stop rect ' + ($empty.stop -join ',') + ' is outside composer card ' + ($empty.card -join ',')) }
                if ($null -ne $empty.send) { throw ('Send rect ' + ($empty.send -join ',') + ' is drawn while the composer is empty and the agent is working') }
                $stopClock = [Diagnostics.Stopwatch]::StartNew()
                $stopCheck.paintAttempts = 0
                Wait-Until {
                    $stopCheck.paintAttempts++
                    Snapshot 'stop-in-box'
                    try {
                        $stopCheck.stopPixels = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'stop-in-box.png'), $script:window, $empty.card, $empty.stop, $null)
                        $true
                    } catch {
                        $stopCheck.stopPixelsReason = $_.Exception.Message
                        $false
                    }
                } 'stop-in-box screenshot paints the grey Stop disc in the logged Stop slot' -Seconds 10
                $stopCheck.paintedAfterMs = [int]$stopClock.ElapsedMilliseconds
                Snapshot 'composer-working-empty'
                $stopCheck.workingEmptyPixels = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'composer-working-empty.png'), $script:window, $empty.card, $empty.stop, $null)
                $stopSize = $empty.stop[2] - $empty.stop[0]
                [VerifyNative]::MoveMouseClient($script:window, [int](($empty.stop[0] + $empty.stop[2]) / 2), [int](($empty.stop[1] + $empty.stop[3]) / 2), $true)
                Wait-Until {
                    Snapshot 'stop-hover'
                    [VerifyNative]::RegionDiff((Join-Path $Evidence 'composer-working-empty.png'), (Join-Path $Evidence 'stop-hover.png'), $script:window, $empty.stop[0] + [int]($stopSize / 4), $empty.stop[1] + [int]($stopSize / 4), $empty.stop[0] + [int]($stopSize / 2), $empty.stop[1] + [int]($stopSize / 2)) -gt 0
                } 'pointer over Stop repaints the hovered button' -Seconds 10
                $stopCheck.hoverLabelDiffPixels = [VerifyNative]::RegionDiff((Join-Path $Evidence 'composer-working-empty.png'), (Join-Path $Evidence 'stop-hover.png'), $script:window, $empty.stop[2] - 4 * $stopSize, $empty.card[1] - [int]($stopSize / 2), $empty.stop[2], $empty.card[1] - 1)
                if ($stopCheck.hoverLabelDiffPixels -gt 4) { throw ('Stop button hover shows a label above the message box: ' + $stopCheck.hoverLabelDiffPixels + ' pixels changed') }
                [VerifyNative]::MoveMouseClient($script:window, [int]($empty.card[0] + ($empty.card[2] - $empty.card[0]) / 2), $empty.card[1] - 3 * $stopSize, $false)
                Type-Text 'x'
                Wait-Until { $typed = & $readStopFrame; $null -ne $typed.card -and $null -ne $typed.send -and $null -eq $typed.stop } 'Send replaces Stop after typing while working'
                $typed = & $readStopFrame
                $stopCheck.typed = $typed
                if (($typed.send[2] - $typed.send[0]) -ne $typed.size -or ($typed.send[3] - $typed.send[1]) -ne $typed.size) { throw 'Send changed size after typing' }
                if (-not (& $insideCard $typed.send $typed.card)) { throw 'Send is outside the composer card after typing' }
                if (($typed.send -join ',') -ne ($empty.stop -join ',')) { throw ('Send rect ' + ($typed.send -join ',') + ' is not in the slot Stop used: ' + ($empty.stop -join ',')) }
                Snapshot 'composer-working-text'
                Snapshot 'grey-buttons'
                $buttonsCheck = @{ name = 'round-bottom-composer-buttons'; passed = $false; frames = @() }
                $result.checks += $buttonsCheck
                foreach ($lines in @(1, 6)) {
                    if ($lines -eq 6) {
                        for ($line = 2; $line -le 6; $line++) {
                            Press-ShiftEnter 'Shift+Enter: grow the owned draft without sending'
                            Type-Text ('Draft line ' + $line)
                        }
                    }
                    Wait-Until {
                        $frame = & $readStopFrame
                        $null -ne $frame.mic -and $null -ne $frame.attach -and $null -ne $frame.send -and $null -eq $frame.stop -and
                        ($lines -eq 1 -or $frame.card[1] -lt $typed.card[1] - 2 * $frame.size)
                    } 'all three composer buttons painted at the requested draft height'
                    $frame = & $readStopFrame
                    foreach ($name in @('attach', 'mic', 'send')) {
                        $rect = $frame[$name]
                        if ($rect[3] -ne $frame.send[3] -or $rect[1] -ne $frame.send[1] -or
                            ($rect[2] - $rect[0]) -ne $frame.size -or ($rect[3] - $rect[1]) -ne $frame.size) {
                            throw ('Composer button is not equally sized and bottom-aligned: ' + $name)
                        }
                    }
                    $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                    if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Multiline proof lost the owned composer' }
                    $draft = [VerifyNative]::EditText($composerHandle)
                    if (@($draft -split "`r?`n").Count -ne $lines) { throw 'Owned composer does not contain the requested number of draft lines' }
                    Snapshot ('composer-' + $lines + '-line')
                    $buttonsCheck.frames += @{ lines = $lines; layout = $frame; draft = $draft }
                }
                $buttonsCheck.passed = $true
                Press @(0x11, 0x41) 'Ctrl+A: select the multiline proof draft'
                Press @(0x08) 'Backspace: restore the earlier single-line proof state'
                Type-Text 'x'
                Press @(0x1B) 'Esc: stop the working agent from the composer'
                Wait-Until {
                    $stdin = [IO.File]::Open($stopPrefix + '-stdin.bin', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                    try {
                        $buffer = New-Object IO.MemoryStream
                        try {
                            $stdin.CopyTo($buffer)
                            $stopBytes = $buffer.ToArray()
                        } finally { $buffer.Dispose() }
                    } finally { $stdin.Dispose() }
                    $stopCheck.receivedBytes = $stopBytes.Length
                    $stopBytes -contains [byte]0x1B
                } 'Esc reached the working stand-in stdin'
                $composerHandle = [VerifyNative]::GetFocusedWindow($script:window)
                if ([VerifyNative]::GetAncestor($composerHandle, 2) -ne $script:window -or [VerifyNative]::Class($composerHandle) -cne 'Edit') { throw 'Send click proof lost the owned composer' }
                $sendFrame = & $readStopFrame
                if ($null -eq $sendFrame.send -or $null -ne $sendFrame.stop) { throw 'Send is not the only action button before the click' }
                if ([VerifyNative]::EditText($composerHandle).Length -eq 0) { throw 'Composer draft is empty before the Send click' }
                [VerifyNative]::ClickClient($script:window, [int](($sendFrame.send[0] + $sendFrame.send[2]) / 2), [int](($sendFrame.send[1] + $sendFrame.send[3]) / 2))
                Wait-Until { [VerifyNative]::EditText($composerHandle).Length -eq 0 } 'clicking Send took the draft out of the composer'
                $stopCheck.sendClicked = $true
                $stopCheck.passed = $true
                $stopCheck.reason = ''
            } catch {
                $stopCheck.reason = $_.Exception.Message
                throw
            }
            try {
                $greyCheck.typed = [VerifyNative]::GreyButtonPixels((Join-Path $Evidence 'grey-buttons.png'), $script:window, $typed.card, $typed.stop, $typed.send)
                $greyCheck.passed = $true
                $greyCheck.reason = ''
            } catch {
                $greyCheck.reason = $_.Exception.Message
                throw
            }
        