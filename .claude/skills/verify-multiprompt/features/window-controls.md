# Window controls

## Sub-features

The app draws three grey minimize, maximize/restore and close buttons at the top right. There is no native Windows title bar or replacement full-width header. The session separator reaches the top edge. Native resize edges, a thin draggable top strip, double-click maximize and Windows snapping remain available.

## How to get to it (user POV)

Open Multiprompt. Use the three top-right window buttons. Drag the empty top strip, double-click it to maximize, or use Win+Left to snap. Chat starts near the top edge instead of below a Windows caption.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=window-controls`, optionally with a published `tag`. The identical driver must reject v0.28.932 specifically with `native title bar still consumes chat height`, not a setup or compilation error.

The workflow uses actual monitor DPI 96, 120 and 144. It restores display resolution and scaling after each isolated Windows run. It records the frame, client origin, native caption inset and real transcript rectangle. Chat must start within the existing eight-pixel pane margin plus six-pixel focus pad and four-pixel content gap; no full-width replacement header is allowed.

For restored and maximized windows, select Dark, Light and AMOLED through the palette. A maximized client must exactly fill the monitor work area; invisible native resize borders outside that area are not usable content. The existing selected chat title must remain readable after each live theme change. Save six screenshots and measure all three grey glyphs, all three native hit codes and the separator's first six pixels. Drive maximize and restore through the same button, then use actual mouse dragging, double-clicking, Win+Left, resize-edge dragging, minimize and close. A real docked browser must leave every control pixel unchanged; a changed-pixel negative control must fail the same comparison. Maximize and restore must also work while that browser has focus. Closing must exit the owned process normally. Doctor runs before close, never after the deliberately closed app.

Inspect `window-controls-baseline.json`, `window-controls-chat-height.json`, `window-controls-pixels.json`, `window-controls-actions.json`, screenshots, build identity and cleanup. The `title-bar` feature runs this same journey; its former DWM-owned-caption oracle is obsolete because the requested app no longer has that caption.

## Gotchas

Run only on GitHub Windows, never on the user's desktop. Mouse targets must belong to the exact foreground app HWND. A hit-test response alone does not prove an action: state and geometry after real input must change. An unrelated setup failure is not the negative control. Compare the published executable hash with the release checksum before claiming released proof.
