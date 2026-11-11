# IGSH-1925 gates

Scope: New inne chats start and answer the first message; startup failures explain the failure instead of silently leaving Not sent. Continue merged PR 919; do not create another application PR.

- [x] G1: Confirm the fixing PR merge, successful CI, and a published release containing the exact merge.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8
  - CI: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 (success).
  - Published v0.28.1668 contains the merge: compare ahead_by=14, behind_by=0, merge_base equals the merge.
- [x] G2: Read the running production desktop identity and confirm it contains the fix. Read-only inspection only; no restart, replacement executable, desktop driving, or additional agent launches.
  - 2026-11-11T09:06Z: production process PID 12164; debug process-start at 09:02:50.367 identifies version 0.28.1661.
  - GitHub compare confirms v0.28.1661 includes the merge: ahead_by=7, behind_by=0, matching merge base.
- [ ] G3: Observe an actual newly created post-fix inne chat's first sent message and corresponding reply. Check startup failure handling without mistaking pre-fix broken sessions for a new regression.
  - UNREACHABLE: production inbox has eight inne tabs; seven have input predating the fix, latest 2026-11-10T16:03:40.165Z; the eighth has no input. No new post-fix first-message evidence exists in the inspected inbox.
  - No startup failure was observed in the inspected current log. Merged launchWorker/startFailed code and CI cover explicit failure handling, not a live failed-start demonstration.
  - The verification skill forbids driving the user's desktop. This run also forbids launching another agent. Do not manufacture a conversation or claim acceptance from green CI.
- [x] G4: Record evidence and move Done only if live acceptance passes; otherwise hand back the precise outstanding proof through fleet/park.
  - Evidence recorded in the ticket agent lane; fleet/park --hand-back succeeded, left AI Review and unassigned Runner 9. Outstanding gate is G3, not an application-code task.
  - Hypertask tool friction reported by adding evidence to existing https://app.hypertask.ai/detail/project-12057/85.

Local builds and tests are forbidden. Preserve unrelated shared checkout changes. No application change is justified without new regression evidence.
