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

## Remaining

Verify the normal in-app update reaches a release containing the recovery fixes without hand-replacing the running executable. Then verify next-call recovery and 15 minutes of attached-agent availability. Preserve user tabs and foreground focus. Hand back in AI Review for those live checks, not a human decision or a claim of completion.
