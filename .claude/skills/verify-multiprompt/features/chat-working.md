# Inline working dots

## Sub-features

- Three dots sit in the next assistant reply slot while the existing working signal is active.
- Animation changes the dots, without changing message geometry.
- Finishing or waiting for permission removes the indicator.

## How to get to it (user POV)

Open Chat View with Alt+C while an agent works.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-working`, optionally `tag=v<version>`.
The job-only console stand-in prints a question and Claude's working line.
The journey emits the supported ACTIVE and DONE hook notifications for that owned session, as a real hooked agent does.
The real app detects it and paints its native transcript.
The journey finds three separate round dots from screenshot pixels, requires a different animation frame, signals the stand-in to reply, and requires the dots to disappear.
Inspect `working-0.png`, `working-1.png`, their crops, `after.png` and `working-proof.json`.
IGSH-1665 waits for the published current step plus minutes or the exact idle Ready reply, then captures `second-line-{working,finished}-{light,amoled,edgegray}-{inbox,sidebar}.png` through real keyboard actions.
The existing gray theme is Edge Grey, not Graphite 2. These captures do not claim an unavailable theme.
The stand-in supplies Inspecting files and Ready, not needs-you questions or real provider activity.
Native layout tests additionally compare the placeholder rectangle against a real one-line reply, including input-wait suppression.

Branch builds also run `test-live-working` before the console journey. The isolated Windows test passes synthetic queued and delivered outbox states and live `turn.started`, `text.delta`, and `turn.ended` event pages through the production reducer, ready callback, layout and native transcript painter. It saves `live-working-*.bmp`, `live-working-native.log`, and `live-working-observations.json`. Inspect queued, accepted-before-event, busy, reply-delta, and answered frames. The JSON records visibility, slot, timer, painted dots, animation and elapsed time from synthetic enqueue. These observations are diagnostic, not acceptance assertions.

The native test does not send input, run a transport, contact a provider, or pump the application window's event loop. It calls the production timer tick after a 300 ms wait. The delivered state is a constructed boundary, not proof of transport acceptance. It cannot establish send-to-paint latency or clean app-process teardown. The separate console journey exercises real input and owned cleanup, but not live events. Neither replaces a real live-agent journey.

## Gotchas

No provider is contacted. Only the console boundary is replaced.
The pre-fix release must fail with `IGSH-924 inline dots painted` after the owned working console and transcript are ready.
Never run this journey on a user's machine.
