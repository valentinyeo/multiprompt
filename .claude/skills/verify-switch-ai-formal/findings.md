# Switch AI counterexamples

The goal is one live chat per address with an AI still running when the new one fails to start. The source at the current sync commit `dccfffcfff2b87949b51d5e9deaecf5120a8ce1a` passes every rule in the bounded model.

## Start failure after the switch committed (fixed)

`FailedSwitchKeepsOld` means `startOk \/ aiRunning`. It failed at `d676860794a9d0571334cec49e38d16d21923b29`, where the host disabled the old AI before `host_start` and answered `switched` even when the start failed. The shortest /statechart path there:

1. Claude chat idle with the old agent running.
2. You request switch to Codex; the host enters the switch.
3. The new Codex agent fails to start.
4. The host still commits the switch, leaves the old Claude stopped and reports success.

SOFT-3057 (PR #1208) reordered `host_switch_ai`: it writes the new config, starts the new agent, and on a failed start calls `host_switch_abort`, restarts the old agent when it was enabled and is no longer alive, and answers `switch_start_failed`. The old agent is stopped only after the new one starts and the locator, message and queue writes succeed. The native table now records `CommitAfterStartFail` false and `StopOldOnCommit` true, so `FailedSwitchKeepsOld` holds.

## Why the rules are not vacuous

- Setting `CommitAfterStartFail` true reproduces the historical failure of `FailedSwitchKeepsOld`.
- Setting `StopOldOnCommit` false leaves the old agent running next to the new one and fails `OneLiveChat`.
- `identityOk` starts true and changes only in `CommitSwitch`: it falls when `CarryIdentity` is false or when the commit leaves two locators for the address. The doubled-chat break, a locator delete turned into a no-op, fails `IdentityStable` with two locators and replay shows them.
- `historyOk` starts true and falls when `CarryHistory` is false. The lost-chat break, a commit that writes only the divider into the new chat's history, fails `HistoryReadable`, and replay shows the new chat with no earlier rows.
- Planting the queued-message adoption no-op fails `NoLostOrDuplicate`, and replay shows the message still queued on the old provider and sid after the commit.

`--self-test` proves all three breaks through production code. Each replayed trace must show the symptom its rule names, and the same trace on unbroken source must not show it, so a replay that finishes without reproducing the violation turns the run red.

## Sends during a switch

When a trace sends while a switch runs, the replay queues the marker message before the atomic `host_switch_ai` call, then reports where the marker ends up. On unbroken source the commit adopts it onto the new provider and sid; with adoption broken it stays queued on the old pair and the check reads that as the lost message.

## Source replay

The check runs isolated Python probes and replays failures through temporary homes with the production `host_switch_ai` body, one switch per request because the real call is atomic. No tmux, provider CLI or desktop window is started.
