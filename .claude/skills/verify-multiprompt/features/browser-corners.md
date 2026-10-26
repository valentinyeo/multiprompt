# Browser corners

## Sub-features

Four native corner masks remain above Chrome and the straight edge strips after activation, session switches, minimize/restore and resize.

## How to get to it (user POV)

Open Browser through Ctrl+K. Click browser content, switch sessions with Ctrl+1/2, minimize/restore the window and resize it.

## Driving it with control.ps1

Driver: `control.ps1 -Feature browser-corners`. Dispatch `gh workflow run verify.yml --ref ceo/IGSH-953 -f feature=browser-corners`.
The standard isolated Windows harness launches the real app and browser. The dedicated `browser-corners.ps1` journey chooses AMOLED through the palette, loads a synthetic white data page through the address bar, creates a second CMD session through the palette and performs twenty mixed cycles. Each cycle records ten visible mask HWNDs, requires all four corner masks above the browser and overlapping straight strips, reads screenshot pixels outside the rounded arc and checks the white-page positive control inside both bottom corners. It saves four corner crops, a full screenshot and measurements per cycle. Require `BROWSER_CORNERS_20_OK`, twenty passed checks, `result.json` passed and owned process cleanup.

## Gotchas

Only run on GitHub Windows, never a user's laptop. No saved state or private messages are seeded. A missing corner, lost stacking order, square pixel or missing white-page control fails. Run the identical journey on the pre-fix app first and retain its failing corner screenshots. Release verification uses the published executable via the workflow's `tag` input.
