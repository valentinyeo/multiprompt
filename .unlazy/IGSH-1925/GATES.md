# IGSH-1925 proof gates

Scope: New inne chats never start, messages show Not sent. A new inne chat must answer its first message; a failed start must say so in the chat. Continue merged PR 919, never a second application PR.

- [x] G1: Verify merged PR 919, successful PR-head CI, and published release ancestry.
  - https://github.com/valentinyeo/multiprompt/pull/919 merged 2026-11-10T16:42:30Z as 307bca51295f1a51bd5d9559bb258108484972c8.
  - https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 succeeded; PR check rollup includes successful test and Windows builds.
  - https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1676 contains merge: ahead 22, behind 0, identical merge base.
- [x] G2: Read the running production desktop identity/version without restarting or replacing it.
  - Main PID 20292 started 2026-11-11T13:17:15.0448966Z. Rotated debug log records process-start at 13:17:15.057, version 0.28.1674.
  - Running release contains merge: ahead 20, behind 0, identical merge base. No desktop input or process changes.
- [ ] G3: Observe an actual newly created post-fix inne chat, first user message and corresponding reply; explicitly assess startup failure handling.
  - UNMET: current read-only snapshot still has the same nine workspace chats; eight have target-folder paths. Identifiers and input times match prior snapshots. No new-chat first-message/reply evidence, and no fresh failed-start demonstration.
  - Existing old chats, source inspection, passing CI and installed version cannot pass this gate.
  - Brief forbids any other agent launch; verification skill forbids driving the user's desktop. A stand-in journey cannot prove the requested real conversation. No acceptance claim.
- [x] G4: Record evidence and honest disposition; route the verification-capability blocker rather than repeat orphan hand-backs.
  - Agent lane records current evidence, unmet G3, constraints and next action.
  - fleet/park --lead succeeded 2026-11-11T14:39Z. Readback: Todo, no assignees, waitingOnAgentId is Chief Of Staff, waitingOnUserId null.
  - Lead needs to provide a permitted isolated real-start verification path or route to an appropriately authorized verifier. No question for Valentin and no second PR.
  - Repeated dispatch feedback +1: https://app.hypertask.ai/detail/project-12057/615.

Constraints observed: single thread; no agent launches, local tests/builds, user desktop driving, private content in Git, unrelated edits, or duplicate PRs. Existing shared checkout remains untouched. Evidence-only changes; ticket is not Done.
