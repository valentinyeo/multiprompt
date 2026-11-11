# Live chat pane

A live chat is a tmux tab named `live-*`. This journey binds two tabs to those names. Each chat uses its own `zsb` session token.

## Sub-features

- `chat-one-selftest`: run the shipped `zsb selftest`. Require all seven steps, the exact session and hosting chat name, and an active visible pane.
- `chat-one-agent-path`: open a page through that chat's token. Require an open pane with its own window id and hosting tab name.
- `chat-one-navigate`: navigate to another page. Require the returned page title and URL match.
- `chat-two-isolation`: the second chat keeps its pane closed while the first opens pages.
- `chat-two-own-page`: the second chat opens its own background pane and page.
- `chats-keep-their-own-pages`: both chats retain separate windows and pages. Neither chat lists the other's pages.
- `chat-two-background-soak`: hold agent calls on the background chat for the requested soak and keep its pane, its page, the selected tab and the visible pane unchanged.

## How to get to it (user POV)

- Open a new chat and ask Claude to run `zsb selftest`.
- The result passes and names that chat.
- Ask Claude to open a page. It belongs to that chat's pane.

## Driving it with control.ps1

Preconditions match [Session open](session-open.md) and [Browser switch speed](browser-switch-speed.md). The runner uses offline mode, an app-owned loopback listener, pinned Chrome with the real extension, Python and Git Bash. SSH attachment is expected to fail.

- **Dispatch.** Run `gh workflow run verify.yml --ref <branch> -f feature=live-chat-pane`.
- **Setup.** Create a group through the palette. Use `session-open` for `live-1` and `live-2`. Require saved tmux tabs with those names. Serve two local pages per chat.
- **Selftest.** Select chat one and confirm the actual switch trace matches its saved tab index. Published Inbox selection can lag behind keyboard input. Run the shipped wrapper with its session token and app listener port. Require successful exit, matching session and chat name, active and visible hosting, and passing open, text, type, click, screenshot, hosting and close steps. Retain the JSON summary and raw output.
- **Chat one.** Use its token to open a page. Require connected published pane state, matching `status` and `pane-info`, and exactly one matching page in `tabs`. Navigate to its second page and wait for its exact title and URL in the pane tab list. A loading acknowledgement is not page evidence.
- **Isolation.** Before opening chat two, require its published pane stays closed with connection id zero.
- **Chat two.** Open its page in the background. Require a distinct window id and matching chat name. Require its tab list excludes both first-chat URLs.
- **Keep pages.** Read both chats' state without switching. Require chat one retains its original window and second page, and excludes chat two's page.
- **Background soak.** With chat one still selected and chat two never viewed, run `status` on chat two's token every 30 seconds for `AGENT_SOAK_SECONDS`, and `tabs` every fourth call. Require every call to answer for chat two with the same open window, its page still in that pane, the selected tab unchanged, the app still foreground, the visible pane still visible, and no `switchToShell` line in the retained debug trace. No keyboard or mouse input during the soak. `verify.yml` sets the soak for this journey: 20 minutes when dispatched, and a shorter stand-in when the harness sets `AGENT_SOAK_SECONDS` itself.
- **Evidence.** Inspect before/action/after screenshots, `chat-one-selftest.json`, selftest output, per-command request/reply pairs, both pane JSON files, session snapshots and `result.json`.

## Gotchas

- The real reader host, tmux and Claude agent are absent. This proves the desktop side with explicit session tokens, not a real hosted chat creation or agent environment. The reader suite checks the supplied environment separately.
- The wrapper selftest uses a real public test page. It fails if the page or pane cannot be reached. An initially empty pane retains a blank tab after the test page closes; existing user tabs are never closed.
- An isolated fixture relay removes only fixture authentication before forwarding unchanged session requests to the app listener. It does not answer browser commands. This replaces the remote relay boundary, not the app or extension. No real relay credential is used.
- The wrapper runs from Git Bash's executable directory so its native Python subprocesses resolve Git Bash rather than the Windows subsystem launcher.
- Background pane ownership uses app-published state and extension tab lists. Screenshots do not prove a background pane is visible.
- Inspect screenshots and cleanup before accepting a passing run.
- The soak drives only chat two's token. It proves the app keeps a background pane across repeated agent calls with the human's tab untouched; it does not claim the owner's desktop or a real hosted agent.
