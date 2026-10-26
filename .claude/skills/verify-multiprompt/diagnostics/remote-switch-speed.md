# Remote conversation and workspace switching

## Sub-features

- Twenty session switches alternate a local CMD and a second-host conversation with 2,000 rendered messages.
- Twenty workspace switches return to the same long conversation.
- Each switch completes below 150 ms, each completed application-frame gap stays at most 50 ms, and process CPU stays below 25% of one core.
- CPU returns to the measured idle range within two seconds.
- Read-marker updates preserve the current visit's measured layout. A moved unread divider invalidates only its affected suffix.
- Status-only remote replies preserve every measured conversation block. A failed remote read keeps its retry deadline across switches.

## How to get to it (user POV)

Use Ctrl+Tab for sessions and Alt+Left or Alt+Right for workspaces. No new app actions or timing limits are added.

## Driving it with the Windows performance harness

Dispatch the delivery driver through the existing workflow:

```sh
gh workflow run remote-switch.yml --ref <branch>
```

The PR runs both sides automatically. Download `remote-switch-baseline` and `remote-switch-candidate`. The driver uses an isolated saved remote tab on host 2, an alternate remote home, and the production embedded reader against the existing SSH/tmux boundary. It copies all 2,000 numbered messages through the real selection/copy commands before measuring. It prepares a read-divider transition, creates a local CMD through the palette, then drives 20 Ctrl+Tab switches. It closes only that owned local fixture, creates a workspace through Ctrl+N, and drives 20 Alt+Left/Alt+Right switches.

`remote-switch/observation.json` retains each switch's painted-shell identity, elapsed time, CPU milliseconds, and completed native paint timestamps. Each target switch first records ordinary process CPU without a repaint observer. An unprobed return records a second CPU sample. A matching replay to the same target then requests actual WM_PAINT completion every 16 ms. The replay retains its CPU separately but never substitutes that observer-added work for ordinary switching CPU. All 80 unprobed CPU samples keep the same 25% limit; all 40 paint-probe replays keep the same 50 ms frame-gap limit. Frame gaps are derived independently from completion timestamps, not copied from the driver's reported gap. CPU is process kernel/user time divided by measured wall time, never divided by logical core count. The first two seconds after the final workspace replay are the unprobed recovery interval.

`tools/remote-switch-proof.mjs` checks every sample, session/workspace alternation, complete rendered history, screenshot signature, and owned-process cleanup. Require `REMOTE_SWITCH_OK`, `result.json` status `passed`, and successful cleanup. Inspect `remote-switch-complete.png`, `remote-switch-unread-visit.png`, copied text, action log, build identity, and raw frame records.

The baseline builds pre-fix master `fe7ffa681d728d222479bfc93b63a932ce09c9f1`. The candidate builds the PR head. Both use the identical current journey. The red must finish its setup and fail a performance budget. A build, launch, incomplete-history, or ownership failure is not a performance red control. Timed-out native paints stay in the frame record and fail the candidate oracle; the driver does not discard those measurements as missing setup. Retain both run URLs.

## Gotchas

The application, cache, parser, native layout, keyboard routing, and paints are real Windows code. The second SSH host and alternate user home are synthetic. This does not prove physical network latency, Unix permissions, or compositor presentation. Forced native repaints add load to both sides equally, so CPU gates use the separate unprobed windows. Do not run this journey, compiler-backed fixtures, or benchmarks on the VPS or a user's laptop. The ordinary messages-only journey retains its own layout and historical negative controls; this separate performance mode uses its own oracle.
