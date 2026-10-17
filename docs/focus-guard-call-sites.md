# Focus guard call-site audit (issue)

App 0.28.687 / bridge-extension 1.0.59. The retained Win32 API names in
`src/main.zig` are now guarded Zig wrappers, not unrestricted extern imports.
Only `FocusNative` declares the raw APIs; their invocations are confined to the
wrapper boundary. All call sites below therefore changed behavior centrally,
including existing sites whose source spelling did not change.

Explicit path changes:
- `focusBrowserThenConsole`: removed foreground/refocus round trip; exact binding only.
- `focusActiveShellInner`, `focusActiveBrowserPane`, `requestShellRefocus`, native
  browser request and refocus/composer retry timers: authorization before focus tricks.
- Foreground WinEvent callback and launch-beacon adoption: return to remembered
  typing surface before interpreting an unsolicited Chromium activation.
- Snippet/URL/tab/window/group editors, workspace activation and system Alt+Tab:
  authorize before synthetic Alt or cross-thread handoffs.
- WebView2 focus callbacks/tab opening: same focus policy, no agent focus flag.
- Screenshot delivery: paste first, authorize before changing workspace/session
  or handing off to the composer; background deliveries cannot hide the typing console.
- Pane shows/geometry: `SW_SHOWNOACTIVATE` / `SWP_NOACTIVATE`.
- Keyboard, permanent mouse and native UI dispatch: carry actual user-action
  provenance, invalidate deferred requests on newer input, exclude injected input.
- `extension/bridge.js`: `openExternalUrlInEscapeWindow` and
  `moveExternalTabOutOfZigShell` create unfocused windows; `raiseExternalWindow`
  no longer requests OS focus. Pane tab activation is unchanged.
- `src/bridge.zig`: legacy `fgUnlock` cannot grant foreground permission.

## Centrally guarded native call sites

Counts exclude extern declarations and raw wrapper implementations; repeated
attach/detach calls are included. Line references describe this revision.

AllowSetForegroundWindow: 2; AttachThreadInput: 22; SetFocus: 48; SetForegroundWindow: 28; SetWindowPos: 29; ShowWindow: 77; ShowWindowAsync: 3; SwitchToThisWindow: 1

| Source | Function/handler | Guarded call(s) |
|---|---|---|
| `src/main.zig:1040` | `parkBrowserForMonitorTransition` | `ShowWindow` |
| `src/main.zig:5848` | `focusGuardReturnFromPane` | `AttachThreadInput` |
| `src/main.zig:5849` | `focusGuardReturnFromPane` | `AttachThreadInput` |
| `src/main.zig:5851` | `focusGuardReturnFromPane` | `SetForegroundWindow` |
| `src/main.zig:5852` | `focusGuardReturnFromPane` | `SetFocus` |
| `src/main.zig:5853` | `focusGuardReturnFromPane` | `AttachThreadInput` |
| `src/main.zig:5854` | `focusGuardReturnFromPane` | `AttachThreadInput` |
| `src/main.zig:9301` | `focusLiveWorkspaceTarget` | `ShowWindowAsync` |
| `src/main.zig:9303` | `focusLiveWorkspaceTarget` | `SetForegroundWindow` |
| `src/main.zig:9326` | `findAndFocusWorkspaceWindow` | `ShowWindowAsync` |
| `src/main.zig:9328` | `findAndFocusWorkspaceWindow` | `SetForegroundWindow` |
| `src/main.zig:11377` | `accountLock` | `ShowWindow` |
| `src/main.zig:11381` | `accountLock` | `SetForegroundWindow` |
| `src/main.zig:11382` | `accountLock` | `SetFocus` |
| `src/main.zig:13143` | `restoreSession` | `ShowWindow` |
| `src/main.zig:13267` | `detachShellsForRestart` | `ShowWindow` |
| `src/main.zig:13326` | `reclaimShell` | `SetWindowPos` |
| `src/main.zig:13327` | `reclaimShell` | `ShowWindow` |
| `src/main.zig:16107` | `detachTabToNewWindow` | `ShowWindow` |
| `src/main.zig:16319` | `detachTabToNewWindow` | `SetWindowPos` |
| `src/main.zig:16334` | `detachTabToExistingWindow` | `ShowWindow` |
| `src/main.zig:16407` | `detachTabToExistingWindow` | `SetWindowPos` |
| `src/main.zig:16408` | `detachTabToExistingWindow` | `ShowWindow` |
| `src/main.zig:18652` | `layoutSnippetCreateControls` | `SetWindowPos` |
| `src/main.zig:18655` | `layoutSnippetCreateControls` | `SetWindowPos` |
| `src/main.zig:18673` | `snippetEditSubclassProc` | `SetFocus` |
| `src/main.zig:18679` | `snippetEditSubclassProc` | `SetFocus` |
| `src/main.zig:18681` | `snippetEditSubclassProc` | `SetFocus` |
| `src/main.zig:18703` | `focusSnippetFormInput` | `AttachThreadInput` |
| `src/main.zig:18705` | `focusSnippetFormInput` | `SetForegroundWindow` |
| `src/main.zig:18706` | `focusSnippetFormInput` | `SetFocus` |
| `src/main.zig:18707` | `focusSnippetFormInput` | `AttachThreadInput` |
| `src/main.zig:19659` | `wakeSnapshotWorkspace` | `ShowWindow` |
| `src/main.zig:19744` | `wakeWorkspaceByIndex` | `ShowWindow` |
| `src/main.zig:20590` | `spawnShellWithSession` | `SetWindowPos` |
| `src/main.zig:20591` | `spawnShellWithSession` | `ShowWindow` |
| `src/main.zig:20735` | `respawnShellInPlace` | `ShowWindow` |
| `src/main.zig:20806` | `respawnShellInPlace` | `SetWindowPos` |
| `src/main.zig:20807` | `respawnShellInPlace` | `ShowWindow` |
| `src/main.zig:20889` | `respawnShellInPlace` | `ShowWindow` |
| `src/main.zig:20932` | `markSshTabDisconnected` | `ShowWindow` |
| `src/main.zig:20960` | `markPinnedLocalTabDisconnected` | `ShowWindow` |
| `src/main.zig:23244` | `closeAllSessions` | `ShowWindow` |
| `src/main.zig:23629` | `activateSessionOverviewRow` | `ShowWindow` |
| `src/main.zig:23857` | `closeShellRemember` | `ShowWindow` |
| `src/main.zig:23977` | `switchToShell` | `ShowWindow` |
| `src/main.zig:24066` | `switchToShell` | `SetFocus` |
| `src/main.zig:24068` | `switchToShell` | `ShowWindow` |
| `src/main.zig:24216` | `switchToWorkspace` | `ShowWindow` |
| `src/main.zig:25928` | `parkMainWindowBeforeActiveShellRemoval` | `AttachThreadInput` |
| `src/main.zig:25929` | `parkMainWindowBeforeActiveShellRemoval` | `SetForegroundWindow` |
| `src/main.zig:25930` | `parkMainWindowBeforeActiveShellRemoval` | `SetFocus` |
| `src/main.zig:25931` | `parkMainWindowBeforeActiveShellRemoval` | `AttachThreadInput` |
| `src/main.zig:25977` | `focusActiveShellInner` | `SetForegroundWindow` |
| `src/main.zig:25987` | `focusActiveShellInner` | `SetFocus` |
| `src/main.zig:26009` | `focusActiveShellInner` | `SetForegroundWindow` |
| `src/main.zig:26010` | `focusActiveShellInner` | `SetFocus` |
| `src/main.zig:26038` | `focusActiveShellInner` | `SetForegroundWindow` |
| `src/main.zig:26039` | `focusActiveShellInner` | `SetFocus` |
| `src/main.zig:26075` | `focusActiveShellInner` | `SetForegroundWindow` |
| `src/main.zig:26084` | `focusActiveShellInner` | `AttachThreadInput` |
| `src/main.zig:26085` | `focusActiveShellInner` | `AttachThreadInput` |
| `src/main.zig:26086` | `focusActiveShellInner` | `SetForegroundWindow` |
| `src/main.zig:26087` | `focusActiveShellInner` | `SetFocus` |
| `src/main.zig:26088` | `focusActiveShellInner` | `AttachThreadInput` |
| `src/main.zig:26089` | `focusActiveShellInner` | `AttachThreadInput` |
| `src/main.zig:26123` | `focusActiveBrowserPane` | `AttachThreadInput` |
| `src/main.zig:26124` | `focusActiveBrowserPane` | `AttachThreadInput` |
| `src/main.zig:26126` | `focusActiveBrowserPane` | `SetForegroundWindow` |
| `src/main.zig:26127` | `focusActiveBrowserPane` | `SetFocus` |
| `src/main.zig:26128` | `focusActiveBrowserPane` | `AttachThreadInput` |
| `src/main.zig:26129` | `focusActiveBrowserPane` | `AttachThreadInput` |
| `src/main.zig:26273` | `switchSystemAltTabToForeign` | `ShowWindow` |
| `src/main.zig:26274` | `switchSystemAltTabToForeign` | `SwitchToThisWindow` |
| `src/main.zig:26278` | `switchSystemAltTabToForeign` | `AttachThreadInput` |
| `src/main.zig:26279` | `switchSystemAltTabToForeign` | `SetForegroundWindow` |
| `src/main.zig:26280` | `switchSystemAltTabToForeign` | `AttachThreadInput` |
| `src/main.zig:26314` | `verifyShellWindowSize` | `SetWindowPos` |
| `src/main.zig:26320` | `verifyShellWindowSize` | `SetWindowPos` |
| `src/main.zig:27882` | `showBrowserWindowAsync` | `ShowWindowAsync` |
| `src/main.zig:27887` | `setBrowserWindowPosAsync` | `SetWindowPos` |
| `src/main.zig:27983` | `dockBrowserWindow` | `SetForegroundWindow` |
| `src/main.zig:27984` | `dockBrowserWindow` | `SetFocus` |
| `src/main.zig:28245` | `positionActiveBrowser` | `ShowWindow` |
| `src/main.zig:28309` | `positionActiveBrowser` | `SetWindowPos` |
| `src/main.zig:28313` | `positionActiveBrowser` | `SetWindowPos` |
| `src/main.zig:28408` | `hideBrowserFloatingChrome` | `ShowWindow` |
| `src/main.zig:28570` | `updateBrowserVisibility` | `ShowWindow` |
| `src/main.zig:28605` | `updateBrowserVisibility` | `ShowWindow` |
| `src/main.zig:28629` | `updateBrowserVisibility` | `ShowWindow` |
| `src/main.zig:28639` | `updateBrowserVisibility` | `ShowWindow` |
| `src/main.zig:28644` | `updateBrowserVisibility` | `ShowWindow` |
| `src/main.zig:28675` | `hideActiveBrowser` | `ShowWindow` |
| `src/main.zig:29348` | `ensureBrowserEdgeMaskWindows` | `SetWindowPos` |
| `src/main.zig:29349` | `ensureBrowserEdgeMaskWindows` | `ShowWindow` |
| `src/main.zig:29361` | `hideBrowserEdgeMasks` | `ShowWindow` |
| `src/main.zig:29362` | `hideBrowserEdgeMasks` | `SetWindowPos` |
| `src/main.zig:29392` | `raiseBrowserEdgeMasksZOrderOnly` | `SetWindowPos` |
| `src/main.zig:29457` | `moveBrowserEdgeMask` | `SetWindowPos` |
| `src/main.zig:29459` | `moveBrowserEdgeMask` | `ShowWindow` |
| `src/main.zig:29584` | `ensureUrlBarWindow` | `SetWindowPos` |
| `src/main.zig:29699` | `startBrowserUrlBarEdit` | `SetForegroundWindow` |
| `src/main.zig:29700` | `startBrowserUrlBarEdit` | `SetFocus` |
| `src/main.zig:29789` | `focusActiveWebView2` | `AttachThreadInput` |
| `src/main.zig:29790` | `focusActiveWebView2` | `SetForegroundWindow` |
| `src/main.zig:29791` | `focusActiveWebView2` | `SetFocus` |
| `src/main.zig:29795` | `focusActiveWebView2` | `AttachThreadInput` |
| `src/main.zig:29922` | `toggleWebView2` | `ShowWindow` |
| `src/main.zig:32786` | `chatCopySelection` | `SetFocus` |
| `src/main.zig:33032` | `chatTranscriptWndProc` | `SetFocus` |
| `src/main.zig:33059` | `chatTranscriptWndProc` | `SetForegroundWindow` |
| `src/main.zig:33097` | `chatTranscriptWndProc` | `SetFocus` |
| `src/main.zig:33359` | `chatAcClose` | `ShowWindow` |
| `src/main.zig:33370` | `chatAcLayout` | `SetWindowPos` |
| `src/main.zig:33474` | `chatAcWndProc` | `SetFocus` |
| `src/main.zig:33705` | `chatAcOpenBrowse` | `SetFocus` |
| `src/main.zig:33801` | `selectChatSkill` | `SetFocus` |
| `src/main.zig:34056` | `sendLocalChatPromptEx` | `ShowWindow` |
| `src/main.zig:34067` | `sendLocalChatPromptEx` | `ShowWindow` |
| `src/main.zig:34068` | `sendLocalChatPromptEx` | `ShowWindow` |
| `src/main.zig:34069` | `sendLocalChatPromptEx` | `ShowWindow` |
| `src/main.zig:34071` | `sendLocalChatPromptEx` | `SetForegroundWindow` |
| `src/main.zig:34072` | `sendLocalChatPromptEx` | `SetFocus` |
| `src/main.zig:35817` | `openChatView` | `ShowWindow` |
| `src/main.zig:35818` | `openChatView` | `ShowWindow` |
| `src/main.zig:35821` | `openChatView` | `SetForegroundWindow` |
| `src/main.zig:35822` | `openChatView` | `SetFocus` |
| `src/main.zig:35854` | `closeChatView` | `ShowWindow` |
| `src/main.zig:35855` | `closeChatView` | `ShowWindow` |
| `src/main.zig:35857` | `closeChatView` | `ShowWindow` |
| `src/main.zig:35919` | `insertTextIntoChatComposer` | `SetFocus` |
| `src/main.zig:36892` | `repositionActive` | `ShowWindow` |
| `src/main.zig:36897` | `repositionActive` | `ShowWindow` |
| `src/main.zig:36945` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:36946` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:36963` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:36964` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:36987` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:36988` | `repositionActive` | `SetWindowPos` |
| `src/main.zig:37204` | `editSubclassProc` | `SetFocus` |
| `src/main.zig:37254` | `startWindowRename` | `SetForegroundWindow` |
| `src/main.zig:37255` | `startWindowRename` | `SetFocus` |
| `src/main.zig:37342` | `startRenameInternal` | `SetForegroundWindow` |
| `src/main.zig:37343` | `startRenameInternal` | `SetFocus` |
| `src/main.zig:37393` | `startGroupRename` | `SetForegroundWindow` |
| `src/main.zig:37394` | `startGroupRename` | `SetFocus` |
| `src/main.zig:37514` | `commitRename` | `SetFocus` |
| `src/main.zig:37674` | `showGroupHeaderMenu` | `SetForegroundWindow` |
| `src/main.zig:37675` | `showGroupHeaderMenu` | `SetFocus` |
| `src/main.zig:37763` | `hideShellsForOverlay` | `ShowWindow` |
| `src/main.zig:37766` | `hideShellsForOverlay` | `ShowWindow` |
| `src/main.zig:37767` | `hideShellsForOverlay` | `ShowWindow` |
| `src/main.zig:37785` | `showActiveShellAfterOverlay` | `ShowWindow` |
| `src/main.zig:37786` | `showActiveShellAfterOverlay` | `ShowWindow` |
| `src/main.zig:37792` | `showActiveShellAfterOverlay` | `SetFocus` |
| `src/main.zig:37795` | `showActiveShellAfterOverlay` | `ShowWindow` |
| `src/main.zig:49830` | `openUrlPicker` | `ShowWindow` |
| `src/main.zig:49835` | `openUrlPicker` | `SetFocus` |
| `src/main.zig:49850` | `closeUrlPickerInternal` | `ShowWindow` |
| `src/main.zig:51328` | `handleShotPaste` | `SetForegroundWindow` |
| `src/main.zig:51329` | `handleShotPaste` | `SetFocus` |
| `src/main.zig:51348` | `handleShotPaste` | `ShowWindow` |
| `src/main.zig:57197` | `startInboxRename` | `SetFocus` |
| `src/main.zig:57590` | `openInbox` | `ShowWindow` |
| `src/main.zig:57593` | `openInbox` | `ShowWindow` |
| `src/main.zig:57594` | `openInbox` | `ShowWindow` |
| `src/main.zig:57612` | `closeInbox` | `ShowWindow` |
| `src/main.zig:57613` | `closeInbox` | `ShowWindow` |
| `src/main.zig:57617` | `closeInbox` | `SetFocus` |
| `src/main.zig:57619` | `closeInbox` | `ShowWindow` |
| `src/main.zig:57695` | `jumpToInboxRow` | `ShowWindow` |
| `src/main.zig:57708` | `jumpToInboxRow` | `AllowSetForegroundWindow` |
| `src/main.zig:59439` | `wndProc` | `SetWindowPos` |
| `src/main.zig:59602` | `wndProc` | `SetFocus` |
| `src/main.zig:60573` | `wndProc` | `ShowWindow` |
| `src/main.zig:60670` | `wndProc` | `ShowWindow` |
| `src/main.zig:61043` | `wndProc` | `ShowWindow` |
| `src/main.zig:61144` | `wndProc` | `ShowWindow` |
| `src/main.zig:61581` | `wndProc` | `SetFocus` |
| `src/main.zig:61662` | `wndProc` | `AttachThreadInput` |
| `src/main.zig:61663` | `wndProc` | `SetForegroundWindow` |
| `src/main.zig:61664` | `wndProc` | `SetFocus` |
| `src/main.zig:61665` | `wndProc` | `AttachThreadInput` |
| `src/main.zig:61773` | `wndProc` | `SetFocus` |
| `src/main.zig:61974` | `wndProc` | `SetFocus` |
| `src/main.zig:62020` | `wndProc` | `SetFocus` |
| `src/main.zig:62283` | `wndProc` | `AllowSetForegroundWindow` |
| `src/main.zig:62285` | `wndProc` | `SetForegroundWindow` |
| `src/main.zig:62286` | `wndProc` | `SetFocus` |
| `src/main.zig:62366` | `wndProc` | `ShowWindow` |
| `src/main.zig:62375` | `wndProc` | `SetWindowPos` |
| `src/main.zig:62377` | `wndProc` | `ShowWindow` |
| `src/main.zig:62380` | `wndProc` | `ShowWindow` |
| `src/main.zig:62382` | `wndProc` | `ShowWindow` |
| `src/main.zig:62389` | `wndProc` | `ShowWindow` |
| `src/main.zig:62394` | `wndProc` | `SetWindowPos` |
| `src/main.zig:62403` | `wndProc` | `ShowWindow` |
| `src/main.zig:64875` | `wndProc` | `SetFocus` |
| `src/main.zig:64909` | `wndProc` | `SetFocus` |
| `src/main.zig:64942` | `wndProc` | `SetFocus` |
| `src/main.zig:65010` | `wndProc` | `SetFocus` |
| `src/main.zig:65030` | `wndProc` | `SetFocus` |
| `src/main.zig:65036` | `wndProc` | `SetForegroundWindow` |
| `src/main.zig:65677` | `wndProc` | `SetWindowPos` |
| `src/main.zig:65746` | `wndProc` | `ShowWindow` |
| `src/main.zig:65749` | `wndProc` | `ShowWindow` |
| `src/main.zig:65804` | `wndProc` | `ShowWindow` |
| `src/main.zig:66360` | `main` | `SetWindowPos` |
| `src/main.zig:66406` | `main` | `ShowWindow` |
| `src/main.zig:66411` | `main` | `SetForegroundWindow` |

## Evidence and limits

The ten extracted-production Zig tests execute authorization and restoration
with mocked Win32 queues/windows: typing in console/composer, intentional Alt+Q,
physical pane click, superseding typing/foreign input, timeouts, nonactivating
shows/raise, message provenance and exact-console restoration across sessions and exact second-pane ownership.
The real extension dispatcher is exercised by the focus regression, and the
complete tool/extension Node suite and Zig Windows build pass. Historical
pre-fix sources plus deliberately injected raw-focus leaks fail the audits.

No live Windows typing acceptance, app restart, unpacked extension reload,
remote deployment was required for these portable checks.
