# IGSH-1892 proof gates

Scope: Keep the agent browser pane open while an agent is attached, and reopen a closed pane on its next browser call. Prove at least 15 minutes without a drop and recovery without user help. Continue merged PR 897; no second implementation PR.

- [x] Confirm Runner 9 assignment and read current ticket, comments, and prior evidence.
- [x] Confirm the merged fix is in a published release, with successful GitHub-hosted checks.
- [ ] Confirm the running desktop release and recover a missing or suspended pane using the next real agent browser call.
- [ ] Keep the attached agent's browser available for at least 15 minutes.
- [ ] Record live evidence before marking Done; unreachable checks are not passes.

## Constraints

No helpers, local builds or tests, application restarts, replacement binaries, or unrelated changes. Preserve the dirty shared checkout. Resume: tmux attach -t ht-or-runner-9 (Cursor Grok RUNNER 9).

## Evidence: 2026-11-11 09:14 UTC

- Original fix: https://github.com/valentinyeo/multiprompt/pull/897, merged at ea17331f2e5873fa7cccbdc97ab151471b757587.
- Published recovery follow-ups: https://github.com/valentinyeo/multiprompt/pull/929 and https://github.com/valentinyeo/multiprompt/pull/933.
- Release https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1666 resolves to bde95cf882aea6c58dbc70737632bc401a3f9fd2 and includes the original fix, confirmed by Git ancestry.
- Exact-source tests succeeded: https://github.com/valentinyeo/multiprompt/actions/runs/42963786529.
- Exact-source publication succeeded: https://github.com/valentinyeo/multiprompt/actions/runs/42963786536.
- Windows access is available now, unlike previous attempts. Initial own-session browser status returned pane_closed; open returned no_tab.
- Created this runner's own background desktop tab through session-open. The tab remains connecting. Browser open then returned no_pane; pane-info confirms the exact tab with windowId=0. Doctor returned pane_closed and version returned reply_timeout. No unrelated tab was changed.
- Read-only SHA256 of the running desktop executable is 11e492dc42f6e4253bb829e5817374d5be3de4ba5c27266c49f7df3ddeb0d7a2. GitHub release asset metadata matches this exactly to v0.28.1661, not the release containing the later recovery fixes. Latest published release is v0.28.1668.
- Recovery gate: FAIL on the running older release; not evidence against or for the newer release. Fifteen-minute availability: UNREACHABLE because no pane was obtained. Not Done.
- No local tests/builds, restart, replacement executable, or second implementation PR. Only this proof ledger changed.
- Reported CLI description truncation through agent-feedback: https://app.hypertask.ai/detail/project-12057/387.

## Evidence: 2026-11-11 09:20 UTC

- Current ticket description reread in full: an agent drives the pane for 15 minutes without a drop; a closed pane reopens on the next browser call. Scope unchanged.
- Launcher assignment is Runner 9 alone. Existing merged PR 897 retained; no second PR.
- Published-fix gate rechecked: the test and publication runs above both remain completed/success at bde95cf882aea6c58dbc70737632bc401a3f9fd2. Latest published release remains v0.28.1668.
- Actual current status failed with reply_timeout after 5.006 seconds. pane-info succeeded for this runner's exact tab: shell_id=19952, tab_name=RUNNER 9, active=false, visible=false, windowId=0. Next real browser call, open about:blank, failed with no_pane. Recovery gate remains unmet; no 15-minute soak was started or claimed.
- Read-only desktop inspection confirms PID 12164 still runs executable SHA256 11e492dc42f6e4253bb829e5817374d5be3de4ba5c27266c49f7df3ddeb0d7a2, matching v0.28.1661.
- New decisive evidence: app debug log at 2026-11-11 09:18:12.638 says `update-card: new version ready 0.28.1668`; subsequent lines render its restart button. The normal updater has prepared the new release, but the running app has not relaunched. This is not evidence of an updater failure. Do not hand-replace or restart the user's running application without consent.
- No source edits, local builds/tests, helpers, application restart, executable replacement, new tabs, or foreground changes this run. Existing hosted test and release results were read, not rerun locally.
- Repeated Hypertask description truncation feedback added to existing https://app.hypertask.ai/detail/project-12057/387.
- Gate count: 2 met, 3 unmet, 0 abandoned. Not Done.

## Evidence: 2026-11-11 09:55–10:01 UTC

- Current description and five people comments reread; current assignment confirmed Runner 9 alone. Existing PR 897 remains merged; no second implementation PR. Moved Doing during verification.
- Earlier relaunch blocker is obsolete. Read-only executable SHA256 is now b1e40c3d5395e5b3d93a150798850b1e5b0890def0f307eebd1bf9367ee67347, exactly matching the published x64 asset at https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1668 . Existing app processes were not restarted or replaced.
- Hosted test https://github.com/valentinyeo/multiprompt/actions/runs/42963786529 and publication https://github.com/valentinyeo/multiprompt/actions/runs/42963786536 revalidated completed/success at bde95cf882aea6c58dbc70737632bc401a3f9fd2.
- Used the repository browser wrapper with explicit ZSB_SESSION=ht-or-runner-9. Initial pane-info returned own tab shell_id=20002, active=false, visible=false, windowId=0. open about:blank timed out after 15.009 seconds, but the pane subsequently existed.
- Supported reset with ZSB_TIMEOUT=40 succeeded, reporting windowId=1813543451, tabs=1, extensionVersion=1.0.90, reloadScheduled=false. The next tabs call succeeded and returned the own blank target tab 1813543452. This proves initial opening and limited transport availability, not recovery after a controlled closure or sustained browser use.
- Actual page read via eval on that exact target then failed reply_timeout after 40.007 seconds. Longer deadlines therefore do not resolve the interaction failure. Stopped retries; did not close a pane whose transport was unreliable, and did not claim a soak.
- Read-only desktop logs prove dispatch reached the native bridge: reset at 09:57:12.737, tabs at 09:57:27.761, eval at 09:57:47.384, all for window 1813543451. Subsequent state logs through 09:59:12 report own shell=20002, window=1813543451, frozen=false, busy=true. The observed timeout is not evidence of automatic pane hibernation; investigate command/reply transport instead.
- Existing linked IGSH-1935 is Done, not an open dependency. No local builds/tests, helpers, binary replacement, application restart, foreground action, selftest page, controlled closure, or unrelated-tab edit. Own blank pane remains for further verification.
- Gate count remains 2 met, 3 unmet, 0 abandoned. No Done claim.

## Remaining

Diagnose why an actual eval times out after 40 seconds even though reset and tabs return successfully on the same live, unfrozen pane. Establish reliable page interaction, then prove controlled closure/next-call recovery and 15 minutes of real attached-agent browser use. The running release is current; do not repeat the old-release or missing-pane diagnosis. Preserve user tabs and foreground focus. Hand back in AI Review for unfinished live proof, not completion. Resume: tmux attach -t ht-or-runner-9 (Cursor Grok RUNNER 9).
