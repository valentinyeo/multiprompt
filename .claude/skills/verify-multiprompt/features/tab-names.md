# Tab names

Tabs whose saved names were not typed by hand (agent or folder names) keep their names and their order across restarts. A restart never renames them to the folder the shell starts in.

## Sub-features

- `names-launch`: the seeded names stay put for 45 seconds after the first launch.
- `names-restart-1`: after a normal close and relaunch, every tab keeps its name and its place.
- `names-restart-2`: after a killed process and relaunch, the same names and order return.
- `names-restart-3`: after a second normal close and relaunch, the same names and order return.

## How to get to it (user POV)

- Open Multiprompt after an update. The sidebar shows the same tab names in the same order as before.
- Ctrl+K, `Tab Order: Manual` keeps the order; Ctrl+Shift+Up moves the active tab up.
- Close the app window normally, or end its process, then open Multiprompt again.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=tab-names`. Use `-f tag=v0.28.893` for the red control.

Seeding boundary: unlike the other baseline journeys, the harness writes `session.json` once, before the first launch, and copies it to `seed-session.json`. It holds three CMD tabs named `Mini Boss CEO`, `HT Product Lead` and `inne Chief of Staff`, with no manual or semantic flag, all with their working folder set to a folder named `GitHub`. This is the state Valentin's tabs were in, and it cannot be reached through the keyboard on the GitHub runner: console titles there carry an `Administrator:` prefix, and the app turns every such name into a manual one within two name polls. Nothing else is seeded and the app is never edited through a setter.

1. Seed, launch the real executable with `--single-window` and restoration enabled, and keep the private data directory for every launch in the job.
2. Sample the saved session and published Inbox every 250 ms for 45 seconds, longer than the 30 second name poll. Any difference from the seeded names fails at once and keeps `<stage>-drift.json` and a screenshot.
3. Choose `Tab Order: Manual`, select the last tab by name and press Ctrl+Shift+Up. Require the saved order `Mini Boss CEO`, `inne Chief of Staff`, `HT Product Lead`.
4. Restart three times: WM_CLOSE, process kill, WM_CLOSE. Before each close the saved names must still be the seeded names in that order and none may be manual. After each relaunch sample for 45 seconds as above.
5. Retain `<stage>-after.inbox.json`, `<stage>-after.session.json` and `<stage>-after.png` for each stage. `result.json` must name feature `tab-names`, state the seeding boundary and contain `names-launch`, `names-restart-1`, `names-restart-2`, `names-restart-3` and `tab-names-order-survive-restarts`.

## Gotchas

- Master failure on v0.28.893: the restored tab has no hold on its name, so the first name poll renames it to `GitHub`. The journey must fail at the sampling step with a `Tab names or order changed` error, not during setup, and the first failing stage is `names-launch`.
- The sampling window outlasts the 30 second poll timer on purpose; checking right after launch would pass before the first poll runs.
- This journey does not cover real agent titles, remote or tmux tabs, the Starred view or the keyboard path that produces an automatic name.
