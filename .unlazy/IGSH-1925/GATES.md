# IGSH-1925 proof gates

Scope: New inne chats start and answer their first message; failed starts explain the failure instead of silently showing Not sent. Continue merged PR 919; no second application PR.

- [x] G1: Verify merged PR 919, successful GitHub CI, and published release ancestry.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8.
  - Completed non-skipped checks pass, including Windows builds/tests, reader/worker and remote tests: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160
  - Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1669 contains the merge: ahead_by=15, behind_by=0, matching merge base.
- [x] G2: Read the running production desktop identity and confirm it contains the fix, without restart or replacement.
  - Read-only inspection 2026-11-11T09:55Z: main PID 3044 started 09:25:01.439 UTC; matching debug process-start at 09:25:01.453 identifies version 0.28.1668.
  - Running release ancestry includes merge: ahead_by=14, behind_by=0, matching merge base.
- [ ] G3: Observe a newly created post-fix inne chat, first sent message, and corresponding reply. Assess startup failure handling honestly; absence of errors is not proof.
  - UNREACHABLE: published inbox has 47 shells, with the same nine inne workspace tabs recorded before this run. No new post-fix inne chat observed. One established tab has recent input but cannot prove new-chat creation/first reply. The previously broken chat still has only pre-fix input; unused tab has no input.
  - Current debug log starts at 00:53:49 and ends at 09:56:18 UTC; zero live-chat failed-start events. No observed failure does not prove successful startup.
  - Reviewed merged native_session launchWorker and chat_live startFailed handling. Source and CI do not replace actual live acceptance evidence.
  - No user's desktop driving or additional agent launches permitted. Do not manufacture acceptance or reimplement the merged fix.
- [x] G4: Record evidence and finish only on actual acceptance proof; otherwise park the exact remaining work.
  - Detailed evidence posted in the ticket agent lane. Board has no QA column; fleet/park --hand-back succeeded after returning to AI Review. Readback confirms AI Review and no assignees.
  - Outstanding work: G3, actual newly created post-fix inne first message and answer through permitted production evidence.
  - CLI feedback friction added to existing https://app.hypertask.ai/detail/project-12057/387.

Constraints: single thread; no helpers or additional agent launches, user's desktop driving, local builds/tests, state edits, restarts, unrelated changes, or private conversation exports. Dirty shared checkout untouched. No application edits or second PR.

Resume claim: tmux attach -t ht-or-runner-4 (Cursor Grok RUNNER 4)
