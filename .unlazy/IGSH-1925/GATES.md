# IGSH-1925 acceptance gates

Scope: New inne chats start like older ones and answer the first message. If startup fails, the chat says so instead of silently leaving Not sent. Continue merged PR 919; do not open a second PR.

Resume: tmux attach -t ht-or-runner-1 (Cursor Grok RUNNER 1)

- [x] G1: Reverify fixing PR merge, successful CI and published release ancestry.
  EVIDENCE: PR https://github.com/valentinyeo/multiprompt/pull/919 merged as 307bca51295f1a51bd5d9559bb258108484972c8. CI https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 successful. Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1682 contains the fixing merge: ahead 28, behind 0, exact merge base.
  MANUAL: Read existing PR 919, its checks and release comparison.
- [x] G2: Confirm the currently running production executable contains the fix.
  MANUAL: Read process identity and executable hash; match published asset checksum. No desktop input, restart or executable replacement.
  EVIDENCE: Production main PID19464 started 2026-11-11T22:05:51.8041322Z; SHA256 43e53e30da1c4fdbae785a96ccd401dcbe1ccb00709def54568016bd2e1e7ff7 matches the published v0.28.1682 x64 asset digest.
- [ ] G3: Observe an actual newly created post-fix inne chat answering its first message, and assess failed-start handling honestly.
  MANUAL: Read bounded persisted metadata and diagnostics. Established restored sessions, absence of errors and static checks are not acceptance. No additional agent may be launched, including as a test.
  EVIDENCE: UNMET. Current snapshot has 47 shells and eight target workspace chats. None observed newly created relative to the previous known session IDs. Reported failing chat input still predates the fix. An established chat has newer input, not new-chat acceptance. Bounded current diagnostics have no startup-failure observation; absence is not proof. Actual first-message/reply acceptance requires a permitted verification capability; neither another agent nor user-desktop driving is permitted here.
- [x] G4: Record evidence and honest board disposition. Done only after acceptance; otherwise park the exact remaining work.
  MANUAL: Read board state back after disposition.
  EVIDENCE: Agent activity c95d78e6-26aa-4a25-a34e-97a56c31f6bb records current inspection. fleet/park --lead succeeded. Readback: Todo, Chief Of Staff owns and is waiting agent, Runner 1 unassigned, waitingOnUserId null, blockerCommentId null. Repeat pickup feedback bumped at https://app.hypertask.ai/detail/project-12057/320.

Result: G1/G2/G4 met; G3 unmet; zero abandoned gates. Not Done. No application edits, additional PR, local build/test, desktop input or agents.

Plan: Read-only production inspection can only pass G3 if an actual new chat has appeared. Previous repeated inspections found none. Do not repeat unchanged inspections beyond one current check. If still unavailable, preserve G3 unmet and hand off capability gap to the owning lead; do not weaken acceptance or drive the user's desktop.

Constraints: single thread; launcher-assigned ticket only; no picker, helper, agent launch, private content export, application change without evidence, local build or heavy test. Shared checkout changes untouched.
