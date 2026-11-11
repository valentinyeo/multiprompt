# IGSH-1925 proof gates

Scope: New inne chats start like older ones, answer the first message, and explain a startup failure instead of silently showing Not sent. Verify existing merged PR 919; do not open another application PR or launch another agent.

- [x] G1: Verify the existing fixing PR merge, successful GitHub CI, and published release ancestry.
  - PR: https://github.com/valentinyeo/multiprompt/pull/919
  - Merge: 307bca51295f1a51bd5d9559bb258108484972c8.
  - CI: https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 (success).
  - Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1675 contains the merge (ahead 21, behind 0, matching merge base).
- [x] G2: Inspect running production app identity read-only and confirm it includes the fix. No restart, executable replacement, or desktop driving.
  - 2026-11-11T13:56Z: main PID 20292 started 13:17:15.044 UTC; matching debug process-start at 13:17:15.057 identifies v0.28.1674.
  - GitHub compare confirms running version contains the fix (ahead 20, behind 0, matching merge base).
- [ ] G3: Observe an actual newly created post-fix inne chat's first user message and corresponding reply. Assess explicit startup failure behavior honestly; source and CI do not replace live evidence.
  - UNREACHABLE: inbox has 48 shells, including the same nine inne workspace tabs from prior verification. No new post-fix chat observed. Two established chats have recent input at 13:08:15 and 13:08:53 UTC; this does not prove new-chat startup. One tab has no input; reported broken tab retains pre-fix input.
  - Current debug file is empty; rotated debug file has no observed failed-start events. Absence of errors is not acceptance proof. Reviewed launchWorker and startFailed implementation; source and successful CI are not production first-message/reply evidence.
  - This run permits neither launching another agent nor driving the user's desktop. No new application change justified by observed evidence.
- [x] G4: Record evidence and close only if acceptance is proven; otherwise park the exact remaining proof and read back disposition.
  - Evidence posted in the ticket's agent lane. Returned to AI Review and fleet/park --hand-back succeeded, unassigning Runner 1.
  - Remaining work: G3, actual newly-created post-fix inne first-message/reply evidence. Ticket not Done.
  - CLI output-format feedback added to existing https://app.hypertask.ai/detail/project-12057/699.

Constraints: one ticket, one thread; no helpers, new agents, local builds/tests, production mutations, private conversation exports, unrelated changes, or second application PR. Existing shared checkout changes remain untouched. Evidence-only branch; no application edits or checks rerun locally.

Resume claim: tmux attach -t ht-or-runner-1 (Cursor Grok RUNNER 1)
