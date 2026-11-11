# IGSH-1892 proof gates

Scope: Keep the agent browser pane open while an agent is attached, and reopen a closed pane on its next browser call. The current ticket requires 15 minutes without a drop and recovery without user assistance. Continue merged PR 897; no second implementation PR.

- [x] Confirm ownership and read the current description/comments.
- [x] Verify merged fixes are included in a published release.
- [ ] Verify a real browser command reopens a missing pane without user assistance.
- [ ] Verify an attached agent keeps its pane available for at least 15 minutes.
- [ ] Record live proof and move Done only after both live gates pass.

## Evidence

- Original PR: https://github.com/valentinyeo/multiprompt/pull/897, merge ea17331f2e5873fa7cccbdc97ab151471b757587.
- Follow-up PR: https://github.com/valentinyeo/multiprompt/pull/929, merge f1f25918d.
- Follow-up PR: https://github.com/valentinyeo/multiprompt/pull/933, merge bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Release: https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1666. Its source includes all three fixes, confirmed using Git ancestry.
- Tests: https://github.com/valentinyeo/multiprompt/actions/runs/42963786529, success on bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Publication: https://github.com/valentinyeo/multiprompt/actions/runs/42963786536, success on that same source revision.
- Live status and open commands both failed with `empty_reply`. The remote device-access service also reported no connected Windows devices. Published release identity therefore does not prove the running desktop identity or browser behavior.
- Live recovery and the 15-minute run remain UNREACHABLE, not PASS. No user processes were restarted or replaced.
- No local tests/builds were run, as required by current repository rules. No implementation changes were needed or made during this verification attempt.

## Recheck, 2026-11-11 06:59 UTC

- Reconfirmed assignment to Runner 1 and moved to Doing for this attempt.
- Published release remains v0.28.1666; PR 897 is already merged. No second PR was opened.
- Both real entry points, `zsb status` and `zsb open https://example.com`, returned `empty_reply` again.
- Read-only device access reported both Windows devices offline. No running release identity, missing-pane recovery, suspended-pane recovery or 15-minute availability can be observed in this state.
- Live gates remain UNREACHABLE. Hand back for a future connected-device verification attempt, not Done. No restart, replacement, local build or local test was attempted.

## Recheck, 2026-11-11 07:03 UTC

- Re-read the current description and comments; scope remains unchanged. Assignment was confirmed and the ticket moved to Doing for verification.
- PR 897 remains merged at ea17331f2e5873fa7cccbdc97ab151471b757587. Latest published release remains v0.28.1666.
- Re-read both GitHub-hosted run results: 42963786529 and 42963786536 completed successfully on bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Real status and open calls both returned `empty_reply`. Independent device listing confirmed both Windows devices disconnected.
- Recovery and 15-minute availability gates remain UNREACHABLE, not PASS. No local tests/builds, restart, user browser changes, or additional implementation PR.
- Existing BlockedBy ticket IGSH-1935 is Done, so it is not the remaining blocker. Device connectivity is required before the live gates can be observed.
- Retry-loop friction was added to existing feedback: https://app.hypertask.ai/detail/project-12057/613.

## Recheck, 2026-11-11 09:38 UTC

- Confirmed Runner 1 ownership, reread the complete current description through `vcc --json task get`, and moved to Doing. Scope remains unchanged. No second implementation PR.
- Published release is v0.28.1668. Hosted test run 42963786529 and publication run 42963786536 both remain successful on bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Windows is now reachable. Read-only inspection found PID 3044, started at 09:25:01 UTC. Its executable SHA256 is b1e40c3d5395e5b3d93a150798850b1e5b0890def0f307eebd1bf9367ee67347, exactly matching GitHub's v0.28.1668 x64 release asset digest. The older-process blocker no longer applies. This run did not restart or replace the application.
- Installed `zsb` pane-info and open both timed out after 15 seconds. The repository wrapper then returned no_tab for this exact session. Workspace inspection confirmed no desktop tab bound to ht-or-runner-1.
- Requested one background desktop tab bound to this already-running runner session, without starting another agent or changing unrelated tabs. Although session-open timed out, subsequent pane-info confirmed RUNNER 1, shell_id=20004, active=false, visible=false, windowId=0.
- Repository-wrapper open about:blank returned ok. Subsequent pane-info showed windowId=1813543251. This proves pane creation, not next-call recovery after closure or sustained browser interaction.
- Status initially timed out after five seconds. The first selftest produced no result and was stopped after 191 seconds. A normal reset request timed out after ten seconds, but subsequent status reported tunnel=up, pane=open with the same window ID.
- A second selftest with an explicit 45-second deadline failed with reply_timeout after 45.042 seconds and warned cleanup may be incomplete. No successful interaction sequence or 15-minute agent-use soak was obtained. Recovery and availability gates remain unmet; do not claim Done.
- No source changes, local builds/tests, foreground changes, executable replacement, application restart, or new implementation PR. Only this ticket's proof ledger changed.

## Resume

Use the repository browser wrapper for the exact ht-or-runner-1 desktop tab (shell_id=20004). First establish a successful selftest; inspect any leftover selftest tabs before cleanup and preserve user tabs. Then verify next-call recovery after closure and at least 15 minutes of real browser interaction. Preserve application process and foreground focus. Do not repeat the obsolete offline-device or old-release diagnosis, or mark Done from CI/pane creation alone.
