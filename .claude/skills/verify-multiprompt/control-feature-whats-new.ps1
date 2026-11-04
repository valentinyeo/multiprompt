            $sourcePath = Join-Path $PSScriptRoot '../../../src/changelog.zig'
            $source = [IO.File]::ReadAllText((Resolve-Path $sourcePath))
            $entries = [regex]::Matches($source, '(?s)\.\{ \.ver = "([^"]+)", \.items = &\.\{(.*?)\}\s*\},')
            if ($entries.Count -lt 3) { throw 'What is new: production changelog has fewer than three releases' }
            $expected = @()
            foreach ($entry in $entries) {
                $items = @([regex]::Matches($entry.Groups[2].Value, '\.\{ \.text = "([^"]+)", \.ticket = "([^"]+)"\s*\}') | ForEach-Object { @{ title = $_.Groups[1].Value; ticket = $_.Groups[2].Value } })
                if ($items.Count -gt 0) { $expected += @{ version = $entry.Groups[1].Value; items = $items } }
            }
            if ($expected.Count -lt 3) { throw 'What is new: production title rows unavailable' }
            Save-Json @{ source = 'src/changelog.zig'; buildVersion = $ExpectedVersion; releases = $expected; note = 'First release version may be stamped at build time; compare visible rows with these source titles.' } 'whats-new-source.json'
            Focus-Palette 'changelog' 6241
            Snapshot 'action'
            Record 'Enter: open Changelog'
            $openMs = [VerifyNative]::MeasureChangelogKey($script:window, 0x0D)
            Snapshot 'whats-new-first'
            Record 'Page Down: navigate historical releases'
            $pageMs = [VerifyNative]::MeasureChangelogKey($script:window, 0x22)
            Snapshot 'whats-new-history'
            Record 'Home: return to newest release'
            $homeMs = [VerifyNative]::MeasureChangelogKey($script:window, 0x24)
            Snapshot 'whats-new-returned'
            Record 'Escape: close Changelog'
            $closeMs = [VerifyNative]::MeasureChangelogKey($script:window, 0x1B)
            Snapshot 'after'
            $result.checks += @{ name = 'whats-new-keyboard-navigation'; entry = 'Ctrl+K Changelog target 6241'; source = 'whats-new-source.json'; first = 'whats-new-first.png'; history = 'whats-new-history.png'; returned = 'whats-new-returned.png'; openMs = $openMs; pageMs = $pageMs; homeMs = $homeMs; closeMs = $closeMs; visualReviewRequired = $true }
