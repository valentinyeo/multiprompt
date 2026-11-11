# Gates: IGSH-1828

Scope: Cancel message removes a waiting message even after hand-off; Up then Delete does the same. Send to a busy bot, cancel it, and prove the bot never answers it in a linked release proof run.

- [x] G1: Published release contains merged application fix.
  Evidence: PR https://github.com/valentinyeo/multiprompt/pull/858 merged at 63bb3a6fa973f8d1f57d6c0a5986e2bc4a220303; v0.28.1668 release https://github.com/valentinyeo/multiprompt/actions/runs/42984760861. Prior runner verified v0.28.1677 contains it.
- [ ] G2: Published app menu Cancel recalls a handed message without answering it.
  Evidence: https://github.com/valentinyeo/multiprompt/actions/runs/43054810100 reached the hosted stand-in and logged one user event. Windows PowerShell bound -split as an argument of Read-Shared, so ConvertFrom-Json read the whole JSONL file and rejected the second event. Parentheses split lines before parsing. Recheck the next branch proof; do not mark Done before a passing published-app proof.
- [ ] G3: Up then Delete recalls another handed message, preserves its sibling, and removes Cancel after the sibling is answered.
  Evidence: pending same release proof.
- [ ] G4: Existing proof PR passes required checks and merges; ticket has evidence and reaches Done.
  Evidence: existing PR https://github.com/valentinyeo/multiprompt/pull/946; no second PR. No local builds/test jobs or helpers.
