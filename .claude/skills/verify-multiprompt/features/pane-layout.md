# Pane layout

## Sub-features

- Alt+Q switches browser ↔ the current typing surface, without a focus outline on chat, browser or shell. Alt+C still selects chat versus shell; this is not a new three-way Alt+Q cycle.
- Console HWND placement and chat content retain their existing pane insets. Surface borders, browser masks and the short centered splitter grip are unchanged.
- Focused and unfocused pane margins have exactly equal screenshot pixels, including rounded-corner areas and the browser bottom-mask row.
- The live journey covers Dark, Multiprompt, Light, AMOLED, Mid, Edge Gray and System at the fresh desktop's default UI scale. Compiled geometry regressions retain 100, 125 and 150 percent coverage.

## How to get to it (user POV)

- Keep the initial CMD tab in console view. Ctrl+K `move to group`, Enter, type `new group`, Enter groups it. Escape the inline rename.
- Create a second ungrouped CMD through Ctrl+K `new cmd`, open its browser through Ctrl+K `open browser`, and maximize with Win+Up. Ctrl+2 returns to the second console.
- Alt+Q enters the browser and returns to typing. Alt+C selects Chat View; repeat Alt+Q to enter the browser and return to the composer.
- Choose each theme through Ctrl+K → Themes. No preferences or session files are seeded.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref ceo/IGSH-807 -f feature=pane-layout` only after an authorized owner publishes the revision. The PR matrix already includes pane-layout. Do not push or open a PR merely to obtain proof without authorization.

1. Launch the isolated real app, pass Doctor, group the first CMD, create the second CMD, and dock its owned browser. Check saved session identities, native ownership, console UIA/HWND bounds, DPI and scale. Retain `pane-layout-rects.json`.
2. For each theme, start on the second console and perform two complete shell → browser → shell Alt+Q cycles, then Alt+C and two chat → browser → chat cycles. Only the initial console selection and Alt+C use the existing foregrounding Press helper; the Alt+Q chords and subsequent proof input use direct real SendInput after read-only Doctor, with no focus-repair operation between chord and evidence.
3. Prove shell input with distinct typed CMD commands and exact marker-file contents before and after each return. Prove chat input with ownership-checked WM_GETTEXT, an exact unsent draft, an unchanged draft while the browser receives input, and a typed suffix after returning. Clear drafts only after evidence is saved.
4. Navigate the owned browser through Ctrl+L to a local data URL whose page increments its title on `j`. Each browser visit must accept the next `j` into page content and publish the exact next counter in its title. This needs no browser extension, remote server or real agent.
5. Save `focus-<theme>-<view>-<cycle>-input.png`, `-browser.png`, `-returned.png` and their focus/UIA snapshots. Compare every pixel in both panes' full ten-scaled-pixel margins between input-focused and browser-focused screenshots. The unfocused screenshot is the same-theme surface reference, not a guessed ring color or a tolerance. Include all four sides, corner areas and the complete browser bottom-mask line. Persist sample counts, mismatch counts and first mismatch coordinates/colors in `-pixels.json` and `focus-ring-proof.json`. Pixels within two scaled pixels of either pane content rectangle are excluded, so browser chrome and console content cannot mask a ring. Require zero mismatches in every checkpoint; do not mask or repaint screenshot pixels.
6. Only after every theme/view/cycle has completed and its input/screenshots are retained, fail with `IGSH-807 focus ring pixels differ from the unfocused surface` if any margin differs. On success, restore Dark and the console, then retain the existing console-inset, clean-gap, plain-group-headline and visible-icon checks in `pane-layout-pixels.json`. Capture `after.png` and require owned-job cleanup.
7. For branch builds, verify.yml first builds exact pre-fix commit `9618091700e09f5958a48390449dc5067874d5dd` in a separate checkout and invokes the identical edited driver against it. Require failure specifically at the no-ring assertion after all input checkpoints; every theme/view/cycle must have nonzero pixel differences. Require zero remaining owned processes and removed scratch. Keep the entire control under `focus-negative/`, including executable provenance, screenshots and pixel measurements. Then run the fixed executable into the root artifact directory and require success.
8. Download `verify-pane-layout` and inspect matching red and green screenshots at the exact revisions. Confirm ring-colored strokes really caused the red pixel differences and that no ring remains in green, rather than accepting unrelated content movement or window occlusion. Record run URL, executable hashes, input proofs and screenshot review in GATES.md. A workflow definition is not a run result.

## Gotchas

- The pinned control and fixed build execute only on GitHub's free Windows desktop runners. A tag run selects a published release and does not supply the branch's paired control.
- Native browser HWNDs are inset ten scaled pixels from the browser slot. Derive slot bounds from that inset, not from an invented focus UIA node. Keep surface borders and pane placement unchanged.
- Exact margin comparisons cover the old ring footprint; content, carets, page text and console output lie inside the excluded content rectangle. Unexpected native focus decoration or geometry movement must fail and be investigated, not relaxed into a color-distance allowance.
- System resolves to the runner's Windows appearance. The DEV-only custom theme is not exposed by this production build; the source removal is unconditional across theme branches. Live 125/150 percent, DEV custom-theme screenshots, full-width and reconnect are not claimed by this default-scale desktop journey.
- Offline CMD, a local page and unsent drafts prove input routing, not AI delivery, account synchronization or remote session behavior. No desktop run or screenshot review has occurred in this editing session.
