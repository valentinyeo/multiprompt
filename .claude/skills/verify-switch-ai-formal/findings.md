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
- Planting the locator-delete no-op fails `OneLiveChat`, and planting the queued-message adoption no-op fails `NoLostOrDuplicate`; `--self-test` proves both through production code.

## Source replay

The check runs isolated Python probes and replays failures through temporary homes with the production `host_switch_ai` body. No tmux, provider CLI or desktop window is started.
