# SOFT-2987 deleted workflows

Fifty-seven workflow files were removed from `.github/workflows`. Seventeen remain: `test.yml`, `pr-verifier.yml`, `pr-verifier-blocked.yml`, `verify.yml`, `release.yml`, `auto-release.yml`, `gitleaks.yml`, `no-comments.yml`, `docs-site.yml`, `dev-build.yml`, `crash-symbols.yml`, `maintain-verification.yml`, `nightly-verification-report.yml`, `chat-delivery-formal.yml`, `ci-repair-receipt.yml`, `service-route-receipt.yml`, `verify-cli.yml`.

Proof for product behaviour moved into `test.yml` (Node/Zig/unit steps) or into the nightly `verify.yml` journey matrix via feature maps under `.claude/skills/verify-multiprompt/features/`. CI-only meta workflows were deleted without replacement.

## CI meta (deleted, no replacement)

| Workflow | Notes |
| --- | --- |
| `check-red-run.yml` | Red-run gate; `tools/check-red-run.mjs` kept for local/reader use only |
| `release-gate.yml` | `tools/auto-release-admit.sh` reads `verify.yml` only |
| `verify-skill-eval.yml` | Skill eval hygiene; not product proof |
| `test-repeat.yml` | Bench meta |
| `ledger-guard.yml` | Budget meta |
| `chat-bench-ab.yml` | Bench meta |
| `release-diagnostics.yml` | Release meta |
| `resource-warning-integration.yml` | Hypertask wiring meta; release job keeps `resource-warning-ticket.mjs` |
| `resource-observation.yml` | Standalone nightly guard; logic lives in `release.yml` `resource-observation` job |

## `test.yml` (Node / Python / Zig tests)

| Workflow | Proof moved to |
| --- | --- |
| `chat-transcript-reconcile.yml` | `test.yml` → `python3 tools/chat-transcript-reconcile.test.py` |
| `room-checks.yml` | `test.yml` → `python3 tools/room-routing.test.py` (and existing room unit tests in build) |
| `chat-history-reader-proof.yml` | `test.yml` → `python3 tools/chat-history-reader-test.py` (already central) |
| `check-red-run.yml` | Dropped; no PR workflow |

`multibot-feedback-test.py` stays on the formal-delivery path filter; also runs in `test.yml` so wiring tests stay green.

## `verify.yml` nightly / manual journeys

Each row is the former adapter workflow; the same journey stem remains in the feature map and runs on `verify.yml` `schedule` and `workflow_dispatch` (and via `pr-verifier.yml` head job when selected).

| Deleted workflow | Feature / journey stem |
| --- | --- |
| `account-bundle.yml` | `account-bundle` |
| `account-journey.yml` | `account-journey` |
| `background-close.yml` | `background-close` |
| `bot-avatars.yml` | `bot-avatars` |
| `browser-corners.yml` | `browser-corners` |
| `browser-toggle-normal.yml` | `browser-toggle-normal` |
| `chat-history-retention.yml` | `chat-history-retention` |
| `chat-perf-bisect.yml` | `chat-perf-bisect` |
| `chat-replies.yml` | `chat-replies` |
| `chat-shape-switch-proof.yml` | `chat-shape-switch-proof` |
| `chat-still.yml` | `chat-still` |
| `chat-style.yml` | `chat-style` |
| `chat-table-bench.yml` | `chat-table-bench` |
| `click-through.yml` | `click-through` |
| `color-emoji.yml` | `color-emoji` |
| `computer-focus-probe.yml` | `computer-focus-probe` |
| `freeze-recorder.yml` | `freeze-recorder` |
| `hax-sessions.yml` | `hax-sessions` |
| `held-queue.yml` | `held-queue` |
| `idle-poll-proof.yml` | `idle-poll-proof` |
| `large-history-switch.yml` | `large-history-switch` |
| `legacy-update-feed.yml` | `legacy-update-feed` |
| `link-picker.yml` | `link-picker` |
| `manage-snippets.yml` | `manage-snippets` |
| `notifications-rejection.yml` | `notifications-rejection` |
| `palette-dialog-design.yml` | `palette-dialog-design` |
| `probe-chrome-frameless.yml` | `probe-chrome-frameless` |
| `question-journey.yml` | `question-journey` |
| `reaction-journey.yml` | `verify.yml` `chat_reactions_proof` input + `chat-delivery` / `chat-double-click` journeys |
| `recall-handed.yml` | `recall-handed` |
| `remote-switch.yml` | `remote-switch` |
| `rooms-preview-build.yml` | `rooms-preview-build` |
| `session-notes.yml` | `session-notes` |
| `shared-sidebar.yml` | `shared-sidebar` |
| `ssh-detached.yml` | `ssh-detached` |
| `symbolize-freeze.yml` | `symbolize-freeze` |
| `title-pill.yml` | `title-pill` |
| `verify-chat-steady.yml` | `verify-chat-steady` |
| `verify-close-disconnected.yml` | `verify-close-disconnected` |
| `verify-close-unattached.yml` | `verify-close-unattached` |
| `verify-long-chat.yml` | `verify-long-chat` |
| `verify-reconnect.yml` | `verify-reconnect` |
| `window-controls.yml` | `window-controls` |
| `workspace-journey.yml` | `workspace-journey` |
| `workspace-number-shortcuts.yml` | `workspace-number-shortcuts` |

## PR verifier judge

Author-family judge selection (`pickVerifier`, `VERIFIER_MODELS`, per-engine workflow steps) removed. The verdict job uses Token Ladder `ladder-call` with `tools/pr-verifier.cjs` `write-judge-request` / `parse-ladder-verdict`.