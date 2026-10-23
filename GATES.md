# Gates: IGSH-611

OWNS: src/**, tools/**, openwiki/operations/keyboard-shortcuts.md, changelog.d/IGSH-611-chat-view-everywhere-once.md, .claude/skills/verify-multiprompt/**, .github/workflows/verify.yml, GATES.md

Scope: One-time everywhere actions, persistent session view locks, legacy migration, palette surfaces, regression coverage and a real-input Windows verification journey.

- [x] G1: Palette and generated shortcut documentation remain synchronized.
  CHECK: node --test tools/palette-rows.test.js tools/shortcuts-doc.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=85004b4cc0fd1fc2090461724674a33fa1022a5ca6a798fc9104a11e7a953fb1; exit=0; EXPECT=matched; output-sha256=69e0b2c6ad58a61ca97a8640eae8b182bb2f26291a8a2b8c2d9075b830a28925; output-bytes=2188; shell=/bin/sh

- [x] G2: Lightweight contracts cover the new state model, Zig behavior tests, persistence migration and Windows journey wiring.
  CHECK: node --test tools/chat-view-everywhere.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=4de9e67478d840175ef28a45e11f722667c50072b5bcc554080b4672ff3ef7db; exit=0; EXPECT=matched; output-sha256=96945ee89860dd92b94eb954164af57c24c9e74449da9f7f39b641e9d1cc6a92; output-bytes=1769; shell=/bin/sh

- [x] G3: Changed code has no removable comments, whitespace errors or version bumps; the tokenizer rejects positive comment controls.
  CHECK: node --test tools/chat-view-everywhere-policy.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=23c5a745ee62a7f68491e2f076693dd35ca79aa36af1ec0fa36f95e3344e6c28; exit=0; EXPECT=matched; output-sha256=df56e969bea037d0e81f98d3b8b93cc44d03c4584506f04036c20914f1ffc35b; output-bytes=538; shell=/bin/sh

- [ ] G4: Native Zig behavior tests and the Windows user journey execute successfully on GitHub Windows.
  EVIDENCE: pending

- [x] G5: Relevant lightweight integration checks and the static portions of updated native harnesses pass without invoking native tools.
  CHECK: node --test tools/verify-multiprompt.test.js tools/verify-chat-delivery.test.js tools/check-browser-pane-locked.test.js tools/start-maximized.test.js tools/favorites-groups.test.js tools/shell-focus.test.js tools/verify-reconnect.test.js tools/app-source.test.js tools/session-lock.test.js tools/chat-rich.test.js tools/paste-focus.test.js tools/other-workspace-invariant.test.js && node --test --test-name-pattern='automatic view functions|palette, restoration|per-shell deferred|every console reveal|hook|lifecycle harness' tools/chat-shell-override.test.js tools/full-width-chat.test.js tools/chat-view-console-return.test.js tools/chat-view-console-visibility.test.js tools/chat-double-click.test.js tools/console-font-lifecycle.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=a8db3c3b5069bab261b739f5e9ae15c4548d4c19ee414b8482350b0ef24e3262; exit=0; EXPECT=matched; output-sha256=f993427de7878d4638f014dfab80c4c8b69d82f10c2bd6d46318733fd62b0d92; output-bytes=30389; shell=/bin/sh

ABANDON: G4 Native execution and desktop verification require GitHub Windows. This code-only handoff cannot publish the uncommitted branch or dispatch its changes; the runner must run the branch verification journey and native regression harnesses after publishing.

The external no-comments wrapper was attempted with the requested worktree argument and returned CLONE_FAILED because it expects a repository slug rather than a worktree. G3 independently tokenizes changed code using the repository scanner, checks whitespace and version constraints, and tests positive comment controls; it does not claim the external wrapper passed.

Machine-specific working-directory and PATH transcript fields are omitted from this public ledger; definition and output fingerprints are retained.
