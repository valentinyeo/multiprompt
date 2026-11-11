# IGSH-1892 proof gates

Scope: Keep the agent browser pane open while an agent is attached; reopen it on the next browser call if closed. Prove 15 minutes of real browser interaction without a drop. Continue merged PR 897, no second PR.

- [x] Read current ticket/comments and confirm Runner 3 ownership.
- [x] Revalidate published fix and GitHub-hosted checks.
- [ ] Prove next-call recovery on this runner's own pane.
- [ ] Prove 15 minutes of attached-agent browser use without a drop.
- [ ] Record live evidence and move Done only when both behavioral gates pass.

## Constraints

No helpers, local builds/tests, user app restart, binary replacement, or unrelated tab changes. Shared checkout untouched. Resume: tmux attach -t ht-or-runner-3 (Cursor Grok RUNNER 3).

## Plan

Prior runners confirmed current v0.28.1668 but intermittent bridge timeouts. Inspect routing and real bridge responses before repeating selftest. Distinguish pane lifecycle from bridge transport failures. Any unresolved gate stays unmet.

## Evidence: 2026-11-11 09:49–09:53 UTC

- Current description requires both 15 minutes without a drop and next-call closed-pane recovery. Original PR remains merged: https://github.com/valentinyeo/multiprompt/pull/897 at ea17331f2e5873fa7cccbdc97ab151471b757587. No new PR or source changes.
- Hosted test https://github.com/valentinyeo/multiprompt/actions/runs/42963786529 and release https://github.com/valentinyeo/multiprompt/actions/runs/42963786536 both re-read: completed, success, source bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Read-only process inspection confirms running executable SHA256 b1e40c3d5395e5b3d93a150798850b1e5b0890def0f307eebd1bf9367ee67347, matching the published x64 asset for https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1668 . Main process 3044 started 09:25:01 UTC; child process 9028 started 09:31:30 UTC. Neither restarted or replaced.
- Initial pane-info returned no_tab for this exact runner session. Workspace inventory confirmed no existing terminal tab for it. Supported background session-open created only this runner's tab 20005; open about:blank succeeded and pane-info returned shell_id=20005, windowId=1813543429, active=false, visible=false. This proves initial opening, not recovery after closure.
- Actual tabs call failed reply_timeout after 15.015 seconds. Status failed after 5.003 seconds. Supported reset subsequently succeeded for windowId=1813543429, tabs=1, extensionVersion=1.0.90, reloadScheduled=false. The next tabs call again failed reply_timeout after 15.010 seconds. Stopped repeated attempts after this supported recovery failed.
- Important distinction: read-only desktop debug log at 09:52:42–09:52:44 reports this exact shell/window frozen=false and busy=true throughout. Thus the observed command failure happens with the pane alive and not frozen. Do not repeat old-release, missing-pane or automatic-hibernation diagnoses without new evidence. No controlled pane closure was attempted while the transport was unreliable.
- Existing BlockedBy IGSH-1935 is Done; this is not an open-ticket wait. Live recovery and 15-minute interaction gates remain unmet. Board 2060 has no QA column; AI Review retains unfinished verification.
- CLI comment-discovery feedback filed: https://app.hypertask.ai/detail/project-15/9060 .
- No local tests/builds, helpers, app restarts, executable replacement, foreground changes, selftest pages, or unrelated-tab edits. Own blank browser pane remains available for the next verifier.

## Handoff

2 gates met; 3 unmet; 0 abandoned. Establish reliable replies on the live, unfrozen runner-owned pane before another soak or selftest. Then prove controlled closure/next-call recovery and 15 minutes of real browser use. No Done claim from CI, initial opening, or successful reset alone.

