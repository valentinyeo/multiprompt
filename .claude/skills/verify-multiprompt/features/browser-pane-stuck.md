# Browser pane stuck opening

Verify browser-pane close/reopen behavior and that a docked pane works without the extension.

## Sub-features

- `pane-close`: Alt+A and the palette close a pane whether opening or docked.
- `pane-close-all`: Ctrl+K Close All Browser Panes closes every pane.
- `pane-reopen`: each reopen has a new connection ID.
- `connected-pane-stays-visible`: a docked pane with window ID 0 stays visible and connected past the 20-second opening deadline.
- `shifted-toggle`: Alt+Shift+A and Alt+Shift+B still toggle working panes.

## How to get to it (user POV)

- Alt+C opens Chat View for the initial CMD session; no agent or account is required for its screen-copy fallback.
- Ctrl+K `open browser` opens the pane; Alt+A toggles it closed. A pane opened by a physical shortcut ignores another chord during its opening guard, then permits close.
- Ctrl+K `Close Browser Pane` closes one pane; `Close All Browser Panes` closes every pane without clearing saved URLs.
- Only a launch with no docked window fails after about 20 seconds. Click Retry, press Alt+Shift+A, or use Ctrl+K `Retry Browser Pane` to retry a failed pane. Alt+A dismisses it.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes on a fresh GitHub Windows desktop with isolated empty app/browser data and an installed browser.
- No extension is installed in the isolated profile. Window ID 0 is expected and must not prevent docking or visibility.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=browser-pane-stuck`; pull requests run both appearance and browser-pane-stuck.
- **Open.** Use Alt+C, then Ctrl+K `open browser` and Enter. Require opening or connected state and a positive connection ID. Docking can complete before the observation; it must not be mistaken for failure. Capture `action.png`.
- **Close and reopen.** Close through Alt+A, Close All, and Close Browser Pane, reopening through Ctrl+K after each. Require closed state with zero connection ID and strictly increasing IDs on reopen.
- **Connected pane stays visible.** Require connected state, window ID 0, and a visible owned browser window intersecting the app frame. Observe continuously for another 21 seconds and fail if it closes, hides, fails, or changes identity. Capture `connected.png`.
- **Shifted shortcuts.** Alt+Shift+A closes the working pane; Alt+Shift+B reopens it with a fresh ID. Neither shortcut is restricted to failed-state Retry.
- **Finish.** Close All again and capture `after.png`. Each asserted transition prints `browser-pane-stuck <step> PASS`; a missing state throws and fails the workflow.
- **Proof.** Inspect screenshots, UIA snapshots, actions, per-step `browser-pane-*.json` records, `result.json`, and owned-job cleanup evidence. Pane URLs are not published in the inbox or copied to these records.

## Gotchas

- No extension is not a failed launch: a successfully docked pane must work indefinitely without a bound window ID.
- Undocked timeout/retry, opening close after the guard, stale replies, URL retention, and cancellation overflow are covered by production-state unit tests. This desktop journey does not claim to force an undocked launch failure or race docking to prove opening-only close.
- Never install an extension, seed settings, fake state, post private app messages or drive another desktop to make this pass.
- Retry's palette and mouse entry points, failed-state Close button and tab-context Hide are not runtime-covered by this journey.
- A green workflow still requires screenshot inspection; this map is not a claim that the journey has already passed.
