# Mb tab open

Source files: tools/mb.mjs, tools/mp-layout.mjs, .claude/skills/verify-multiprompt/control-feature-mb-tab-verbs.ps1, .claude/skills/verify-multiprompt/features/mb-tab-open.md, src/session.zig, src/sidebar.zig

## Sub-features

- Mocked account login, two workspaces, and one proof shell tab published without local tmux.
- `mb open` runs on the Windows runner with admin layout credentials.
- The tab appears in `session.json` with the expected workspace index and tmux session name.
- Before and after desktop screenshots, session snapshots and `result.json` in the journey artifact.

## How to get to it (user POV)

- Publish a shell tab into workspace Multiprompt with `mb open`.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=mb-tab-open`.

The driver builds the local account worker when needed, serves it on the account hostname with a private certificate, enrolls one device, creates workspaces Multiprompt and Other, launches the branch executable, runs `node tools/mb.mjs` for the verb, and asserts sidebar state from `session.json`. It records `before.png`, `after.png`, session snapshots and `result.json`. Evidence stays in artifact `verify-mb-tab-open` including `journey.mp4`. Pin, archive, wait, and restore require SOFT-3141 `mb` commands on the branch under test.

## Gotchas

- Dispatch this journey. It is not in the automatic pull-request matrix unless `tools/mb.mjs` or a listed layout-sync source changes.
- Requires SOFT-3141 tab verbs in `tools/mb.mjs` for pin, archive, wait, and restore journeys.
