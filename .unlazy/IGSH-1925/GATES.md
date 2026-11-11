# IGSH-1925 acceptance gates

Scope: New inne chats start and answer the first message; a failed start says so in the chat instead of silently leaving Not sent. Continue merged PR 919; no duplicate application PR.

Resume: tmux attach -t ht-or-runner-9 (Cursor Grok RUNNER 9)

Plan: Reverify merged CI and published release ancestry, then inspect actual running desktop identity and persisted session metadata read-only. Do not drive the user's desktop, start another agent, restart or replace an executable, or run local builds/tests. Established chats and static checks cannot satisfy new-chat acceptance.

Premise under examination: another read-only inspection can establish a newly created chat's first-message/reply acceptance. Earlier runs repeatedly found only restored established chats. Current inspection again supplies no new-chat acceptance; an isolated permitted verification capability is required. No additional application fix is justified by this evidence.

- [x] G1: Fixing PR is merged, CI succeeded, and a published release contains its merge.
  MANUAL: Read GitHub PR/checks and exact merge-to-release ancestry.
  EVIDENCE: https://github.com/valentinyeo/multiprompt/pull/919 merged as 307bca51295f1a51bd5d9559bb258108484972c8. Checks read this run remain successful, including https://github.com/valentinyeo/multiprompt/actions/runs/42853784160. Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1681 compares ahead 27, behind 0, with the fixing merge as merge base.
- [x] G2: The actual running desktop executable belongs to that fixed published release.
  MANUAL: Read process identity and executable hash; correlate with published release asset hash.
  EVIDENCE: Main desktop PID24688 started 2026-11-11T18:12:23.8751052Z. Executable SHA256 40fa3e29571ef97c7cb4c8700898afd126c76dd46eee4f2ae6a4bc60d03243d8 equals multiprompt-x64.exe in published v0.28.1681 SHA256SUMS.txt. No restart, executable replacement or desktop input occurred.
- [ ] G3: Observe an actual newly created post-fix inne chat's first sent message and corresponding reply, and verify failed-start handling without mistaking restored pre-fix chats for a new regression.
  MANUAL: Inspect persisted metadata and bounded diagnostics read-only. No new agent or user-desktop input is permitted by this run.
  EVIDENCE: UNMET at 2026-11-11T20:42:19Z. Snapshot contains 48 shells overall and the same nine target-workspace chats. One established chat received input at 18:53:27.254Z; this is not evidence of a newly created chat's first message. The reported failing chat's input still predates the fix, at 2026-11-10T16:03:29.510Z. Recent bounded debug inspection found no startup-failure observation; absence is not proof. The single-thread run prohibits starting another agent, and the verification skill prohibits driving the user's desktop. A permitted isolated actual-start verifier or independently observable new-chat event remains required.
- [x] G4: Record honest evidence and final board disposition; Done only when acceptance passes.
  MANUAL: Read back board after disposition, preserving G3 if unmet.
  EVIDENCE: Findings recorded in ticket agent activity 416b89c5-ba10-43a5-b9e5-3fec7bd5544a. fleet/park --lead succeeded; readback confirmed Todo, no assignees, waitingOnAgent Chief Of Staff, waitingOnUserId null and blockerCommentId null. No application edits or second PR. Repeated unchanged lead-wait pickup reported as +1 at https://app.hypertask.ai/detail/project-12057/320; truncated ticket evidence reported as +1 at https://app.hypertask.ai/detail/project-12057/610.

Result: G1/G2/G4 met; G3 unmet; zero abandoned gates. Not Done. No local builds/tests or additional agents. Existing shared-checkout changes untouched. Only sanitized evidence is public; no private conversation content is included.
