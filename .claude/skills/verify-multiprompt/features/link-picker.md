# Link picker

## Sub-features

- Alt+W shows both links above the native Chat View children.
- AMOLED selection uses the existing rounded dark control and outline.
- Escape restores chat; Down and Enter open the selected second URL.

## How to get to it (user POV)

Print two links in a console, open Chat View with Alt+C, then press Alt+W.

## Driving it with control.ps1

Run the Link picker workflow or verify.yml with feature=link-picker.
The journey selects AMOLED through the palette, prints two loopback URLs in the real console, switches to Chat View, and presses Alt+W.
It requires the native transcript to become hidden, saves action.png, checks dark selection and outline pixels with no blue, cancels and verifies restoration, then reopens, selects the second row and presses Enter.
A loopback listener must receive the exact second URL request after Enter, whether the configured browser opens externally or docked; link-request.json records the request and after.png records restored chat.
Pass a published tag to verify a released binary; no tag builds the branch.

## Gotchas

The offline CMD has no live agent conversation. Printed console URLs exercise the same production picker scan without seeding settings or app state.
A job-owned loopback socket supplies both URLs and records a real browser request, without contacting outside services. The listener closes even when the journey fails.
Run only on isolated GitHub Windows runners, never on the user's desktop.
