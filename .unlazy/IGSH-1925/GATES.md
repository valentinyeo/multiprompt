# IGSH-1925 acceptance gates

Scope: New inne chats start like older chats and answer their first message. If a chat cannot start, it says so in the chat; no silent Not sent. Verify already merged PR https://github.com/valentinyeo/multiprompt/pull/919 without another application PR.

- [x] G1: Confirm PR919 merge SHA, successful GitHub CI, and published release ancestry.
  EVIDENCE: PR919 merged 2026-11-10T16:42:30Z as 307bca51295f1a51bd5d9559bb258108484972c8. CI https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 conclusion success, head dc5e3774f62132093a77bee3a4dedb10598c73db. Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1681 contains the fixing merge: compare ahead 27, behind 0, matching merge base.
- [x] G2: Identify the running production desktop release and confirm it contains PR919, using read-only inspection without restart or replacement.
  EVIDENCE: Production main PID 24688 started 2026-11-11T18:12:23.8751052Z. Its executable was last written 18:09:55.9332865Z, before that start. SHA256 40fa3e29571ef97c7cb4c8700898afd126c76dd46eee4f2ae6a4bc60d03243d8 equals GitHub's published v0.28.1681 multiprompt-x64.exe asset digest. Size 14946304 bytes. No desktop input, replacement, or restart.
- [ ] G3: Observe actual newly created post-fix inne chat first input and corresponding reply. Assess failed-start behavior honestly. Older established chats, old failures, missing errors, CI, and source alone cannot satisfy this acceptance gate.
  EVIDENCE: UNMET at 2026-11-11T20:25:51Z. Published desktop snapshot has 48 shells overall and the same nine inne workspace tabs as prior runs. Reported failing chat's last input remains 2026-11-10T16:03:29.510Z, before the fix merged. No new inne-chat first-input/reply pair is observable. The extra overall shell is not a new inne chat. Debug log rotated away launch evidence; no inference from absent errors. Additional agents are forbidden by this run; the verification skill prohibits driving a user's desktop. Read-only inspection cannot create the missing acceptance event. No invented acceptance and no second PR.
- [x] G4: Record exact evidence and disposition. Done only when acceptance is proven; otherwise park the capability blocker with the owning lead rather than manufacture evidence or repeat orphan hand-backs.
  EVIDENCE: Fresh findings recorded in ticket agent activity 151786ec-247e-46df-b3ef-75bdb386dd34. fleet/park --lead succeeded; readback confirms Todo, no assignees, waitingOnAgent Chief Of Staff, waitingOnUserId null. Repeated pickup despite unchanged lead wait reported as +1 at https://app.hypertask.ai/detail/project-12057/320. G3 remains unmet: 3 gates met, 1 unmet, none abandoned. Not Done.

Constraints: one assigned ticket, single thread, no other agents or models, no user's desktop input, no local build/test jobs, no private conversation content in public artifacts, no second PR or unrelated edits. Existing dirty shared checkout remains untouched.

Resume: tmux attach -t ht-or-runner-4 (Cursor Grok RUNNER 4)
