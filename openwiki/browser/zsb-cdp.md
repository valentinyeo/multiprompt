# CDP commands and held-session scripts

`zsb cdp <method> [params-json]` sends one Chrome DevTools Protocol command; params must be a JSON object. Each call attaches and detaches the debugger, so enabled domains and new-document scripts do not survive between calls.

Use a script for stateful sequences:

```sh
zsb cdp --script profile.json
zsb cdp --script profile.json --out results.json
cat profile.json | zsb cdp --script - --out results.json
```

For example, `profile.json` can contain:

```json
[
  {"method":"Profiler.enable","params":{}},
  {"method":"Profiler.start"},
  {"method":"Page.addScriptToEvaluateOnNewDocument","params":{"source":"globalThis.profileMarker = true"}},
  {"method":"Page.reload","waitEvent":"Page.loadEventFired","timeoutMs":15000},
  {"waitMs":500},
  {"method":"Profiler.stop"}
]
```

All steps run in order in **one attached debugger session**, detached on success or failure. A concurrent CDP command for the same tab fails immediately with a busy error. Use `zsb reset` to cancel stuck work; a cancelled script cannot issue later steps. A script uses the same exact-session/window binding and `target:true` tab as a single CDP call, not an arbitrary active browser tab. Use `zsb tabs` and `zsb activate <id> --target-only` to choose a different target within the bound pane. Scripts do not broaden the command allow-list or targeting permissions.

## Steps and results

- `method` is a nonempty CDP method name; optional `params` is an object (default `{}`). The result entry is `{"method":"Profiler.stop","result":{"profile":{...}}}`: the complete CDP result is retained, including large profiles.
- `waitEvent` waits for the named event on the same tab's top-level debugger session. With `method`, the listener is installed before sending the command, so immediate events are not lost. The result entry also includes `event` containing the event parameters. Without a method, the entry is `{"waitEvent":"Page.loadEventFired","event":{...}}`. Page events automatically enable the Page domain first; enable other domains explicitly before waiting for their events.
- `timeoutMs` bounds the whole command/event step (default 15000 ms, range 1–300000 ms).
- `waitMs` is a standalone delay (integer, range 0–300000 ms); its result is `{"waitMs":500}`. It cannot be combined with other fields.

A script must be an array of 1–1000 steps. Unknown fields and invalid steps are rejected before attachment. The sum of command/event timeout budgets and delays cannot exceed 300000 ms. Split larger investigations into separate scripts, remembering that debugger state does not persist across scripts.

Native scripts have a 320-second request deadline and a 360-second CLI watchdog, rather than the ordinary command's 20-second request and 60-second watchdog. The app's script subprocess limit is 330 seconds. The remote wrapper gives scripts a 360-second total reply deadline (single CDP commands default to 30 seconds). `ZSB_TIMEOUT` overrides that deadline using finite seconds greater than zero, at most 86400. Incoming reply bytes do not reset the deadline.

On success stdout is a JSON array with one entry per step, or `--out FILE` writes that array without printing it. For the example above, the profile is at `[5].result.profile`; extract it if a profiling viewer expects the profile object itself. On failure execution stops, the command exits nonzero, and stdout contains `{"ok":false,"failedStep":2,"error":"...","results":[...]}` with a **1-based** failed step and completed results. Existing output files are not overwritten on a step failure. Scripts are not automatically replayed after a lost reply or a step failure.

Input and output paths belong to the machine running the CLI. The remote wrapper reads the file/stdin locally and sends its JSON contents through the existing tunnel; it writes `--out` locally too. Native script files are limited to 1 MiB; remote scripts also fit the existing 64 KiB encoded request and Windows command-line limits. Responses retain the existing 16 MiB bridge limit; `--out` avoids terminal output, not transport limits. Run `zsb cdp --help` for a short reference. No keyboard shortcut or palette action is added for this CLI-only option.
