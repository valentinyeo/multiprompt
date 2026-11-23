---
name: verify-switch-ai-formal
description: Check Switch AI identity, locator, handover and restart behavior after changing host_switch_ai, host_switch_follow or host_dispatch_switch; read every TLA+ result with pstack /statechart.
---

# Verify Switch AI formally

Switching AI must keep one live chat on the same address, preserve name and picture, retain readable history, and leave the previous AI running when the new one fails to start.

## Run

From the repository root, with Python 3.12, Java 21 and the checksum-pinned TLA+ Tools jar used by chat-delivery-formal:

```sh
python3 .claude/skills/verify-switch-ai-formal/check.py --self-test --output /tmp/switch-ai-formal-new
```

Use a new output directory. `TLA2TOOLS` and `JAVA` may point at existing installations. The GitHub workflow runs the same command on Ubuntu.

Exit 0 classifies inherited findings on pull requests. Exit 1 reports current counterexamples. Exit 2 means drift, tool failure or failed replay. Read `summary.json`, `current/results.json`, `current/*.log` and `replay/host.json`.

Read **every result with pstack /statechart** using `current/Switch.tla`, the generated config and `view.mjs`. Provider names come from [providers.json](providers.json); add Antigravity there when SOFT-3050 lands without editing the checker.

`--model-only` skips native probes and mutation planting. It is for local model investigation, not a shipping claim.

## Why TLA+

Switch AI interleaves host disable, locator moves, handover history, message-store updates and agent start. TLA+ explores busy switches, restarts, round-trips and concurrent requests within a small bound without live tmux or paid providers. Python runs the real `host_switch_ai` decisions in native probes and replays each counterexample through isolated homes and SQLite stores.

## Bounds and assumptions

One logical chat address, at most two pending switch requests, five successful switches per run and one start failure. Busy refusal, locator deletion, old-config disable and success-shaped replies even when start fails are modeled as native decisions. Restart clears an in-flight switch but not completed identity. Message loss and duplicate rendering are out of scope for this bound. Antigravity is listed in `providers.json` but excluded from TLC constants until `HOST_SWITCH_TARGETS` includes it.

## Coverage and sync

Last confirmed source/model sync commit is `d676860794a9d0571334cec49e38d16d21923b29`. [coverage.json](coverage.json) records full-file hashes. Update hashes and move the sync commit forward only after confirming the verification still describes the code.

| Source | Covered behavior |
| --- | --- |
| `src/chat_history_reader.py`: `host_switch_ai`, `host_switch_handover`, `host_switch_rows`, `host_switch_follow`, `host_dispatch_switch` | Busy refusal, handover capture, locator and config moves, follow chain and dispatch eligibility |
| `tools/chat-switch-ai.test.js` | Isolated switch identity, round trip and history serving |

## Prove the checker can fail

`--self-test` first checks a reliable control with start failure and restart disabled. It then replaces the locator delete with a no-op in real source; `OneLiveChat` must fail while `SkipLocatorDelete` flips true in the native table. Both must replay through production `host_switch_ai`. Restoring the checkout must return to the starting findings, including `FailedSwitchKeepsOld`.

## Read current findings

See [findings.md](findings.md). Do not weaken invariants or edit product code in this verification pull request.
