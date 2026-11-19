# Delivery verification maintenance for IGSH-1921

This branch stacks the nightly host-rotation repair on the chat-delivery repair. The delivery model, properties, bounds, decision table, native probes, replay, mutation controls and inheritance code are unchanged. Only whole-file drift hashes are refreshed so the check can reach its native stage.

## Observed failure

The nightly-rotation branch changed guarded files, so the check stopped at `MODEL DRIFT: review src/chat_history_reader.py and the coverage map before updating its sync commit` before native decisions, TLC, replay, mutations or inheritance. That early stop reports drift, not a delivery result.

## Review from the confirmed sync

The confirmed sync remains `6baea66c637034b9d6285a5894de3ed7ffb24fe5`. Reviewing the difference against that record:

| File | Actual change | Classification |
| --- | --- | --- |
| `src/chat_history_reader.py` | Spawned reader source now carries `RUNTIME_GENERATION` and reads `130`. | Module tail only. Covered `message_store_transaction`, `message_poll` and `message_poll_locked` are byte-identical. |
| `tools/chat-history-reader-test.py` | Adds a separate `SpawnedSourceGenerationTest` class. | Covered `IGSH_1266_SharedMessageHostTest` is byte-identical. The new class supplies the failing-on-master rotation regression, not a delivery assertion. |
| `src/chat_render.zig` | One verbose-only unread-counter line in `chatScrollBy`, plus the delivery repair's `chatSetTopPad` padding shift. | Covered `chatRelayout` and `chatEchoNotSent` are byte-identical. Neither reads the unread counter. |
| Other five guarded files | Byte-identical to the delivery repair base. | No effect. Native send/echo decisions, connector and store fixtures are unchanged. |

`native.py` executes echo and send decisions; `replay.py` checks their state transitions and the temporary SQLite store. Neither reads the reader generation constant, the unread counter or the rotation test.

`src/chat_echo.zig` and `src/chat_send.zig` describe the fixed decisions from the delivery repair, and `src/app_state.zig` matches it. Those same fixes remove the three findings documented in [findings.md](findings.md), so the check does not rely on inheriting them from master. Strict whole-file inheritance is unchanged: if any finding returned, `--inherit-from` would still reject this branch because three guarded files differ from the base.

Review the complete difference with:

```sh
git diff origin/soft-2724-chat-delivery HEAD -- src/chat_history_reader.py src/chat_render.zig tools/chat-history-reader-test.py
```

## Outcome and what the check needs

**Drift reviewed; hosted confirmation pending.** Run the existing hosted command on this coverage record. Require the native table to match, the reliable control to pass, both planted breaks to fail and replay, and restoration to reproduce the starting results. Read every current trace with pstack `statechart` after those artifacts exist.

## Remaining limits

This review does not prove Windows pixels, assistant formatting, network delivery timing, Android, extra sends or any behavior outside the existing bounded model. It does not prove that a hosted chat survives a real 03:00 rotation; the `server-chat` journey and the spawned-source tests cover that.
