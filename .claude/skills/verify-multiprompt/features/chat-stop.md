# Stop a running reply

Journeys: chat-view

## Sub-features

- Stop the current run from the square Stop button, Escape or the Stop palette action; keep the chat available for another message.

## How to get to it (user POV)

Open a working chat with an empty message box. Click Stop inside the box, press Escape, or select Ctrl+K Chat View: Stop the agent. The tab context menu and chat More menu offer the same action. Focus the composer and dismiss autocomplete or transcript selection before using Escape. Typed text replaces Stop with Send; use Escape or the palette for the draft-preservation case.

## Driving it with drive.ps1

Preconditions: a healthy hosted Windows instance, matching executable/hash/version and the exact Part A/B or provider prerequisites below. The named Journeys are supporting existing routes; they do not exercise the complete path unless explicitly stated.

1. On a healthy Part B host, send a request that stays busy long enough to stop. Capture the working state.
2. Click the square Stop button with real mouse input. Require the host's current turn to end and the working dots to disappear.
3. Repeat with Escape and the palette action. Send a follow-up after each stop and require one reply.
4. Preserve the prior messages and unsent draft. Observe host cancellation independently; disappearance of the button alone is not proof.

`chat-view` includes the `stop-in-box` visual case. It proves button placement and Escape delivery to the local stand-in, not interruption of a real server process.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### stop: Stop

Follow the priority Stop recipe above with button, Escape and palette independently.

Observable proof: Real current turn ends; a subsequent message receives one reply.

UNREACHABLE for live interruption until Part B exposes a busy cancellable host and the native button/key/palette sequence. chat-view stop-in-box proves placement only.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_STOP_OFFSET` | Ctrl+K, type **stop the agent**, then select the matching action with Up/Down and Enter. Follow `stop` above. |
| `SEARCH_TABCTX_CHAT_STOP` | Right-click the intended tab, then choose **chat view stop the agent interrupt escape**. Follow `stop` above. |

## Gotchas

UNREACHABLE for real interruption until Part B supplies a busy, cancellable real host and the desktop driver covers button, Escape and palette cancellation. Track SOFT-2566 for busy-send/Stop product behavior; do not change product code in this map PR.

Part A is [PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070): `seed-profile.py`, `seed-profile.ps1` and the `chat-real-size` journey. Part B is [PR 1072](https://github.com/valentinyeo/multiprompt/pull/1072): the runner-owned SSH/tmux `server-chat` journey. These stems are not available on this branch until those prerequisites are integrated; do not add replacement fixtures here.
