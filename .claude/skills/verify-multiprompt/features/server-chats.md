# Real server chats

Journeys: chat-delivery, chat-model, chat-slash

## Sub-features

- Create, reopen and exchange replies with Claude, Codex, Pi and Cursor on the selected server and workspace folder.

## How to get to it (user POV)

Ctrl+T, Alt+T and the sidebar plus use the default workspace launch. Use Ctrl+K New Claude session, New Codex chat, New Pi chat or New Cursor chat for explicit provider selection; choose the server and folder when requested. Pi /login and its Log in row have separate authentication prerequisites. New Claude in terminal is a distinct terminal action, not live-chat proof.

## Driving it with drive.ps1

Preconditions: a healthy hosted Windows instance, matching executable/hash/version and the exact Part A/B or provider prerequisites below. The named Journeys are supporting existing routes; they do not exercise the complete path unless explicitly stated.

1. Use the merged Part B runner-owned real SSH/tmux host that `feature=server-chat` installs on the Windows runner (see [server chat](server-chat.md)). Do not create another server fixture; Part A's real-size profile never landed.
2. Open each available provider chat on that server. Send a prompt requesting one unique marker, require one matching logical reply turn, leave and reopen the chat.
3. Require the same server, session ID and history, exactly one sent user turn and one logical reply turn, and an editable draft after returning.
4. Pair native keyboard/screenshot proof with the receiving host's transcript. A painted synthetic reply alone is insufficient.

`chat-delivery`, `chat-model` and `chat-slash` exercise production reader/host paths through disclosed SSH/provider stand-ins. Their existing journeys are useful but do not certify a real SSH server or paid provider.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### server: Real server chat creation

Follow the priority server-chat recipe above, using the selected server and folder for each provider.

Observable proof: One receiving session and one reply per unique input; stable session identity on reopen.

REACHABLE for real SSH and tmux through `feature=server-chat`, which owns both ends of a loopback OpenSSH/tmux connection and a deterministic stream-json provider. UNREACHABLE for a paid provider reply: that needs an installed authenticated provider CLI on the runner. `chat-delivery` remains a stand-in.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CODEX_TMUX_OFFSET` | Ctrl+K, search for **New Codex chat**. Follow `server` above. |
| `SEARCH_NEW_CLAUDE_CHAT_OFFSET` | Ctrl+K, type **new claude session**, then select the matching action with Up/Down and Enter. Follow `server` above. |
| `SEARCH_NEW_CLAUDE_TERMINAL_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_NEW_CURSOR_CHAT_OFFSET` | Ctrl+K, type **new cursor chat**, then select the matching action with Up/Down and Enter. Follow `server` above. |
| `SEARCH_NEW_ANTIGRAVITY_CHAT_OFFSET` | Ctrl+K, type **new antigravity sessions**, then select the matching action with Up/Down and Enter. Follow `server` above. |
| `SEARCH_NEW_PI_CHAT_OFFSET` | Ctrl+K, type **new pi chat**, then select the matching action with Up/Down and Enter. Follow `server` above. |
| `SEARCH_NEW_TERMINAL_OFFSET` | Ctrl+K, type **new terminal**, then select the matching action with Up/Down and Enter. Follow `server` above. |
| `SEARCH_OPENALL_HOST_BACK_OFFSET` | Open the named submenu, then choose **back**. Follow `server` above. |
| `SEARCH_OPENALL_HOST_DE_OFFSET` | Ctrl+K, search for **open all vps tmux sessions**, then choose the German host row. Follow `server` above. |
| `SEARCH_OPENALL_HOST_INNE_OFFSET` | Ctrl+K, search for **open all vps tmux sessions**, then choose the inner host row. Follow `server` above. |
| `SEARCH_OPENALL_HOST_UK_OFFSET` | Ctrl+K, search for **open all vps tmux sessions**, then choose the UK host row. Follow `server` above. |
| `SEARCH_OPENALL_OFFSET` | Ctrl+K, search for **open all vps tmux sessions**. Follow `server` above. |
| `SEARCH_OPENFOLDER_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_OPEN_SESSION_MENU_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_RECOVER_REPO_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TMUX_OFFSET` | Type a query in Ctrl+K to discover tmux sessions; choose the displayed title/session and verify its host. Follow `server` above. |

## Gotchas

Real-server transport is reachable through the merged `server-chat` journey: runner-owned WSL OpenSSH, a restricted runner-SID key and a real tmux session. Still UNREACHABLE is a paid provider reply, which needs an installed authenticated provider CLI; list each missing provider separately.

Part A ([PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070), `seed-profile.py`, `seed-profile.ps1`, the `chat-real-size` journey) was closed unmerged, so master still has no real-size seeded profile. Part B ([PR 1072](https://github.com/valentinyeo/multiprompt/pull/1072)) merged on 2026-11-18 as the runner-owned SSH/tmux [server chat](server-chat.md) journey, which runs as `feature=server-chat`; use it rather than adding another server fixture. Do not add replacement real-size fixtures here until a Part A equivalent lands.
