# Title bar

## Sub-features

Multiprompt now draws its own three grey window buttons, without the Windows title bar. The native DWM-caption comparison previously used here no longer describes the app. `title-bar` retains its existing dispatch name and runs the [window controls](window-controls.md) journey.

## How to get to it (user POV)

Use the top-right minimize, maximize/restore and close buttons. Drag or double-click the thin top strip. The left separator reaches the top edge and chat uses the reclaimed caption height.

## Driving it with control.ps1

Use `feature=window-controls` for three real DPI cases, including published release verification. The existing `feature=title-bar` dispatch runs the same native-input, screenshot and geometry checks at its existing real DPI settings. See the window controls map for evidence and negative-control requirements.

## Gotchas

Do not compare against DWM caption-button bounds: those buttons are no longer painted. Require actual control actions, visible grey glyphs, native resizing and snapping, and no replacement full-width chat header. Verification runs only on disposable GitHub Windows desktops.
