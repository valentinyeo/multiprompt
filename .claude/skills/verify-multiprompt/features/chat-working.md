# Inline working dots

## Sub-features

- Three dots sit in the next assistant reply slot while the existing working signal is active.
- Animation changes the dots, without changing message geometry.
- Finishing or waiting for permission removes the indicator.

## User entry points

Open Chat View with Alt+C while an agent works.

## Driving recipe

Dispatch `verify.yml` with `feature=chat-working`, optionally `tag=v<version>`.
The job-only console stand-in prints a question and Claude's working line.
The real app detects it and paints its native transcript.
The journey finds three separate round dots from screenshot pixels, requires a different animation frame, signals the stand-in to reply, and requires the dots to disappear.
Inspect `working-0.png`, `working-1.png`, their crops, `after.png` and `working-proof.json`.
Native layout tests additionally compare the placeholder rectangle against a real one-line reply, including input-wait suppression.

## Gotchas

No provider is contacted. Only the console boundary is replaced.
The pre-fix release must fail with `IGSH-924 inline dots painted` after the owned working console and transcript are ready.
Never run this journey on a user's machine.
