# Live chat pane

A live chat is a tmux tab whose session name is `live-*`, so this journey binds two tabs to `live-*` names and drives each chat's own `zsb` session token to check it opens, names and fills only its own browser pane.

## Sub-features

- `chat-one-agent-path`: `zsb status` from the first chat's own session token reports that chat's pane as open with a window id.
- `chat-one-navigate`: `zsb navigate <page>` from the first chat puts that page in the first chat's pane.
- `chat-two-isolation`: the second chat has no pane and no page while the first chat shows its own.
- `chat-two-own-page`: the second chat opens its own pane and page.
- `chats-keep-their-own-pages`: returning to the first chat shows its page again, not the second chat's.

## How to get to it (user POV)

- Valentin presses Ctrl+T in a new chat and asks Claude "can you see your browser pane?".
- Claude runs `zsb status` and gets that chat's pane, then `zsb navigate <url>` and the page appears in that chat's pane only.

## Driving it with control.ps1

Preconditions are the same as [Session open](session-open.md) plus the extension build that [Browser switch speed](browser-switch-speed.md) uses: single-window offline mode, a live initial CMD tab, the app-owned loopback listener, and a docked pane with a real extension window id. SSH attachment is expected to fail.

- **Dispatch.** Run `gh workflow run verify.yml --ref <branch> -f feature=live-chat-pane`.
- **Setup.** Create a group through the palette, then create `live-1` and `live-2` tabs through `session-open` and require both saved tabs have kind `tmux` and the exact `live-*` session. Serve two local pages whose titles are the chat markers.
- **Chat one agent path.** Select chat one, open its pane through Ctrl+K `open browser`, require a connected docked pane with a window id, then send `ZSB:live-1:` `status` and `navigate <chat one page>` and require the reply names `live-1`, reports the pane open, and the pane window title becomes the chat one marker. Capture `chat-one-page.png`.
- **Isolation.** Require chat two's published pane stays closed with connection id 0, select chat two, require no owned pane is visible, and require `ZSB:live-2:` `status` reports `pane: closed` for `live-2`. Capture `chat-two-without-page.png`.
- **Chat two own page.** Open chat two's pane, send `ZSB:live-2:` `navigate <chat two page>`, require the pane window title becomes the chat two marker. Capture `chat-two-own-page.png`.
- **Keep pages.** Return to chat one, require its pane window title is the chat one marker again and `ZSB:live-1:` `status` still reports its open pane. Capture `chat-one-keeps-page.png`.
- **Evidence.** `session-before.png`, `chat-one-page.png`, `chat-two-without-page.png`, `chat-two-own-page.png`, `chat-one-keeps-page.png`, `pane-chat-one-connected.json`, `pane-chat-two-connected.json`, the request and reply pair of every `zsb` command, `session-live-chats.json`, `session-live-chats-after.json`, `result.json`.

## Gotchas

- The reader host, real tmux and the Claude agent are not on a Windows runner. The tab identity (`live-*` session name), the pane assembly and the `zsb` routing by session token are covered; the agent's environment (`ZSB_SESSION`, `MULTIPROMPT_TAB`, no `TMUX`) is covered by the reader test suite instead.
- Both chats run the same no-account offline app; a chat that shows another chat's page fails the isolation steps.
- Screenshots still need inspection; a green workflow is not a claim that the journey has already passed.
