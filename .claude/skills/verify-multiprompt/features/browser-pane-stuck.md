# Browser pane stuck opening

Verify recovery from an unconnected browser pane using a fresh Windows profile with no browser extension attached.

## Sub-features

- `opening-close`: Alt+A closes a pending pane without losing its URL.
- `opening-close-all`: Ctrl+K Close All Browser Panes also closes pending panes.
- `opening-reopen`: each reopen has a new connection ID and the same URL.
- `opening-timeout-retry`: after about 20 seconds the pane shows a connection failure with Retry and Close; Alt+Shift+A retries with a fresh connection ID.

## How to get to it (user POV)

- Alt+C opens Chat View for the initial CMD session; no agent or account is required for its screen-copy fallback.
- Ctrl+K `open browser` opens the pane; Alt+A toggles it closed, including while opening.
- Ctrl+K `Close Browser Pane` closes the opening pane; `Close All Browser Panes` closes every pane without clearing saved URLs.
- After a connection failure, click Retry, press Alt+Shift+A, or use Ctrl+K `Retry Browser Pane`; Close or Alt+A dismisses it.
- The tab-context palette also offers Hide Browser Pane. This journey does not exercise that entry point or mouse buttons.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes on a fresh GitHub Windows desktop with isolated empty app/browser data.
- No extension is installed in the isolated profile; an unexpected nonzero browser window binding fails the journey rather than accepting a connected pane.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=browser-pane-stuck`; Windows runs `control.ps1 -Feature browser-pane-stuck`.
- **Open.** Use Alt+C, then Ctrl+K `open browser` and Enter. Read `inbox-default.json` through the control interface and require `browser_state=opening`, a positive `browser_connection_id`, no bound browser window, and a nonempty URL. Capture `action.png`.
- **Close and reopen.** Use Alt+A. Require closed state, zero connection ID and the same URL, then reopen through Ctrl+K and require a larger connection ID.
- **Close all and reopen.** Search Ctrl+K `close all browser panes` and Enter while opening. Require all panes closed, URL retained, then reopen with a larger ID again.
- **Close one through the palette.** Search Ctrl+K `close browser pane`, Enter, and assert closed state and URL retention. Reopen and require another larger connection ID.
- **Timeout and retry.** Wait at most 25 seconds for failed state with no pending connection. Capture `timeout.png`, showing Retry and Close. Press Alt+Shift+A and require opening with a larger ID and the original URL.
- **Finish.** Close All again and capture `after.png`. Each asserted transition prints `browser-pane-stuck <step> PASS`; a missing state throws and fails the workflow.
- **Proof.** Inspect before/action/timeout/after screenshots, matching UIA snapshots, actions, per-step `browser-pane-*.json` records and `result.json`, plus copied app state and normal owned-job cleanup evidence.

## Gotchas

- This deliberately proves failure recovery, not successful extension integration or navigation.
- Never install an extension, seed settings, fake state, post private app messages or drive another desktop to make this pass.
- Opening remains pending until the extension binds the exact browser window; seeing a Chromium window alone does not prove a connection.
- Retry's palette and mouse entry points, failed-state Close button and tab-context Hide are source-covered only, not runtime-covered by this journey.
- A green workflow still requires screenshot inspection; the map describes a runnable journey, not a claim it has already passed.
