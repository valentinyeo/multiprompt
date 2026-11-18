# Busy server chat and Stop

Verify on: push, pull_request
Source files: src/chat*, src/tmux*, src/message*, src/command_palette.zig, src/main.zig, build.zig, build.zig.zon, tools/verify-server-chat/*, .claude/skills/verify-multiprompt/seed-profile.py

## Sub-features

- Open a real Linux-hosted Claude chat from a 64-session, eight-workspace profile seeded with PR 1070's generator. The selected server conversation contains 2,400 source messages.
- Send a normal message through the Windows composer and real SSH before testing busy delivery.
- Start a long turn on the original owner. Through the production host CLI, end that owner and start a different live chat on the same saved route. Park the legacy physical pane in `sleep`, as the ticket's activity log reports. Leave the Windows tab untouched.
- Type a follow-up into the same saved tab and press Enter without Escape while the replacement is busy, then observe it for 611 real seconds. Escape interrupts an active turn; completion dismissal is only used by ordinary idle sends. No app clock, timeout, database or client state is patched.
- After the first follow-up's delivery budget, submit `newer follow-up before Stop` without Escape. The user's screenshot has older Not sent rows beside newer pending sends. Retain both native outbox snapshots and require this newer row to remain pending for a master reproduction.
- Click the actual painted Stop button. Require a provider interrupt receipt and the production interrupted-turn event within ten seconds, with the same replacement provider process surviving.
- Require the waiting follow-up to reach the provider once and its reply to appear in copied rendered text.
- Retain native outbox state, read-only server snapshots, screenshots and a desktop video on both success and failure.

## How to get to it (user POV)

Open the saved server chat and send `busy server turn`. Its owner then ends and a different chat starts working on the same route, with the legacy pane parked in `sleep`. Without reopening or changing the saved tab, send `follow-up during busy turn`. Wait through the ten-minute pending-message budget, then submit `newer follow-up before Stop` so the older failed send and a fresh pending send coexist. Click the actual Stop button in the message box. The live replacement's current turn must stop and the waiting message must receive a reply.

This tests a missing condition from the ticket's activity log: an ended owner, a different live chat and a parked pane. The earlier continuously live-owner control did not reproduce the report. Its follow-up reached the provider and Stop worked within the ten-second budget. Owner replacement is a hypothesis until the GitHub desktop artifact shows the same visible Not sent label and ineffective real Stop. The helper uses a normal production `disable`, `enable` and `start` lifecycle. It does not kill the host or provider abruptly, drop the connection, edit client routing state or disable interrupt handling.

## Driving it with control.ps1

The automatic `server-chat-busy` click-through job calls the shared `verify.yml` workflow. Do not dispatch extra runs. `control.ps1` calls `tools/verify-server-chat/drive.ps1 -Busy`, reusing PR 1072's runner-owned WSL2 Ubuntu OpenSSH server, real tmux and Windows OpenSSH. The merged PR 1072 ordinary journey remains unchanged when neither repro mode is selected. Busy mode explicitly enables the large seed. PR 1070's seed files are copied unchanged from `ff2aba50`; the server uses the same source-message factory.

Only the paid Claude process is synthetic. Its stream-json boundary holds one turn open, queues incoming stdin prompts, and accepts the normal interrupt control request. `cancel_queued` discards only prompts already handed to that provider, not messages in the production durable store. It neither rejects valid delivery nor ignores Stop to force a failure.

The provider records stdin arrival in `provider-received.jsonl` before queueing or processing. `provider-input.jsonl` records processing, not arrival. Snapshots retain both, plus `queued` and `discarded`. A prompt queued by the provider and then discarded by `cancel_queued` has reached the session. A missing processed reply after Stop cannot prove that it never arrived. `reproduction.json` reports receipt, processing and cancellation separately; the strict checker rejects this contradiction and missing receipt evidence.

When `app_revision` selects master, both the app and the server reader/connectors use that revision. The harness and deterministic provider stay identical. The current reproduction commit restores all application files to master; no fix may follow until the hosted artifact proves the report.

A red workflow is not sufficient. Run `node tools/verify-server-chat/check-evidence.cjs <artifact> --repro` against the downloaded master artifact. It requires both `notSent=true` and `stopIneffective=true`, successful open/send preconditions, a real Stop click, the full observation budget, a still-busy provider with the same PID, native pending state, video and clean shutdown. Inspect `busy-before-stop.png` to confirm the visible Not sent label. Setup errors and a failure of only one symptom do not authorize a fix.

The checker also requires `busy-start.json`, `busy-owner-replacement.json`, both native saved-tab snapshots, the replacement's independent busy-turn receipt and a read-only pane probe. The old host and provider must have ended; a different live provider must remain busy through the failed Stop observation. The pane must actually run `sleep`. On master the selected saved tab must still have the old public chat id; a later passing app must follow the replacement. Missing lifecycle facts or a missing painted Stop remain failed evidence, not proof of the report.

The workflow runs the strict checker even after a failed desktop step and retains `check-evidence-repro.stdout.log`, stderr and exit status. Setup failures still fail admission. The verifier places the declared reproduction's head/master results and checker output before unrelated artifacts in its bounded input.

The identical positive journey requires `result.json` passed, no Not sent state, the interrupt receipt/event, one follow-up receipt, its copied reply, and cleanup. The checker without `--repro` rejects partial results. Inspect `journey.mp4`, `busy-*.json`, `busy-*.png`, `fixture-manifest.json`, `actions.json`, `doctor.json` and `build.json`.

## Gotchas

This is real SSH, tmux, production dispatch and native Windows input, with a deterministic provider instead of a paid Claude account. It does not prove every provider version behaves identically. Never manufacture a red result by altering the app, dropping transport packets, changing clocks or disabling the provider's interrupt handler.

If master does not show both reported symptoms, retain the evidence and keep the application fix withdrawn. Do not call a contract-only or missing-follow-up failure a reproduction of Not sent plus ineffective Stop.
