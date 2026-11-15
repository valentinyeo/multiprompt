# Full-size colour reactions

## Sub-features

- A reaction chip contains a full-size colour emoji at the normal 14 px chat body size.
- The hover react button contains a colour smiling emoji, never a monochrome text smiley.
- Reply and More remain visible in their original neighbouring action cells.
- Dark and Light retain visible colour reaction chips and hover emoji.
- Normal and bold inline code appear in the same transcript before reacting, exercising the code-font cache independently of the emoji font.

## How to get to it (user POV)

Hover an assistant reply to see React, Reply and More. Right-click the reply and select the thumbs-up reaction. Use Ctrl+K, Themes to switch Dark and Light.

## Driving it with control.ps1

Run `gh workflow run verify.yml --ref <branch> -f feature=reaction-emoji` on GitHub Windows only.

The existing chat-delivery boundary supplies an isolated saved remote tab, a synthetic Claude transcript and SSH/tmux stand-ins. The real app parses the transcript, paints code, receives native right-click and menu keyboard input, submits one reaction, and paints the chip and hover actions. No live provider, credentials or network server is used.

`control.ps1` selects the focused reaction-emoji driver. It locates the two real reply bubbles on AMOLED, creates a reaction through the native menu, and records their painted geometry. It switches Dark and Light through the real theme picker and captures the same chip and hover row on each theme. All geometry is at the isolated profile's default 100% UI scale and 96 DPI, with 14 px body text.

The independent pixel checker requires at least 20 yellow/orange pixels per emoji, a colour-ink height of at least 80% of the body em and width of at least 65%. It separately requires ink in the original Reply and More cells and the expected dark or light transcript background. Tiny, monochrome and missing emoji controls are rejected by the focused Node test.

Inspect `reactions-emoji-dark.png`, `reactions-emoji-light.png`, the four `reaction-emoji-*-4x.png` crops and the measured bounds in `result.json`. `doctor.json` records the owned executable identity. `cleanup.json` must show zero owned processes and removed scratch data.

After the head journey passes, the workflow builds pre-fix master `9b8c59971273f6146b20fe901166b8469c88f637` and runs this identical head harness against that executable. The old build must fail the colour-pixel assertion after reaching the real reaction, not at launch or setup. Its screenshots, Doctor and cleanup receipts are retained under `emoji-negative/`, and the root `result.json` records the rejected pixel assertion. A passing head run proves both themes; source tests alone do not.

## Gotchas

This is a native desktop journey, not a browser test. It uses the existing reaction harness's explicit synthetic transcript boundary. Do not claim live Claude delivery. A failed pixel check retains screenshots, stderr, the raw transcript, input actions, Doctor and cleanup receipts. The existing full reaction transport/restart journey remains unchanged.
