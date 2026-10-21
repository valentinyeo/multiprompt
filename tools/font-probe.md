# Windowless chat font probe

Build on a development server with Zig 0.16:

```
zig build font-probe -Dtarget=x86_64-windows-gnu
zig build font-probe -Dtarget=aarch64-windows-gnu
node --test tools/font-probe.test.js tools/one-font.test.js
```

Run `font-probe.exe` in an empty output directory on Windows. It creates no window and does not interact with the app. It writes a top-down 32-bit BMP and JSON word boxes for each combination of body weight 400/500 and GDI quality 4/5/6, plus DirectWrite natural-symmetric grayscale and ClearType. Bold remains 700. DirectWrite obtains the same selected font through `CreateFontFaceFromHdc`; both paths load the app's embedded font resources through `fonts.register()`.

The fixed line is `Clear bold words make **bold** text readable`. The repeated word allows a same-glyph bold/body ink comparison rather than confounding different letter shapes. Word boxes include vertical padding; JSON also records the physical em size. Normalize coverage sums by character count times em-size squared for comparable per-glyph ink. A nonzero pixel is inked; partial coverage is strictly between 0.1 and 0.9.

`--shipped` renders only `fonts.ChatFontOptions` defaults through the shared `fonts.chat()` creation path used by Chat View. This is the GDI renderer, not a capture of a live app window. Candidate options do not change shipped weights or quality.

Options:

- `--size 14`: logical chat pixel size, matching the current default (despite the app variable's `_pt` suffix).
- `--scale 100`: app UI percentage.
- `--dpi 144`: explicit display DPI. Otherwise use the existing `ZigShell` window's DPI when accessible, or the process's system DPI. Remote desktops may have different DPI from the interactive desktop; always inspect `DPI_PROVENANCE` and JSON `dpi_source`.
- `--background 242424`, `--foreground ffffff`: Win32 COLORREF values (hex BBGGRR). Defaults are the dark AMOLED agent bubble and white body text. Other themes need their actual bubble and text colours.

Physical font height is truncated exactly like `uiScaled`: logical size × UI percentage × DPI / 9600. The probe has a Windows subsystem, so it does not allocate a console; redirect standard error to a file to capture diagnostics. Images, JSON output, screenshots and machine-specific runners are not source artifacts.
