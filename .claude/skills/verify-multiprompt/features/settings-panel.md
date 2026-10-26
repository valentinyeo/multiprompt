# Settings panel

Open the approved centred Settings panel using Ctrl+, and the Settings command in Ctrl+K. Close using Escape or the round close button. Existing settings remain backed by their original stores.

## Driving it with control.ps1

Run `control.ps1 -Feature settings-panel` through the existing GitHub Verify desktop workflow. The journey runs an isolated app, never the laptop's running copy. It must identify the actual owned Settings window, not a mock or a screenshot fixture. `settings-panel.png` and `settings-palette.png` show both entry paths.

The pre-panel master must fail when Ctrl+, cannot open Settings. This is the negative control, not a timing exemption.
