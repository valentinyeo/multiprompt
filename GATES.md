# Gates: IGSH-845 caption corner

OWNS: GATES.md, src/**, tools/**, .claude/skills/verify-multiprompt/**, .github/workflows/verify.yml, changelog.d/**

Scope: Separate Windows pixel-proof and caption-fix commits, preserve browser-chrome masking, and prepare an origin/master negative-control branch without local execution.

- [x] G1: Required guidance and caption, mask, theme and verification paths have been inspected before implementation.
  EVIDENCE: Read CLAUDE.md, verify-multiprompt SKILL.md, feature index and pane-layout map, Win32 guidance, main native-window creation, applyTitleBarTheme, browser docking/positioning and all edge-mask fill/placement/theme-refresh paths before implementation.

- [x] G2: Commit A contains a real Windows AMOLED caption journey covering light and dark browser chrome at 100%, 125% and 150%, live app theme changes, single glyphs, black caption backgrounds and app-coloured caption mask, with durable pixel evidence and negative controls.
  EVIDENCE: Source inspection of title-bar.ps1, title-bar-native.cs, tools/title-bar.test.js and verify.yml: six DPI/theme jobs; real DisplayConfig plus GetDpiForWindow; browser-free DWM pixel reference; restored/maximized and Light-to-AMOLED refresh; all-pixel caption/apron comparisons; separate IGSH-810 interior samples; identical-oracle duplicate/band negative controls. This gate proves committed harness content, not execution (G4).

- [x] G3: Commit B gives the caption corner one painter, bounds browser-coloured masking below it, refreshes app caption colour on theme changes and preserves IGSH-810 browser-mask behaviour.
  EVIDENCE: Source review: lockedBrowserStyle now strips WS_SYSMENU as well as native caption/minimize/maximize styles; only the main DWM caption retains native window controls. browserEdgeMaskWndProc fills the controls cover with shared themeTitleBarBg, then paints sampled browser colour only below the browser screen origin; positionBrowserEdgeMasks clamps both control covers below the main client origin. Existing theme actions call applyTitleBarTheme and refreshBrowserEdgeMasks, so no launch-only colour cache is used. Main class has no stale launch brush. IGSH-810 sampling and browser-interior colour selection are unchanged. Added stronger style assertions and extracted-production clipping/negative-mutation tests; runtime remains G4.

- [ ] G4: Real Windows execution proves the unchanged journey red on origin/master plus A and green on A plus B.
  EVIDENCE: Not run. The user requested local branch preparation and dispatch commands, not publication. No push, workflow dispatch, local build or test was performed. An authorized runner must publish both refs, require a caption/apron-specific red failure rather than an infrastructure failure, require six green jobs, and inspect exact-revision screenshots and cleanup.

- [x] G5: Local ceo/IGSH-845 contains commits A and B; local ceo/IGSH-845-red starts at origin/master with only A; exact branch SHAs, changed files and workflow dispatch commands are recorded.
  EVIDENCE: Red branch 7028aea137ea013f035f37bb4a2f166deaa1d63c was created at observed origin/master c52611da6783999b4b4c03d84c333ca9c05f7eb9 with only journey commit A cherry-picked; its temporary worktree was clean and removed. Green commit A is 4fd33a95c7214ad49a6b6e91b1c10c5c16df2775; this ledger update ships in app-fix commit B. Post-commit branch HEADs, parentage and changed-file reads are the final report oracle. Source base difference is only intervening release stamps/changelog consumption (green base 717f6fca, red base c52611da), not caption code. Exact dispatch commands are recorded below.

- [x] G6: No local app build, Zig, PowerShell or test suite execution was performed; changed code contains no added comments and no weakened assertions.
  EVIDENCE: Session command review: only source/Git reads, edits, requested Git operations and ETA updates; no local app build, Zig, PowerShell, node test suite, ledger lint/check or desktop execution. Mandatory Git secret-scan hooks stayed enabled. Diff review found no added code comments or weakened assertions; the style contract gains WS_SYSMENU, and existing geometry assertions remain intact.

Verification boundary: the user permits local reading only, plus the requested edits and Git commit/branch operations. All app/test validation is reserved for the Windows workflow; mandatory Git security hooks remain enabled for the requested commits. Ledger lint/check execution is also excluded by the local-reading-only restriction. Manual source inspection is not a claim of a passing Windows run. G4 must remain visibly unproven until workflow evidence exists.

ABANDON: G4 Windows red/green execution and screenshot review require authorized publication and runner dispatch; no runtime proof is claimed.

## Runner commands

```sh
gh workflow run verify.yml --repo valentinyeo/multiprompt --ref ceo/IGSH-845-red -f feature=title-bar
gh workflow run verify.yml --repo valentinyeo/multiprompt --ref ceo/IGSH-845 -f feature=title-bar
```

Source/preparation gates: G1, G2, G3, G5 and G6. Runtime gate G4 is a required handoff, not a pass. Commit A retains the unchanged Windows pixel journey on both refs. No executable gate-checker evidence was generated under the user's local-reading-only rule.
