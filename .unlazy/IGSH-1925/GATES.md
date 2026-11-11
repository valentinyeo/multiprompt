# IGSH-1925 gates

Scope: New inne chats start and answer the first message; startup failures explain the failure instead of silently leaving Not sent. Continue merged PR 919; do not create another application PR.

## Plan and boundaries

RUNNER 9 resumed 2026-11-11T16:09Z. Reverify the merged fix, CI, published release ancestry and running desktop identity; inspect read-only production state for a newly created conversation and its first reply. Preserve the outstanding live acceptance gate if no permitted proof exists. Never drive the user's desktop, launch another agent, replace or restart the running application, or run local builds/tests.

Resume: tmux attach -t ht-or-runner-9 (Cursor Grok RUNNER 9).

## Gates and evidence

- [x] G1: Confirm the fixing PR merge, successful CI, and a published release containing the exact merge.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8.
  - CI: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 is completed/success on this run's read.
  - Published release: https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1678 (2026-11-11T15:57:40Z).
  - GitHub compare: status ahead, ahead_by=24, behind_by=0, merge_base_commit.sha equals the fixing merge.
- [x] G2: Read the running production desktop identity and confirm it contains the fix.
  - Read-only process inspection at 2026-11-11T16:10:52Z: main PID 4484 started at 16:06:43.0258363Z.
  - Matching debug process-start at 16:06:43.038 identifies version 0.28.1678. Release ancestry verified by G1.
  - No restart, executable replacement, desktop input or other agent was used.
- [ ] G3: Observe an actual newly created post-fix inne chat's first sent message and corresponding reply. Check startup failure handling without mistaking pre-fix broken sessions for a new regression.
  - UNREACHABLE: read-only persisted session/inbox inspection at 2026-11-11T16:11:45Z still finds nine workspace tabs, eight with input timestamps and one without input. The two latest inputs remain 2026-11-11T13:08:53.849Z and 13:08:15.328Z on established sessions; the others predate the fixing merge.
  - Shell IDs changed after the application restarted; unchanged input timestamps and persisted conversation bindings show restored sessions, not proof of newly created chats.
  - Recent bounded debug inspection at 16:12:13Z found zero matching startup-failure/native-start lines. Absence is not failed-start proof.
  - The verification skill forbids driving the user's desktop; this run forbids launching another agent. Existing CI/release identity cannot establish the ticket's first-message acceptance.
- [x] G4: Record evidence and move Done only if live acceptance passes; otherwise park with the board lead for the precise unresolved verification capability.
  - fleet/park --lead succeeded. Readback: Todo, no assignees, waitingOnUserId null, waitingOnAgentId Chief Of Staff. G3 remains unmet, not Done.
  - No application-code change or second PR is justified by current evidence.
  - Required next action: provide a permitted isolated actual-start verification path, or an appropriately authorized verifier. Preserve G3; do not substitute existing-chat activity or static CI success.
  - Ticket-read truncation reported as a repeat on https://app.hypertask.ai/detail/project-12057/610.

Four gates evaluated: G1/G2/G4 met, G3 unmet. No acceptance gate was removed or abandoned; the ticket remains open with its board lead. No local builds/tests were run; no application changes require a new test run. Shared checkout changes were left untouched. Public evidence excludes private conversation content, host names and machine paths.
