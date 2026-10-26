# Chat first paint

One failure class: Chat View shows one layout in the first frame after launch and a different layout once restore finishes (IGSH-925: the message card was drawn for a narrow pane while the transcript and message box kept the full width, then everything jumped).

## Sub-features

- `first-paint-layout`: from the first painted frame of a relaunch until restore finishes, the transcript, the message box and the composer card each keep exactly one rectangle for a given window size.
- `docked-browser-pane`: the quit state has Chat View open beside a docked browser pane, so the saved launch snapshot must describe the same pane that restore later reopens.
- `fast-reopen`: the journey adds no wait, hide or delay to the app; the first frame still comes from the launch snapshot (IGSH-568).

## How to get to it (user POV)

- Ctrl+K → `Open Browser Pane`, then Alt+C to show Chat View, then close Multiprompt and open it again.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=chat-first-paint` (or `--ref <branch>`). It also runs in the full matrix on every master push.

1. Launch with the isolated profile and the browser set up as in `pane-layout`. Open the browser pane from the palette, press Alt+C, and wait until the app itself has saved both `cv` and `bon` for the tab.
2. Close the owned window normally (WM_CLOSE). The journey requires exactly one app-written launch snapshot with an open Chat View and records whether it carries the browser pane (`launch-snapshot-summary.json`). Nothing is seeded by hand.
3. Relaunch with `--single-window`. A tight loop saves `first-paint.png` the moment the log shows `launch first-paint`, then waits for `launch step=browser` plus six quiet seconds and saves `settled.png`.
4. The debug log of launch 2 is saved as `launch-2.debug.log`. `[chat] frame` lines (transcript, message box, composer card, logged by `layoutChatControls`) and `[chat] composer card` lines (logged on paint) are grouped by the `[reposition] client=` window size. Any kind with more than one rectangle in a group fails with `chat layout moved after first paint`.
5. `result.json` names the check `chat-first-paint`; evidence is `chat-layout-events.json`, `chat-first-paint-verdict.json`, the two screenshots and the launch 2 log.

## Gotchas

- Red control: current master does not save the browser pane in the launch snapshot, so the first frame uses the full width and the later frame the pane width; the run fails with `chat layout moved after first paint`. The red and green run links are on the IGSH-925 ticket.
- The two `[chat]` log lines exist only under verbose logging, which the journey turns on; they add no behaviour.
- Groups are keyed by window size so a deliberate resize is never reported as a shift.
- The screenshots are evidence for a person; the verdict comes from the logged rectangles.
