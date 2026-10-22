# zsb systematic test plan (local + Remote host 1 + Remote host 2)

Goal: exercise EVERY zsb verb from a shell in each environment and verify it drives the docked
Edge pane. zsb is the browser-control CLI on each ZigShell-spawned shell's PATH.

## Key setup invariant — tunnel ownership
VPS zsb reaches the multiprompt instance whose dedicated per-host keeper owns
the `-R 19548` reverse tunnel. Interactive restored shells do not request the
forward themselves. The keeper starts before shell restore, belongs to a
kill-on-close job, and retries after disconnects. Test STABLE first, confirm
the DE/UK keeper fields in diagnostics, then verify the relevant VPS accepts a
loopback connection on port 19548.

## Verb list (confirm at execution: `zsb` with no args / grep `handleZsb` / zsb.cmd)
1. `zsb open [url]`        — open/dock the pane from a shell (local + VPS)
2. `zsb navigate "<url>"`  — load a page in the pane
3. `zsb text [--limit N] [--tab <id|match>]` — read visible text across frames
4. `zsb snapshot [--tab <id|match>]` — compact page state across frames
5. `zsb click "<css>" [--tab <id|match>]` — trusted click, including cross-origin frames
6. `zsb type "<text>"` or `zsb type "<css>" "<text>"` — trusted focused input or selector replacement
7. `zsb status` / `zsb doctor` — report tunnel up/down + pane open/closed for this session
8. `zsb key "Alt+2"`     — send a native key chord to the active tab
9. `zsb screenshot -o f.png`   — capture the pane; on VPS this writes the remote file
10. `zsb eval "<js>"`     — eval JS in MAIN world, returns the value (awaits promises)
11. `zsb sidebar`         — reveal the ZigShell sidebar from a shell (issue)
12. `zsb active-tab` / `zsb url` — report the targeted tab and its exact URL
13. `zsb console [-n N]`  — return recent Runtime and browser Log entries
14. `zsb close-tab <id|match>` — close one same-pane tab without closing the final tab

## Per-environment procedure

### A. LOCAL
1. In the target ZigShell instance, spawn a local cmd tab (Ctrl+Shift+1) — it gets
   ZIGSHELL_SHELL_ID/NOTIFY_PORT env + zsb on PATH.
2. From that tab: `zsb open https://example.com` → pane docks + loads. (or Alt+B then navigate)
3. Run each verb 2–10 in order; record output + visually confirm the pane responds.
   - text/snapshot/eval: expect real content (e.g. eval `document.title` → "Example Domain").
   - click/type: use example.com or a form page; verify via a follow-up `zsb text`/`eval`.
   - screenshot: confirm a non-blank PNG.
   - sidebar: confirm the sidebar reveals.
4. Driving the tab without a human: inject the command via WriteConsoleInput / WM_CHAR to the
   conhost, or have the test run from a real keypress. Capture output by reading the console or
   redirecting zsb output to a file and reading it.

### B. REMOTE HOST 1 (host de) and C. REMOTE HOST 2 (host uk)
1. A tmux Claude tab on that host, in a ZigShell tab whose pane is bound (panewin-<session>).
   The remote shim is `~/.local/bin/zsb` (tools/vps-zsb.sh) — derives session via
   `tmux display-message -p '#S'` only when `$TMUX` proves the caller is inside
   tmux, base64+0x1F-joins argv, and writes to /dev/tcp/localhost/19548. A
   headless caller must provide `ZSB_SESSION`; it must never inherit tmux's
   ambient current session.
2. `zsb open https://example.com` from the remote tmux session → drives the pane on the owning tab.
3. Run `zsb status` first. It must never be empty: expect tunnel=`up` and pane=`open` when bound,
   or a structured tunnel/pane error with the recovery hint.
4. Run verbs 2–14; same verification. Known caveat: strict-CSP pages make `eval` return the CSP
   error, not the value (issue).

5. Send a 14 KiB `Runtime.evaluate` parameter object through the remote shim and
   verify the result returns. Open a URL longer than 512 bytes whose final query
   parameter is unique, then compare `zsb url --tab <unique-tail>` byte for byte.

## Recording

Keyboard-driven typeahead: use `zsb type --keys 'input._58al' 'business_management'`
then `zsb key Enter`. The `--keys`, `--raw-enter`, and `--tab` flags may appear
in any order, each at most once.
With one text argument, typing uses the focused editable; with a selector it
clicks and replaces the selected input as ordinary `type` does. The response
reports `mode:keys`. Ordinary `type` retains the faster text-insertion path.
Newlines in typed text are inserted as line breaks in both modes, so chat
composers never submit; add `--raw-enter` to press Enter at each newline instead.
The keyboard path emits Unicode characters individually through CDP keyDown
and keyUp; Chromium generates keypress and input events. Do not synthesize DOM
events or insert the same character again. Test suggestions and Enter selection
in a controlled React input, including trusted events and underscore handling.

Table per environment: verb | command | result (PASS/FAIL) | notes. Report a bug for any FAIL.
