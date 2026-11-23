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

Exit 0 classifies inherited findings on pull requests. Exit 1 reports current counterexamples. Exit 2 means drift, tool failure or failed replay: a counterexample that finishes without reproducing its symptom counts as a failed replay. Read `summary.json`, `current/results.json`, `current/*.log` and `replay/host.json`.

Read **every result with pstack /statechart** using `current/Switch.tla`, the generated config and `view.mjs`. Provider names come from [providers.json](providers.json); add Antigravity there when SOFT-3050 lands without editing the checker.

`--model-only` skips native probes and mutation planting. It is for local model investigation, not a shipping claim.

## Why TLA+

Switch AI interleaves host start, locator moves, handover history, message-store updates and stopping the old agent. TLA+ explores busy switches, failed starts, restarts, round-trips and concurrent requests within a small bound without live tmux or paid providers. Python runs the real `host_switch_ai` decisions in native probes and replays each counterexample through isolated homes and SQLite stores, then requires the symptom the rule names to appear in that replay.

## Bounds and assumptions

One logical chat address, at most two pending switch requests, five successful switches per run and one start failure. Busy refusal, start failure, the old agent's stop, queued-message adoption, locator deletion, config identity carry and history carry are modeled as native decisions. Agent processes may overlap for the moment between the new start and the old stop; `liveCount` counts chats on the address, so a missing old-agent stop shows up as two. Doubling is a second locator for the same address, because the reader resolves one locator per address. `identityOk` falls when a switch keeps two locators for the address or does not carry the picture and board login into the new config. `historyOk` falls when a commit opens the new chat without the earlier rows. Duplicate rendering is out of scope for this bound. Antigravity is listed in `providers.json` but excluded from TLC constants until `HOST_SWITCH_TARGETS` includes it.

## Coverage and sync

Last confirmed source/model sync commit is `9e4d749e01aea7405ed2bde50182ce4507e1fafd`. [coverage.json](coverage.json) records full-file hashes. Update hashes and move the sync commit forward only after confirming the verification still describes the code. SOFT-3098 changed only archive row identity in `host_history_append`, `host_event`, `host_assistant_event` and the two event-log rebuild readers that `host_switch_rows` and the handover use, so the carried rows and every switch decision are unchanged.

| Source | Covered behavior |
| --- | --- |
| `src/chat_history_reader.py`: `host_switch_ai`, `host_switch_abort`, `host_switch_handover`, `host_switch_rows`, `host_switch_follow`, `host_dispatch_switch` | Busy refusal, handover capture, start before the old stop, abort on a failed start, queued-message adoption, locator and config moves, follow chain and dispatch eligibility |
| `tools/chat-switch-ai.test.js` | Isolated switch identity, round trip, failed start and history serving |

## Prove the checker can fail

`--self-test` first checks a reliable control. It then plants three breaks in real source and requires the named rule to fail in each:

- Doubling a chat, by replacing the locator delete with a no-op, must fail `OneLiveChat` and `IdentityStable` with two locators for one address.
- Losing the earlier conversation, by writing only the divider into the new chat's history, must fail `HistoryReadable`.
- Losing a queued message, by replacing the queued-message adoption with a no-op, must fail `NoLostOrDuplicate` with the message still queued on the old provider and sid.

Every failing trace replays through production `host_switch_ai`, including sends that happen while a switch runs. The replay must show the symptom the rule names, so a trace that finishes without reproducing it is a red run. Each trace is then replayed against the unbroken source, which must not show the symptom. Restoring the checkout must return to the starting findings.

## Read current findings

See [findings.md](findings.md). Do not weaken invariants or edit product code in this verification pull request.
