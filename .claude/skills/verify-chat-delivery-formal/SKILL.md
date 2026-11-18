---
name: verify-chat-delivery-formal
description: Check desktop chat sends, outbox recovery, echo reconciliation and retry after changing chat_echo, chat_send, pending-row rendering or the shared message store; read every TLA+ result with pstack /statechart.
---

# Verify desktop chat delivery

Each sent message must have exactly one visible copy and must never show **Not sent** after the agent accepted it. Duplicate copies invite duplicate sends. A false failure tells the user to repeat work the agent already received.

## Run

From the repository root, with Python 3.12, Java 21 and Zig 0.16.0 available, run:

```sh
python3 .claude/skills/verify-chat-delivery-formal/check.py --self-test --output /tmp/delivery-formal-new
```

Use a new output directory. The checker downloads checksum-pinned TLA+ Tools 1.7.4 into the user cache. `TLA2TOOLS` may select an existing copy with that same checksum; `JAVA` may select the Java executable. The GitHub workflow installs checksum-pinned Zig 0.16.0 and runs the same command.

Exit 0 means the modeled properties hold. Exit 1 means a counterexample. Exit 2 means source drift, a tool failure, an incomplete run or failed replay. Read `summary.json`, every `current/*.log`, `current/results.json` and `replay/`. Do not turn an error into a finding or a pass.

Read **every result with pstack /statechart**. Use the generated `current/Delivery.tla`, the corresponding generated config and `view.mjs` from this skill. Read both the all-events and resume-only scenarios. Let /statechart report the shortest path, including when the native source result passes. This skill deliberately does not copy /statechart's commands, options or installation paths.

`--model-only` runs only bounded TLC checks against the recorded decision table. It is suitable for a short local model investigation, not verification of the source, mutation proof or a shipping claim. Run native checks and reviews on GitHub-hosted runners. Follow [verify-multiprompt](../verify-multiprompt/SKILL.md) separately for actual desktop behavior. No product code changes are made by this skill.

## Why TLA+

The failure depends on whether an acceptance receipt or saved chat arrives before a timeout or restart. TLA+ explores those orders without requiring a live provider or waiting ten minutes. Zig cannot be executed symbolically by TLC. The checker therefore runs extracted production decisions with Zig, passes their results as model constants, and replays each shortest counterexample through those decisions and the production SQLite store. A model pass is not a proof of the whole desktop app.

## Bounds and assumptions

- One logical human message, at most two wire IDs, one explicit retry, one app restart and a ten-minute age boundary. Disconnect and reconnect may repeat; the finite state space closes those cycles.
- One retained Claude chat and a fixed session identity. Receipts may be arbitrarily delayed or absent. The app's local outbox save succeeds. Host writes are transactional and wire IDs do not collide.
- The agent accepts a queued message in a separate step. The acceptance receipt and transcript may arrive independently. The transcript contains one exact-text user block newer than the send anchor.
- Transcript installation and echo reconciliation are one UI-thread action, before painting. One pending bubble is replaced by that user block. The native probe also checks two identical pending texts cannot claim the same block.
- The timeout action includes the production outbox timeout branch. Restart applies the persisted state through `stateOnLoad`. Retry of an already accepted host row is rejected by the real store. External connection and process lifecycle events remain modeled boundaries.

No liveness is claimed when a connection can stay down forever. This does not verify all strings, allocation or disk failures, full serialization, event pagination, scheduling, cancellation, session rotation, stale-session callbacks, provider restarts, Codex/Pi, assistant reply formatting, rendering pixels or Android. SOFT-2688's three assistant forms and SOFT-2681's stale session are motivating adjacent problems, not covered proofs. Use their real app journeys for those cases.

## Coverage and sync

Last confirmed source/model sync commit is `9dd167dad7dde81749519038b0bcc5866c6deebb`. [coverage.json](coverage.json) records that full SHA and conservative whole-file hashes. The function list below, not the file hashes, describes the modeled behavior.

| Source | Covered behavior |
| --- | --- |
| `src/chat_echo.zig`: `mayType`, `stateOnLoad`, `showsNotSent`, `assign` | Send eligibility, uncertain written sends on restart, failure label and matching one exact-text echo. These execute unchanged in native probes. |
| `src/chat_send.zig`: `chatEchoWaitsOnTranscript`, timeout branch in `chatOutboxTick`, state assignment in `chatMessageReduce` | These source fragments execute unchanged in replay. Only the fields they read are supplied by a small boundary struct. |
| `src/chat_send.zig`: `chatEchoEnqueueForShell`, `chatOutboxTrySendEntry`, `chatOutboxParseJson`, `chatEchoSendAgain`, `chatEchoMatchActive` | Reviewed mapping for durable enqueue, send reservation, load invocation, replacement request and atomic removal after matching. These complete functions are not executed by the native replay. |
| `src/chat_render.zig`: `chatRelayout`, `chatEchoNotSent`; `src/app_state.zig`: `ChatOutboxEntry` | Reviewed mapping for counting a pending bubble and the failure label. Native replay checks the underlying predicate, not pixels. |
| `src/chat_history_reader.py`: `message_store_transaction`, `message_poll`; `src/chat_connectors/claude.py`: `poll` | Real temporary SQLite store, repeat-submit identity, connector acceptance and replacement rejection. No SSH, tmux process or paid provider is run. |
| `tools/chat-history-reader-test.py`: `IGSH_1266_SharedMessageHostTest`; `tools/multibot-feedback-test.py` | Existing isolated host fixture and its import dependency. They supply a synthetic transcript, temporary home and terminal-send stand-in. |

Whole-file drift stops before checking, even for an unrelated function change. This favors an explicit source review over silently trusting a stale model. Re-read the covered functions and callers; change the mapping, native probes or bounds when needed. Update `decisions.json` only from native output after understanding the semantic change. Update hashes and move the sync commit forward **only after confirming the verification still describes the code**. A hash refresh alone is not verification.

## Prove the checker can fail

`--self-test` first checks a reliable control with no timeout or restart. It then copies real source into temporary directories and plants two breaks:

1. Stop v1 outbox entries waiting for transcript reconciliation. `SingleVisibleCopy` must fail with a transcript bubble plus a pending bubble.
2. Label a delivered v1 message **Not sent**. In the reliable control, `NoFalseNotSent` must fail on a delivered message. This isolates the planted break from existing timeout/restart findings.

Both counterexamples must replay through the changed production decisions. The original checkout is untouched. The checker then regenerates the original native table, reruns TLC and replay, and requires the exact starting results. A failed mutation, compiler failure or replay mismatch is exit 2.

## Read current findings

The current source violates `NoFalseNotSent` through timeout and restart. [findings.md](findings.md) contains the /statechart paths and code mapping. Keep those findings; do not weaken the invariant to make the job green. For a modeling error, identify the impossible action or mismatching source operation and fix the model. For a real bug, file each counterexample separately and keep its trace and native replay.

The CI command adds `--inherit-from <base>`. Existing findings can return exit 0 only after both mutations and every native replay finish, and only if **every guarded source file is byte-identical to that base**. `summary.json` still lists all failures and the base SHA. Default runs still return exit 1. Changed covered code, drift and replay errors never inherit. This classifies a verification-only PR's pre-existing bugs without calling them passes.

After a source change that did not recheck this model, use pstack /maintain-formal-verification-skill.
