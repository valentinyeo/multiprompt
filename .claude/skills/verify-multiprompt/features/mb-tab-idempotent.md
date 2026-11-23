# Mb tab idempotent

Source files: tools/mb.mjs, tools/mp-layout.mjs, .claude/skills/verify-multiprompt/control-feature-mb-tab-verbs.ps1, .claude/skills/verify-multiprompt/features/mb-tab-idempotent.md, src/session.zig, src/sidebar.zig

## Sub-features

- Mocked account login, two workspaces, and one proof shell tab published without local tmux.
- `mb star` runs on the Windows runner with admin layout credentials.
- The second command reports an already-on state and `favorite` stays true once.
- Before and after desktop screenshots, session snapshots and `result.json` in the journey artifact.

## How to get to it (user POV)

- Star the proof tab twice through `mb star on`.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=mb-tab-idempotent`.

The driver builds the local account worker when needed, serves it on the account hostname with a private certificate, enrolls one device, creates workspaces Multiprompt and Other, launches the branch executable, runs `node tools/mb.mjs` for the verb, and asserts sidebar state from `session.json`. It records `before.png`, `after.png`, session snapshots and `result.json`. Evidence stays in artifact `verify-mb-tab-idempotent` including `journey.mp4`. Pin, archive, wait, and restore require SOFT-3141 `mb` commands on the branch under test.

## Gotchas

- Dispatch this journey. It is not in the automatic pull-request matrix unless `tools/mb.mjs` or a listed layout-sync source changes.
- Requires SOFT-3141 tab verbs in `tools/mb.mjs` for pin, archive, wait, and restore journeys.
