# Palette order

Verify on: push

Open an empty Ctrl+K with a known usage history and check the Most used band, the job groups, a removed command and renamed commands.

## Sub-features

- `most-used-band`: the ten commands with the highest use counts appear first under a Most used header, highest count first, and the selection lands on the first of them.
- `job-groups`: every other row sits under one group header, and no header repeats.
- `rare-recent-stays-out`: a command used twice but stamped as very recent stays out of Most used, so recency alone cannot jump the list.
- `removed-command`: `chat view per tab` finds no rows.
- `renamed-commands`: new names such as `copy session diagnostics`, `rename workspace`, `mobile latency mode`, `restore disconnected workspace sessions`, `auto-suspend idle panes`, `use agent or terminal session name` and `insert agent instructions` find their commands, and the old name `copy shell diagnostics` still works.

## How to get to it (user POV)

- Press Ctrl+K with an empty search. Recent sessions come first without a header, then Most used, then the groups Sessions, Workspaces and windows, Sidebar and tabs, Look and settings, Debug and repair, Browser, Account and usage, and Chat View.
- Up and Down skip headers; clicking a header does nothing.
- Typing a query keeps the ranked search list without headers.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes with the single initial CMD tab, so no recent session rows lead the list.
- Before launch the harness copies `tools/fixtures/IGSH-1743/palette-usage.tsv` to `%APPDATA%\ZigShell\palette-usage.tsv`. This revises the IGSH-612 fixture to use current empty-palette commands while retaining its counts and timestamps. Each line is a command id, a use count and a last-used Windows file time.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=palette-order`; Windows runs `control.ps1 -Feature palette-order`. Add `-f tag=<release>` to run the same journey against a release.
- **Open.** Press Ctrl+K and wait for `[palette] ready chars=0`. Capture `action.png`.
- **Order.** The selected target must be the highest count in the fixture. The last `[palette] rows chars=0` line must start with `h0`, list the ten highest counts in order (ties by newer use), then a group header. The fixture's lowest count, stamped in 2030, must not be in that band. `palette-order-rows.json` keeps the ids.
- **Removed and renamed.** Reopen Ctrl+K for each query. `chat view per tab` must log `ready chars=17 count=0 target=0` (`removed-absent.png`). Every other query must log a `rows` line for its full length that contains the expected id (`renamed.png` for `copy session diagnostics`).
- **Session ranking.** After the empty-query checks, close the owned app. Seed one saved local CMD session and one closed workspace, both named `Funeralprints`, in the isolated profile, then relaunch with restoration. Press Ctrl+K and type `fune`. Require focus before typing, at least two logged rows, session 0 selected and first, and the closed workspace present and last. Save `palette-ranking-rows.json` and `typed-session-workspace.png`.
- **Proof.** `result.json` records both checks. Compare `before.png`, `action.png`, `after.png` and `typed-session-workspace.png` with the row logs.

## Gotchas

- The seeded file is usage history, not a setting; the app reads it on every palette open. It holds only numeric ids for commands shown on an empty search, with distinct counts, and no destructive commands.
- Releases before this change ranked by recency first, so the 2030 entry was selected first. A tag run must fail with `palette-order: selected row ...`.
- Row ids come from `[palette] rows` debug lines; headers appear as `h<index>`, where `h0` is Most used.
- The ranking case seeds `session.json` and `windows.json` once between owned launches. It does not use a test-only setter or verify remote sessions. The initial empty-query checks still use the original unseeded session.
- This journey does not run the commands it finds or cover tab context menus.
