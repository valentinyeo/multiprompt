# Test CLI checks

Source files: tools/mbv.mjs, tools/fixtures/SOFT-2755/*, .github/workflows/verify-cli.yml
CI workflow: verify-cli.yml

## Sub-features

The desktop test CLI (`tools/mbv.mjs`) reads and drives desktop verification; it never launches the app itself. Its own node tests cover listing features, running and watching a journey, reading `result.json`, refusing missing evidence and printing decisive failures. The changed-file selector is the second half: a pull request that touches `tools/mbv.mjs` or `tools/fixtures/SOFT-2755/*` must select this workflow and no desktop journey.

Before this map, those files matched no feature, so the selector fell back to the nearest map name and picked `session-actions`. PR 1120 therefore had the verifier run a Windows desktop journey for a tool change. The map gives the CLI its own owner and its own receipt.

## How to get to it (user POV)

Nobody opens this from the app. A change to the files above runs the `Verify CLI tests` workflow on GitHub, and the verifier reads its result instead of driving the desktop app.

## Driving it with GitHub CI

One Linux job runs `tools/mbv.test.mjs` and `tools/touched-journeys.test.js` on the pull request head. It then checks out the base source into a worktree, copies the head test files into it and runs the same two files, so `summary.json` records both exit codes. On the base the new selector case has no map to find, falls back to a nearest desktop feature and fails with an assertion error; on head it passes.

One artifact named `verify-cli` holds `summary.json` and both TAP logs. The PR selector owns these files through `CI workflow:`, not a nearest desktop name. The verifier waits for this workflow to finish on the exact PR head, requires a successful conclusion, downloads the artifact and gives the independent judge its raw summary and run receipt.

## Gotchas

The base comparison proves the selector case only. A change to `tools/mbv.mjs` that leaves `tools/touched-journeys.test.js` alone shows base green, so such a PR needs its own repro or a new selector assertion. These tests never launch the app, so a green receipt says the CLI and its file ownership work and says nothing about desktop journeys.
