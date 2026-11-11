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

## Resume

When Windows access is available, verify the running release, open an owned browser pane through the normal agent entry point, verify 15 minutes of availability, then verify recovery after closure. Preserve the unrelated user's browser tabs and application process. Do not mark this ticket Done from CI evidence alone.
