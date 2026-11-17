# Clear a server chat

Journeys: chat-slash

## Sub-features

- Clear the current agent context without deleting the chat identity or silently resending held messages.

## How to get to it (user POV)

In a server chat, type /clear into the message box and press Enter. Do not substitute Reset this chat or Fresh start.

## Driving recipe and observable proof

1. Start with a healthy Part B real server chat containing a known exchange and an unsent marker.
2. Invoke /clear through the composer, wait for the host result, then send a new unique message. Use Escape to dismiss a completion popup before sending /clear as literal text.
3. Require the originating chat alone to change context, the new message to arrive once, and a usable reply. Retain the raw host result and before/after screenshots.
4. If the command is refused, require the visible explanation and unchanged editable draft. Record a product failure rather than replacing /clear with another action.

The existing `chat-slash` journey checks command/mode routing through a synthetic host; it does not currently drive /clear. It is supporting evidence only.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### clear: Clear

Follow the priority /clear recipe above; never replace it with Reset or Fresh start.

Observable proof: Host context changes once or a precise refusal appears, with usable chat/draft afterward.

UNREACHABLE until Part B supplies a /clear-capable real agent and the native driver exercises /clear.

## Gotchas

UNREACHABLE until Part B provides a real host and a /clear-capable authenticated agent, plus a desktop /clear journey. Existing chat-slash coverage must not be called /clear coverage. Source triage: `src/chat_slash.zig` sends /clear as an ordinary message unless completion marks it unavailable; the live host has no dedicated clear control. A send acknowledgement is not context-reset proof. Record unsupported host semantics as a product gap, not a fixture prerequisite.

Part A is [PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070): `seed-profile.py`, `seed-profile.ps1` and the `chat-real-size` journey. Part B is [PR 1072](https://github.com/valentinyeo/multiprompt/pull/1072): the runner-owned SSH/tmux `server-chat` journey. These stems are not available on this branch until those prerequisites are integrated; do not add replacement fixtures here.
