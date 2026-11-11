# Gates: IGSH-1925

OWNS: .unlazy/IGSH-1925/**

Scope: New inne chats start like older ones and answer the first message. A chat that cannot start says so in the chat. No silent Not sent. Prove merged PR 919 live. Open a second PR only if a new post-fix inne chat still fails.

- [x] G1: Merged PR 919, its GitHub CI, and a published release all contain the start-command fix.
  CHECK: node .unlazy/IGSH-1925/check-release.mjs
  EXPECT: G1 PASS
  EVIDENCE: automatic-evidence=v1; definition-sha256=d5b88c033127b6a7749e59ccbd9273097f09bff735aeecbdb8bea1cf9d283094; exit=0; EXPECT=matched; output-sha256=5d8b5c60d861bed4ae53626ef9646eaeea46a5e22622bfeb4fa9e3abebbd2b70; output-bytes=198; shell=/bin/sh; cwd=/home/valentin/projects/mp-runner-4-1925-live; path=40375c739e86/57 entries

- [x] G2: The running laptop1 app is a release that contains merge 307bca51295f1a51bd5d9559bb258108484972c8. No restart and no desktop driving.
  EVIDENCE: 2026-11-11T14:15Z laptop1 connected. Main PID 20292 started 2026-11-11T13:17:15.044Z. Debug process-start at 13:17:15.057 says version 0.28.1674. GitHub compare of that tag to the merge is ahead 20, behind 0. No restart.

- [ ] G3: A newly created post-fix inne chat has a first user message and a matching reply. A failed start is visible in the chat. Missing errors are not proof.
  EVIDENCE: UNMET 2026-11-11T14:20Z. Nine inne tabs, same set as the prior run. Black Friday Plan still has three Not sent messages from 2026-11-10T15:53Z and 16:03Z, before merge 16:42Z, and still has no host config. No inne host config was created after the merge. Debug logs have no live-chat start failed line. Existing hosted inne chats still accept messages, latest accepted 13:08Z. A new non-inne chat created after the fix has user and assistant messages. That is not an inne chat, so G3 stays unmet. Do not open a second PR for that.

- [x] G4: Done only after G1, G2 and G3 pass. Otherwise park the remaining proof and read the board back.
  EVIDENCE: 2026-11-11T14:22Z readback: section AI Review, assignees empty, waitingOnUserId null. fleet/park --hand-back succeeded. G3 remains unmet. Left to do: one newly created post-fix inne chat, its first user message, and the reply.
