
            $commandsPath = Join-Path $scratch 'roaming/ZigShell/commands.json'
            New-Item -ItemType Directory -Force -Path (Split-Path $commandsPath) | Out-Null
            $folder = '/tmp/multiprompt-harness-folder'
            $names = @('Workspace 1', 'Workspace 2', 'Starred', 'Main', 'Software Factory', 'Verification')
            $entries = @(foreach ($name in $names) { [ordered]@{ label = ('Harness folder ' + $name); kind = 'vps'; default = $true; workspace = $name; cwd = $folder } })
            $json = [ordered]@{ commands = $entries } | ConvertTo-Json -Depth 5
            [IO.File]::WriteAllText($commandsPath, $json, (New-Object Text.UTF8Encoding($false)))
            Start-Sleep -Milliseconds 500
            $beforeClaude = @( (Read-Session).tabs ).Count
            Press @(0x11, 0x54) 'Ctrl+T: new Claude chat'
            Start-Sleep -Milliseconds 2000
            $entry = 'Ctrl+T'
            if (@( (Read-Session).tabs ).Count -ne $beforeClaude + 1) {
                $entry = 'palette New Claude chat'
                Palette 'New Claude chat'
                Press @(0x0D) 'Enter: New Claude chat'
                Start-Sleep -Milliseconds 2000
            }
            Wait-Until { @( (Read-Session).tabs ).Count -eq $beforeClaude + 1 } 'new Claude chat tab saved'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state) { return $false }
                $tab = @($state.tabs)[$state.active_tab]
                $null -ne $tab -and $tab.PSObject.Properties['cv'] -and $tab.cv -eq $true
            } 'new Claude tab saved in Chat View'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $transcript = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                $composer = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                $shown = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $transcript) | Where-Object { -not $_.Current.IsOffscreen }).Count -ge 1
                $shown -and @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $composer) | Where-Object { -not $_.Current.IsOffscreen }).Count -ge 1
            } 'Chat View transcript and composer visible for the new Claude tab'
            Snapshot 'ctrl-t-chat-view'
            $result.checks += @{ name = 'ctrl-t-chat-view'; entry = $entry; tabsBefore = $beforeClaude; tabsAfter = @( (Read-Session).tabs ).Count; commands = 'harness workspace folder seeded' }
            Press @(0x11, 0x57) 'Ctrl+W: close the new Claude tab'
            Wait-Until { @( (Read-Session).tabs ).Count -eq $beforeClaude } 'new Claude tab closed'
            Remove-Item -LiteralPath $commandsPath -Force

            $before = @( (Read-Session).tabs ).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New CMD shell'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $before + 1 } 'new CMD tab saved'
            Press @(0x71) 'F2: rename active tab'
            Press @(0x11, 0x41) 'Ctrl+A: replace tab name'
            Type-Text 'Verification session'
            Press @(0x0D) 'Enter: save tab name'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -eq 'Verification session' }).Count -eq 1 } 'renamed tab persisted'
            $marker = Join-Path $scratch 'user-created.txt'
            Type-Text ('echo verified-from-real-cmd>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute shell command'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq 'verified-from-real-cmd' } 'real console command wrote file'
            $result.checks += @{ name = 'create-rename-execute'; tabsBefore = $before; tabsAfter = @((Read-Session).tabs).Count; marker = (Get-Content $marker -Raw).Trim() }
            Snapshot 'after'
        