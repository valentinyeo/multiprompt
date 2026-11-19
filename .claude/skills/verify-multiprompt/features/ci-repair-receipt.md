# CI repair receipt

Source files: tools/pr-verifier.cjs, tools/ci-receipt-summary.mjs, tools/strip-comments.mjs, .github/workflows/no-comments.yml, src/chat_echo.zig, src/chat_perf_test.zig, .claude/skills/verify-multiprompt/features/README.md, .github/workflows/ci-repair-receipt.yml
CI workflow: ci-repair-receipt.yml

## Sub-features

Repairs to CI itself have no desktop journey. This map gives them a receipt. The PR verifier's recovery step must read a GitHub run list larger than Node's 1 MB pipe limit without failing with ENOBUFS. The no-comments check on a pull request fails only on comments that change adds or edits, so master's existing comments do not block every PR; the nightly run still checks the whole repository. The echo-assign budget (50 ms) is judged on the median of five trials per case, because the Windows thread CPU clock ticks in about 15.6 ms steps.

## How to get to it (user POV)

Nobody opens this from the app. A change to the files above runs the `CI repair receipt` workflow on GitHub, and the verifier reads its result.

## Driving it with GitHub CI

The `CI repair receipt` workflow has two jobs. The Linux job runs `tools/pr-verifier-cancel.test.js` and `tools/strip-comments.test.js` on the PR head. It then runs the same test file against the base source and records both exit codes, so `summary.json` shows the 2 MB runs payload test and the added-comments-only test failing on base and passing on head. The Windows job builds `src/chat_perf_test.zig` with Zig 0.16.0 at ReleaseSmall, runs only the `IGSH-991` tests and adds every `CPU961` trial line and the `CPU991` median line. One artifact named `ci-repair-receipt` holds both parts.

The PR selector owns these files through `CI workflow:`, not a nearest desktop name. The verifier requires this workflow to pass on the exact PR head, downloads the artifact and gives the independent judge its raw summary and run receipt. When every file in a fix PR is owned by such a workflow and its summary shows the repro test red on base and green on head, that receipt is the repro. Missing, pending, failed or stale evidence cannot pass.

## Gotchas

The CPU991 part is a timing flake, so base cannot be made to fail on demand. Its receipt shows the head median and every trial, not a base failure. A product fix, or a fix PR with any file outside a workflow map, still needs a `Repro journey:` line. A PR that changes `tools/pr-verifier.cjs` without changing `tools/pr-verifier-cancel.test.js` shows base green, so it needs its own repro.
