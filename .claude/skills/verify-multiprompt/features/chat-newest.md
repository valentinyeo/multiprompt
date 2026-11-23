# Jump to the newest chat message

Covers: palette:SEARCH_CHAT_NEWEST_OFFSET, shortcut:palette-actions/shift-g-twice-end-ctrl-k-jump-to-newest-message
Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/drive.ps1, tools/chat-newest-proof.mjs

## Sub-features

- Shift+G twice within 600 ms, starting in an empty composer, jumps from older messages to the newest message and leaves the box empty.
- Lowercase `gg`, capital `GG` typed more than 600 ms apart, and `GG` within an existing draft remain ordinary text without jumping.
- Ctrl+K `jump to newest message` shows the single renamed production action. Enter executes it without changing the draft.
- Each outcome appears directly in `result.json` checks, with native composer observations, raw input actions, screenshots and owned cleanup.

## How to get to it (user POV)

Open Chat View, scroll up and focus the empty message box. Press Shift+G twice quickly. Alternatively search Ctrl+K for `jump to newest message` and press Enter.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-newest`. Download `verify-chat-newest`.

The existing chat-delivery boundary seeds an isolated saved tmux tab and a synthetic 50-message Claude transcript. The real app launches its production reader over the SSH stand-in. Native input opens Chat View. The driver requires a scrollable transcript, scrolls away from newest, and uses genuine SendInput typing to check `draftGG`, lowercase `gg` and slow capital `GG`. Native WM_GETTEXT must preserve those exact drafts, and the transcript must remain scrolled up.

After clearing the composer, genuine Shift+G twice must produce a new bottom frame and an empty native composer. Scroll away once more. Real Ctrl+K search must select production row 6465 with the visible name `Jump to newest message`. Enter must return to newest again.

`tools/chat-newest-proof.mjs` checks the raw observations and log ranges independently. A later palette jump cannot satisfy the earlier keyboard-jump assertion. It also checks input timing, owned executable identity, screenshots and zero-process cleanup. Its negative fixtures run on the hosted journey before desktop driving.

Inspect `chat-newest-before.png`, `chat-newest-after.png`, `chat-newest-draft.png`, `chat-newest-palette.png`, `full-history/newest.json`, `actions.json`, `result.json` and `cleanup.json`. The artifact retains the established boundary's `full-history` case directory, but does not run the separate history/performance journey.

## Gotchas

The current keyboard evidence independently checks the slow G interval, not the fast pair timing. The palette draft-preservation case starts empty; a nonempty-draft palette case remains unexercised. Keep those limits separate from the successful jump assertions.


Run only on GitHub Windows. This proves native keyboard, draft and palette behavior, not a real provider, account sync or live SSH server. No restart or latency promise belongs to this shortcut. The existing `chat-full-history`, `chat-focus` and broad `command-palette` recipes remain unchanged; their unrelated baseline failures do not replace this focused proof. Shortcut documentation remains covered by the hosted shortcut-row and documentation checks.
