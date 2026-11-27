# Live chat model and effort

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, src/plus_menu.zig, src/agent_host.zig, src/app_state.zig, src/sidebar.zig, src/mp_sessions.py, src/mp_layout.mjs, tools/mb.mjs, tools/mp-layout.mjs, tools/palette-verbs.mjs, tools/fixtures/IGSH-1649/action-notices.json, CLAUDE.md, openwiki/operations/keyboard-shortcuts.md, openwiki/operations/spawn-multibot-session.md, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/model-settings.ps1, .github/workflows/click-through.yml

## Sub-features

- Every Claude, Codex, Pi and Antigravity plus menu starts with exactly four rows: AI, Model, Effort and Permission level. No message controls or badges are added.
- AI opens Switch AI; Model opens only this provider's choices, including Pi's discovered model list.
- Select a Claude model and effort. Claude permission choices are Default, Auto and Bypass.
- Codex permission choices show approval/sandbox pairs: untrusted/workspace write, on request/workspace write, untrusted/read only, never/full access.
- Pi and Antigravity show their fixed full-access permission as disabled information, not a working mode switch.
- New chats use Bypass/full access for all four providers and all server slots, including slot 2 and cross-user launches. Existing saved choices survive re-enable and restart.
- Select an Antigravity model (Neon, Carbon, Argon, Hydrogen, Flash, Opus, Sonnet) and effort up to XHigh, with XHigh offered only on Neon and Hydrogen. Older clients' XHigh requests still normalize to High on other models.
- Select a Codex effort (Low, Medium, High). The saved effort rides on every later turn.
- Select a Pi effort (Low, Medium, High, XHigh). A live chat takes it at once as the thinking level, and a fresh start passes it as the thinking flag.
- Retain history and the unsent draft.
- Show the active model, effort and permission rows in the plus menu in the active style, with no check mark.

## How to get to it (user POV)

Open any AI chat. Click plus, then AI, Model, Effort or Permission level. Up/Down and Enter choose a row; Escape returns to the four-row menu, then closes it. Ctrl+K has matching **Chat View: AI**, **Chat View: Model**, **Chat View: Effort** and **Chat View: Permission level** actions. File attachment remains under **Chat View: Attach File**, paste and drop.

A live Antigravity chat offers its own Model rows (Neon, Carbon, Argon, Hydrogen, Flash, Opus, Sonnet) and Effort rows up to XHigh through the same plus button. Models without XHigh never show that effort as a working choice. The host still normalizes legacy requests for older clients.

A live Codex chat offers its Effort rows up to High through the same plus button. Pi's Model row opens its discovered provider-qualified model picker, and its Effort row offers up to XHigh.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-model` on the branch, without a release tag. The workflow selects the chat-delivery driver and uploads `verify-chat-delivery`.

The saved tab, remote shell and tmux are fixture boundaries. The app supplies its embedded reader unchanged. The fixture starts that reader's production Python host in an isolated home and configures a synthetic Python Claude process. Windows-only fixture compatibility supplies file locks, notification polling and socket/pipe selection. The synthetic process records its actual arguments and emits a synthetic init and transcript. It makes no network or Claude calls.

The real Windows app opens the plus menu, requires exactly the four root rows, opens the Model or Effort submenu with native mouse input, then clicks each Haiku, Low, Medium and High choice. It opens all three setting submenus again to check the active model, effort and permission style. Each choice must retain the unsent draft, update the independently read host config, restart the synthetic process with the chosen flags and produce the host's model_effort_settings_applied event. Copied rendered history remains present before and after. The active model/effort/permission rows use the active style without a check mark. Inspect the actual native clicks and selected-row screenshot; a config write alone is insufficient.

Inspect `model-before.png`, `model-plus-{haiku,low,medium,high}.png`, `model-plus-menu.png`, `model-plus-menu-active.png`, `model-plus-menu-active-{models,efforts,permissions}.png`, matching `*-root.png` four-row captures, `model-settings/plus-active.json`, `model-after-{haiku,low,medium,high}.png`, `model-after.png`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and `model-settings/` config, argv, host log, copied history and observation files. A passing result needs screenshot inspection as well as the independent evidence checker.

### Command-line and shared-host regressions

Run the hosted Tests workflow. `tools/chat-menu-controls.test.js` exercises the production host API and CLI for all four providers, three isolated host homes, old enable requests, repeated settings, live changes with an outstanding turn and pending messages, native Claude permission names, Codex turn payloads and fixed permission refusals. `tools/mb-chat-controls.test.mjs` exercises `mb ai/model/effort/permission`, server-slot refusal, alias mapping and repeated calls. The Zig plus-menu tests cover four-row geometry, provider-specific choices and disabled fixed permissions. These are system-boundary stand-ins, not real provider or Windows proof.

On a disposable hosted chat, run `mb model <name> <model>`, `mb effort <name> high` and `mb permission <name> bypass` twice; compare config, native session and pending-message IDs before and after. Repeat on slots 0, 1 and 2. Claude and Antigravity wait for idle and resume the same native conversation for startup-only changes; Codex applies settings to its next turn; Pi sends live RPC controls. Switch AI through the AI row and repeat `mb ai <name> <provider>` to require an already-selected no-op.

Android counterpart: https://app.hypertask.ai/detail/project-13734/285. Permission follow-up: https://app.hypertask.ai/detail/project-13734/172. Bare Codex and Pi workspace programs now open hosted chats, matching Claude and Antigravity. Explicit terminal launches also request full permissions unless their command already chooses a permission policy. No wire operation is removed. Legacy `manual`, `acceptEdits`, `plan`, `dontAsk` and `auto` requests remain accepted where previously supported. Claude's legacy `manual` is translated to its native `default` control value.

## Gotchas

The fixture maps Unix sockets to isolated loopback sockets when Windows Python lacks Unix sockets. This does not verify a real SSH server, real Claude, a Haiku response, model quality or billing. No hosted run or screenshot inspection is implied by this map.

The `chat-model` journey drives a synthetic Claude chat only. The Antigravity, Codex and Pi rows come from the reader's own unit tests plus the Antigravity chats map; this journey does not click them.
