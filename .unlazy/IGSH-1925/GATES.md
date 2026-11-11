# Gates: IGSH-1925

Scope: New inne chats start like older ones and answer the first message. A failed start is explained in Chat View instead of silent Not sent. Verify existing merged PR 919; no second PR. Read production state only; no desktop driving, restarts, agents, local builds or tests.

- [x] G1: The existing merged fix has successful GitHub checks and is contained in the published release.
  EVIDENCE: 2026-11-11T14:26Z: PR https://github.com/valentinyeo/multiprompt/pull/919 merged as 307bca51295f1a51bd5d9559bb258108484972c8. CI https://github.com/valentinyeo/multiprompt/actions/runs/42853784160 conclusion success. Published https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1676 contains that merge: ahead 22, behind 0, identical merge base.
- [x] G2: The running desktop release contains that fix.
  EVIDENCE: 2026-11-11T14:27Z: running desktop process started 13:17:15Z. Its process-start log identifies version 0.28.1674. GitHub ancestry: ahead 20, behind 0, identical merge base. Read-only observation; no restart or desktop input.
- [ ] G3: A newly created post-fix inne chat has its first user message and matching reply; failed start handling is verified without treating missing log errors as proof.
  EVIDENCE: UNMET 2026-11-11T14:27Z. All 18 inne host configurations predate merge; newest modification 2026-11-09T11:43:26Z. The originally reported chat still has no host configuration and only pre-fix messages: two cancelled at 2026-11-10T15:53Z, three failed at 16:03Z. The other unconfigured inne chat has no messages. No observed new post-fix inne chat/reply pair. The merged change includes explicit chat startup failure handling, but source inspection does not prove visible live behavior. No new application change is justified by pre-fix failures. Repeated unchanged verification handoffs reported at https://app.hypertask.ai/detail/project-12057/613.
- [x] G4: The board reflects actual verification: Done only after G1-G3 pass; otherwise park the remaining work and read back the board.
  EVIDENCE: fleet/park --hand-back succeeded. Final board readback: AI Review, no assignees, no waiting person. G3 remains required. No second PR, application changes, local tests, agents, desktop driving or restarts. Move projection friction reported at https://app.hypertask.ai/detail/project-12057/308.

Result: 3 met, 1 unmet, 0 abandoned. Not Done. Remaining action: permitted end-to-end new inne-chat first-message/reply verification, not another check of old conversations.
