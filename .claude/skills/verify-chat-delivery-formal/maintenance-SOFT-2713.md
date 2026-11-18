# Delivery verification maintenance for SOFT-2713

Desktop fixes must stop waiting on unrelated failures. This review keeps the delivery findings and the strict inheritance rule. It does not fix SOFT-2724, SOFT-2725 or SOFT-2726.

## Observed failure

[Hosted run 44370558547](https://github.com/valentinyeo/multiprompt/actions/runs/44370558547) at `feeecd83e956696b37f9ee1c0f98b9712602b83c` exits 2 with `MODEL DRIFT: review src/chat_render.zig and the coverage map before updating its sync commit`.

The check stops before native decisions, TLC, replay, mutations or inheritance. The absent summary artifact is a consequence of that early stop, not proof that delivery passed or failed anew.

## Review from the last confirmed sync

The confirmed sync remains `9dd167dad7dde81749519038b0bcc5866c6deebb`. The only commit changing guarded files between that sync and this branch is `5be4370e4d1dc44c3a80386954ee3b216b49819a`.

| File | Actual change | Classification |
| --- | --- | --- |
| `src/chat_render.zig` | `chatSetTopPad` shifts held scroll by the padding delta. | No effect on this model's pending-copy count or failure label. Covered `chatRelayout` and `chatEchoNotSent` are byte-identical. |
| `src/app_state.zig` | Adds `g_chat_read_anchor` for a reading position. | No effect on delivery state. Covered `ChatOutboxEntry`, including its methods, is byte-identical. |
| Other six guarded files | Byte-identical to the recorded sync. | No effect. Native send/echo decisions, reader/store/connector and replay fixtures are unchanged. |

`native.py` executes echo/send decisions, and `replay.py` checks their state transitions plus the temporary SQLite store. Neither uses padding or the reading anchor. The reviewed layout still counts pending copies through the same outbox loop. The failure-label predicate is unchanged.

Review the complete difference with:

```sh
git diff 9dd167dad7dde81749519038b0bcc5866c6deebb feeecd83e956696b37f9ee1c0f98b9712602b83c -- src/chat_render.zig src/app_state.zig
```

Only the two whole-file drift hashes are refreshed. The model, properties, bounds, decision table, native probes, replay, mutation controls and inheritance code are unchanged. The source sync is not advanced while hosted revalidation is pending.

## Outcome and what the check needs

**Drift reviewed; hosted confirmation pending.** Run the existing hosted command again on this changed coverage record. Require the native table to match, the reliable control to pass, both planted breaks to fail and replay, and restoration to reproduce the starting results. Read every current trace with pstack `statechart` after those artifacts exist.

**Known bugs remain.** The last confirmed source has the three findings documented in [findings.md](findings.md). The covered decisions are unchanged, so those same findings are expected, not newly measured in the early-stop run. Their product work remains on [SOFT-2724](https://app.hypertask.ai/detail/project-2060/2724), [SOFT-2725](https://app.hypertask.ai/detail/project-2060/2725) and [SOFT-2726](https://app.hypertask.ai/detail/project-2060/2726).

**CI inheritance remains blocked.** After successful replay and mutations, `--inherit-from` still requires every guarded file to be byte-identical to master. These two files differ, so known failures cannot count as inherited. The unchanged checker will reject that comparison. A coverage refresh is not an inheritance exception and does not make this PR green.

The orchestrator must keep the PR waiting on the existing delivery findings under the current rule. Do not narrow the guarded files, change the base, omit a finding, weaken a property, or rerun unchanged evidence to obtain passage. Do not move the confirmed sync until hosted maintenance establishes the current mapping and its remaining bugs.

## Remaining limits

This review does not prove Windows pixels, assistant formatting, network delivery timing, Android, extra sends or any behavior outside the existing bounded model. The separate stillness proof does not establish delivery correctness.
