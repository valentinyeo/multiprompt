# Safe release updates

## Sub-features

Signed-manifest verification, background staging, explicit and cold apply, helper retirement, bundle rollback, launch-argument preservation and plain update-card notes.

## How to get to it (user POV)

Dispatch `verify.yml` with `feature=safe-updates` on the branch. The shared `control.ps1` validates the executable identity and delegates this feature to `tools/update-release-journey.ps1` instead of the normal session driver.

## Driving it with control.ps1

The disposable GitHub Windows job compiles local fake release executables, creates a throwaway Ed25519 key in memory, embeds its public key in the branch verifier, and serves release downloads from a local folder through the PowerShell library transport. No production signing key or network release is used for swaps.

Prove responsive signed-out launch during background checking, cold-launch staged apply with original arguments, valid and rejected manifest signatures, checksum and provenance refusals, no unattended restart, explicit apply behind a download lock, matching bridge/extension installation, a second update with old helpers locking the backup, immediate-exit rollback, and recovery after the old-process exit timeout.

## Update-card notes

The fixture driver stages signed notes for several versions newer than the running app, then launches that real app with the cold-apply readiness flag. A held update mutex prevents production checks from replacing the local fixture. It waits for paint logs, checks five plain lines newest first across versions, skips internal and out-of-range lines, and checks `+2 more`. Missing notes fail the journey, including on the old app. It saves `update-card-notes.png` and the asserted lines in `update-card-notes.json`; no restart is clicked.

## Gotchas

`safe-updates.json` records each successful scenario and cleanup; `sign-in-ready.png` shows the responsive signed-out app; `build.json` pins the branch executable and commit. Any missing assertion fails the job. All fixture processes are stopped before evidence is uploaded.
