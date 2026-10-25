# Chat composer text

IGSH-760: typing must not flash blank text or a different background between keystrokes. IGSH-731: the message box uses the transcript's grayscale DirectWrite rendering without changing native EDIT input, geometry or caret ownership.

## Sub-features

- Default-on DirectWrite glyph painting at `EM_POSFROMCHAR` client positions, including wrapped lines, vertical scrolling, tabs and selection text in the system highlight foreground.
- `IGSH_731=0` restores the native EDIT text and its previous foreground. The switch is independent of `IGSH_610`.
- Native desktop tests paint the production composer into a memory DC at every combination of UI scale 100/125/150 and DPI 96/120/144, with system font smoothing disabled. For the same sentence and font, DirectWrite must have at least 25% fewer hard edges than the native EDIT rollback.
- Live `IGSH-760 typing frames steady` captures the actual visible composer during keyboard typing, not a forced repaint. It requires at least 30 frames spanning the typing, with no transient ink loss or row/border background change.
- Live `IGSH-731 composer edges` requires at least 100 measured edges, partial-coverage pixels and `hardEdgeFraction < 0.18`, with system font smoothing OFF. Missing text, wrong rectangles and enabled smoothing fail.

## How to get to it (user POV)

Press Alt+C to open Chat View, then type in the message box at the bottom. Selection, caret, undo, multiline input, autocomplete and IME remain owned by the native EDIT.

## Driving it with control.ps1

- Branch: `gh workflow run verify.yml --ref ceo/IGSH-731 -f feature=chat-composer-text`.
- Required red control, identical harness and threshold: `gh workflow run verify.yml --ref ceo/IGSH-731 -f feature=chat-composer-text -f tag=v0.28.858`.
- Before launching either executable, the driver reads the system font-smoothing setting, turns it OFF with `SystemParametersInfo`, and verifies the readback. Cleanup restores the original setting.
- It selects Dark through the real palette, opens Chat View with Alt+C, verifies ownership/focus, and types `The message box should look as smooth as the chat text.` with real keyboard input. `WM_GETTEXT` must match the sentence.
- It captures `after.png`, finds the text row from the native EDIT's first and near-final character coordinates, excludes the blinking caret, and writes a 32-bit `composer-live.bmp`. `tools/chat-composer-text-proof.mjs` applies the existing `edgeHardness` metric from `chat-code-font-proof.mjs` and saves `composer-text-4x.png`.
- `result.json` records `IGSH-731 composer edges`, the threshold, actual measurements including `partialPerInk`, and smoothing state. A release must reach this check and fail it; launch or focus failures are not the red control.
- Branch native evidence: `composer-<scale>-<dpi>-{dwrite,gdi}.{bmp,json}`, 4x crops, and `composer-native-summary.json`. The Node evaluator independently remeasures the BMPs and validates native JSON measurements. `result.json` also includes `IGSH-731 composer native scale and DPI`.
- IGSH-760 green journey, after the rendering fix is included in the build under test: `gh workflow run verify.yml --ref ceo/IGSH-760 -f feature=chat-composer-text`.
- IGSH-760 required red control, **same journey and thresholds**: `gh workflow run verify.yml --ref ceo/IGSH-760 -f feature=chat-composer-text -f tag=v0.28.860`. The flickering release must **FAIL `IGSH-760 typing frames steady`**; a fixed build must **PASS** it. A launch/focus/sampling failure, or failure only of the separate IGSH-731 check, does not count as the red control. Inspect the named check and its mismatched frames on Windows; if the release passes, the red control is unproven and the sampler must be revisited, not its thresholds relaxed.
- After the settled-image proof, the driver selects and clears the sentence through Ctrl+A/Backspace, then reuses `Assert-ChatTyping` to retype it into the same owned EDIT. The first 12 characters (`The message `) seed stable ink. A concurrent C# thread in the existing `VerifyNative` helper uses screen `BitBlt`/SRCCOPY on a small composer-row crop every 2 ms while the remaining real keyboard input runs. There is no PrintWindow/WM_PAINT/DwmFlush in the burst: forcing a complete repaint or waiting for composition would hide the intermediate frame. BMP writes happen only after capture stops. `WM_GETTEXT`, original focus and foreground ownership remain checked.
- `composer-typing-<index>.bmp` preserves each captured crop; `composer-typing.json` records timestamps, typing bounds and row/prefix rectangles. One final reference frame is captured after the typing thread signals completion, following the existing keyboard helper's 250 ms settling delay and supplies the settled background/border and prefix-ink reference. The prefix rectangle stops five characters before the seed's caret, so growing text and caret blink are not mistaken for disappearing prefix ink. Full-row ink is measured too, to catch loss confined to later characters.
- Thresholds in `composer-typing-summary.json` and the named `result.json` check: **30** mid-typing frames minimum; **1000 ms** minimum typing duration; no gap or start/end coverage hole above **100 ms**. Any single frame fails if prefix ink is below **20** pixels, below **0.8** of settled prefix ink, below **0.8** of previous-frame prefix ink, or full-row ink drops below **0.8** of its previous value. Ink is any pixel at least **24** RGB channel levels away from settled row background. The row's modal RGB background and four fixed border/background probe pixels must stay within **2** levels per channel of the settled reference; a delta of **3** fails.
- Read `frames` (in the typing interval), `capturedFrames`, `durationMs`, `maxGapMs` and `samplingPassed` first. `inkSeries.values/min/max/settled` shows fixed-prefix stability; `rowInkSeries.min/max` may grow naturally. `measurements` contains every frame's timestamp, prefix/full-row ink, background RGB (0xRRGGBB integer), channel deltas and previous-frame ratios. `mismatchedFrames` identifies offending BMP indices, measurements and reasons (`ink-drop`, `row-background`, `border-background`). A green check has adequate sampling, nonblank settled ink and **zero** mismatched frames; a valid red control has adequate sampling and at least one visual mismatch, even though its final screenshot looks normal.
- Download `verify-chat-composer-text`, inspect the before/action/after images, `composer-typing-after.png`, frame BMPs and summaries, and compare the branch and release named checks. Native red/green outcomes require actual GitHub Windows run evidence; the pure Node fixtures prove the evaluator, not the app.

## Gotchas

- No Windows builds, native tests, Wine or copied Zig fixture tests run on the VPS. Native tests run only on GitHub Windows.
- The live threshold is fixed below the reported pre-fix composer fraction of 0.24; do not relax it to let v0.28.858 pass.
- The live sentence is a single unselected line. Native geometry/input integration beyond this path needs the desktop tests and additional real Windows caret, selection, wrapping, scrolling, autocomplete and IME inspection; a screenshot alone does not prove those behaviors.
- This offline journey does not claim live AI delivery or real remote autocomplete/IME coverage.
