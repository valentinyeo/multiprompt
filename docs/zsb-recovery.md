# zsb deadlines and recovery (IGSH-154)

Run `zsb reset` to cancel stuck CDP work for this pane and reconnect the native bridge without reopening the pane, navigating, or changing the target tab. If debugger detach also times out, reset schedules an extension-worker reload to release the browser-owned debugger session. This reconnects the shared native transport; other in-flight requests can fail and should be retried. `zsb reset --help` is local.

Native requests share one absolute deadline across retries and version healing: 20 seconds normally, 40 seconds for screenshots. A 60-second CLI watchdog also bounds blocking operating-system calls. Remote commands have a 90-second absolute transport deadline, including partial replies; `ZSB_TIMEOUT_SECONDS` can select a deadline greater than zero and no more than 300 seconds. Timeout errors recommend reset. The app already runs remote requests in separate worker threads and bounds each bridge subprocess.

## Hang paths

- `tools/vps-multiprompt-browser.sh` sends `ZSB:session:base64-args` through the forwarded app TCP port.
- `src/browser_bridge.zig` dispatches each connection to `zsbWorkerThread`, resolves the session's pane, and starts `zigshell-bridge.exe` through `zsbRunBridgeOnce`.
- `src/bridge.zig` sends JSON through the profile-specific command named pipe. The native host forwards it over Chrome native messaging. Each CLI owns a separate reply pipe.
- `extension/bridge.js` dispatches requests independently, but the old `withCdpSession` chained operations per tab. Its attach had a deadline; focus setup, pending detach, and final detach did not. A hung promise there retained the chain forever. The outer 15-second response timeout did not cancel that underlying chain. Later CDP operations therefore queued behind abandoned work. Even `active-tab` can reach that queue through `getTargetTab` and background-tab focus emulation. Now a busy tab fails immediately, every CDP stage is bounded, and reset cancels retained ownership.
- The native host also routed replies on its sole native-message reader and called `FlushFileBuffers`, which waits for the reply-pipe reader. An unresponsive reader could therefore stop replies for **all** commands, including tabs. Replies now use nonblocking writes and never flush-wait on the client. Ordinary CLI reply reads previously had no deadline.
- Popup handling uses `tabs.onCreated` and `webNavigation.onCreatedNavigationTarget`; the isolated-profile routing guard returns early rather than deflecting page-created targets. The product does not issue `Target.setAutoAttach` or `waitForDebuggerOnStart`, and it does not wait for child-target attachment during a click. The available historical report cannot identify which browser promise or pipe wait actually stalled.

## Slack investigation and remaining evidence gap

The old report described Edge. Read-only inspection of the current Windows installation instead found the full Chrome executable, using `--new-window`, `--profile-directory=Default`, and a dedicated `ChromeUserData` directory. The ordinary Chrome window uses a different profile. This is not an iframe or WebView2 storage partition, and authentication/storage are not shared with the ordinary profile.

Current pane launch flags do not override user agent or client hints and do not disable service workers, IndexedDB, JavaScript, or cookies. Notification suppression, extension loading, first-run suppression, and background-process suppression are present. The source does not install a Slack request blocker or override third-party-cookie settings.

Read-only laptop checks found:

- Both profiles leave third-party-cookie settings unset and expose the same default content-setting values.
- Neither profile has Slack-specific cookie, JavaScript, background-sync, notification, or durable-storage exceptions.
- The pane profile has service-worker storage and existing `app.slack.com` IndexedDB directories; their presence alone does not prove the current page can read them or that its stored session is valid.
- `debug.log` and `debug.log.old` contain no Slack page error. Matches for the word Slack were unrelated status notifications.
- No `console.log`, `pane-console.log`, or `chrome_debug.log` file was present under the inspected app/profile directories. Console capture in the extension is transient, enabled only during `zsb console`.

These observations do **not** establish that Slack currently loads, that its stored session is valid, or that the original failure is outside the app. There is no evidence-backed Slack settings change in this PR. Completing that part requires an authorized reproduction with page console/network errors and storage-access results for the failing isolated-profile tab; this task allowed only file reads on the laptop. Do not treat the requested PR title as live Slack verification.
