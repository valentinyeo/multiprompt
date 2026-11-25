# Computer pane

Source files: src/computer_pane.zig, src/computer_view.cpp, src/computer/discover.py, src/computer/adapter.js, src/computer/resources.zig, src/command_palette.zig, src/shortcuts.zig, src/ui_words.zon, .claude/skills/verify-multiprompt/control-feature-computer-pane.ps1, tools/verify-computer/host.sh, tools/verify-computer/websockify-desktop.py, .github/workflows/computer-host.yml

Journeys: computer-menu, computer-pane

## Sub-features

The recipes below name the user actions, expected result and exact boundary.

## How to get to it (user POV)

Use the entry paths in the action table below on a disposable owned profile.

### computer: Computer viewing and control

Real viewing, control and the private-screen boundary on a disposable Linux host.

Open Computer from the existing three-dot menu or Ctrl+K. Use Ctrl+Shift+F to toggle full width; the
old Computer width palette ID is not generated. Take control, give back and force a lost connection
before Retry. Return to Browser or chat and compare the unsent draft.

Observable proof: the pane shows the disposable desktop, Take control sends input only to that desktop,
Give back stops it, Retry reconnects the same identity, and the VNC port never leaves host loopback.

Journey: computer-pane covers the live pane. computer-menu covers menu selection and the draft.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_COMPUTER_CONTROL_OFFSET` | Ctrl+K, type **take control**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_RETRY_OFFSET` | Ctrl+K, type **computer retry**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_TOGGLE_OFFSET` | Ctrl+K, type **computer**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_WIDTH_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use Ctrl+Shift+F instead. |
| `SEARCH_TABCTX_COMPUTER` | Right-click the intended tab, then choose **Computer: Show or hide**. Follow `computer` above. |

## Driving it with drive.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=computer-pane`. The `computer-host` job
runs a throwaway Linux desktop on a GitHub runner and publishes its SSH port through the free
`bore.pub` tunnel, which needs no account, no paid VM and no stored secret. The Windows job reaches it
only through that tunnel, so no shared or personal server is touched.

The host creates the non-root `desk` user, `xvfb-desktop.service`, `x11vnc.service` on `127.0.0.1` with
`-localhost`, `novnc-desktop.service` running the known literal `websockify-desktop.py` layout, and a
plain window manager with an `xterm` filled with the marker colour `#123456`. The driver writes
`remote-1`, `remote-2` and `remote-3` in the app's own SSH settings so the real executable, the real
discovery script and the real loopback forward are exercised.

Each ticket item is recorded as proven, failed or unreachable in `computer-pane-items.json`:

1. Pane shows the server screen and starts view-only: `state live`, the app's own discovery accepted
   display `:0`, at least half the pane samples are the host marker colour, and a click leaves the host
   pointer untouched.
2. Take control, then click and type: the host pointer moves, the typed marker reaches
   `/home/desk/typed.txt`, and keys after Give back never arrive.
3. Ctrl+Shift+F: the pane's left edge moves left and the caption controls still answer the real hit
   areas `8,9,20`.
4. Two chats on the one host: the viewer-forward count never grows and exactly one `ssh.exe` holds
   `-L 127.0.0.1:`.
5. A hidden chat logs `state sleeping` and its last picture is back within 2.5 s of returning.
6. After `Restart-SessionRestore` the same saved choice reopens the pane with no input.
7. The forced drop (`systemctl stop novnc-desktop.service`) makes the log carry connecting, live,
   sleeping, reconnecting and lost, and Retry returns the same chat to live.
8. `ss -ltn` holds 5900 and 6080 on host loopback only, the tunnel runs `bore local 22`, and the public
   listener answers SSH, never RFB.

The host is told to stop when the driver writes `/tmp/verify-computer-done`, so it never outlives the
journey. Nothing secret crosses a job boundary: the Windows job generates a throwaway key pair in
`RUNNER_TEMP` and posts only its public half to a second free tunnel port derived from the run id, the
host installs that half in `authorized_keys` and closes the enrollment tunnel, and the VNC password is
generated on the host and only ever handed back over SSH. No private key reaches a log, and the evidence
artifact holds paths and public fingerprints, never credentials.

A red run is a product symptom, not a driver gap: read `computer-pane.png`, the `[computer]` lines in
`data/roaming/ZigShell/debug.log`, and the item table. The known released symptom is
`viewer could not start, WebView2 unavailable`, which reaches `Lost` before any SSH starts.

## Gotchas

Never treat an offline, synthetic or diagnostic check as authenticated end-to-end proof.

The pane needs a real systemd host, a non-root desktop user and the exact service layout above; a
container without systemd or a root session shows Lost.

`bore.pub` is a free public tunnel, so the port range is derived from the workflow run id and a busy
port moves to the next candidate. If every candidate is taken the run fails before the app starts.

Verified product gap from the first proof run: `src/computer/adapter.js` opens `ws://127.0.0.1:<port>/`,
while the discovery-validated `websockify-desktop.py` answers `/` with a 302 redirect to `vnc.html`, so
the websocket handshake can be rejected even after WebView2 starts.
