# Live chat model and effort

## Sub-features

- Start a Claude process with explicit Opus and medium flags despite saved Fable settings and model aliases.
- Show the last assistant model and effort on a second line below the chat name, with amber Fable and grey Opus text.
- Hover that line for a hand cursor and click it to open the model and effort picker.
- Select a Claude model and effort, retaining history and the unsent draft.
- Show Opus and Medium as the unchosen defaults, and the selected model, effort and permission rows in the active style with no check mark.

## How to get to it (user POV)

Open a live Claude chat. Click the model under its name, or click the plus button left of the message box, then choose a model or effort. Ctrl+K with `plus attach file` opens the same picker.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-model` on the branch, without a release tag. The workflow delegates to the chat-delivery driver while retaining the selected journey identity and uploads `verify-chat-model`. The PR verifier downloads that artifact for its head evidence.

The saved tab, remote shell and tmux are fixture boundaries. The app supplies its embedded reader unchanged. The fixture starts that reader's production Python host in an isolated home and configures a synthetic Python Claude process. Windows-only fixture compatibility supplies file locks, notification polling and socket/pipe selection. A fixture thread runs production message polling and dispatch because Windows has no Unix FIFO wake pipe. The synthetic process records its actual arguments and emits a synthetic init and transcript. It makes no network or Claude calls.

Before launch, the isolated provider settings save Fable and all model aliases point to Fable. The synthetic process records the production host's actual argv, saved default and inherited aliases. `config-initial.json` and `argv-initial.jsonl` prove no model or effort was chosen and the process received Opus and medium with no aliases. A seeded old Fable reply proves the amber header line comes from the last assistant, not the new launch settings. The journey measures its visible pixels, its position below the name and the native hand cursor, then clicks the line with real mouse input and requires the owned plus picker. A composer send produces an Opus transcript reply, after which the same header checks require grey `Opus 5.5 · medium`. The opened picker must highlight Opus and Medium without Fable highlighting.

The real Windows app then opens the plus menu from Ctrl+K and clicks Haiku, Low, Medium and High with real mouse input. Each choice must retain the unsent draft, update the separately read host config, restart the synthetic process with the chosen flags, and produce the production host's `model_effort_settings_applied` event. The copied rendered history must remain present before and after. After the last choice the journey opens the plus menu once more, reads the row positions from the app's debug log, and samples the screen pixels of every row. The Haiku, High and Ask rows must be drawn in the accent colour and no row may carry a check mark. Screenshots show the owned app before, every palette selection and every applied state. Doctor checks executable identity and input ownership; cleanup must leave zero owned processes and remove both isolated directories.

Inspect `model-header-{fable,opus}.png`, `model-header-{fable,opus}-picker.png`, `model-default-menu.png`, `model-settings/header-{fable,opus}.json`, `model-settings/plus-default.json`, `model-before.png`, `model-plus-{haiku,low,medium,high}.png`, `model-plus-menu-active.png`, `model-settings/plus-active.json`, `model-after-{haiku,low,medium,high}.png`, `model-after.png`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and `model-settings/` config, argv, host log, copied history and observation files. A passing result needs screenshot inspection as well as the independent evidence checker.

## Gotchas

The fixture maps Unix sockets to isolated loopback sockets when Windows Python lacks Unix sockets. This does not verify a real SSH server, real Claude, a Haiku response, model quality or billing. No hosted run or screenshot inspection is implied by this map.
