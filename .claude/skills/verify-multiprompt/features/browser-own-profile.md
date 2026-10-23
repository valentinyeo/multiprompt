# Own browser profile per workspace

## Sub-features

- A workspace whose id is listed in `%APPDATA%\ZigShell\browser-own-profile.txt` (one workspace id per line, read only when a pane launches) opens its browser pane in its own empty profile at `%LOCALAPPDATA%\ZigShell\BrowserWorkspaces\<engine>\own-<hash>`.
- `<hash>` is the first 24 lowercase hex characters of SHA-256 over the UTF-8 workspace id. The test vector `ws-inne-test` gives `own-9fcaf773c928d505d4457afd`; Zig tests and the journey both check it.
- Every later command for that pane (window binding, navigation, history, screenshots, lifecycle, zsb) goes to the profile's own native-host pipe `multiprompt-browser-isolated-own-<hash>` through the bridge `--profile` argument. The bridge picks the same token by reading its Chrome or Edge parent's `--user-data-dir`.
- Workspaces that are not listed keep the shared `ChromeUserData` or `EdgeUserData` profile, pipe and commands exactly as before. Nothing in the shared profile is copied, moved, claimed or deleted.
- There is no new UI: no palette row, shortcut, menu or button. The opt-in file is the only switch.

## How to get to it (user POV)

- Create or pick a workspace, find its id (`wid` in the app-written `session.json`), and add that id on its own line to `browser-own-profile.txt` next to `browser-engine.txt`.
- Open a browser pane in that workspace with Ctrl+K `open browser`, Enter. It starts signed out in a fresh profile; panes in other workspaces stay signed in as before.
- After an app restart the restored pane in that workspace opens in the same own profile again.

## Driving it with control.ps1

Run the GitHub verify.yml journey with feature `browser-own-profile`; it is in the pull-request matrix and also runs with `workflow_dispatch`. It uses the pinned Chrome for Testing, the repository extension and a disposable test-only native host, like `browser-switch-speed`. Download `verify-browser-own-profile`.

1. Launch the isolated app with `--single-window`, pass Doctor and check the journey's token derivation against the fixed test vector. Require no `BrowserWorkspaces` folder and no opt-in file.
2. Warm the shared `ChromeUserData` profile with the extension, wait for the shared native-host pipe, then stop the warmup. Open a pane in the first workspace through Ctrl+K `open browser`; read the docked HWND's process command line and require `--user-data-dir` to be the shared profile. Wait for its app-published window id, then list the shared profile's top-level and `Default` folders.
3. Ctrl+N creates a second workspace. Read its `wid`, derive the expected own folder, then write only that id to `browser-own-profile.txt` while the app runs. Snapshot `action` and open a pane in the new workspace.
4. Require the docked pane's browser process to use the own folder, otherwise fail with `Inne workspace has no own browser profile`. It must be a different process from the shared pane. Wait for the own native-host pipe and a nonzero window id, which proves the app routed binding to that profile.
5. Require the shared browser still running, no shared folder missing, no `own-`, `BrowserWorkspaces` or `workspace-owner` entry inside the shared profile, and exactly one `chrome\own-<hash>` leaf under `BrowserWorkspaces`.
6. Close the app normally and relaunch it with the same data. The restored selection must be the new workspace, and its pane must dock without an open command, use the own folder, reach the own pipe and bind a window id. Snapshot `after` and save `browser-own-profile.json`.

## Gotchas

- A released executable without this feature is expected to fail at step 4 with `Inne workspace has no own browser profile`, because its second pane opens in the shared profile.
- The opt-in file is read at pane launch, not at app start, so writing it while the app runs is a real user path. Changing it never moves an already open pane.
- The own profile is a cold first run on every runner; waits for its pane and pipe are longer than the shared ones.
- The journey never seeds session JSON and never touches the shared profile's contents; it only lists folder names.
