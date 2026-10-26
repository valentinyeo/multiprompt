# Chat session switch speed

## Sub-features

- Real Ctrl+1 to Ctrl+5 session switches between five Chat View sessions that each hold real console output, with the browser pane closed and then open on every session.
- Click-to-chat-shown time: from the native SendInput call until the app log holds `[switch] chat content shown shell=<id>` for the target session. That line is written on the first paint after the switch where the transcript has blocks, the layout is not dirty and the transcript cache belongs to the target session. An empty "Loading conversation..." area never counts as shown.
- Window hang probe: a native thread sends WM_NULL to the main window every 2 ms and records the longest round trip in each sample window (from the switch input until 1.2 s later, so the delayed second layout and save are included).
- The named `chat-switch-speed` case fails if any median is above 150 ms, any single window hang is above 100 ms, or any switch never shows its chat.

## How to get to it (user POV)

- Start with one CMD. Pick Ctrl+K `tab order`, Tab Order Manual, so Ctrl+1 to Ctrl+5 follow creation order. Create four more with Ctrl+K `new cmd`, Enter. In each, print 80 numbered lines through a real `cmd /c "for /L ..."` command, then press Alt+C to open Chat View.
- Switch with Ctrl+1 to Ctrl+5. For the pane-open set, open each session's browser with Ctrl+K `open browser`, Enter.

## Driving it with control.ps1

Run on demand with `workflow_dispatch` using feature `chat-switch-speed` on a branch build (the journey needs the repository bridge and extension, like `browser-switch-speed`). Download `verify-chat-switch-speed`.

1. Launch the isolated app with debug logging and pass Doctor. Disable only timed browser closing through Ctrl+K `browser auto suspend` and require `browser_suspend_min: 0` in the saved session.
2. Create the five sessions, fill each console, open Chat View in each, and save `chat-switch-sessions.json` with the shell IDs.
3. Start the hang probe. For each of `browser_closed` and `browser_open` (panes opened and docked on all five sessions first): visit every session once as a warm-up, return to session one, then do 20 switches in a round robin (1 to 2, 2 to 3, and so on).
4. Each switch is one native call that starts the Stopwatch, sends the key chord, and polls the app log from the pre-switch byte offset for the content line. It returns the click-to-shown time and the longest probe round trip. The app's own `ms=` value for the same line is kept as `app_ms`.
5. Save `switch-timings.json` from finally: per mode `samples_ms`, `app_ms`, `hang_ms`, `missing`, `median_ms`, `max_ms`, `max_hang_ms`. A switch that never shows its chat is recorded as 1200 ms and counted in `missing`. Each sample's raw log range is kept as `<mode>-<sample>-debug.log`.

## Gotchas

- The pane-open set needs the same Chrome for Testing and extension set-up as `browser-switch-speed`, so it is excluded from the pull request journey matrix.
- The probe measures whether the window thread answers messages, which matches a frozen frame. It does not measure GPU presentation.
- The journey measures only. The numbers are only meaningful from the GitHub Windows runner, never from a laptop.
