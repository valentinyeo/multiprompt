# IGSH-1892 proof gates

Scope: Keep the agent browser pane open while an agent is attached; reopen a closed pane on the next browser call. Prove 15 minutes of real agent use without a drop and recovery without user assistance. Continue merged PR 897, not a second implementation PR.

- [x] Confirm Runner 5 assignment; read current description, comments and prior evidence.
- [x] Verify published fixes, hosted checks and actual running release identity.
- [ ] Prove next-call closed-pane recovery on this runner's own pane.
- [ ] Prove at least 15 minutes of real attached-agent browser interaction without a drop.
- [ ] Record honest evidence; move Done only after live gates pass.

Constraints: single thread; no helpers, local builds/tests, application restart, executable replacement or unrelated-tab changes. Preserve dirty shared checkout. Resume: tmux attach -t ht-or-runner-5 (Cursor Grok RUNNER 5).

Plan: inspect the actual native command/reply path rather than repeat selftest timeouts from earlier attempts. Establish real interaction first; then recover only the own test pane and measure availability. Published CI alone does not establish live behavior.

## Initial evidence

- Existing implementation PR https://github.com/valentinyeo/multiprompt/pull/897 merged at ea17331f2e5873fa7cccbdc97ab151471b757587. Follow-ups 929 and 933 also merged.
- Prior runner confirmed running v0.28.1668 and native dispatch, but actual eval timed out after 40 seconds while pane remained unfrozen. Longer deadlines are not a demonstrated fix.
- Own pane-info currently returns reply_timeout after 15.015 seconds. No live gate passed.

## Evidence: 2026-11-11 10:01–10:10 UTC

- Existing GitHub-hosted test https://github.com/valentinyeo/multiprompt/actions/runs/42963786529 and publication https://github.com/valentinyeo/multiprompt/actions/runs/42963786536 both remain completed/success at bde95cf882aea6c58dbc70737632bc401a3f9fd2, including the original lifecycle fixes.
- Read-only desktop inspection confirms running executable SHA256 b1e40c3d5395e5b3d93a150798850b1e5b0890def0f307eebd1bf9367ee67347. This exactly matches the x64 asset at https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1668 . No restart or replacement was performed.
- Workspace listing timed out at 15.016 seconds, then at 40.040 seconds. Own-session pane-info also failed at 15.015 seconds, though a subsequent request returned no_tab. No controlled pane closure or soak was attempted with this unreliable transport.
- Traced the real path: loopback notification relay -> desktop-specific Unix socket -> embedded notify_link.py -> shared native alert channel -> native browser listener. A direct read-only pane-info probe to the existing desktop Unix socket received no bytes in eight seconds, so increasing the CLI timeout is not a fix.
- Found an independent, concrete reply-ownership defect in src/shared_alerts.zig. Three per-host pump threads share one g_slots array. Remote IDs start at one independently on each server. claimSlot keys only by ID; flushSlots(channel) sends every completed global slot through whichever host's channel calls it. Both colliding IDs and distinct IDs can therefore cross server connections. Source inspection proves the ownership defect, not the routing history of an individual timed-out request.
- Installed release v0.28.1668 resolves to 63bb3a6fa973f8d1f57d6c0a5986e2bc4a220303. Its shared_alerts.zig is byte-identical to current inspected source (SHA256 3a9159ff25797bf988ca184084007f047049f9b8622c756c9fba00d7ba731792); original shared-link commit e2b4ad1f5 is an ancestor.
- Searched browser/replies/alerts/shared/connection tickets. Existing lifecycle and shared-link tickets are Done; no open matching reply-ownership blocker existed. Filed https://app.hypertask.ai/detail/project-2060/1938 with source evidence and explicit multi-host regression requirements. No work taken on that ticket.
- Hypertask description truncation workaround required --json. Added feedback to existing https://app.hypertask.ai/detail/project-12057/387 .
- Gate result: 2/5 met, 3 unmet. Recovery and 15-minute real agent use remain UNREACHABLE, not PASS. No application/source changes, local builds/tests, helpers, new implementation PR, user-tab changes or foreground changes.

## Resume

Wait for IGSH-1938 to ship and verify its reply ownership. Then establish successful real page interaction on the exact runner tab, prove closed-pane recovery on the next call, and complete 15 minutes of attached-agent use. Preserve the existing merged PR and do not repeat the obsolete old-release diagnosis. Park through fleet/park --waits-on IGSH-1938, rather than recycling this as an unblocked orphan.
