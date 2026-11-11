# IGSH-1925 proof gates

Scope: New inne chats start and answer their first message; failed starts explain the failure instead of silently showing Not sent. Continue merged PR 919; no second application PR.

- [x] G1: Confirm PR 919 merge, successful CI, and a published release containing the fix.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8.
  - CI: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 (success).
  - Release: https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1668; comparison ahead_by=14, behind_by=0, matching merge base.
- [x] G2: Confirm the running production desktop version contains that merge, without restart or replacement.
  - Read-only inspection at 2026-11-11T09:49Z: main process start and debug process-start both identify the current session; debug version is 0.28.1668.
- [ ] G3: Observe a newly created post-fix inne chat, its first sent message, and corresponding reply; assess startup failure handling honestly.
  - UNREACHABLE: no newly created post-fix chat in the inspected workspace. One established tab has post-fix input, but predates the merge; it cannot prove new-chat startup. Previously broken chat input still predates the fix. The unused chat has no input.
  - No new failed-start was observed in the inspected log tail. Merged launchWorker/startFailed code and successful CI do not replace a live first-message demonstration.
  - The verification skill forbids user's desktop driving; this run forbids additional agent launches. Do not manufacture a conversation or infer acceptance from the running version.
- [x] G4: Record evidence; Done only with actual acceptance proof. Otherwise park with exact outstanding work, not a false completion.
  - Evidence recorded in the ticket agent lane. fleet/park --hand-back succeeded; readback confirms AI Review and no runner assignment. Outstanding gate is G3. No application changes or second PR.
  - Tool PATH feedback added to existing https://app.hypertask.ai/detail/project-12057/310.

Constraints: read-only production inspection; no user's desktop driving, agent launches, local tests/builds, or unrelated changes. Preserve the dirty shared checkout. No application edits without new regression evidence.
