                            Palette 'open browser'
                            Press @(0x0D) 'IGSH-724: opening an existing pane focuses its page'
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Opening the pane did not focus its browser' }
                            [VerifyNative]::Chord(@(0x20))
                            $pageKeys++
                            if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 opening a pane sent Space to browser chrome' }
