# Switch AI counterexamples

The goal is one live chat per address with an AI still running when the new one fails to start, a chat that follows the saved order when its plan runs out, and a chat that stays put while the automatic switch is off. The source at the current sync commit `e11386929a20a51d87f0d91c429a097324c5571b` passes every rule in the bounded model.

## Start failure after the switch committed (fixed)

`FailedSwitchKeepsOld` means `startOk \/ aiRunning`. It failed at `d676860794a9d0571334cec49e38d16d21923b29`, where the host disabled the old AI before `host_start` and answered `switched` even when the start failed. The shortest /statechart path there:

1. Claude chat idle with the old agent running.
2. You request switch to Codex; the host enters the switch.
3. The new Codex agent fails to start.
4. The host still commits the switch, leaves the old Claude stopped and reports success.

SOFT-3057 (PR #1208) reordered `host_switch_ai`: it writes the new config, starts the new agent, and on a failed start calls `host_switch_abort`, restarts the old agent when it was enabled and is no longer alive, and answers `switch_start_failed`. The old agent is stopped only after the new one starts and the locator, message and queue writes succeed. The native table now records `CommitAfterStartFail` false and `StopOldOnCommit` true, so `FailedSwitchKeepsOld` holds.

## Automatic move when a plan runs out (SOFT-2469)

`PlanOutMovesChat` means a used-up plan with the automatic switch on and another AI still holding a plan ends with the chat on that AI. `ToggleOffKeepsChat` means a chat never moves because of a used-up plan while the switch is off. `AutoSwitchFollowsOrder` means a plan-out move lands on the next AI in the saved order.

SOFT-2469 (PR #1249) added `host_usage_limit`, the saved order and cooldown in `host_auto_switch_settings` and `host_auto_switch_target`, the toggle request in `host_auto_switch_set`, the trigger and the detached runner in `host_auto_switch_trigger` and `host_auto_switch_run`. The reader marks the used-up provider empty, picks the next AI with a plan, and reuses `host_switch_ai` with reason `usage_limit`, which writes the divider `Switched AI automatically: <AI> ran out of plan` above the carried conversation. With the toggle off the trigger returns before it marks anything empty, so the plain `No plan left anywhere` notice does not appear either.

## Why the rules are not vacuous

- Setting `CommitAfterStartFail` true reproduces the historical failure of `FailedSwitchKeepsOld`.
- Setting `StopOldOnCommit` false leaves the old agent running next to the new one and fails `OneLiveChat`.
- `identityOk` starts true and changes only in `CommitSwitch`: it falls when `CarryIdentity` is false or when the commit leaves two locators for the address. The doubled-chat break, a locator delete turned into a no-op, fails `IdentityStable` with two locators and replay shows them.
- `historyOk` starts true and falls when `CarryHistory` is false. The lost-chat break, a commit that writes only the divider into the new chat's history, fails `HistoryReadable`, and replay shows the new chat with no earlier rows.
- Planting the queued-message adoption no-op fails `NoLostOrDuplicate`, and replay shows the message still queued on the old provider and sid after the commit.
- Forcing the saved toggle on fails `ToggleOffKeepsChat`, and replay shows a chat that moved after the switch was turned off.
- Walking the fallback list backwards fails `AutoSwitchFollowsOrder`, and replay shows the chat landing on an AI that is not the next one.
- Dropping the event kind before the phrase check fails `PlanOutMovesChat`, and replay shows a used-up plan with no move and no notice.

`--self-test` proves all six breaks through production code. Each replayed trace must show the symptom its rule names, and the same trace on unbroken source must not show it, so a replay that finishes without reproducing the violation turns the run red.

## Sends during a switch

When a trace sends while a switch runs, the replay queues the marker message before the atomic `host_switch_ai` call, then reports where the marker ends up. On unbroken source the commit adopts it onto the new provider and sid; with adoption broken it stays queued on the old pair and the check reads that as the lost message.

## Source replay

The check runs isolated Python probes and replays failures through temporary homes with the production `host_switch_ai` body, one switch per request because the real call is atomic. A plan-out trace feeds the recorded events in `tools/fixtures/SOFT-2469/` through the production `host_agent_event` turn path and runs the production `host_auto_switch_run`; only the provider CLI start is replaced. No tmux, provider CLI or desktop window is started.
