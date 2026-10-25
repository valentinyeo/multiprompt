# Status card

Measure the sidebar status card on all three pages after real Ctrl+Shift+G presses, and capture the hover view.

## Sub-features

- `one-line-overview`: page 1 (Overview) is a single line with a state dot, the active host's CPU load, each account's week used and the overall label.
- `one-line-vps`: page 2 (VPS) is a single line with a state dot, host label, CPU load, RAM free and state label. Without a VPS workspace it shows the Overview line, as before.
- `one-line-ai`: page 3 (AI) is a single line with the burn label (CL or CX), week used per account (CL and CX) and the time to the next weekly reset, all in white directly on the sidebar background, with no fill, border or colour.
- `hover-details`: while the mouse is over the card, the full numbers of the current page appear in a card directly above it and hide when the mouse leaves. The AI page shows each account's weekly reset day and local time, countdown, pending bonus reset and pace.
- `page-cycle`: Ctrl+Shift+G and a click still cycle the three pages; the app saves the page in `sidebar-status-card.txt`.

## How to get to it (user POV)

- The card sits at the bottom of the expanded sidebar. Press Ctrl+Shift+G, click the card or scroll the wheel over it to change page.
- Hover the card to see every number the old tall card showed for that page.
- The collapsed sidebar keeps its small status card.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes with the single initial CMD tab and a fresh profile, so the first page is Overview and no update card is shown.
- Offline mode has no AI usage data and no VPS host, so the lines show their waiting state. The journey measures the card frame, not its numbers.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=status-card`; Windows runs `control.ps1 -Feature status-card`. Add `-f tag=<release>` to run the same journey against a release.
- **Measure.** Move the mouse away from the card. For each page, capture `status-card-<n>.png`, then scan the window screenshot upward from the client bottom at client x = 14 px (scaled by DPI), inside the card left padding. The first colour change from the window background is the card's bottom border; the first change from the card fill above it is the top border. The height is the inclusive border-to-border span in device pixels divided by DPI / 96.
- **Cycle.** Between pages press real Ctrl+Shift+G through SendInput and wait until the app writes the next page number to `%APPDATA%\ZigShell\sidebar-status-card.txt`.
- **Hover.** Move the real mouse onto the card bottom, capture `hover.png`, then move it away and capture `after.png`. The hover view is a screenshot only, not asserted.
- **Plain AI page.** Page 3 has no frame to measure. The same column is scanned 40 px up from the client bottom and must stay within 8 of the bottom pixel (no fill or border). White text is checked by eye in the screenshot, since ClearType fringes rule out a pixel colour test.
- **Proof.** `result.json` has `"statusCard": {"heights": [h1, h2]}` in 100% pixels for pages 1 and 2, and `status-card.json` keeps the scan rows, colours and the page 3 `edge` (null). The journey fails when any height is above 30 or below 20, or page 3 shows a frame or fill.

## Gotchas

- Releases before IGSH-673 draw a 222 px card. A tag run such as `tag=v0.28.839` launches normally and fails on the height check with heights near 222.
- The scan column must stay left of the card's text (content starts 10 px inside the frame) and right of its 4 px corner radius.
- The fresh profile runs at 100% UI size; only the DPI scale is divided out.
- Offline data means the lines show waiting text; live usage numbers, the burn chip and VPS values need real telemetry and a VPS workspace.
