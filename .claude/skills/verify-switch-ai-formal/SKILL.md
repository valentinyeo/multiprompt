---
name: verify-switch-ai-formal
description: Check Switch AI identity, locator, handover, restart, automatic plan-out fallback and the auto-switch toggle after changing host_switch_ai, host_switch_follow, host_switch_abort, host_dispatch_switch, host_usage_limit or host_auto_switch_*; read every TLA+ result with pstack /statechart.
---

# Verify Switch AI formally

Switching AI must keep one live chat on the same address, preserve name and picture, retain readable history, and leave the previous AI running when the new one fails to start. A chat whose plan runs out must move to the next AI in the saved order with the automatic switch divider, must never move while the automatic switch is off, and must stay put with a plain notice when no AI has a plan left.

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

Switch AI interleaves host start, locator moves, handover history, message-store updates, stopping the old agent, a provider reporting a used-up plan, the saved fallback order and the automatic switch toggle. TLA+ explores busy switches, failed starts, restarts, round-trips, plan-out moves and concurrent requests within a small bound without live tmux or paid providers. Python runs the real `host_switch_ai` and `host_auto_switch_*` decisions in native probes, replays each counterexample through isolated homes and SQLite stores, and requires the symptom the rule names to appear in that replay.

## Bounds and assumptions

One logical chat address, at most two pending switch requests, five successful switches per run, one start failure and three providers with a plan. Busy refusal, start failure, the old agent's stop, queued-message adoption, locator deletion, config identity carry, history carry, usage-limit detection, the saved fallback order and the toggle are modeled as native decisions. Agent processes may overlap for the moment between the new start and the old stop; `liveCount` counts chats on the address, so a missing old-agent stop shows up as two. Doubling is a second locator for the same address, because the reader resolves one locator per address. `identityOk` falls when a switch keeps two locators for the address or does not carry the picture and board login into the new config. `historyOk` falls when a commit opens the new chat without the earlier rows. Duplicate rendering is out of scope for this bound. Antigravity is listed in `providers.json` but excluded from TLC constants until `HOST_SWITCH_TARGETS` includes it.

`PlanRunsOut` is one atomic step: the recorded provider event, the usage-limit decision, the toggle state and the move or the plain stay all happen together, because the real reader reaches them in one turn end. A plan-out move reuses the switch commit decisions, so start failure inside an automatic move is the same `FailedSwitchKeepsOld` rule. `plansLeft` counts providers that still have a plan, so the model can exhaust the order. The model does not model the cooldown clock or the redelivery of the message that triggered the switch.

## Coverage and sync

Last reviewed source/model sync commit is `2bf6233d01f65f21f4afb3b3eb8e06dcf3cc7a66`. [coverage.json](coverage.json) records full-file hashes. Update hashes and move the sync commit forward only after confirming the verification still describes the code.

MUBO-136 adds a hosted clear control and pins its empty display history in the other-user stream. All twelve covered reader functions are unchanged from master, as are the other covered files, model, bounds, decisions, probes and mutations. Clear and provider restart are outside the switch model. Only the reader hash and sync commit move; GitHub Actions reruns the self-test and replay.

SOFT-2681 publishes Claude's current native session and changes transcript selection. All twelve covered reader functions are unchanged from the prior sync, as are every other covered file, the model, bounds, decisions, probes and mutations. Only the reader hash and sync commit move. Hosted CI must rerun the full self-test and native replay; this review does not extend the model to transcript rotation.

SOFT-3097 changes only the reader's command reconstruction: `clean_command_markup` drops the mention wire note from `<command-args>` before `command_reply`. The covered `host_switch_*`, `host_usage_limit` and `host_auto_switch_*` functions, the recorded provider events, the probes and the decision table are unchanged. Only the reader hash and the sync commit move.

SOFT-3145 publishes the bundled tools from one table, sets their mode before the atomic rename and removes leftover temporary files. The covered `host_switch_*`, `host_usage_limit` and `host_dispatch_switch` functions are unchanged, so only the reader's whole-file hash and the sync commit move.

MUBO-246 also gates that blocked settlement behind `blocked_settlement` in the history query so a phone build with a fixed settlement enum keeps its history read. The gate sits outside every switch function, so only the reader hash moves.

MUBO-246 handles a prompt a UserPromptSubmit hook blocked before the chat read it: a settlement fact from the transcript, a not-sent send in the host stream and a not-sent fact from the connector. The covered `host_switch_*`, `host_usage_limit`, `host_auto_switch_*` and `host_dispatch_switch` functions are unchanged, so only the reader's whole-file hash and the sync commit move.

MUBO-454 rewrites the mention wire note and drops `currentLive`'s exclude argument. That sits outside every covered switch function, whose behavior, probes, decisions and mutations are unchanged, so only the reader's whole-file hash and the sync commit move.

MUBO-286 adds the owner browser relay endpoint, the hosted-session registration and every documented runtime name for the browser CLI. All of it sits outside the covered switch functions, whose behavior, probes, decisions and mutations are unchanged, so only the reader's whole-file hash and the sync commit move.

MUBO-278 lets a non-hosted hax chat read its saved transcript. `resolve_response_path` returns the empty-history reply for hax only when a host config exists, so a runner tab falls through to `resolve_tmux_agent` and reads the transcript it already owns, while a hosted hax chat still answers from the host history only. hax is not a switch target and no covered switch, usage-limit or auto-switch function calls that resolver, so the model, bounds, decisions, probes and mutations are unchanged. Only the reader's whole-file hash and the sync commit move.

MUBO-293 rebuilds the typed slash command in the reader's command path and records a refused slash command's settlement. No covered switch, usage-limit, auto-switch or dispatch function calls that path, so the model, bounds, decisions, probes and mutations are unchanged. Only the reader's whole-file hash and the sync commit move.

MUBO-194 stores optional `workspace` and `group` strings in `chat_names_publish` for `~/.local/state/multiprompt/chat-names.json`. The covered `host_switch_*`, `host_usage_limit` and `host_dispatch_switch` functions are unchanged, so only the reader's whole-file hash moves; the sync commit names the merged master tip.

MUBO-194 merges master `b4f6f6a22`. The mention and offline-identity edits sit in different reader regions from `chat_names_publish`, so the merged reader carries all three and no covered switch, usage-limit or auto-switch function changes. The model, bounds, decisions, probes and mutations are unchanged; only the reader's whole-file hash and the sync commit move.

MUBO-293 merges master `5baddb613`. The optional `workspace` and `group` strings in `chat_names_publish` sit outside every covered switch function, and the MUBO-293 command rebuild and refused-command settlement sit outside them too. The model, bounds, decisions, probes and mutations are unchanged; only the reader's whole-file hash and the sync commit move.

MUBO-135 keeps one row per hax server reply in the reader's conversation and host-history paths. `host_switch_ai`, `host_switch_abort`, `host_switch_handover`, `host_switch_rows`, `host_switch_follow`, `host_dispatch_switch`, `host_usage_limit` and every `host_auto_switch_*` function are unchanged, and `host_switch_rows` still reads the same display-history rows; the model, bounds, decisions, probes and mutations are unchanged. Only the reader's whole-file hash and the sync commit move.

| Source | Covered behavior |
| --- | --- |
| `src/chat_history_reader.py`: `host_switch_ai`, `host_switch_abort`, `host_switch_handover`, `host_switch_rows`, `host_switch_follow`, `host_dispatch_switch` | Busy refusal, handover capture, start before the old stop, abort on a failed start, queued-message adoption, locator and config moves, follow chain and dispatch eligibility |
| `src/chat_history_reader.py`: `host_usage_limit`, `host_auto_switch_settings`, `host_auto_switch_target`, `host_auto_switch_set`, `host_auto_switch_trigger`, `host_auto_switch_run` | Per-provider usage-limit detection, saved order and cooldown, toggle default and toggle off, plan-out move, all-plans-empty stay notice and redelivery |
| `tools/chat-switch-ai.test.js` | Isolated switch identity, round trip, failed start and history serving |
| `tools/chat-auto-switch.test.js` | Recorded usage limit moving the chat with name, history and message, second fallback, toggle default and toggle off, per-provider predicate |
| `tools/fixtures/SOFT-2469/*` | The recorded Claude, Codex, Pi and Antigravity limit events the detection probe reads |

## Prove the checker can fail

`--self-test` first checks a reliable control. It then plants six breaks in real source and requires the named rule to fail in each:

- Doubling a chat, by replacing the locator delete with a no-op, must fail `OneLiveChat` and `IdentityStable` with two locators for one address.
- Losing the earlier conversation, by writing only the divider into the new chat's history, must fail `HistoryReadable`.
- Losing a queued message, by replacing the queued-message adoption with a no-op, must fail `NoLostOrDuplicate` with the message still queued on the old provider and sid.
- Ignoring the toggle, by forcing the saved setting on, must fail `ToggleOffKeepsChat` with a chat that moves after the switch was turned off.
- Ignoring the saved order, by walking the fallback list backwards, must fail `AutoSwitchFollowsOrder` with a chat that lands on an AI that is not the next one.
- Ignoring the usage limit, by dropping the event kind before the phrase check, must fail `PlanOutMovesChat` with a used-up plan and no move.

Every failing trace replays through production code, including sends that happen while a switch runs and the recorded provider events that trigger a plan-out move. The replay must show the symptom the rule names, so a trace that finishes without reproducing it is a red run. Each trace is then replayed against the unbroken source, which must not show the symptom. Restoring the checkout must return to the starting findings.

## Read current findings

See [findings.md](findings.md). Do not weaken invariants or edit product code in this verification pull request.
