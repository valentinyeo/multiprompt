# Chat focus

## Sub-features

- A restored Chat View session starts with its typing box focused.
- Alt+Q closes Chat Find and restores typing, even without a browser pane.
- Alt+M keeps the same focus shortcut behavior as Alt+Q.
- Alt+Q restores typing after interacting with the transcript; normal browser-pane toggling is preserved.

## How to get to it (user POV)

- Launch a local CMD session and press Alt+C to turn on Chat View.
- Quit normally and reopen the app: type immediately, without clicking the typing box.
- Ctrl+F opens Find with focus on the transcript. Alt+Q or Alt+M closes Find and returns to typing.
- Click the transcript and press Alt+Q to bring typing back to the chat box. With a browser pane, Alt+Q still switches between typing and that pane.

## Driving it with control.ps1

- Dispatch verify.yml with feature=chat-focus on the branch, or use its PR matrix entry. Download verify-chat-focus and inspect result.json, screenshots, focus snapshots and UIA ValuePattern evidence.
- Launch the normal isolated offline CMD instance. Press Alt+C through real SendInput and require exactly one app-written Chat View session with no browser pane. Capture chat-enabled.png with the owned composer Edit focused.
- Reuse Restart-ChatView, shared with chat-view-everywhere: close only the owned app normally, stop its job descendants and require zero active processes. Relaunch the same verified executable with the same isolated data directory. Recheck the owned PID, HWND, hash and version with Doctor; retain restart-process-tree.json.
- Before any typing or focus-repair chord after restart, require UIA FocusedElement is a visible Edit in the app PID under the owned frame. Require its ValuePattern is empty, type abc through real keys, and require ValuePattern reads exactly abc. Capture restart-typing-focused.png, restart-typing.png and restart-typing.value.json.
- Clear the draft with Ctrl+A and Backspace. Press Ctrl+F and require the owned ZigShellChatTranscript focused; capture find-open.png. Press Alt+Q, require the composer focused and empty, type abc, and require exactly abc through ValuePattern. Capture find-alt-q-typing-focused.png, find-alt-q-typing.png and its value evidence. This checkpoint rejects a Find overlay that remained open and merely swallowed typing.
- Clear the draft, Esc any remaining Find, locate the visible owned transcript and ownership-check its native handle, PID, root and client rectangle. Click its center with real mouse SendInput, capture transcript-clicked.png, then press Alt+Q and require composer focus and exact abc typing again. Retain transcript-alt-q-typing screenshots and value evidence.
- Clear the draft and repeat the Find checkpoint with Alt+M; retain alias-find-open.png and find-alt-m-typing evidence.
- Doctor runs before every keyboard or mouse input and at completion. All waits are bounded condition waits. The shared finally block retains result.json, actions, logs, app data, screenshots and zero-process cleanup evidence.
- Run the same recipe with tag=v0.28.848 as a negative control: Alt+Q without a pane cannot escape Find, so composer focus or exact typing must fail. Then run the branch and require every checkpoint to pass. Do not claim either result until its Windows artifacts have been inspected.

## Gotchas

- Never seed or edit session JSON, use private app messages, call UIA SetFocus/SetValue, or insert a stand-in agent. All state changes use genuine keyboard or mouse input; JSON and UIA are read-only evidence.
- Empty transcript clicks currently return focus to the composer on mouse-up. The click checkpoint records the actual focused element rather than claiming that a click necessarily leaves transcript focus; the Find checkpoints independently require real transcript focus before Alt+Q and Alt+M.
- The journey has no browser pane and no remote agent. It proves typing and Find recovery, not browser navigation or live message delivery. Native decision tests cover preserving the existing pane toggle from composer/pane focus and repairing null/frame/transcript focus.
- This map is an executable recipe, not a claim of a completed Windows run. Require the failing release control and successful branch artifacts before reporting live verification.
