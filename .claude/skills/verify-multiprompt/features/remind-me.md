# Remind Me

Open the Remind Me preset picker with Ctrl+H on a tmux session, see the hour and evening presets, and leave without choosing one.

## Sub-features

- `remind-me-open`: Ctrl+H opens the preset picker for the focused tmux session.
- `remind-me-rows`: the picker lists In 1, 2, 3, 6 and 12 hours, Tomorrow morning, Tomorrow evening, the later presets and Custom.
- `remind-me-close`: Esc leaves the picker without snoozing anything.

## How to get to it (user POV)

- Press Ctrl+H, or Ctrl+Shift+H, or Alt+H on a tmux or Claude session. In Inbox the same keys act on the selected row.
- Ctrl+K `Remind Me` opens the same picker; this journey uses Ctrl+H.
- Picking a preset hides the local tab until the reminder is due; this journey never picks one.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes. The initial CMD session has no tmux session, so the journey first creates a group and a `verify-1` tmux tab through the app's own `session-open` request, then focuses it with Ctrl+2.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=remind-me`; Windows runs `control.ps1 -Feature remind-me`. The PR trigger runs it too.
- **Open.** Press the real Ctrl+H. Require the app's `[palette] rows` debug log line to list every preset routing id (base read from `SEARCH_REMIND_PRESET_OFFSET` in `src/app_state.zig`, except This evening which hides after 16:00). Capture `picker.png`.
- **Close.** Press Esc and require a new rows line with no preset ids, then press Esc again to close the palette. Capture `closed.png`.
- **Proof.** `result.json` records the preset row ids and that the session count and active tmux tab are unchanged.

## Gotchas

- The signal is the app's `[palette] rows` line, not a pixel check. It proves which rows exist, not how they look; inspect `picker.png` for the labels and times.
- The first Esc returns to the normal palette, so a second Esc is needed to close it.
- The tmux tab fails its SSH attach on the runner; the picker only needs the tab's saved tmux name.
- No preset is chosen, so snoozing and wake-up are not covered.
