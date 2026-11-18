# Chat echo budget

Source files: src/chat_echo.zig, .claude/skills/verify-multiprompt/features/chat-echo-budget.md, .github/workflows/chat-echo-budget.yml, tools/ci-receipt-summary.mjs
CI workflow: chat-echo-budget.yml

## Sub-features

Matching a pending sent message to its echo in a long history stays within 50 ms. Each of the largest cases runs five trials and is judged on its median, because the Windows thread CPU clock ticks in about 15.6 ms steps and one stray tick must not fail the budget.

## How to get to it (user POV)

A user sends a message in a long chat and sees the reply line up at once. The budget guards that wait.

## Driving it with GitHub CI

The `Chat echo budget` workflow builds `src/chat_perf_test.zig` with Zig 0.16.0 on GitHub's hosted Windows runner at ReleaseSmall, runs only the `IGSH-991` tests and uploads the `chat-echo-budget` artifact. Its `summary.json` holds the exit code and every `CPU961` trial line and the `CPU991 matching slowest_median_ms` line.

The PR selector owns `src/chat_echo.zig` through `CI workflow:`. The verifier requires this workflow to pass on the exact PR head, downloads the artifact and gives the independent judge its raw summary and run receipt. Missing, pending, failed or stale evidence cannot pass.

## Gotchas

A change that only edits test blocks in `src/chat_perf_test.zig` is filtered out of source mapping, so such a PR selects this workflow only by also touching this map, the workflow or `src/chat_echo.zig`. The budget stays 50 ms: a real slowdown makes every trial slow and still fails.
