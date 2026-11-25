# Chat in long sessions

Journeys: chat-full-history, chat-switch-speed, chat-newest

## Sub-features

- Read the complete conversation, move between older and newer messages, search, copy, leave, and return without losing the draft; record the actual return position.
- Receive messages while reading older history without an unsolicited jump.

## How to get to it (user POV)

Select a long chat in the sidebar. Use Page Up, Home, Find, selection and Copy; use End or two Shift+G presses in an empty box to return to newest.

## Driving it with drive.ps1

Preconditions: a healthy hosted Windows instance, matching executable/hash/version and the exact Part A/B or provider prerequisites below. The named Journeys are supporting existing routes; they do not exercise the complete path unless explicitly stated.

1. There is no real-size seeded profile: Part A ([PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070)) was closed unmerged. Until an equivalent lands, use the largest existing fixture and say which one you used. Do not build a second fixture generator here.
2. Open a long chat, scroll up, type an unsent marker, switch sessions and workspaces, and return.
3. Find and copy a known early message. Jump to newest through keys and Ctrl+K. Repeat after restart.
4. Require the early and last message text, the unchanged draft and observed reading position in screenshots and native observations. Arrival while scrolled up must show the new-message control rather than steal the position.

Existing hosted routes are `verify.yml feature=chat-full-history`, `chat-switch-speed` and `chat-newest`. Their individual feature files define assertions and fixture boundaries. They are separate focused journeys, not proof that every step above has run.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### long: Long-session chat

Follow the priority long-session recipe above with Part A's profile.

Observable proof: Known earliest/latest text, draft match after switches and restart; record the actual opening position.

Journey: chat-full-history, chat-switch-speed, chat-newest. Complete real-size proof requires Part A.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_NEWEST_OFFSET` | Ctrl+K, type **jump to newest message**, then select the matching action with Up/Down and Enter. Follow `long` above. |

## Gotchas

UNREACHABLE for the complete real-size journey: no real-size profile exists to expose message IDs to these journeys. Existing default 50-message, long-proof and switch fixtures are not a real-size profile. Source currently resets scroll on a session change (`src/chat_session.zig`); preserving position across that change is an unproven product expectation, not a passing assertion. Arrival anchoring within the same chat is a separate path.

Part A ([PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070), `seed-profile.py`, `seed-profile.ps1`, the `chat-real-size` journey) was closed unmerged, so master still has no real-size seeded profile. Part B ([PR 1072](https://github.com/valentinyeo/multiprompt/pull/1072)) merged on 2026-11-18 as the runner-owned SSH/tmux [server chat](server-chat.md) journey, which runs as `feature=server-chat`; use it rather than adding another server fixture. Do not add replacement real-size fixtures here until a Part A equivalent lands.
