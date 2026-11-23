# Sidebar click row

Source files: src/sidebar.zig, src/app_state.zig, src/console.zig, src/main.zig, .claude/skills/verify-multiprompt/control.ps1, .claude/skills/verify-multiprompt/sidebar-click-row.ps1

## Sub-features

- Clicking a sidebar session row while the pointer stays inside the sidebar leaves that row under the pointer.
- The clicked row keeps its place while its chat spawns or reconnects.

## How to get to it (user POV)

Keep the pointer over a session row in the sidebar and click it. The chat opens or reconnects; the row you clicked must stay where it was until the pointer leaves the sidebar.

## Driving it with control.ps1

Before launch the harness saves two stand-in tmux tabs on the replaced SSH boundary, with distinct manual names and activity times, and selects the newer one. The journey reads the sidebar text bands from a real screenshot, parks the real pointer on the last (older) session row, screenshots the row, clicks at that exact point, logs the pointer position before and after, waits for the chat to reopen, and screenshots again. The pass requires the row glyphs under the pointer to be the same before and after (ink overlap of the band at the pointer) and the pointer to stay at the same screen point. Evidence: `sidebar-row-before.png`, `sidebar-row-after.png`, `sidebar-row.json`, the app log and `result.json`.

## Gotchas

- The pointer is never moved between the click and the second screenshot; `sidebar-row.json` records both screen positions.
- The comparison uses the band the pointer sits on, so it does not depend on the rest of the sidebar. Rows are located from the screenshot, not from layout constants.
- Only SSH is replaced; the sidebar, the click handling and the chat reopen run in the real app.
