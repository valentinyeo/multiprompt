# Title bar

On-demand feature stem: `title-bar`. Branch builds only; do not pass a release tag.

## Contract

Windows DWM owns the Multiprompt caption and all three native window buttons. No app or browser mask draws another set. The browser controls cover has two surfaces: its exposed caption-facing apron follows the app caption colour; its interior still follows Chromium's frame colour (IGSH-810). Browser pixels and masks must not paint above the main client origin.

## Real Windows journey

`verify.yml` dispatches six isolated jobs: actual monitor DPI 96, 120 and 144 (100%, 125%, 150%), each with pinned real Chrome for Testing in light and dark. The helper changes the disposable runner display with DisplayConfig, requires one active display and confirms `GetDpiForWindow` equals the requested DPI. Unsupported display/DPI changes fail; synthetic DPI messages, image resizing and app UI scale are not substitutes. Original monitor scaling is restored during cleanup.

Only the browser's isolated profile is seeded, selecting Chrome's light/dark colour scheme. Dark also uses Chrome's process-level dark-mode switch. App themes are always selected through the real Themes palette. Chrome runs without the extension so app theme changes cannot silently make the browser match. The browser's own frame pixels must independently prove the requested theme: light channels at least 160; dark channels between 16 and 100. Page-content colour is never a reference.

For restored and maximized app windows:

1. Close the browser pane through the palette, select AMOLED, move the cursor away, activate the verified app and capture a browser-free native-caption reference.
2. Read DWM caption-button bounds, the main client screen origin and native window DPI. The measured caption rectangle extends 12 scaled pixels left of the three buttons, from the DWM top to the client origin; it includes the lower edge where a grey band can bleed. Only this corner is compared, not variable title text.
3. Open and dock the real browser through the existing guarded helper. Require all ten visible app-owned edge masks. Preserve the exact main HWND, browser HWND, window mode, caption geometry and DPI.
4. Change the running app to Light and then AMOLED without restarting either window. For each, capture the actual desktop, UIA, HWNDs, focus, masks and pixel measurements. The caption-facing apron must become light (each RGB channel at least 235), then app-black (each channel at most 8), even while Chrome retains its independent theme.
5. Count three distinct foreground shapes by occupied-column runs in the browser-free reference. Require native-sized glyph bounds/areas, a thin minimize line, and tall maximize-or-restore and close shapes. Compare every caption-corner pixel to that reference with maximum per-channel tolerance 8. This is a doubled-pixel signature check: an extra offset glyph, even faint, adds nonmatching pixels. Every background pixel outside the reference glyph support must be app-black within 8; zero nonblack background pixels, zero mismatches and zero broad grey-band pixels are allowed. Glyph pixels themselves are necessarily not black.
6. Identify exactly one controls cover by its browser-relative geometry. Scan every pixel of its exposed top apron, not just one sample, and require app-black. Save its sample and Chrome-frame sample, requiring distance greater than 8. Separately require the cover's interior to match the browser-frame sample within 10, preserving IGSH-810. The black apron is not a request to turn Chrome's interior cover black.
7. Inject a faint second copy of the actual glyph pixels offset in both axes, and separately a one-pixel grey bottom band, into saved screenshot copies. Run the identical measurement and assertion methods and require each to fail specifically on the caption signature/band assertion, not a missing precondition or theme mismatch.

`caption-pixels.json` is saved before assertions; it includes screenshot/reference names, window identities, real DPI, caption/browser/mask rectangles, glyph bounds/areas, colour samples, deltas and all mismatch counts. Each artifact is named `verify-title-bar-<dpi>-<browser-theme>`. Inspect both modes, both app themes, negative-control images/JSON, `build.json`, `doctor.json`, `result.json`, process accounting and cleanup. A green run still needs screenshot review at its recorded revision.

## Red and green

Commit A contains this journey, oracle and workflow only. The local `ceo/IGSH-845-red` branch is origin/master plus A; the local `ceo/IGSH-845` branch adds app-fix commit B. An authorized publisher must publish both before dispatch:

```sh
gh workflow run verify.yml --repo valentinyeo/multiprompt --ref ceo/IGSH-845-red -f feature=title-bar
gh workflow run verify.yml --repo valentinyeo/multiprompt --ref ceo/IGSH-845 -f feature=title-bar
```

The unchanged baseline paints the exposed controls-cover apron with Chrome's colour, so it must fail the app-black apron assertion. Reject unrelated startup, DPI, theme or oracle failures as proof of red. The fixed branch must pass all six cases with the same assertions. These runs have not been executed locally or remotely by the patch author; recorded coverage remains unverified until the runner supplies the artifacts.
