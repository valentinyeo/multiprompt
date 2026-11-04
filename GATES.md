# IGSH-1651 gates

- [x] A test fails today and passes with the fix. Windows run 41810436539 failed the pending-frame test; candidate run 41811555235 passed test-windows (1).
- [ ] Live Windows proof: after time in the background, the app answers at once. Background/minimize/restore journey pending.
- [ ] CI green.
- [ ] Full CI green on this PR. https://github.com/valentinyeo/multiprompt/pull/743
- [ ] A freeze with a responsive message loop but missing paints saves a report. Ordered redraw-suppression journey pending.

# Work order

1. Reproduce it yourself on the matching surface via the control skill.
2. Binary-search the cause.
3. Plan the fix.
4. Verify on the same surface.
5. Stage the commits so the failing repro lands before the fix in git history.
6. Run Opening a PR.

# Evidence and limits

- The original maximized-client intersection is preserved in commit 54cfe285. Its pending-frame regression expects the proposed rectangle to remain usable rather than shrink to the previous work area's overlap.
- Initial CI 41808774866 stopped at the missing-fragment gate, not the geometry regression. Commit 66267510 supplies the fragment; run 41810436539 is the intended failing regression control.
- The fix selects the monitor from proposed geometry, excludes iconic windows, and clips only a proposed maximized frame that spans the chosen work area. Restored and pending frames must retain their proposed dimensions.
- The native journey first validates cross-process NCCALCSIZE marshalling with a settled-frame control, then synthesizes an eight-pixel overlap. A checksum-verified v0.28.1450 must fail specifically with an eight-pixel client calculation. The candidate must preserve the proposal.
- Five real foreground/minimize/restore cycles retain client and frame bounds. Foreground and background idle periods must not create reports. A separate ordered posted-message fixture suppresses painting while WM_NULL stays responsive; it must produce exactly one paint-reason report and recover.
- The supplied incident continues processing window actions through normal taskbar closure. Missing slow-paint log entries alone do not prove missing paints. Geometry clipping is a concrete defect matching the collapsed client, but the exact operating-system transition from the incident remains inferred.
- Release RVAs disassemble to dialog-font callbacks. Raw stack scanning does not establish an active call chain. The symbol twin has a different layout; its required matching PDB is not a published asset. These addresses do not prove a synchronous-call deadlock.
- Transcript loading runs on a worker. Its long elapsed time is not evidence of a UI-thread wait. Browser mask suspension stops mask timers, not main-window redraw. Composer redraw suspension has deferred restoration.
- Allowed local checks: node --test tools/background-freeze.test.js tools/window-controls.test.js yielded 11 passes, 1 hosted-PowerShell skip. zig ast-check accepted all three changed Zig files. Native unit tests and desktop journeys have not run locally.
- No local builds, Wine or benchmarks. No board writes, version bump or merge. Native proof runs only on GitHub-hosted Windows. Synthetic geometry and paint suppression do not prove the exact live incident or physical multi-monitor movement.
