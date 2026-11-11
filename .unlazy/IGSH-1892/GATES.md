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

## Resume

When Windows access is available, verify the running release, open an owned browser pane through the normal agent entry point, verify 15 minutes of availability, then verify recovery after closure. Preserve the unrelated user's browser tabs and application process. Do not mark this ticket Done from CI evidence alone.
