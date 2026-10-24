# Chat composer text

IGSH-731: the message box uses the transcript's grayscale DirectWrite rendering without changing native EDIT input, geometry or caret ownership.

## Sub-features

- Default-on DirectWrite glyph painting at `EM_POSFROMCHAR` client positions, including wrapped lines, vertical scrolling, tabs and selection text in the system highlight foreground.
- `IGSH_731=0` restores the native EDIT text and its previous foreground. The switch is independent of `IGSH_610`.
- Native desktop tests paint the production composer into a memory DC at every combination of UI scale 100/125/150 and DPI 96/120/144, with system font smoothing disabled. For the same sentence and font, DirectWrite must have at least 25% fewer hard edges than the native EDIT rollback.
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
- Download `verify-chat-composer-text`, inspect the before/action/after images and crops, and compare the branch and release composer checks.

## Gotchas

- No Windows builds, native tests, Wine or copied Zig fixture tests run on the VPS. Native tests run only on GitHub Windows.
- The live threshold is fixed below the reported pre-fix composer fraction of 0.24; do not relax it to let v0.28.858 pass.
- The live sentence is a single unselected line. Native geometry/input integration beyond this path needs the desktop tests and additional real Windows caret, selection, wrapping, scrolling, autocomplete and IME inspection; a screenshot alone does not prove those behaviors.
- This offline journey does not claim live AI delivery or real remote autocomplete/IME coverage.
