# Chat View everywhere

## Sub-features

- One-time Chat View on everywhere and off everywhere actions update every unlocked session.
- A session locked to Always shell view is skipped and stays locked after restart.
- Alt+C on an unlocked session sticks after switching away and back.
- The removed chat view per tab command has no palette row.
- Native ISSUE-611 tests additionally cover Always Chat View, clearing locks, both legacy global modes, shell-override migration and session save/load round trips.

## How to get to it (user POV)

- Ctrl+K, New CMD Shell, Enter opens a local session; repeat to have three sessions.
- Alt+T is the actual new workspace tmux tab shortcut, not Ctrl+T. It requires a configured workspace folder; this offline local journey uses the palette's New CMD Shell instead.
- Ctrl+1, Ctrl+2 and Ctrl+3 switch between the three sessions.
- Ctrl+K, Always shell view for this session, Enter locks session 3. Always Chat View for this session and Clear Always view for this session are the other choices; all three also appear in tab actions.
- Ctrl+K, Chat View on everywhere or Chat View off everywhere, Enter changes unlocked sessions once. Alt+C still toggles an unlocked session afterwards.

## Driving it with control.ps1

- Dispatch verify.yml with feature=chat-view-everywhere on the branch, or use its PR matrix entry. Download verify-chat-view-everywhere and inspect result.json and screenshots. A branch run executes native desktop tests, including ISSUE-611; a release run only verifies the selected executable.
- Launch the normal isolated offline CMD instance. Persist the initial session through UI Size: Reset using real Ctrl+K input. Create two more CMD sessions through Ctrl+K New CMD Shell. Require exactly three saved tabs and the newly created tab selected each time.
- Select Always shell view for this session through Ctrl+K on session 3. Require its app-written chat_view_lock to be shell and all three cv flags absent or false. Capture lock-action.png and locked-shell.png.
- Run Chat View on everywhere through Ctrl+K. Require sessions 1 and 2 cv=true, session 3 shell and locked, and no chat_view_mode field. Capture action.png and on-everywhere.png.
- Select session 1 through Ctrl+1 and require a visible native transcript. Alt+C returns it to shell. Ctrl+2 must still show Chat View; Ctrl+1 must stay shell. Capture session-1-toggled.png, session-2-chat.png and toggle-sticks.png with matching session JSON.
- Run Chat View off everywhere through Ctrl+K. Require every session shell, with session 3 still locked. Capture off-action.png, off-everywhere.png and locked-after-off.png.
- Close only the owned app normally, stop its job descendants and require zero active processes. Relaunch the same verified executable with the same isolated data directory. Doctor rechecks its PID, HWND, hash and version. Visit all three sessions through Ctrl+1/2/3 and require shell views and the persisted shell lock. Retain restart-process-tree.json and restart-session-1/2/3 screenshots and session snapshots.
- Open Ctrl+K with a known existing command first, close it with Esc, reopen an empty palette and type chat view per tab through real SendInput. Require the app's bounded palette-ready trace for all 17 characters to report count=0, target=0. Capture per-tab-absent.png showing No matches, close with Esc and capture after.png.
- Every view checkpoint independently reads the app-written session JSON and checks visible ZigShellChatTranscript controls for the selected session. Screenshots and session snapshots accompany each checkpoint. Doctor runs before every input and at completion; the shared finally block retains result.json, actions, logs, app data, screenshots and zero-process cleanup evidence.

## Gotchas

- Never seed or edit session JSON, change settings directly, send private app messages or replace missing prerequisites with a stand-in. All changes use genuine keyboard input.
- Saved shell preferences may omit cv entirely; only true means Chat View. The shell lock must explicitly remain shell.
- Palette rows are custom-painted, not UI Automation buttons. Focus-Palette waits for the existing app-written query/selected-target trace before Enter; zero-result proof uses that same trace and a screenshot, with a known positive command as its control.
- No live agent, SSH, account synchronization or remote workspace creation is claimed. The three local sessions prove view behavior only.
- This map is an executable recipe, not a claim of a completed GitHub run. Require a successful branch run and inspect its screenshots before reporting live verification.
