# Switch AI counterexamples

The goal is one live chat per address with the old AI still running when the replacement fails to start. The unchanged source at `d676860794a9d0571334cec49e38d16d21923b29` violates `FailedSwitchKeepsOld` in the bounded model.

## Start failure after the old AI was disabled

`FailedSwitchKeepsOld` means `startOk \/ oldRunning`. The shortest /statechart path:

1. Claude chat idle with the old agent running.
2. You request switch to Codex; the host enters the switch.
3. The host commits the switch, disables the old session and reports success.
4. The new Codex agent fails to start.
5. The old Claude agent stays disabled even though the new agent never took over.

`host_switch_ai` disables the source config before `host_start` and returns `status="switched"` even when `start.status` is `start_failed`. Native replay confirms the old config is already `None` while the reply is still `switched`.

## Source replay

The check runs isolated Python probes and replays failures through temporary homes with the production `host_switch_ai` body. No tmux, provider CLI or desktop window is started.

The locator-delete mutation must fail `OneLiveChat` when planted; restoration must return the production decision table and both findings above.