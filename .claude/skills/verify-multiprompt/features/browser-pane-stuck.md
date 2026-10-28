# Browser pane stuck opening

Verify on: push

Verify browser-pane close/reopen behavior and that a docked pane works without the extension.

## Sub-features

- `pane-close`: Alt+A closes an opening or docked pane; the palette closes an opening pane only.
- `pane-close-all`: Ctrl+K Close All Browser Panes closes every pane.
- `pane-reopen`: each reopen has a new connection ID.
- `connected-pane-stays-visible`: a docked pane with window ID 0 stays visible and connected past the 20-second opening deadline.
- `shifted-toggle`: Alt+Shift+A and Alt+Shift+B still toggle working panes.

## How to get to it (user POV)

- Alt+C opens Chat View for the initial CMD session; no agent or account is required for its screen-copy fallback.
- Ctrl+K `open browser` opens the pane; Alt+A toggles it closed. A released and repressed shortcut closes immediately, including while the pane opens.
- Ctrl+K `Close Browser Pane` closes a pane while its launch is in flight; on a docked pane it retains master's open/focus behavior. `Close All Browser Panes` closes every pane without clearing saved URLs.
- Only a launch with no docked window fails after about 20 seconds. Click Retry, press Alt+Shift+A, or use Ctrl+K `Retry Browser Pane` to retry a failed pane. Alt+A dismisses it.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes on a fresh GitHub Windows desktop with isolated empty app/browser data and an installed browser.
- Setup gives the isolated Edge profile up to 60 seconds to render an owned blank setup page before any pane assertions. The setup browser stays job-owned until cleanup; no pane assertion is retried. Docking then retains its separate 25-second bound and main-window activation its 5-second bound.
- No extension is installed in the isolated profile. Window ID 0 is expected and must not prevent docking or visibility.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=browser-pane-stuck`; pull requests run both appearance and browser-pane-stuck.
- **Open.** Use Alt+C, then Ctrl+K `open browser` and Enter. Require opening or connected state and a positive connection ID. Before further input, wait up to 25 seconds for that connection to be connected with a visible docked pane, activate the main window with the harness's `SetForegroundWindow` entry point (the taskbar-selection equivalent), and observe its foreground root within 5 seconds. Apply the same handoff after each palette reopen and Alt+Shift+B. Capture `action.png`.
- **Close and reopen.** Close through Alt+A and Close All, reopening through Ctrl+K after each. For opening-only Close Browser Pane, queue palette open and palette close in one SendInput batch: input messages drain before the adoption WM_TIMER, so docking cannot race the close command. Require closed state with zero connection ID, then reopen normally with an ID that skips at least one connection since the last observed open ID, proving the batch opened an intermediate connection. The batch does not capture that intermediate opening ID.
- **Connected pane stays visible.** Require connected state, window ID 0, and a visible owned browser window intersecting the app frame. Observe continuously for another 21 seconds and fail if it closes, hides, fails, or changes identity. Capture `connected.png`.
- **Shifted shortcuts.** Alt+Shift+A closes the working pane; Alt+Shift+B reopens it with a fresh ID. Neither shortcut is restricted to failed-state Retry.
- **Immediate toggle.** Twenty real Alt+A pairs send the second chord after 100 ms, fail above 300 ms, and require logged open then close plus a closed published pane. A local page sends headers and partial HTML, then holds its response for 30 seconds; navigate through Alt+L and close before it finishes. Save both key logs, pair timings, loading receipts and a 45-second desktop recording. No retries of failed pairs.
- **Finish.** Close All again and capture `after.png`. Each asserted transition prints `browser-pane-stuck <step> PASS`; a missing state throws and fails the workflow.
- **Proof.** Inspect screenshots, UIA snapshots, actions, per-step `browser-pane-*.json` records, `result.json`, and owned-job cleanup evidence. Pane URLs are not published in the inbox or copied to these records.

## Gotchas

- Foreground immediately after Enter can precede Edge's asynchronous activation. Do not treat that transient observation as launch completion or rely on docking to return foreground to the main window. Every input still requires the unchanged foreground safety guard.
- No extension is not a failed launch: a successfully docked pane must work indefinitely without a bound window ID.
- Undocked timeout/retry, immediate opening close, stale replies, URL retention, and cancellation overflow are covered by production-state unit tests. This desktop journey does not claim to force an undocked launch failure; its opening-only palette close queues input ahead of adoption timers rather than racing docking.
- Never install an extension, seed settings, fake state, post private app messages or drive another desktop to make this pass.
- Retry's palette and mouse entry points, failed-state Close button and tab-context Hide are not runtime-covered by this journey.
- A green workflow still requires screenshot inspection; this map is not a claim that the journey has already passed.
