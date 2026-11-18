# PR verifier tools

Source files: tools/pr-verifier.cjs, .claude/skills/verify-multiprompt/features/pr-verifier-tools.md, .github/workflows/pr-verifier-tools.yml, tools/ci-receipt-summary.mjs
CI workflow: pr-verifier-tools.yml

## Sub-features

The PR verifier's own code must keep working at scale. Its recovery step reads a GitHub run list larger than Node's default 1 MB pipe limit and must not fail with ENOBUFS. The cancel, recovery and repro tests all run together.

## How to get to it (user POV)

Nobody opens this from the app. A change to `tools/pr-verifier.cjs` runs the verifier test files on GitHub, and the verifier reads the result.

## Driving it with GitHub CI

The `PR verifier tools` workflow runs every `tools/pr-verifier*.test.js` on GitHub's hosted Linux runner and uploads the `pr-verifier-tools` artifact. Its `summary.json` holds the exit code, the pass and fail counts and the named recovery tests, including the 2 MB runs payload test.

The PR selector owns `tools/pr-verifier.cjs` through `CI workflow:`, not a nearest desktop name. The verifier requires this workflow to pass on the exact PR head, downloads the identically named artifact and gives the independent judge its raw summary and run receipt. Missing, pending, failed or stale evidence cannot pass.

## Gotchas

This proves the verifier's own code, not any desktop journey. The test files themselves are skipped by source mapping, so a test-only change does not select this workflow.
