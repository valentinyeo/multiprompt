# Idle CPU scheduling

UI timers retain foreground responsiveness while background work uses notifications where available. Remote polling retains bounded freshness and failure fallbacks.

## Changed work

- TIMER_BROWSER_PLACEHOLDER: one-shot wake at the opening-to-not-open deadline; no timer for a covered pane, an outstanding launch, or a settled not-open label. Existing browser adoption/visibility/layout invalidations still handle actual changes.
- TIMER_UPDATE_CHECK: replaced by a nonrecursive executable-directory change notification. Rearm before posting the UI message, stat/version checks remain unchanged, stop event and join release the worker on close. The original 30 s timer is retained only if watching cannot start or subsequently fails.
- TIMER_CHAT_REFRESH: retains its 750 ms activity/status cadence, but hidden/minimized non-voice views do no refresh work. File-backed chats read only the last 70 console rows needed for working-status detection, not 1200 rows followed by discarded transcript parsing. Voice and screen-backed chats retain their previous behavior.
- TIMER_NAME_POLL: cadence unchanged; inbox publication now follows actual detected changes instead of an unconditional heartbeat. Inbox liveness uses live HWND enumeration, not file age.
- TIMER_SYSTEM_THEME: no timer for fixed themes. System themes keep the same 1/10 s normal/saving fallback and deep-idle stop; Windows broadcasts remain immediate. Loading/saving a theme or changing the power profile resynchronizes the timer, including switching back to System. The helper ignores a null startup HWND rather than creating a thread timer.
- TIMER_BROWSER_HEALTH / visibility reconciliation: global orphan-pane scans run only after coalesced EVENT_OBJECT_DESTROY notifications rather than every 2 s in every window. The existing health tick consumes pending events at 1/5/30 s by power mode, no slower than before; hung-pane checks keep their original cadence. If hook registration fails, the original 2 s scan deadline remains. Startup and name-poll reconciliation remain, and shutdown unregisters both WinEvent hooks. The sweep flag is cleared before enumeration so a subsequent event is not lost.
- Bench mailbox response wait: arm directory notification before publishing the request, inspect the response before waiting, and rearm before inspecting again. Keep the 60 s deadline and 10 ms fallback only if notifications are unavailable. This is isolated fixture transport, not evidence of an equivalent production SSH saving.
- Foreground checks shared by the retained timers: reject a different/unavailable PID or a non-Chromium class before asking for title, rectangles, ownership and window styles. The existing popup classifier already rejects those cases. Native tests verify no metadata reads for impossible popups and preserve a positive owner-linked Chromium popup; removing the early exits makes two tests fail while the positive control still passes. This avoids repeated foreign-window work without delaying focus, activity or browser checks.

## Complete timer disposition

| Timer | Disposition |
| --- | --- |
| TIMER_NAME_POLL | Existing 30 s normal / 60 s saving/deep-idle reconciliation retained: titles, process/CWD/RAM discovery, missed hook recovery and console-only tools have no complete event source. Publication changed as above. |
| TIMER_REFOCUS | Bounded user-action focus retry; preserve latency and focus guard. |
| TIMER_HOOK_UNINSTALL | Short, bounded input-release retry; retain. |
| TIMER_SPINNER | Already stops without active agents; 500/1000 ms animation and stale-event expiry must stay live. TCP notifications start it immediately. |
| TIMER_RESUME_RECONNECT | One-shot suspend/resume recovery; retain. |
| TIMER_FONT_HUD | One-shot HUD expiry; retain. |
| TIMER_INBOX_REFRESH | Only armed for Inbox/All Sessions; retain 1 s visible live-model/relative-time/ETA refresh. A directory watcher alone cannot detect dead HWNDs, remote inventories, or time expiry. |
| TIMER_SYSMENU | Bounded foreground/menu retry; retain. |
| TIMER_CAP_MSG | One-shot notice expiry; retain. |
| TIMER_BROWSER_ADOPT | Only while adopting a requested pane, with deadline; retain. |
| TIMER_BROWSER_SETTLE | Bounded geometry/visibility settling; retain. |
| TIMER_BROWSER_URL_POLL | Already active-tab-only and skips suspended/minimized/background windows; retain extension fallback for missed URL notifications and immediate navigation checks. |
| TIMER_BROWSER_EDGE_MASK_RAISE | Bounded z-order repair, suspended for browser popups; retain. |
| TIMER_REMINDERS | 30 s due-time correctness fallback; retain, not a file-only problem. |
| TIMER_CONSOLE_GEOMETRY_SETTLE | Bounded resize/monitor transition work; retain. |
| TIMER_WEBVIEW2_FOCUS | Bounded user-requested focus retry; retain. |
| TIMER_NATIVE_BROWSER_FOCUS | User-requested focus retry/deadline; retain. |
| TIMER_BROWSER_HEALTH | Retain 1/5/30 s hung-window checks; consume dirty orphan notifications instead of unconditional global enumeration. Registration failure keeps the original polling fallback. |
| TIMER_TUNNEL_KEEPER | 2/10/30 s by power mode; retain process/connection recovery, not replaced by UI-only messages. |
| TIMER_UNARCHIVE_UNATTACHED | On-demand unarchive queue, stops when drained; retain. |
| TIMER_VPS_CAPACITY | Already single leader, shared cache and 15/60 s/deep-idle stop; retain remote inventory freshness. |
| TIMER_MONITOR_TRANSITION | Bounded monitor geometry transition; retain. |
| TIMER_AI_PACE | 15/60 s/deep-idle stop; retain remote provider refresh. |
| TIMER_SYSTEM_THEME | Changed as above: no fixed-theme wakeups; retain immediate broadcasts and the unchanged System-theme fallback. |
| TIMER_BROWSER_ENGINE_SWITCH | One-shot engine transition deadline; retain. |
| TIMER_CHAT_REFRESH | Changed as above; no added delay to visible status or activity. |
| TIMER_POWER_IDLE | 30 s global input/power reevaluation, immediate foreground/resume wake already exists; retain. |
| TIMER_INBOX_PUBLISH | Already debounced one-shot after mutations; retain, remove unchanged periodic scheduling. Favorites use this same publication path. |
| TIMER_VOICE_POLL | 150 ms only while speech is playing; retain playback completion latency. |
| TIMER_VOICE_TURN_END | One-shot debounce after DONE; retain. |
| TIMER_CHAT_AC_DEBOUNCE | One retry for open autocomplete; retain. |
| TIMER_CHAT_SEND_VERIFY | Bounded verification/retry sequence after send; retain. |
| TIMER_CHAT_SEL_SCROLL | Only during selection drag; retain 50 ms interaction. Separate child HWND from SSH reconnect's numeric id. |
| TIMER_ETA_REPAINT | Only while an ETA exists; retain 15 s countdown. |
| TIMER_VOICE_TTS_POS | One-shot playback diagnostic; retain. |
| TIMER_SSH_RECONNECT | Only while reconnecting; retain 1 s deadline display and retries. |
| TIMER_CHAT_OUTBOX | Only while queued sends exist; retain delivery latency. |
| TIMER_BROWSER_PLACEHOLDER | Changed as above. |
| TIMER_CHAT_BROWSER_SWAP | One-shot first-paint browser barrier; retain. |
| TIMER_CHAT_DRAFT | One-shot composer debounce; retain durability latency. |
| TIMER_SHOT_FOCUS | Bounded screenshot/paste focus handoff; retain. |
| TIMER_CHAT_FOREGROUND_RETRY | Bounded user-action focus retry; retain. |
| TIMER_ACCOUNT | 20 s authenticated remote sync; retain server freshness; file notifications cannot observe server-side changes. |
| TIMER_FONT_SYNC | On-demand incremental font sync, stops when complete; retain. |
| TIMER_UPDATE_CHECK | Changed as above, failure fallback only. |
| TIMER_ACCOUNT_SAVE | Dirty-layout retry/debounce only; retain authentication/conflict recovery. |
| TIMER_CHAT_BENCH | Fixture-only 1 s command/heartbeat; retain hang and switch measurement semantics. |
| INPUT_HOOK_THREAD_TIMER_REQUEST_ID | 5 s low-level-hook stall watchdog, blocking GetMessage between ticks; retain missed-hook recovery. |

## Polling-loop disposition

- Chat history: visible active tab only, single cross-window worker, existing 2 s working / 8 s idle / exponential failure / 60 s missing-session schedules. Keep remote freshness; local directory notifications cannot observe remote SSH transcript appends. Completion already posts WM_APP_CHAT_FILE_READY.
- Console capture/preview/hash and title/CWD/process inventories: status-only reduction above; keep fallback scans for uninstrumented console applications and needs-input/missed-DONE correctness. Do not back off visible activity or attention checks.
- Bench response-file polling: converted as above. Bench command-file heartbeat is deliberately retained.
- SSH persistent-channel/pipe reads, initial connection, browser adoption/close, pane-id discovery, screenshots/clipboard acquisition and UI request mailboxes: bounded, operation-scoped waits; retain timeouts. No perpetual idle loop to remove.
- Notification listener: blocking accept/recv, queue plus WM_APP notification; already event-driven, no reader polling timer.
- Keyboard/mouse hooks: blocking GetMessage plus the watchdog above; already event-driven.
- Voice/TTS/audio capture/playback, dictation, image decode/paste workers: run only for an active operation, use events where supplied by the audio subsystem; retain bounded device/stream and completion waits.
- Mutex spin/yield loops: contention-only synchronization, not periodic schedulers; unchanged.
- Usage telemetry collector: existing named refresh event, per-account deadlines, 15/60 s power policy and 5 min global-idle wait; preserve provider freshness and throttle behavior.
- Account login HTTP/device polling: only during explicit sign-in, bounded cancellation/deadlines; retain protocol-required polling.
- Update helper peer-process wait: blocking WaitForMultipleObjects with a deadline, already event-driven.
- Token Ladder post-command refresh: one delayed refresh after an explicit mode change, not a recurring idle loop; retain.
