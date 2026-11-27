# Live chat model and effort

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, src/plus_menu.zig, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/model-settings.ps1, .github/workflows/click-through.yml

## Sub-features

- Select a Claude model and effort.
- Select an Antigravity model (Neon, Carbon, Argon, Hydrogen, Flash, Opus, Sonnet) and effort up to XHigh, with XHigh saved as High for models that do not offer it.
- Select a Codex effort (Low, Medium, High). The saved effort rides on every later turn.
- Select a Pi effort (Low, Medium, High, XHigh). A live chat takes it at once as the thinking level, and a fresh start passes it as the thinking flag.
- Retain history and the unsent draft.
- Show the active model, effort and permission rows in the plus menu in the active style, with no check mark.

## How to get to it (user POV)

Open a live Claude chat. Click the plus button left of the message box and choose a model or effort, or open the Plus menu through Ctrl+K. Direct Claude Model/Effort palette labels have handlers but no current result-generation branch; they are not alternative live entries.

A live Antigravity chat offers its own Model rows (Neon, Carbon, Argon, Hydrogen, Flash, Opus, Sonnet) and Effort rows up to XHigh through the same plus button. XHigh is saved as High for a model that does not offer it, so `agy` never receives a model ID it does not list.

A live Codex chat offers its Effort rows up to High through the same plus button. A live Pi chat offers only Effort rows up to XHigh; its model still comes from the Pi model picker.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-model` on the branch, without a release tag. The workflow selects the chat-delivery driver and uploads `verify-chat-delivery`.

The saved tab, remote shell and tmux are fixture boundaries. The app supplies its embedded reader unchanged. The fixture starts that reader's production Python host in an isolated home and configures a synthetic Python Claude process. Windows-only fixture compatibility supplies file locks, notification polling and socket/pipe selection. The synthetic process records its actual arguments and emits a synthetic init and transcript. It makes no network or Claude calls.

The real Windows app opens the plus menu and clicks each Haiku, Low, Medium and High choice through native mouse input. Each choice must retain the unsent draft, update the independently read host config, restart the synthetic process with the chosen flags and produce the host's model_effort_settings_applied event. Copied rendered history remains present before and after. The active model/effort/permission rows use the active style without a check mark. Inspect the actual native clicks and selected-row screenshot; a config write alone is insufficient.

Inspect `model-before.png`, `model-plus-{haiku,low,medium,high}.png`, `model-plus-menu.png`, `model-plus-menu-active.png`, `model-settings/plus-active.json`, `model-after-{haiku,low,medium,high}.png`, `model-after.png`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and `model-settings/` config, argv, host log, copied history and observation files. A passing result needs screenshot inspection as well as the independent evidence checker.

## Gotchas

The fixture maps Unix sockets to isolated loopback sockets when Windows Python lacks Unix sockets. This does not verify a real SSH server, real Claude, a Haiku response, model quality or billing. No hosted run or screenshot inspection is implied by this map.

The `chat-model` journey drives a synthetic Claude chat only. The Antigravity, Codex and Pi rows come from the reader's own unit tests plus the Antigravity chats map; this journey does not click them.
