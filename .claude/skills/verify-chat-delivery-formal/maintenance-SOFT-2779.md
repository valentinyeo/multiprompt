# Delivery verification maintenance for SOFT-2779

A chat tail that holds only tool results must still open on its newest message. This review keeps the delivery findings and the strict inheritance rule. It does not fix SOFT-2724, SOFT-2725 or SOFT-2726.

## Observed drift

[Run 44602962521](https://github.com/valentinyeo/multiprompt/actions/runs/44602962521) exits 2 with `MODEL DRIFT: review src/chat_history_reader.py and the coverage map before updating its sync commit`.

The check stops before native decisions, TLC, replay, mutations or inheritance. The absent `summary.json` is a consequence of that early stop, not proof that delivery passed or failed anew.

## Review from the last confirmed sync

The confirmed sync remains `9dd167dad7dde81749519038b0bcc5866c6deebb`. The only guarded files changed since then are these two.

| File | Actual change | Classification |
| --- | --- | --- |
| `src/chat_history_reader.py` | `read_tail` starts a first page at the newest message row and caps it at `TAIL_VISIBLE_BYTES`; `fit_tail` and the shown-budget trim keep the newest question. | No effect on this model. Covered `message_store_transaction`, `message_poll` and `message_poll_locked` are byte-identical. |
| `tools/chat-history-reader-test.py` | Adds `SOFT_2779_TailWindowTest` and widens one existing first-page bound. | No effect on this model. Covered `IGSH_1266_SharedMessageHostTest` is byte-identical. |
| Other six guarded files | Byte-identical to the recorded sync. | No effect. |

`native.py` executes echo and send decisions from `chat_echo.zig` and `chat_send.zig`. `replay.py` checks their transitions plus the temporary SQLite store through the covered reader functions. None of them read the transcript tail window.

Review the complete difference with:

```sh
git diff 9dd167dad7dde81749519038b0bcc5866c6deebb HEAD -- src/chat_history_reader.py tools/chat-history-reader-test.py
```

Only the two whole-file drift hashes are refreshed. The model, properties, bounds, decision table, native probes, replay, mutation controls and inheritance code are unchanged. The source sync is not advanced while hosted revalidation is pending.

## Outcome and what the check needs

**Drift reviewed; hosted confirmation pending.** Run the existing hosted command again on this changed coverage record. Require the native table to match, the reliable control to pass, both planted breaks to fail and replay, and restoration to reproduce the starting results.

**Known bugs remain.** The last confirmed source has the three findings documented in [findings.md](findings.md). The covered decisions are unchanged, so those same findings are expected, not newly measured in the early-stop run. Their product work remains on [SOFT-2724](https://app.hypertask.ai/detail/project-2060/2724), [SOFT-2725](https://app.hypertask.ai/detail/project-2060/2725) and [SOFT-2726](https://app.hypertask.ai/detail/project-2060/2726).

**CI inheritance remains blocked.** After successful replay and mutations, `--inherit-from` still requires every guarded file to be byte-identical to master. These two files differ, so known failures cannot count as inherited. A coverage refresh is not an inheritance exception and does not make this PR green.

Do not narrow the guarded files, change the base, omit a finding, weaken a property, or rerun unchanged evidence to obtain passage.
