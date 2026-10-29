# Release path

Master pushes start release workflows.
Both x64 and arm64 builds run.
Gitleaks gates publication.
The x64 app must open successfully.
Its visible ZigShell window must respond.
The launch job allows five minutes.
A screenshot and process details record proof.
Signed assets publish after these gates pass.

Tests run nightly or manually.
Their results cannot block releases or trigger reverts.
Auto-revert and automerge have disabled job guards.
They also require disabling through GitHub settings.
The original release workflow remains archived.
Find it at `tools/workflow-archive/release.yml`.
Broader release diagnostics use `release-diagnostics.yml`.
Gitleaks also runs on pushes.
TruffleHog runs on scheduled and manual scans.

Nightly and manual workflow inventory:

- `account-bundle.yml`
- `account-journey.yml`
- `background-close.yml`
- `bot-avatars.yml`
- `browser-corners.yml`
- `browser-toggle-normal.yml`
- `chat-bench-ab.yml`
- `chat-history-retention.yml`
- `chat-perf-bisect.yml`
- `chat-replies.yml`
- `chat-shape-switch-proof.yml`
- `chat-style.yml`
- `chat-table-bench.yml`
- `chat-transcript-reconcile.yml`
- `check-red-run.yml`
- `color-emoji.yml`
- `docs-site.yml`
- `freeze-recorder.yml`
- `hax-sessions.yml`
- `held-queue.yml`
- `idle-poll-proof.yml`
- `large-history-switch.yml`
- `ledger-guard.yml`
- `link-picker.yml`
- `manage-snippets.yml`
- `no-comments.yml`
- `notifications-rejection.yml`
- `palette-dialog-design.yml`
- `probe-chrome-frameless.yml`
- `question-journey.yml`
- `reaction-journey.yml`
- `release-diagnostics.yml`
- `release-gate.yml`
- `remote-switch.yml`
- `session-notes.yml`
- `shared-sidebar.yml`
- `test-repeat.yml`
- `test.yml`
- `title-pill.yml`
- `verify-close-unattached.yml`
- `verify-long-chat.yml`
- `verify-reconnect.yml`
- `verify.yml`
- `window-controls.yml`
- `workspace-journey.yml`
- `workspace-number-shortcuts.yml`
