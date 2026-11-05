# Inbox without shortcut legend

## Sub-features

- The bottom Inbox legend is absent in normal, search, no-match and unread-only states.
- Search, read/unread, unread-only, session opening and Escape still work.
- Transient feedback is not a shortcut legend; this journey does not suppress or measure it.

## How to get to it (user POV)

- Ctrl+Shift+I opens Inbox; Alt+I opens or selects All.
- Ctrl+F searches, Enter opens a match, and Esc clears search or closes Inbox.
- U toggles the selected session's read state; Ctrl+Shift+U toggles unread-only.

## Driving it with control.ps1

This is manual-only. Use the same branch revision and driver for both dispatches:

```sh
gh workflow run verify.yml --ref <branch> -f feature=inbox-no-footer -f tag=v0.28.1482
gh workflow run verify.yml --ref <branch> -f feature=inbox-no-footer
```

Identify each run by revision and input. Watch at intervals of at least 300 seconds and download `verify-inbox-no-footer` from each, including the failed release run. The first uses the checksum-verified published executable, not branch application code. Require that it reaches all captures and fails with `Inbox shortcut legend still visible`, not a setup or routing failure. Require the branch run to pass. Inspect corresponding screenshots from both runs, especially Light, AMOLED and Edge Grey.

The isolated offline app starts with one real CMD and no settings seed. Select Light, AMOLED, Edge Grey, Dark, Mid, Multi Bot and System through the palette; verify each app-written theme token. Dev Blue is development-only and Graphite 2 is unavailable, not an alias. Open Inbox with Ctrl+Shift+I, select All with Alt+I, and capture normal, empty search, typed no-match and typed match. Enter on no-match keeps Inbox open; Ctrl+F restarts search; type the observed, nonempty ASCII name from the published CMD without renaming it. Enter must close Inbox and select that same published session ID, confirmed in both published Inbox and saved session state. Reopen with Alt+I, clear a no-match search with Esc, toggle U twice and verify published attention changes and returns. Toggle Ctrl+Shift+U and verify `unread_only` is saved, capture unread-only and unread-search, then clear search and restore the saved filter. Esc closes Inbox; verify the same saved session survives.

Every state is captured before the final assertion. `inbox-footer-pixels.json` and `result.json` contain each screenshot, measured rectangle, background, DPI, UI scale and count. The driver maps the client origin to the screenshot using native window coordinates. It scans only the centered list's bottom 30 logical pixels, inset from the edges and with the mouse moved away. It independently samples background and counts pixels differing by more than three in any channel. Fixed captures require zero; the release's AMOLED normal capture must contain at least 100 contrasting pixels, including faint text on black. Review counts and screenshots for every theme and state; a setup failure or a different visual mismatch is not the intended red control.

## Gotchas

- The app paints its Inbox; no invented accessibility selectors or private messages are used.
- A search query is only proven to match when Enter opens the actual session. A no-match Enter must leave Inbox open.
- Screenshots prove only these offline, single-session paths. They do not prove remote aggregation or all transient feedback.
- No Windows journey has been run by adding this map. Record both run URLs and inspect artifacts before claiming proof.
