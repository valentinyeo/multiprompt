# Gates: IGSH-845 caption corner

OWNS: GATES.md, src/**, tools/**, .claude/skills/verify-multiprompt/**, .github/workflows/verify.yml, changelog.d/**

Scope: Separate Windows pixel-proof and caption-fix commits, preserve browser-chrome masking, and prepare an origin/master negative-control branch without local execution.

- [x] G1: Required guidance and caption, mask, theme and verification paths have been inspected before implementation.
  EVIDENCE: Read CLAUDE.md, verify-multiprompt SKILL.md, feature index and pane-layout map, Win32 guidance, main native-window creation, applyTitleBarTheme, browser docking/positioning and all edge-mask fill/placement/theme-refresh paths before implementation.

- [x] G2: Commit A contains a real Windows AMOLED caption journey covering light and dark browser chrome at 100%, 125% and 150%, live app theme changes, single glyphs, black caption backgrounds and app-coloured caption mask, with durable pixel evidence and negative controls.
  EVIDENCE: Source inspection of title-bar.ps1, title-bar-native.cs, tools/title-bar.test.js and verify.yml: six DPI/theme jobs; real DisplayConfig plus GetDpiForWindow; browser-free DWM pixel reference; restored/maximized and Light-to-AMOLED refresh; all-pixel caption/apron comparisons; separate IGSH-810 interior samples; identical-oracle duplicate/band negative controls. This gate proves committed harness content, not execution (G4).

- [ ] G3: Commit B gives the caption corner one painter, bounds browser-coloured masking below it, refreshes app caption colour on theme changes and preserves IGSH-810 browser-mask behaviour.
  EVIDENCE: pending

- [ ] G4: Real Windows execution proves the unchanged journey red on origin/master plus A and green on A plus B.
  EVIDENCE: pending

- [ ] G5: Local ceo/IGSH-845 contains commits A and B; local ceo/IGSH-845-red starts at origin/master with only A; exact branch SHAs, changed files and workflow dispatch commands are recorded.
  EVIDENCE: pending

- [ ] G6: No local app build, Zig, PowerShell or test suite execution was performed; changed code contains no added comments and no weakened assertions.
  EVIDENCE: pending

Verification boundary: the user permits local reading only, plus the requested edits and Git commit/branch operations. All app/test validation is reserved for the Windows workflow; mandatory Git security hooks remain enabled for the requested commits. Ledger lint/check execution is also excluded by the local-reading-only restriction. Manual source inspection is not a claim of a passing Windows run. G4 must remain visibly unproven until workflow evidence exists.
