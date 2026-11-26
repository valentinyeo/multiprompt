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

Last reviewed source/model sync commit is `793597b04`. [coverage.json](coverage.json) records full-file hashes. Update hashes and move the sync commit forward only after confirming the verification still describes the code.

MUBO-221 adds `HOST_HISTORY_OWNERS` and `host_history_claim`, called once from `host_loop`, so a fresh Antigravity host owns its canonical history file and replays committed rows from the shared message events when the file is missing. None of the twelve covered switch, history, usage-limit or auto-switch functions changed, and the claim neither starts a switch nor edits the decision table. The reader's whole-file hash and the sync commit move; the model, bounds, decisions, probes and mutations are unchanged. Hosted CI must rerun the full self-test and native replay; Antigravity remains outside the formal provider set.

MUBO-582 adds an Antigravity model and effort choice to `host_settings` and the Antigravity launch argv. None of the twelve covered switch, history, usage-limit or auto-switch functions changed, and a model choice neither switches providers nor edits the decision table. Only the reader's whole-file hash moves; the model, bounds, decisions, probes and mutations are unchanged. Hosted CI must rerun the full self-test and native replay.

MUBO-243 adds a name-resolution path for published chat names and publishes a new Claude conversation to the account layout and the name entry on init. All twelve covered reader functions are unchanged from the prior sync, as is every other covered file, the model, bounds, decisions, probes and mutations. Only the reader hash and sync commit move. Hosted CI must rerun the full self-test and native replay; this review does not extend the model to conversation changes.

That review covers the merge commit: trunk's optional `workspace` and `group` strings sit on the same publish path as the name resolution, so the merged reader is the reviewed source.

MUBO-221 merges master `f4086e71c` (MUBO-558, MUBO-17) at `d0c4798475d8629de8c19e12b06946612b811978`. All twelve covered switch functions, including the busy refusal before the flock in `host_switch_ai` and the recheck inside `host_switch_ai_locked`, are byte-identical to `c56c8bb4d`; MUBO-558 only reorders helper publishing in the reader's bootstrap and MUBO-17 changes streaming log code outside the covered files. The reader's whole-file hash and the sync commit move; the model, bounds, decision table, probes and mutation controls do not. Require fresh hosted self-tests.

MUBO-221 merges master `f6d470f180f746e83f3e4171de2913f9d7dfc015` (MUBO-525, SOFT-3163) at `f8cbf6dff039f687f1c4145540e0162627c30e72`. All twelve covered switch functions keep the bodies they had at `1be48b7fa`, including the busy refusal before the flock in `host_switch_ai` and the check inside `host_switch_ai_locked`. Master's read-only live snapshot, its retention-sweep probe and its store-only wake filter sit outside every covered function, and nothing master added starts a switch or dispatches a message behind the flock. SOFT-3163 adds a sidebar draft-marker invalidation that touches neither. The busy-refusal paragraph below still describes the code at this head. Only the reader's whole-file hash and the sync commit move; model, bounds, probes, decisions and mutation controls stay the same. Require fresh hosted self-tests.

MUBO-221 refuses a busy switch before taking the per-chat `.dispatch` flock at `19e65cb339ea68a7e172e52e48041a0bde604099`. `host_switch_ai` now asks `host_turn_busy` before the flock and again inside `host_switch_ai_locked`, so a chat that is replying is refused promptly instead of waiting behind the dispatch that is holding the flock, while a switch that does queue behind a dispatch still refuses after it. No switch decision, bound, replay or planted mutation changes; the reader hash moves. Require fresh hosted self-tests.

MUBO-221 merges master `2d3eeee17b4fe6dd433b110577c42df91b96be9c` (MUBO-528) and serializes `host_switch_ai` with `message_dispatch` via `message_dispatch_lock_path` at `7c73d53491a5bbdedc4c1145c0e4acfcbfe0b999`, moving the switch body into `host_switch_ai_locked` while preserving busy refusal, failed-start abort, locator replacement, queued-message migration and all six planted mutation targets; `tools/chat-switch-ai.test.js` adds hosted race regressions for an incoming send after idle during handoff and busy refusal behind an active dispatch. The reader and switch-test hashes move; the model, bounds, decision table, replays and mutations are unchanged and Antigravity remains excluded from the formal provider set. Require fresh hosted self-tests.

MUBO-221 integrates fresh-start master `8474aabb7a55a11595ab33e008c32c00624ce1b5` at `257df205bcc2804ea897b65a0259163eebe52afc`. The covered reader functions are unchanged from the previous reviewed branch head. The incoming `message_expire` and `message_worker` changes retain sends while a fresh-start phase is pending; that phase is outside the fixed-session model. Both fresh-start and Antigravity desktop journeys remain selected independently. The reader and reader-test hashes move, with no model, bound, decision probe, replay or mutation-control changes. Require fresh hosted self-tests and current-base desktop proof.

MUBO-221 merges master `91d6d9e9cb27aa29ecc58a2e8473013e0de18cc0` at `8e6e1237fb84ed858122b8c1e457349810a1a681`. All twelve covered reader functions match that master. The Antigravity adapter and provider registry sit outside those functions. The merged switch tests retain the Antigravity round trip and every master case. Whole-file hashes move; the model, bounds, decision probes, replays and mutation controls do not change. The existing formal model excludes Antigravity from its provider set, so its result is not Antigravity-provider proof. Fresh hosted desktop and real-provider continuity proof remain required.

MUBO-221 reviews `1a59f4ad97899f924ca18a24a5568caf5519d134`. The reader's only change since the preceding PR head selects Neon 4 in `host_antigravity_argv`; none of the covered switch, history, usage-limit, or auto-switch functions changed. The reader hash and sync commit move, while the model, bounds, decisions, probes, and mutation controls stay unchanged. Hosted self-tests must rerun; model selection and rendered-history continuity remain separate desktop proof.

MUBO-558 reviewed merged source at `f6d470f18`, which carries MUBO-525's read-only event push. It records the app version that published each runtime helper in `tools.json` and refuses to move a helper back to an older version. The publish step runs in the reader's bootstrap before any request, outside every covered switch, usage-limit and auto-switch function. The model, bounds, decisions, probes and mutations are unchanged; only the reader's whole-file hash and the sync commit move.

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

MUBO-452 holds a queued message through a pending fresh start in `message_expire` and `message_worker`. `host_fresh_phase_wait` and `host_fresh_pending` read the host session state and are new; no covered `host_switch_*`, `host_usage_limit`, `host_auto_switch_*` or `host_dispatch_switch` function calls them, so the model, bounds, decisions, probes and mutations are unchanged. Merging master `9db3f9b5a` carries MUBO-293's command rebuild and MUBO-135's once-only server reply row in the reader; both sit outside every covered switch function, so only the reader's whole-file hash and the sync commit move.

MUBO-135 keeps one row per hax server reply in the reader's conversation and host-history paths. `host_switch_ai`, `host_switch_abort`, `host_switch_handover`, `host_switch_rows`, `host_switch_follow`, `host_dispatch_switch`, `host_usage_limit` and every `host_auto_switch_*` function are unchanged, and `host_switch_rows` still reads the same display-history rows; the model, bounds, decisions, probes and mutations are unchanged. Only the reader's whole-file hash and the sync commit move.

MUBO-528 makes `start_message_worker` ask the store whether a message is due before it forks, and hands its locked descriptor to the child so a poll during the child's startup reaches that lock. The covered `host_switch_*`, `host_usage_limit`, `host_auto_switch_*` and `host_dispatch_switch` functions are unchanged, so only the reader's whole-file hash and the sync commit move.

MUBO-525 changes only the reader's event push: a synced live snapshot now reads the store read-only, the minute retention sweep probes read-only before it writes, the folder watch drops `IN_CLOSE_WRITE`, and the push loop wakes only for `store.sqlite3` or its `-wal`. The twelve covered `host_switch_*`, `host_usage_limit` and `host_auto_switch_*` functions are unchanged, including `host_switch_follow`, so only the reader's whole-file hash and the sync commit move. Bounds, decisions, probes and mutations stay the same. Merging master `2d3eeee17` carries MUBO-452's fresh-start queue hold, MUBO-304's ready tab wait and MUBO-528's due-check before a message worker forks, all outside every covered switch function.

MUBO-243's merge of master `5908369f8` puts MUBO-525's idle push loop in the same reader that keeps a cleared chat's name. All twelve covered `host_switch_*`, `host_usage_limit` and `host_auto_switch_*` functions are unchanged, as is every other covered file, the model, bounds, decisions, probes and mutations, so only the reader's whole-file hash and the sync commit move.

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

MUBO-588 adds an effort choice to Codex and Pi chats in `host_settings`, the Codex turn parameters and the Pi thinking level on start and live. None of the twelve covered switch, history, usage-limit or auto-switch functions changed, and an effort choice neither switches providers nor edits the decision table. Only the reader's whole-file hash moves; the model, bounds, decisions, probes and mutations are unchanged. Hosted CI must rerun the full self-test and native replay.
