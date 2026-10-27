# App icon

## Sub-features

The Windows app icon is the approved white robot head on a dark tile. The same icon shows on the taskbar button, in the window's small and large icon slots, and as the icon of the executable file. The 16 pixel frame still reads as a robot: a bright head, a dark visor and two light eyes.

## How to get to it (user POV)

Open Multiprompt and look at its taskbar button, the window corner and the file icon in Explorer. There is no setting; the icon is compiled into the executable from `assets/icon.ico` through `assets/zigshell.rc`.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=app-icon`, optionally with a published `tag`. The journey is `tools/verify-app-icon/drive.ps1`. It starts the real executable in an isolated profile on the GitHub Windows desktop, finds the visible app window by owning process and reads the icons Windows reports through `WM_GETICON` for both the large and the small slot. It also extracts the executable's own icon and requires the executable to embed the bytes of all five approved frames (16, 32, 48, 64 and 256 pixels), which is how the 16 pixel frame is covered. Each icon is compared with the matching approved frame from `assets/icon<size>.png` over a dark background, and the mean per-channel difference must be at most 8 of 255.

The run also captures the full primary screen, not a window rectangle, and saves the bottom strip as `taskbar-strip.png`, so the taskbar button is visible in the evidence. Inspect `desktop.png` and `taskbar-strip.png` yourself; the pixel comparison covers the icon handles, the screenshot covers what the user sees.

Red control: dispatch the same journey with `tag=` set to a release published before this change. The comparison against the new frames must fail with `taskbar-icon-is-robot` and `exe-icon-is-robot` reporting a large difference, not a setup error.

Evidence: `result.json`, `exe-icon.png`, `window-icon-big.png`, `window-icon-small.png`, `desktop.png`, `taskbar-strip.png`, cleanup.

## Gotchas

Run only on GitHub Windows, never on the user's desktop. A hosted runner may show the taskbar without a button for the app until the window has been foreground for a few seconds; the driver waits five seconds after the window appears. The window icon slots can be filled by the class icon, so the executable icon is checked separately. When the screen capture shows no taskbar, report that and rely on the icon handle checks, never claim a taskbar screenshot that does not show one.
