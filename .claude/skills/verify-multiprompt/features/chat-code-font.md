# Chat code font

IGSH-678: every code piece in Chat View draws in the bundled Nordwand Mono SemiBold, 2 pt smaller than before, with the same smooth DirectWrite edges as body text, including diff rows on green and red backgrounds.

## Sub-features

- `code-cell-size`: a fenced code block printed by a real CMD and formatted by Chat View draws 40 full-block cells exactly 40 Nordwand cells wide at the new size (`chat_font_pt - 3`, minimum 8, scaled by UI size and DPI). The previous size (`chat_font_pt - 1`) draws wider cells and fails.
- `code-font-face`: under `ZIGSHELL_DEBUG=1` the app logs `[chatcode] face=... em=... advance=... body_em=... pt=...` once each time it creates the Chat View code font, read back from the selected GDI font. The face must be `Nordwand Mono MP SemiBold`, the em size the new size, exactly 2 px below the previous size at 100% UI size and 96 DPI, and smaller than body text.
- `code-edges`: the code crop from the real window is saved at 4x as `code-crop-4x.png`, with its antialiased pixel counts.
- `diff-rows-smooth`: low-level painter coverage only; Chat View no longer displays tool/activity blocks (IGSH-759). Branch builds only. The native painter test draws a synthetic `Wrote dec.html +2 -1` tool block whose added and removed rows are wider than the row, plus a code block, once with `IGSH_610=1` (DirectWrite) and once with `IGSH_610=0` (the GDI path these rows used to fall back to). DirectWrite must draw every diff and code run with no GDI fallback, and its diff rows must have fewer hard edges than the GDI image.

## How to get to it (user POV)

- Any Claude or Codex reply with a fenced code block, inline code, or a file edit preview (`Wrote file +15 -0` with green and red rows) in Chat View. Alt+C or Ctrl+K `chat view` opens Chat View.
- Ctrl++, Ctrl+- and Ctrl+0 in Chat View change the text size; code follows it, always 2 pt below the old code size.

## Driving it with control.ps1

- Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-code-font`, or add `-f tag=v<version>` for a release. Watch at 60-second intervals and download `verify-chat-code-font`.
- The driver resets UI size through Ctrl+K `interface`, Down twice, Enter, then types a PowerShell command into the real CMD that prints a body line, a three-backtick fence, `a` followed by 40 U+2588 full blocks (a row that starts with block elements is hidden as the Claude Code startup banner), `let answer = 42;` and the closing fence, plus a completion marker file. It captures `action.png`, presses Alt+C, requires the app-written `cv: true` and the visible `ZigShellChatTranscript` control.
- It captures `after.png` until the 40-cell bar is found inside the transcript bounds: the widest high-contrast horizontal run stacked over at least four rows. Width divided by 40 is the drawn cell width; it must be within 3 px over 40 cells of `round(0.6 * em)` for the expected em (Nordwand's advance is 600 of 1000 units).
- It saves `code-crop-4x.png`, measures the code text row below the bar, reads `[chatcode]` from `data/roaming/ZigShell/debug.log`, and on branch builds reads `chat-code-proof-summary.json` from the painter step.
- `result.json` always lists `IGSH-678 code cell size`, `IGSH-678 code font face and size`, `IGSH-678 code edges` and `IGSH-678 diff rows smooth on green and red`. The first failing one names IGSH-678 in `error`.
- Painter evidence: `chat-code-render.png`, `chat-code-render-gdi.png`, `chat-code-diff-4x.png`, `chat-code-diff-gdi-4x.png`, `chat-code-block-4x.png`, `chat-code-proof-dwrite.json`, `chat-code-proof-gdi.json` and `chat-code-proof-summary.json`, written by `tools/chat-code-font-proof.mjs`.
- Inspect `before.png`, `action.png`, `after.png`, both 4x crops and the painter images yourself. The release crop is larger; the branch crop smaller; the DirectWrite diff crop is smooth on both backgrounds.

## Gotchas

- A release built before IGSH-678 draws 13 px code at default size and has no `[chatcode]` line, so it fails `IGSH-678 code cell size` after launch and Chat View opened. That is the expected red, not a launch failure.
- The fenced block is formatted from real console text, not a seeded transcript or app setter. Tool/diff blocks are hidden in Chat View. The separate branch painter image still exercises their low-level drawing routine directly, not visible transcript rows.
- Fenced code lines that fit already drew through DirectWrite before IGSH-678; only rows wider than their space (diff previews ending in `...`) fell back to GDI. The live crop therefore records edges, while the painter compares DirectWrite against GDI.
- Lines containing a tab or a character the font lacks still fall back to GDI, as body text does.
