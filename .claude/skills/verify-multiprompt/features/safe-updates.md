# Safe release updates

Source files: src/update*, src/release*, src/startup.zig, src/launch_snapshot.zig, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/update-release-journey.ps1, .github/workflows/legacy-update-feed.yml, tools/legacy-update-proof.ps1

## Sub-features

Signed-manifest verification, background staging, explicit and cold apply, helper retirement, bundle rollback and launch-argument preservation.

- Plain update-card notes show up to three plain lines from the offered release, never an older skipped version, then a `See all` link to that release's notes on GitHub (MUBO-577).
- Staged release notes retain ticket IDs, titles and ticket links.
- Background checks run every five minutes, so a release reaches an open app quickly (IGSH-838).

## How to get to it (user POV)

Dispatch `verify.yml` with `feature=safe-updates` on the branch. The shared `control.ps1` validates the executable identity and delegates this feature to `tools/update-release-journey.ps1` instead of the normal session driver.

## Driving it with control.ps1

The disposable GitHub Windows job compiles local fake release executables, creates a throwaway Ed25519 key in memory, embeds its public key in the branch verifier, and serves release downloads from a local folder through the PowerShell library transport. No production signing key or network release is used for swaps.

Prove responsive signed-out launch during background checking, cold-launch staged apply with original arguments, valid and rejected manifest signatures, checksum and provenance refusals, no unattended restart, explicit apply behind a download lock, matching bridge/extension installation, a second update with old helpers locking the backup, immediate-exit rollback, and recovery after the old-process exit timeout.

- The fixture driver stages signed notes for several versions newer than the running app, then launches that real app with the cold-apply readiness flag. A held update mutex prevents production checks from replacing the local fixture.
- It independently checks signed staged JSON for four ticket-title entries across three releases, one of them ticketed on the moved board (`MUBO-77`). Production paint logs must show only the offered release's two plain titles, with the middle and older release titles absent, the `See all` destination matching the offered version, and unclipped note bounds. A real ownership-checked mouse click on `See all` opens that release's notes in the default browser. Screenshots and observed paint data are saved as `update-card-notes.png` and `update-card-notes.json`.
- A second signed fixture checks `IGSH-1243 Changelog ticket links` and its ticket URL; its proof is `ticket-title staged notes retain title and ticket link`. The fixture also stages a newer native executable at the installed path and verifies the restart card restores the saved session. Screenshots still require visual review; paint logs cannot prove readability.

## Gotchas

User entry points are the sidebar Update ready card and Ctrl+K Restart to update; the latter is absent in dev builds. Dismissal, the `See all` link and overflowing release notes are separate controls. Signed release lines keep the ticket key the release pipeline publishes: `IGSH-` from board 2060 (including `SOFT-` fragments) and `MUBO-` from board 13734. The card paints the plain title alone and logs the key for proof. The fixture restart uses posted mouse messages, not proof of a physical user click on every update surface.

The real release-notes proof (`tools/update-card-real-notes.test.js`) runs the same default browser inside the app's isolated environment, so a fresh browser profile would show first-run onboarding instead of the release page. It applies the documented `HideFirstRunExperience` and `SyncDisabled` Edge policies, proves a local page renders in that profile, then requires the real `See all` click to start a browser process carrying the release address and a window naming the release. It restores the previous policy values at cleanup and leaves the user's default browser choice alone.

When the offered release names no change the card shows no lines and no `See all`. It never borrows an older release's notes, so the card and the page it opens always describe the same release.

The wrapped-card proof (`tools/update-card-release-proof.ps1`) restores the window to 1024x768 before its first screenshot, forces and flushes a paint, and checks the captured pixels: the Restart control, the `See all` row below the notes and the note lines must be visible, so a stale or clipped frame fails instead of passing on log coordinates alone. The new contract looks for its white pill at the point the app logs; the old released painter keeps a blue filled Restart button, so the released contract instead requires an 86x19 blue block with white label pixels inside the sidebar card columns, which a blue text line or a thin blue bar cannot satisfy. It saves `released-card.png` with `wrapped-normal.png`, `wrapped-minimum.png`, `wrapped-scrolled.png` and `wrapped-collapsed.png`, each with its window, client and DPI record in `wrapped-card.json`. The update card is bottom-anchored, so its controls sit near the window edge at small sizes; always read an image next to its own geometry record.


`safe-updates.json` records each successful scenario and cleanup; `sign-in-ready.png` shows the responsive signed-out app; `build.json` pins the branch executable and commit. Any missing assertion fails the job. All fixture processes are stopped before evidence is uploaded. The journey waits for the proof names the harness actually passes, and writes `result.json` only after its last check, so a late failure cannot report passed.
