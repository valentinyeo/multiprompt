# Wrong-session history regression

`historical-resolver.py` contains the unchanged `claude_transcript_for_cwd`, `codex_transcript_for_cwd`, and `resolve_tmux_agent` functions from commit `1648c59e146e06be0fec8247f6db800da4fba3ad`, immediately before the Codex ownership fix `f2bcef53`.

The fixture preserves the faulty rule: choose the newest conversation in a shared working directory. The production reader no longer uses that rule. The later unidentified-Claude fix is `3d9dc2d4`.

The reader suite runs these controls on GitHub-hosted Linux:

- Two actual child processes hold different Codex transcript descriptors while sharing a working directory. Alternating neighbour writes must not switch either conversation.
- The historical resolver must fail that same ownership assertion, not fail to load.
- An unidentified Claude process must not inherit another conversation in its directory. The historical resolver must fail that ownership assertion too.
- An unbound or changed send destination must leave the unfinished terminal draft intact and issue no terminal send or paste.

Run through the repository's Tests workflow. The reader job executes `python3 -W error::DeprecationWarning tools/chat-history-reader-test.py -v`.

The released desktop UI proof uses `verify.yml` with `feature=chat-delivery`, `hax_sessions_proof=true`, and a published `tag`. It copies distinct same-folder native runner histories through real keyboard actions and retains both released session screenshots together as `session-pair.png`. This desktop boundary uses synthetic hax session files, not a signed-in provider or the owner's live sessions.

No production routing code changes are required for this proof.
