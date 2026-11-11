# Gates: IGSH-1828

Scope: Cancel message removes a waiting message even after hand-off; Up then Delete does the same. Send to a busy bot, cancel it, and prove the bot never answers it in a linked release proof run.

- [x] G1: Published release contains merged application fix.
  Evidence: PR https://github.com/valentinyeo/multiprompt/pull/858 merged at 63bb3a6fa973f8d1f57d6c0a5986e2bc4a220303; v0.28.1668 release https://github.com/valentinyeo/multiprompt/actions/runs/42984760861. Prior runner verified v0.28.1677 contains it.
- [ ] G2: Published app menu Cancel recalls a handed message without answering it.
  Evidence: https://github.com/valentinyeo/multiprompt/actions/runs/43053163118 fails waiting for three received messages. The hosted stand-in initializes, but no dispatch worker survives Windows: production message_worker uses os.mkfifo and SIGALRM. Reuse the existing Windows accepted-message dispatch adapter for recall; keep production dispatch and host logic unchanged. Preserve host diagnostics. New CI regression covers both adapter cases, absent source, and worker lock contention. Recheck the next branch proof after 2026-11-11T16:11:00Z; do not mark Done before a passing published-app proof.
- [ ] G3: Up then Delete recalls another handed message, preserves its sibling, and removes Cancel after the sibling is answered.
  Evidence: pending same release proof.
- [ ] G4: Existing proof PR passes required checks and merges; ticket has evidence and reaches Done.
  Evidence: existing PR https://github.com/valentinyeo/multiprompt/pull/946; no second PR. No local builds/test jobs or helpers.
