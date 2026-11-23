
            Select-Theme 'dark' 'baseline-dark-action'
            Snapshot 'before'
            Select-Theme 'light' 'action'
            Snapshot 'after'
            $dark = Sidebar-Luminance 'before'
            $light = Sidebar-Luminance 'after'
            if ($light -lt $dark + 60) { throw "Visible sidebar did not become light: $dark -> $light" }
            $reader = Sidebar-Dominant 'before'
            foreach ($channel in @($reader.r, $reader.g, $reader.b)) {
                if ([Math]::Abs($channel - 0x10) -gt 4) { throw "IGSH-1016 dark sidebar is not the Android reader background 101010: $($reader.r),$($reader.g),$($reader.b)" }
            }
            $result.checks += @{ name = 'IGSH-1016-reader-sidebar'; sidebarRgb = "$($reader.r),$($reader.g),$($reader.b)"; expected = '16,16,16' }
            $result.checks += @{ name = 'dark-to-light'; darkLuminance = $dark; lightLuminance = $light; savedTheme = 'light' }
        