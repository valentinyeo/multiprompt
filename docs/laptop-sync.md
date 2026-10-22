# Laptop sync (ISSUE-252)

Existing account sync stays on exactly as before: automatic `/v1/layout` transfer of workspaces, remote tabs, split settings and hosts, a 20-second pull, background device public-key publication, approval prompts and revoked-key cleanup. A 401 locks the session and requires sign-in. Service web pages continue reading fresh layouts. Local CMD/PowerShell/WSL/Git Bash sessions, private keys, passwords, paths and window geometry remain device-local.

PR #12 introduced host feature negotiation, missing-host import and public known-host keys. IGSH-423 added split settings. These are existing behaviors, not opt-in record-sync features, and are preserved. Public host keys and device public keys still use their original authenticated endpoints; the new record allowlist does not carry any keys.

Ctrl+K → **Sync between laptops**, also listed in F1, enables supplemental deletion history (OFF by default). Turning it off stops only record requests; existing layout sync, SSH import and account security continue. The same account timer schedules records at most every three minutes, or after a layout push; there is no new timer or directory watcher. Sign-out preserves files; journals are account-hash scoped.

## Ownership and reconciliation

[sync-fields.json](sync-fields.json) inventories local stores and declares the owner of every portable value. `/v1/layout` is the only owner of hosts (including slot/name/hostname/port/user/public host keys), workspaces, remote sessions (including name/manual/favorite/used/input/visits), and settings, regardless of the opt-in setting. Existing layout three-way rebasing and per-field monotonic activity merges remain in force.

`/v1/sync-records` adds bounded deletion-history metadata, which the layout snapshot does not retain. It does not publish a second live copy of those values or apply legacy record payloads to SSH files or the layout. On first enable, records are pulled and adopted before observing the local baseline; an empty fresh machine cannot stamp over established records. Missing-parent and legacy payload records remain protocol-readable, not a second desktop authority.

Record protocol support retains typed host/workspace/session/settings payloads for protocol interoperability and executable tests. Session name, manual, favorite and workspace have individual timestamp/device stamps; activity uses max used/input and the newest eight unique visits. Legacy records without field stamps use their record stamp. A later activity-only edit retains earlier metadata stamps and cannot revert another device's rename or favorite. Tombstones use timestamp/device ordering. Equal timestamps break ties by device ID.

Records use the server clock. Clock skew over five minutes shows a clear notice and automatically uses server time for stamping; the system clock is not modified. Every submitted record must name the token's device. Only changed records are sent, in batches of at most 16. D1 uses compare-and-swap updates; races, capacity exhaustion, expired submissions and oversized batches return errors, never a false successful acknowledgement. The client verifies each batch's readback and writes account-records.json once after a completed push. Failed requests leave its previous observation intact for retry.

Both server and client expire tombstones after 30 days. Server submissions older than that window are rejected rather than resurrecting deleted data; an offline device returning after that window adopts current remote state before making new edits. The cap is 4096 retained records. Exhaustion returns `record_capacity`; no records are silently dropped. Deletion history never removes a user's SSH directives. SSH host import backs up existing config to a timestamped, exclusively created `.bak` before writing. The standalone host rewrite also preserves original directives on edits and returns identical bytes on deletion. Failed `ssh -G` resolution aborts discovery, never produces a deletion, and cached discovery is reused for key-host resolution.

## Server rollout

The additive `sync_records` schema and Worker endpoint need service-owner rollout. **Not deployed by this change.** Before rollout, the optional history request can fail without disabling existing layout sync. Host/workspace/session metadata is plaintext in D1, as with existing layouts; this is not end-to-end encryption. No deployment, laptop access or ticket write is part of this PR.

## Evidence

`tools/issue-252-review.test.js` checks ownership, bootstrap ordering, SSH backup safety, bounded retention/deltas, server field merges, token binding and visible clock correction. Each test rejects the pre-review implementation. GitHub runs the production Zig record scenarios and Worker/D1 regression tests; only small Node checks and syntax checks run on the VPS.
