# Delivery verification maintenance for the Cancel predicate change

The delivery check must not be waived to get a PR green. This review records why two whole-file hashes moved and why the model still describes the code. It does not change the model, the properties, the bounds or the decision table.

## Observed failure

[Hosted formal run 44606612959, job 135851868501](https://github.com/valentinyeo/multiprompt/actions/runs/44606612959/job/135851868501) at `1b2cd09314404bd6ea9aa5c592d3fcae2b142850` exits 2 with `MODEL DRIFT: review src/chat_send.zig and the coverage map before updating its sync commit`.

The check stops at drift, before native decisions, TLC, replay, mutations or inheritance. The missing `chat-delivery-formal` artifact and the failed `tests` gate in the PR verifier are consequences of that early stop.

## What moved since the last hash refresh

The hashes were last refreshed at `a97d6859` (`src/chat_render.zig`, `src/chat_send.zig` recorded there). One commit changed the two guarded files after it: `0c372245` (offer Cancel only when the app can pull the message back). Everything else in the range is byte-identical.

| File | Actual change | Classification |
| --- | --- | --- |
| `src/chat_send.zig` | `shellTmuxIdentity` extracted from the three copies inside `chatAgentKey`, `chatCancelQueued` and `chatShellOp`; new `chatCanCancelQueued` answers whether that identity exists. | Outside the covered functions. `chatEchoEnqueueForShell`, `chatOutboxTrySendEntry`, `chatEchoWaitsOnTranscript`, `chatMessageReduce`, `chatEchoSendAgain`, `chatEchoMatchActive`, `chatOutboxParseJson`, the `chatOutboxTick` v1 timeout exclusion and the `sendTextToShellVerifiedAt` mapping are byte-identical. The refactor keeps one predicate instead of three, so the extracted copies cannot drift apart. |
| `src/chat_render.zig` | New `chatEchoCancelWaiting` (the Cancel predicate shared by the message menu and the cancel path) plus one import and one menu call site. | Outside the covered functions. `chatRelayout` and `chatEchoNotSent` are byte-identical, so the pending-bubble count and the failure label are unchanged. Cancel eligibility is not one of the modeled decisions; the model bounds do not include a cancel action. |
| Other six guarded files | Byte-identical to the recorded hashes. | No effect. |

`native.py` executes the echo and send decisions, and `replay.py` checks their transitions plus the temporary SQLite store. Neither reads the shell identity predicate or the menu. Nothing in the model reacts to Cancel, so the shared predicate cannot make TLC or replay report a different result.

Review the complete difference with:

```sh
git diff a97d6859 1b2cd093 -- src/chat_send.zig src/chat_render.zig
```

Only those two whole-file hashes are refreshed. The confirmed sync commit is not advanced while hosted revalidation is pending.

## What the check still needs

Run the existing hosted command on this changed coverage record. Require the native table to match the recorded decisions, the reliable control to pass, both planted breaks to fail and replay, and restoration to reproduce the starting results. Read every current trace with pstack `statechart` after those artifacts exist.

The covered decisions in this branch already carry the SOFT-2724, SOFT-2725 and SOFT-2726 fixes, so the historical findings in [findings.md](findings.md) are fixed in the same source rather than inherited from master.

## Remaining limits

This review proves no pixels, no network timing, no assistant formatting and no Android behavior, and it does not widen the model.
