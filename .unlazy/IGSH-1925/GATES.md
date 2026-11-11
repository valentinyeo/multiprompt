# IGSH-1925 gates

Scope: New inne chats start and answer the first message; startup failures explain the failure instead of silently leaving Not sent. Continue merged PR 919; do not create another application PR.

- [x] G1: Confirm the fixing PR merge, successful CI, and a published release containing the exact merge.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8
  - CI: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 (success).
  - Published release: https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1676
  - 2026-11-11T14:32Z: GitHub compare reports ahead_by=22, behind_by=0, and merge_base equal to the fixing merge.
- [x] G2: Read the running production desktop identity and confirm it contains the fix. Read-only inspection only; no restart, replacement executable, desktop driving, or additional agent launches.
  - 2026-11-11T14:33Z: main process PID 20292; process-start at 13:17:15.057 identifies version 0.28.1674.
  - GitHub compare confirms v0.28.1674 contains the merge: ahead_by=20, behind_by=0, matching merge base.
- [ ] G3: Observe an actual newly created post-fix inne chat's first sent message and corresponding reply. Check startup failure handling without mistaking pre-fix broken sessions for a new regression.
  - UNREACHABLE: read-only inspection at 2026-11-11T14:32Z still finds nine workspace tabs. Eight have input timestamps and one has none. The latest two input timestamps are 13:08:53.849Z and 13:08:15.328Z on established sessions; remaining input predates the fixing merge.
  - The inbox snapshot was last written at 14:05:36.470Z. These facts do not establish a newly created chat or its first reply.
  - No matching startup-failure line was observed in the inspected recent log. Merged code and successful CI are not live first-message or failed-start proof.
  - The verification skill forbids driving the user's desktop. This run forbids launching another agent. Do not manufacture a conversation or claim acceptance from green CI.
- [x] G4: Record evidence and move Done only if live acceptance passes; otherwise hand back the precise outstanding proof through fleet/park.
  - No application-code change or second PR is justified by the current evidence. Hand-back succeeded; readback confirms AI Review, no assignees, and no person waiting.
  - The board has no QA column; AI Review is its supported merged-work review column. A rejected QA move was corrected before ending the run.
  - Ticket-read truncation reported as a repeat on https://app.hypertask.ai/detail/project-12057/610.
  - Missing QA-column friction recorded on https://app.hypertask.ai/detail/project-12057/616.

No local builds or tests were run. Preserve unrelated shared-checkout changes. Public evidence intentionally excludes private conversation content and machine paths.
