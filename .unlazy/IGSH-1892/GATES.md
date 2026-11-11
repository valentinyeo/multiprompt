# IGSH-1892 proof gates

Scope: Keep the agent browser pane open while an agent is attached; reopen a closed pane on the next browser call. Prove 15 minutes of real agent browser use without a drop and recovery without user assistance. Continue merged PR 897; no second implementation PR.

- [x] Confirm Runner 2 assignment and read current ticket, comments and prior evidence.
- [x] Confirm merged fix, published release and successful GitHub-hosted checks.
- [ ] Identify actual running release and demonstrate next-call closed-pane recovery.
- [ ] Demonstrate at least 15 minutes of attached-agent browser interaction without a drop.
- [ ] Record actual live evidence before moving Done; unreachable is not PASS.

## Constraints

Single thread. No helpers, local tests/builds, app restart, binary replacement or changes to unrelated tabs. Preserve shared dirty checkout. Resume: tmux attach -t ht-or-runner-2 (Cursor Grok RUNNER 2).

## Plan

Use the current repository browser wrapper and exact runner session, verify running release read-only, then prove recovery and availability through the real browser entry point. Prior work confirms v0.28.1668 now runs; do not repeat the obsolete old-release diagnosis. Existing merged fixes and hosted CI remain the implementation evidence.

## Evidence: 2026-11-11 09:42–09:47 UTC

- Original fix remains merged: https://github.com/valentinyeo/multiprompt/pull/897 at ea17331f2e5873fa7cccbdc97ab151471b757587. No second PR created.
- Successful hosted tests: https://github.com/valentinyeo/multiprompt/actions/runs/42963786529 and publication: https://github.com/valentinyeo/multiprompt/actions/runs/42963786536, both at bde95cf882aea6c58dbc70737632bc401a3f9fd2. Results re-read this run; no local tests/builds.
- Published release https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1668 resolves to 63bb3a6fa973f8d1f57d6c0a5986e2bc4a220303. Git ancestry confirms both the original fix and subsequent recovery fixes are included.
- Read-only Windows inspection reports main process PID 3044 started at 09:25:01 UTC, plus child PID 9028 started at 09:31:30 UTC. Both executable hashes match the release x64 asset SHA256 b1e40c3d5395e5b3d93a150798850b1e5b0890def0f307eebd1bf9367ee67347. This run did not restart or replace either process.
- Initial installed and repository-wrapper pane-info calls timed out after 15 seconds; status timed out after five seconds. A supported reset request also timed out after 20 seconds, but subsequent pane-info succeeded: this runner's existing shell_id=19997, windowId=1813543410, active=false, visible=false. No new desktop tab was created.
- Real status later succeeded with tunnel=up and pane=open. Tab listing succeeded on extension 1.0.90, initially showing only this pane's untouched about:blank page. This proves availability at that instant, not recovery after closure.
- A bounded real selftest failed with reply_timeout after 60.030 seconds. Subsequent tab listing showed its uniquely identified test page; eval successfully read that page's title, URL and readyState=complete. The bridge therefore works intermittently; a successful eval does not erase the timeout failure. A later pane-info again timed out after 15.016 seconds.
- Cleanup requested close-tab only for this run's selftest tab ID 1813543418, matching this session and unique selftest marker. That request timed out after 15.015 seconds, so cleanup is unconfirmed. Do not close unrelated or user tabs. Original blank tab ID 1813543411 must remain.
- Current live gates remain unmet: no controlled closed-pane recovery and no 15-minute successful interaction run. Not Done. Selftest also requires a visible foreground host; do not foreground the user's application just to satisfy that unrelated visibility check.
- Hypertask description truncation reported as +1 on https://app.hypertask.ai/detail/project-12057/387. Read-only vcc JSON projection retrieved the full current scope.
- No source edits, local builds/tests, application restarts, executable replacement, foreground changes, helpers or new PR. Only this ticket's ledger changed.

## Remaining

On the exact runner-owned pane, establish reliable real browser interaction first. Verify whether the uniquely marked selftest tab remains before cleaning it up. Then demonstrate closed-pane next-call recovery and 15 minutes without a drop. The running release is current; offline-device and old-release diagnoses do not apply. Published CI, pane existence and one successful eval are not substitutes for either live gate.
