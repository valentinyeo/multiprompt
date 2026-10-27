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
The app-written saved URL and a native docked browser must match that selection; after.png records the result.
Pass a published tag to verify a released binary; no tag builds the branch.

## Gotchas

The offline CMD has no live agent conversation. Printed console URLs exercise the same production picker scan without seeding settings or app state.
The loopback port is deliberately closed; navigation verification checks the selected URL and browser creation, not web connectivity.
Run only on isolated GitHub Windows runners, never on the user's desktop.
