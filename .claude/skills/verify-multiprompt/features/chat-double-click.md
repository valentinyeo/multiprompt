# Double-click thumbs up

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/reactions.ps1

## Sub-features

- Double-click an assistant bubble to show one thumbs-up badge.
- Double-click the same bubble again to remove it without sending another message.
- Keep the composer draft unchanged during both actions and delivery.
- Keep the badge hidden when the already queued reaction arrives.

## How to get to it (user POV)

Double-click a Claude reply in Chat View. Double-click it again to remove the thumbs up.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-double-click`. The workflow selects the existing chat-delivery reaction fixture and its owned Windows app. Only the SSH, tmux and provider boundary is synthetic. The renderer and input are real.

The driver locates the first of two same-prefix replies from screenshot pixels. It sends two genuine mouse clicks there, requires a painted badge and one queued reaction, then double-clicks another point in the same bubble. It requires no badge, one unchanged queue entry and the original composer draft. After delivery it requires exactly one transport enqueue, one consumed attachment and no returning badge. The independent checker reads screenshots, the raw transcript, the observed draft and zero-process cleanup.

Download `verify-chat-double-click`. Inspect `reactions-before.png`, `reactions-double-click-added.png`, `reactions-double-click-removed.png`, `reactions-double-click-delivered.png`, `result.json`, `doctor.json` and `cleanup.json`. Run the same harness against the merge base through the PR verifier. The base should fail the first painted-badge assertion.

## Gotchas

This journey does not assert F1 shortcut text, drag selection, triple-click selection, menu toggling or restart persistence. Existing chat journeys may fail before the reaction fixture becomes ready. Such a failure is not badge-toggle proof; retain its matching base failure and link the repair ticket rather than weakening the journey.
