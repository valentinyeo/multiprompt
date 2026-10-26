# Composer buttons

## Sub-features

- Round attach, microphone and Send or Stop controls share one bottom line while the draft grows.
- One-line and six-line drafts retain screenshots and measured button rectangles.
- A working agent with an empty draft shows Stop; typing replaces Stop with Send in the same slot so at most two buttons show on the right, clicking Send takes the draft, and Escape still reaches the agent.

## How to get to it (user POV)

Open Chat View with Alt+C, then type a draft. Shift+Enter adds lines without sending.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=composer-buttons`, optionally `tag=vX.Y.Z`. This uses the normal Chat View toggle and working console stand-in, without requiring unrelated transcript-selection or message-delivery scenarios. The full `chat-view` journey retains all those checks unchanged.

Require `round-bottom-composer-buttons`, `stop-in-box` and `grey-buttons` to pass. Inspect `composer-1-line.png` and `composer-6-line.png`; the result retains each draft and the attach, microphone and Send rectangles. The draft must really contain one or six lines, and those controls must have equal square bounds and matching top and bottom edges. Native Windows pixel tests additionally check circle backgrounds for every control, including idle and active microphones, at multiple sizes.

## Gotchas

The working console stand-in replaces only the agent at its console boundary. No provider, microphone hardware, user data seeding or laptop input is involved. Release-tag runs verify the published executable, not a rebuilt substitute.
