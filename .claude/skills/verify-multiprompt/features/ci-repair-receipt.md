# CI repair receipt

Source files: src/vps.zig, src/win32.zig, tools/ci-receipt-summary.mjs, tools/strip-comments.mjs, .claude/skills/verify-multiprompt/features/README.md, .github/workflows/ci-repair-receipt.yml, .github/workflows/auto-release.yml, tools/reusable-workflow-permissions.test.js, tools/ssh-idle-reuse.test.js
CI workflow: ci-repair-receipt.yml

## Sub-features

Repairs to CI itself have no desktop journey. This map documents the path-filtered receipt workflow. The PR verifier recovery step must read a GitHub run list larger than Node's 1 MB pipe limit without failing with ENOBUFS.

## How to get to it (user POV)

Nobody opens this from the app. A change to the files above runs the `CI repair receipt` workflow on GitHub as its own check. The verifier does not wait for that workflow or download its artifact.

## Driving it with GitHub CI

The `CI repair receipt` workflow runs `tools/pr-verifier-cancel.test.js`, `tools/pr-verifier-download-retry.test.js`, `tools/strip-comments.test.js`, `tools/reusable-workflow-permissions.test.js` and `tools/ssh-idle-reuse.test.js` on the PR head. It then runs the same five files against the base source and records both exit codes, so `summary.json` shows the 2 MB runs payload test, the retried artifact download test, the added-comments-only test, the single head journey set, the reusable-workflow permission test and the idle SSH reuse wiring failing on base and passing on head. The single-journey-set test reads `.github/workflows/pr-verifier.yml`, so it is red on a base that still runs a base build and green on head. `ssh-idle-reuse.test.js` reads the probe, usage-read, handshake-wait and reader-retry sources, so it is red on a base that still starts one `ssh.exe` per idle health probe and green once they ride the shared connection. One artifact named `ci-repair-receipt` holds the receipt.

## Gotchas

A PR that changes `tools/pr-verifier.cjs` without changing `tools/pr-verifier-cancel.test.js` shows base green, so it needs its own red-on-base test in that list. The single-journey-set test is the only part of this receipt that fails on base for a `.github/workflows/pr-verifier.yml` change. `ssh-idle-reuse.test.js` checks source wiring only; the runtime login count comes from the dispatch-only `Verify idle SSH reuse` workflow.