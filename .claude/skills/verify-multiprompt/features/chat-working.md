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
Native layout tests additionally compare the placeholder rectangle against a real one-line reply, including input-wait suppression.

## Gotchas

No provider is contacted. Only the console boundary is replaced.
The pre-fix release must fail with `IGSH-924 inline dots painted` after the owned working console and transcript are ready.
Never run this journey on a user's machine.
