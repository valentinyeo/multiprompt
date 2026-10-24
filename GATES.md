# Gates: IGSH-759 hide Chat View activity rows

OWNS: GATES.md, src/chat_render.zig, .claude/skills/verify-multiprompt/**, .github/workflows/verify.yml, tools/verify-chat-delivery/drive.ps1, tools/verify-chat-delivery/boundary.py, tools/chat-messages-only-proof.mjs, tools/chat-messages-only-proof.test.mjs, changelog.d/IGSH-759-chat-messages-only.md

Scope: Hide tool/activity rows in Chat View without modifying transcript data or other message behavior; verify on GitHub Windows only, then commit, push and open the requested PR without merging.

- [ ] G1: Renderer omits tool rows before layout, painting and hit collection, preserving transcript data and ordinary message paths
  EVIDENCE: pending

- [ ] G2: GitHub Windows regression proves tool-heavy turns occupy exactly the same layout as messages alone, including selection/copy and streaming updates
  EVIDENCE: pending

- [ ] G3: Verify journey captures the real composer and a tool-heavy assistant transcript and rejects visible activity rows on unchanged origin/master
  EVIDENCE: pending

- [ ] G4: GitHub Windows changed-branch journey passes with screenshots inspected, Doctor identity and owned-process cleanup
  EVIDENCE: pending

- [ ] G5: Dependent verification assertions and maps match the new messages-only rendering contract
  EVIDENCE: pending

- [ ] G6: Diff is limited to this ticket, adds no code comments or settings, and no local builds or tests execute
  EVIDENCE: pending

- [ ] G7: Only ceo/IGSH-759 is committed and pushed, and an unmerged PR has the requested title and plain-language change, proof and red-run notes
  EVIDENCE: pending
