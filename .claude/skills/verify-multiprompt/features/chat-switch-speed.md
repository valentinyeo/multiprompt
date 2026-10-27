# Chat session switch speed

## Sub-features

- Real Ctrl+1 to Ctrl+5 session switches between five remote Claude sessions in Chat View that each hold a 400-round conversation (over 1,200 transcript blocks with code blocks, tables and tool calls), with the browser pane closed and then open on every session.
- Click-to-chat-shown time: from the native SendInput call until the app log holds `[switch] chat content shown shell=<id>` for the target session. That line is written on the first paint after the switch where the transcript has blocks, the layout is not dirty and the transcript cache belongs to the target session. An empty "Loading conversation..." area never counts as shown.
- Window hang probe: a native thread sends WM_NULL to the main window every 2 ms and records the longest round trip in each sample window (from the switch input until 1.2 s later, so the delayed second layout and save are included).
- First frame already final: the `chat content shown` line also carries `layout_w` (the width the transcript was laid out for) and `client_w` (the width of the transcript window at that paint). They must be equal, and no `[chat] frame` or `[reposition]` line may follow the shown line inside the sample window, so nothing moves after the first frame with content.
- The named `chat-switch-speed` case fails if any median is above 150 ms, any single window hang is above 100 ms, any switch never shows its chat, any first frame has the wrong width, or any layout moves after the first frame.

## How to get to it (user POV)

- Five saved remote tabs on a stand-in SSH host, as in the Chat delivery journey. Pick Ctrl+K `tab order`, Tab Order Manual, so Ctrl+1 to Ctrl+5 follow the saved order. Press Alt+C on each to open Chat View.
- Switch with Ctrl+1 to Ctrl+5. For the pane-open set, open each session's browser with Ctrl+K `open browser`, Enter.

## Driving it with control.ps1

Run on demand with `workflow_dispatch` using feature `chat-switch-speed` on a branch build (the journey needs the repository bridge and extension, like `browser-switch-speed`). Download `verify-chat-switch-speed`.

1. Launch the isolated app with debug logging and pass Doctor. Disable only timed browser closing through Ctrl+K `browser auto suspend` and require `browser_suspend_min: 0` in the saved session.
2. Before launch the harness writes `session.json` once with five tmux tabs, an `ssh-path.txt` pointing at the compiled stand-in `ssh.exe`, and five seeded transcripts (`boundary.py shell seed-many 400`). This is the same documented exception as Chat delivery; nothing else is seeded. After restore, select each tab with Ctrl+1 to Ctrl+5, press Alt+C and wait for its `chat content shown` line, then save `chat-switch-sessions.json` with the shell IDs.
3. Start the hang probe. For each of `browser_closed` and `browser_open` (panes opened and docked on all five sessions first): visit every session once as a warm-up, return to session one, then do 20 switches in a round robin (1 to 2, 2 to 3, and so on).
4. Before each switch the harness appends one new assistant answer to the target session's transcript, like a running agent that kept working while another session was in front, so the switch also has to take in new history. Each switch is one native call that starts the Stopwatch, sends the key chord, and polls the app log from the pre-switch byte offset for the content line. It returns the click-to-shown time and the longest probe round trip. The app's own `ms=` value for the same line is kept as `app_ms`.
5. Save `switch-timings.json` from finally: per mode `samples_ms`, `app_ms`, `hang_ms`, `missing`, `median_ms`, `max_ms`, `max_hang_ms`, `first_frame_layout_w`, `first_frame_client_w`, `first_frame_wrong_width`, `moved_after_first_frame`, `moved_lines`. A switch that never shows its chat is recorded as 1200 ms and counted in `missing`. Each sample's raw log range is kept as `<mode>-<sample>-debug.log`.

### Audit-shape mode and separate CPU capture

Enable `chat_shape_proof` with `feature=chat-switch-speed`.
Use `tag=v0.28.946` for the released baseline.
Leave `tag` empty for the ReleaseSmall candidate.
These runs require approved repository access.
Never run this journey on the VPS.

- `boundary.py shell seed-shapes` preserves process/session metadata.
- The generator uses anonymous numeric audit statistics.
- Four profiles preserve complete-source bytes and record counts.
- Two endpoint markers add two explicit records.
- The fifth profile remains a partial cache sample.
- Message order and Markdown semantics remain generated.
- No real messages enter fixtures or evidence.
- Both browser modes contain twenty measured switches.
- `shape-switch.json` records ordinary process CPU windows.
- CPU counters include start, paint-observation, and settled values.
- Cumulative samples expose short-window CPU spikes.
- Percentages use one-core process time, without core division.
- Observer CPU and whole-machine busy time stay separate.
- Owned-job CPU also includes browsers and reader processes.
- Owned-job counters have a separately recorded enclosing interval.
- Idle observations use the same WM_NULL hang probe.
- Ordinary CPU windows never force paints or capture images.
- Separate replays capture first-observed and settled transcript images.
- Actual transcript copy verifies generated latest-message receipts.
- The oracle checks every switch, not the median.
- Post-cleanup checks require no remaining owned processes.

Enable `chat_switch_profile` for a separate WPR replay.
The recorder chooses the slowest observed switch route.
It restores that route's browser mode before recording.
Existing or ambiguous WPR recordings stay untouched.
`switch-profile/profile-request.json` records the target PID and interval.
`switch-profile/cpu.etl` contains system-wide kernel samples.
Analyze only the recorded app PID and interval.
`app-stages.log` retains the corresponding numeric app stages.
The trace remains explicitly unanalysed until source mapping.
An ETL file alone never proves a bottleneck.
Matching symbols may require additional Windows setup.

Shown time covers first nonempty cached paint.
Latest-message receipts are checked after that window.
This does not prove latest-message paint latency.
Product acceptance still needs that native proof.
The current native input remains Ctrl+digit.
It does not prove sidebar-click latency.
The image follows the completed target-paint log.
It does not guarantee the first compositor-presented frame.
Those limitations remain in the oracle's output.
The oracle always marks product acceptance unproven.
Do not close the product ticket on these alone.
Native compilation, execution, and profiling require Windows CI.

## Gotchas

- Only SSH is replaced (stand-in `ssh.exe` and `tmux.exe` from `tools/verify-chat-delivery/launcher.c`, served by `boundary.py`); the real transcript reader, cache, layout and switching run. The seeded sessions are not real Claude or a real server.
- The pane-open set needs the same Chrome for Testing and extension set-up as `browser-switch-speed`, so it is excluded from the pull request journey matrix.
- The probe measures whether the window thread answers messages, which matches a frozen frame. It does not measure GPU presentation.
- The journey measures only. The numbers are only meaningful from the GitHub Windows runner, never from a laptop.
