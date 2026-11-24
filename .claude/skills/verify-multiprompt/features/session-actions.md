# Quit, archive and delete chats

Source files: src/workspaces.zig, src/workspace*, src/session.zig, src/sidebar.zig, src/session*, src/ssh_reconnect.zig, src/launch_plan.zig, src/ssh*, src/tmux*, src/launch_cache.zig, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-session-actions/drive.ps1, tools/verify-session-actions/*, tools/fixtures/SOFT-2762/*, src/archive.zig, src/account_desktop.zig, src/sidebar_attention.zig

## Sub-features

Ctrl+K Quit multi bot quits without stopping agents; Ctrl+W does not quit. Ctrl+Shift+W is the active-chat delete shortcut, while this journey selects Delete through the palette. Deletion saves its history identity before stopping it. Alt+X has no action. Right-click opens the seven shared palette actions plus New tab on server, with Delete last and red.

## How to get to it (user POV)

Choose Ctrl+K Quit multi bot, reopen, then right-click a chat. Search Ctrl+K for Copy chat ID or Archive chat. Press Ctrl+Shift+W to delete the active chat.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=session-actions` on the verification branch. The dedicated hosted Windows driver launches the real app with an isolated offline profile. It seeds two saved remote tabs and distinct synthetic provider transcripts once. An explicit SSH boundary dispatches production session-end commands to two independently owned synthetic agent processes.

Require quit/reopen to keep both processes and chats. Search `close tab`, require the Archive chat target, and close the local CMD tab without stopping either synthetic remote process. This local check does not prove remote archive keeps its tmux carrier running. Require right-click to expose exactly the eight ordered IDs (the seven shared actions plus New tab on server), then open the background chat's inline Rename without changing the active chat. Capture paired closed/open menu screenshots after selecting each built-in Light, AMOLED and Mid theme through real input. Delete the background chat through that menu, then delete the active chat with one shortcut. Require exactly one stop request per identity and both archive identities.

Search each deleted chat's name through Ctrl+K **archived sessions**, then filter the All Sessions Archived list and open its existing archived resume action. Since SOFT-2444 the plain Ctrl+K session list shows active sessions only, so the old direct archived rows no longer exist. The SSH boundary accepts only a resume command whose saved identity matches an ended fixture, then supplies a new console transport without modifying either original transcript. Require an owned visible native transcript, nonempty native text layout and the correct original question and answer copied through the app's Select all command. Reject the other chat's text. Save `history-Alpha.txt`, `history-Beta.txt` and matching screenshots, and verify both original transcript hashes again. Require zero remaining owned processes. Retain launch identity, actions, saved files and boundary logs in `verify-session-actions`.

The sessions journey separately uses the close/archive palette path when removing its temporary tabs. Remote archive persists identity and kills its tmux carrier; it is distinct from Delete's explicit provider-stop identity.

## Gotchas

This boundary proves native routing, lifecycle requests and transcript access through archived resume, not real SSH, paid agents, account sync or Android. Archived resume is not a read-only history viewer; the production path normally resumes the provider. The original synthetic agent processes must remain stopped during the history checks. A run that verifies only retained bytes does not pass history readability.

IGSH-1747 follows up on deleted chats reopening with the wrong assistant. Desktop-local session and archive records save provider IDs; older records without one retain Claude behavior, and older clients ignore the added field. No shared server or Android wire format changes. Codex and Pi resume through existing host configuration; provider roundtrip and resume command unit checks are authored but need a hosted run. They do not prove live-provider history. IGSH-1748 follows up on copied local IDs changing after restart. Its local CMD copy-ID journey checks the same identity after restart; the combined revision still needs a hosted run.

Pixel counts are supporting evidence only; independently review screenshots for the eight labels, red Delete and 4px palette panel, input, selected-row and keycap corners. The shared palette is used by both right-click and Ctrl+K; do not add a second menu. A reviewer who changed the implementation cannot approve its appearance. The available built-in theme is named Mid, not Graphite 2. Do not silently equate them: comparison with the approved Figma themes and independent design QA remain separate gates.
