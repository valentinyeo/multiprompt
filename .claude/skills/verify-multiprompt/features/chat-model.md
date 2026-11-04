# Live chat model and effort

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-model` on the branch, without a release tag. The workflow selects the chat-delivery driver and uploads `verify-chat-delivery`.

The saved tab, remote shell and tmux are fixture boundaries. The app supplies its embedded reader unchanged. The fixture starts that reader's production Python host in an isolated home and configures a synthetic Python Claude process. Windows-only fixture compatibility supplies file locks, notification polling and socket/pipe selection. The synthetic process records its actual arguments and emits a synthetic init and transcript. It makes no network or Claude calls.

The real Windows app receives Ctrl+K searches and Enter for Model Haiku and Effort Low, Medium and High. Each choice must retain the unsent draft, update the separately read host config, restart the synthetic process with the chosen flags, and produce the production host's `model_effort_settings_applied` event. The copied rendered history must remain present before and after. Screenshots show the owned app before, every palette selection and every applied state. Doctor checks executable identity and input ownership; cleanup must leave zero owned processes and remove both isolated directories.

Inspect `model-before.png`, `model-palette-{haiku,low,medium,high}.png`, `model-after-{haiku,low,medium,high}.png`, `model-after.png`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and `model-settings/` config, argv, host log, copied history and observation files. A passing result needs screenshot inspection as well as the independent evidence checker.

This does not verify a real SSH server, real Claude, a Haiku response, model quality or billing. No hosted run or screenshot inspection is implied by this map.
