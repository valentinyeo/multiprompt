# Verification migration inventory

Baseline `b51c0c164`, where the checkout had 138 tracked PowerShell scripts, including build/install helpers, and 50 scheduled workflows. At `43c8df86a` the same commands report 146 scripts and 59 scheduled workflows, so treat these rows as the migration plan for that baseline, not as a current file listing. The ticket counts predate this revision. No reachable script is deleted in this slice. Files sharing a row have the same disposition.

Reproduce the inventory with `git ls-files "*.ps1"` and `rg -l "^  schedule:" .github/workflows`. Follow-up means consolidate the recipe behind `drive.ps1`, prove equivalent visible/side-effect coverage on hosted Windows, then remove its old route. Keep native/shared helpers; never convert diagnostic-only checks into desktop proof.

## PowerShell scripts

Paths are repository-relative. The new `drive.ps1` is the reusable entry point, not a per-ticket script.

| Scripts | Decision |
| --- | --- |
| `.claude/skills/verify-multiprompt/browser-corners.ps1`, `.claude/skills/verify-multiprompt/chat-options.ps1`, `.claude/skills/verify-multiprompt/chat-skill-pill.ps1`, `.claude/skills/verify-multiprompt/chat-slash.ps1`, `.claude/skills/verify-multiprompt/chat-working.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-appearance.ps1`, `.claude/skills/verify-multiprompt/control-feature-browser-own-profile.ps1`, `.claude/skills/verify-multiprompt/control-feature-browser-pane-locked.ps1`, `.claude/skills/verify-multiprompt/control-feature-browser-pane-stuck.ps1`, `.claude/skills/verify-multiprompt/control-feature-browser-switch-speed.ps1` | Keep as journey; appearance/palette reused; other files follow up |
| `.claude/skills/verify-multiprompt/control-feature-browser-typing.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-browser-autoload.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-browser-shortcut.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-code-font.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-composer-text.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-chat-dictation.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-first-paint.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-focus.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-not-sent-remove.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-send-latency.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-chat-switch-speed.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-tables.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-view-everywhere.ps1`, `.claude/skills/verify-multiprompt/control-feature-chat-view.ps1`, `.claude/skills/verify-multiprompt/control-feature-command-palette.ps1` | Keep as journey; appearance/palette reused; other files follow up |
| `.claude/skills/verify-multiprompt/control-feature-computer-menu.ps1`, `.claude/skills/verify-multiprompt/control-feature-favorites-groups.ps1`, `.claude/skills/verify-multiprompt/control-feature-group-rail.ps1`, `.claude/skills/verify-multiprompt/control-feature-inbox-no-footer.ps1`, `.claude/skills/verify-multiprompt/control-feature-inbox-order.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-inbox-space.ps1`, `.claude/skills/verify-multiprompt/control-feature-inbox.ps1`, `.claude/skills/verify-multiprompt/control-feature-live-chat-pane.ps1`, `.claude/skills/verify-multiprompt/control-feature-palette-order.ps1`, `.claude/skills/verify-multiprompt/control-feature-pane-layout.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-relaunch-saved-sessions.ps1`, `.claude/skills/verify-multiprompt/control-feature-remind-me.ps1`, `.claude/skills/verify-multiprompt/control-feature-server-open-group.ps1`, `.claude/skills/verify-multiprompt/control-feature-session-open.ps1`, `.claude/skills/verify-multiprompt/control-feature-session-restore.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-session-tabs.ps1`, `.claude/skills/verify-multiprompt/control-feature-sessions.ps1`, `.claude/skills/verify-multiprompt/control-feature-status-card.ps1`, `.claude/skills/verify-multiprompt/control-feature-tab-names.ps1`, `.claude/skills/verify-multiprompt/control-feature-whats-new.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/control-feature-workspace-focus.ps1`, `.claude/skills/verify-multiprompt/control-inline-rename.ps1`, `.claude/skills/verify-multiprompt/control-library.ps1`, `.claude/skills/verify-multiprompt/control.ps1`, `.claude/skills/verify-multiprompt/link-picker.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/owner-browser-proof.ps1`, `.claude/skills/verify-multiprompt/permission-rows.ps1`, `.claude/skills/verify-multiprompt/servers.ps1`, `.claude/skills/verify-multiprompt/settings-panel.ps1`, `.claude/skills/verify-multiprompt/title-bar.ps1` | Keep as journey/helper; follow-up |
| `.claude/skills/verify-multiprompt/tmux-binding.ps1`, `.claude/skills/verify-multiprompt/window-controls.ps1`, `.claude/skills/verify-multiprompt/workspace-switcher.ps1`, `src/update_release.ps1`, `tools/account-journey/diagnostics.ps1` | Keep as journey/helper; follow-up |
| `tools/account-journey/diagnostics.test.ps1`, `tools/account-journey/drive.ps1`, `tools/account-journey/foreground-predicate.test.ps1`, `tools/account-journey/foreground.ps1`, `tools/account-journey/foreground.test.ps1` | Keep as journey/helper; follow-up |
| `tools/background-close.ps1`, `tools/background-freeze-journey.ps1`, `tools/browser-panes-onscreen.ps1`, `tools/browser-toggle-normal.ps1`, `tools/changelog-link-fixture.ps1` | Keep as journey/helper; follow-up |
| `tools/check-powershell-host-names.ps1`, `tools/close-disconnected.ps1`, `tools/dev-laptop-driver.ps1`, `tools/fixtures/HYCI-137/rename.ps1`, `tools/fixtures/HYCI-137/workspace.ps1` | Keep as journey/helper; follow-up |
| `tools/fixtures/HYCI-158/open-pane-before.ps1`, `tools/fixtures/HYCI-253/legacy-asset-check.ps1`, `tools/fixtures/IGSH-1165/foreign-first-key.ps1`, `tools/freeze-recorder-journey.ps1`, `tools/freeze-recorder-upload.ps1` | Keep as journey/helper; follow-up |
| `tools/idle-budget.ps1`, `tools/laptop-check/check.ps1`, `tools/legacy-update-proof.ps1`, `tools/local-listener-accounts.ps1`, `tools/probe-chrome-frameless.ps1` | Keep as journey/helper; follow-up |
| `tools/release-launch.ps1`, `tools/resource-guard/launcher-lifetime.test.ps1`, `tools/resource-guard/measure.ps1`, `tools/resource-guard/session.ps1`, `tools/resource-guard/session.test.ps1` | Keep as journey/helper; follow-up |
| `tools/resource-guard/setup.ps1`, `tools/resource-guard/snapshot.ps1`, `tools/resource-guard/snapshot.test.ps1`, `tools/resource-guard/stage.ps1`, `tools/resource-guard/stage.test.ps1` | Keep as journey/helper; follow-up |
| `tools/resource-guard/tcp.test.ps1`, `tools/shared-sidebar.ps1`, `tools/split-feature-controls.ps1`, `tools/ssh-detached/proof.ps1`, `tools/switch-performance.ps1` | Keep as journey/helper; follow-up |
| `tools/update-card-release-proof.ps1`, `tools/update-release-fixtures.ps1`, `tools/update-release-journey.ps1`, `tools/update-release.test.ps1`, `tools/usage-telemetry/reconnect-accounts.ps1` | Keep as journey/helper; follow-up |
| `tools/usage-telemetry/test_reconnect_accounts.ps1`, `tools/verify-account-photos/desktop.ps1`, `tools/verify-account-photos/start-fixture.ps1`, `tools/verify-account-photos/stop-fixture.ps1`, `tools/verify-app-icon/drive.ps1` | Keep as journey/helper; follow-up |
| `tools/verify-bot-avatars/drive.ps1`, `tools/verify-bot-photo/drive.ps1`, `tools/verify-bot-photo/switch-target.ps1`, `tools/verify-chat-delivery/chat-switch-profile.ps1`, `tools/verify-chat-delivery/drive.ps1` | Keep as journey/helper; follow-up |
| `tools/verify-chat-delivery/hax-sessions.ps1`, `tools/verify-chat-delivery/instant-chat.ps1`, `tools/verify-chat-delivery/live-delivery.ps1`, `tools/verify-chat-delivery/long-chat.ps1`, `tools/verify-chat-delivery/model-settings.ps1` | Keep as journey/helper; follow-up |
| `tools/verify-chat-delivery/reactions.ps1`, `tools/verify-chat-delivery/recall-handed.ps1`, `tools/verify-chat-delivery/recovery-palette-test.ps1`, `tools/verify-chat-delivery/recovery-palette.ps1`, `tools/verify-chat-delivery/remote-switch.ps1` | Keep as journey/helper; follow-up |
| `tools/verify-chat-delivery/resync-recovery.ps1`, `tools/verify-chat-delivery/resync.ps1`, `tools/verify-chat-delivery/startup-failure.ps1`, `tools/verify-chat-delivery/working-live.ps1`, `tools/verify-chat-reply.ps1` | Keep as journey/helper; follow-up |
| `tools/verify-reconnect/close-unattached.ps1`, `tools/verify-reconnect/drive.ps1`, `tools/verify-reconnect/pending-close.ps1`, `tools/verify-scratch.test.ps1`, `tools/verify-session-actions/drive.ps1` | Keep as journey/helper; follow-up |
| `tools/workspace-number-shortcuts.ps1`, `webview2-spike/build-bridge.ps1`, `webview2-spike/build.ps1` | Keep as journey/helper; follow-up |

## Scheduled workflows

Paths are relative to `.github/workflows/`. Preserve shared CI and release gates. Only the nightly fixed historical-release comparison is obsolete; its manual bisect remains available.

| Workflow | Decision |
| --- | --- |
| `account-bundle.yml` | Keep shared CI/release gate; outside journey migration |
| `account-journey.yml` | Keep as journey/diagnostic; follow-up |
| `background-close.yml` | Keep as journey/diagnostic; follow-up |
| `bot-avatars.yml` | Keep as journey/diagnostic; follow-up |
| `browser-corners.yml` | Keep as journey/diagnostic; follow-up |
| `browser-toggle-normal.yml` | Keep as journey/diagnostic; follow-up |
| `chat-bench-ab.yml` | Keep as journey/diagnostic; follow-up |
| `chat-history-retention.yml` | Keep as journey/diagnostic; follow-up |
| `chat-perf-bisect.yml` | Delete as obsolete: nightly v0.28.900/v0.28.917 comparison; keep manual bisect |
| `chat-replies.yml` | Keep as journey/diagnostic; follow-up |
| `chat-shape-switch-proof.yml` | Keep as journey/diagnostic; follow-up |
| `chat-style.yml` | Keep as journey/diagnostic; follow-up |
| `chat-table-bench.yml` | Keep as journey/diagnostic; follow-up |
| `chat-transcript-reconcile.yml` | Keep as journey/diagnostic; follow-up |
| `check-red-run.yml` | Keep shared CI/release gate; outside journey migration |
| `color-emoji.yml` | Keep as journey/diagnostic; follow-up |
| `docs-site.yml` | Keep shared CI/release gate; outside journey migration |
| `freeze-recorder.yml` | Keep as journey/diagnostic; follow-up |
| `gitleaks.yml` | Keep shared CI/release gate; outside journey migration |
| `hax-sessions.yml` | Keep as journey/diagnostic; follow-up |
| `held-queue.yml` | Keep as journey/diagnostic; follow-up |
| `idle-poll-proof.yml` | Keep as journey/diagnostic; follow-up |
| `large-history-switch.yml` | Keep as journey/diagnostic; follow-up |
| `ledger-guard.yml` | Keep shared CI/release gate; outside journey migration |
| `legacy-update-feed.yml` | Keep shared CI/release gate; outside journey migration |
| `link-picker.yml` | Keep as journey/diagnostic; follow-up |
| `manage-snippets.yml` | Keep as journey/diagnostic; follow-up |
| `no-comments.yml` | Keep shared CI/release gate; outside journey migration |
| `notifications-rejection.yml` | Keep as journey/diagnostic; follow-up |
| `palette-dialog-design.yml` | Keep as journey/diagnostic; follow-up |
| `probe-chrome-frameless.yml` | Keep as journey/diagnostic; follow-up |
| `question-journey.yml` | Keep as journey/diagnostic; follow-up |
| `reaction-journey.yml` | Keep as journey/diagnostic; follow-up |
| `release-diagnostics.yml` | Keep shared CI/release gate; outside journey migration |
| `release-gate.yml` | Keep shared CI/release gate; outside journey migration |
| `remote-switch.yml` | Keep as journey/diagnostic; follow-up |
| `room-checks.yml` | Keep as journey/diagnostic; follow-up |
| `session-notes.yml` | Keep as journey/diagnostic; follow-up |
| `shared-sidebar.yml` | Keep as journey/diagnostic; follow-up |
| `test-repeat.yml` | Keep shared CI/release gate; outside journey migration |
| `test.yml` | Keep shared CI/release gate; outside journey migration |
| `title-pill.yml` | Keep as journey/diagnostic; follow-up |
| `verify-close-disconnected.yml` | Keep as journey/diagnostic; follow-up |
| `verify-close-unattached.yml` | Keep as journey/diagnostic; follow-up |
| `verify-long-chat.yml` | Keep as journey/diagnostic; follow-up |
| `verify-reconnect.yml` | Keep as journey/diagnostic; follow-up |
| `verify.yml` | Keep as journey; appearance/palette use drive.ps1; other routes follow up |
| `window-controls.yml` | Keep as journey/diagnostic; follow-up |
| `workspace-journey.yml` | Keep as journey/diagnostic; follow-up |
| `workspace-number-shortcuts.yml` | Keep as journey/diagnostic; follow-up |
