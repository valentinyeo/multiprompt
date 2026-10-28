
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'Offline CMD session proves typing focus, not agent delivery' }
            Press @(0x12, 0x43) 'Alt+C: enable Chat View for the isolated CMD session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].cv -and
                    -not ($state.tabs[0].PSObject.Properties['bon'] -and $state.tabs[0].bon)
            } 'one saved Chat View session without a browser pane'
            Wait-ChatFocus 'Edit' 'chat-enabled'
            Restart-ChatView 1
            Assert-ChatTyping 'abc' 'restart-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select restart draft'
            Press @(0x08) 'Backspace: clear restart draft'
            Press @(0x11, 0x46) 'Ctrl+F: open Chat Find'
            Wait-ChatFocus 'ZigShellChatTranscript' 'find-open'
            Snapshot 'action'
            Press @(0x12, 0x51) 'Alt+Q: close Find and restore typing without a pane'
            Assert-ChatTyping 'abc' 'find-alt-q-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select recovered draft'
            Press @(0x08) 'Backspace: clear recovered draft'
            Press @(0x1B) 'Esc: dismiss any remaining Find'
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
            $transcript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
            if ($null -eq $transcript -or $transcript.Current.ProcessId -ne $process.Id -or $transcript.Current.IsOffscreen) { throw 'Owned transcript is not visible for mouse input' }
            $handle = [IntPtr]$transcript.Current.NativeWindowHandle
            if ($handle -eq [IntPtr]::Zero -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Transcript is not in the owned app window' }
            $rect = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetClientRect($handle, [ref]$rect) -or $rect.Right -le 0 -or $rect.Bottom -le 0) { throw 'Owned transcript rectangle unavailable' }
            Doctor
            Assert-Foreground
            Record 'Click the ownership-checked transcript rectangle using real mouse input'
            [VerifyNative]::ClickClient($handle, [int]($rect.Right / 2), [int]($rect.Bottom / 2))
            Snapshot 'transcript-clicked'
            Press @(0x12, 0x51) 'Alt+Q: return from transcript to composer without a pane'
            Assert-ChatTyping 'abc' 'transcript-alt-q-typing'
            Press @(0x11, 0x41) 'Ctrl+A: select final draft'
            Press @(0x08) 'Backspace: clear final draft'
            Press @(0x11, 0x46) 'Ctrl+F: reopen Find for the Alt+M alias'
            Wait-ChatFocus 'ZigShellChatTranscript' 'alias-find-open'
            Press @(0x12, 0x4D) 'Alt+M: close Find and restore typing without a pane'
            Assert-ChatTyping 'abc' 'find-alt-m-typing'
            Snapshot 'after'
            $result.checks += @{ name = 'chat-focus'; restartTyping = $true; findAltQTyping = $true; transcriptAltQTyping = $true; findAltMTyping = $true; panePresent = $false; entry = 'Alt+C, Ctrl+F, Alt+Q, mouse and Alt+M' }
        