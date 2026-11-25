# Chat composer dictation

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/control-feature-chat-dictation.ps1, src/voice.zig

Verify on: push

## Sub-features

- Ctrl+D starts the existing dictation state; the microphone, left of the send button, visibly changes from the idle glyph to an accented glyph on a filled background.
- Enter, a second Ctrl+D, and a real microphone click each stop listening and append the transcript immediately to the native message box, without another keystroke or send.
- The send button sits at the far right in every state, with the microphone to its left. While dictating, one press on send, or Ctrl+Enter, stops the dictation, keeps every spoken word and sends the whole message; the sent message holds the typed and spoken words exactly once, read from the app outbox after the box empties. Stopping with the microphone still only fills the box.
- Normal composer typing remains available while listening, and that typed draft survives transcription.
- In Chat View the header beside the session title never shows dictation status text, and no model or context line sits under the title.

## How to get to it (user POV)

Open Chat View with Alt+C. Focus the message box and press Ctrl+D. Type while listening, then stop with Enter, Ctrl+D, or the microphone left of the send button. Press send, or Ctrl+Enter, to stop and send in one action. The dictated words appear in the unsent draft.

## Driving it with control.ps1

Run this journey on GitHub Windows:

```sh
gh workflow run verify.yml -f feature=chat-dictation
```

Leave `tag` empty for the offline fixture boundary. Windows runtime proof now exists. Two first-attempt journeys passed on `d7437dd7`: [40263673090](https://github.com/valentinyeo/multiprompt/actions/runs/40263673090) and [40264332073](https://github.com/valentinyeo/multiprompt/actions/runs/40264332073). Repeat with independent dispatches for a longer streak.

The five-minute step cap leaves time for uploads. Each wait logs its condition and timeout. Launch, Doctor, Drive, Evidence, and Cleanup print progress. Failure uploads retain screenshots and logs.

[Deliberate capture stall](https://github.com/valentinyeo/multiprompt/actions/runs/40262943273) fails after one second. Its message names the missing capture precondition. Screenshots and logs survive; owned processes reach zero.

[Native audit regression](https://github.com/valentinyeo/multiprompt/actions/runs/40262947063) retains 401 complete records under concurrent writers. The original exclusive append fails that same oracle. Records now append atomically without writer exclusion. The reader permits writers and returns plain strings. Deep JSON no longer expands provider metadata.

The normal control.ps1 Launch / Doctor / Drive / Evidence / Cleanup contract applies, including hash/version/PID/HWND checks, SendInput, an isolated profile, disabled updates, offline login, and zero active owned processes after cleanup. The harness chooses Dark through the real palette, opens Chat View, verifies the owned native Edit and transcript HWNDs, and derives the rightmost microphone rectangle from their actual geometry and the window DPI at default UI scale. It never reads private app memory or posts app messages.

For each stop method (`dictation-enter`, `dictation-ctrl-d`, `dictation-mic-click`):

1. Require an empty native Edit, press Ctrl+D and require the recorded audio to reach the production capture worker.
2. Capture microphone pixels: more than half the button must be the Dark active fill (63,83,113), with the accent microphone glyph (80,150,255). Baseline and stopped samples instead require no active fill and the idle glyph (137,146,164).
3. Type a distinct marker and require exact WM_GETTEXT while the microphone is still active, with native focus still on the original Edit.
4. Stop with real Enter, Ctrl+D or a mouse click inside the ownership-checked microphone rectangle. Require exact `typing-<method> Go forward ten meters.` through bounded Unicode WM_GETTEXT within **1000 ms** from the stop input, before any additional input or screenshot. Both the poll and an independent monotonic elapsed-time assertion enforce the bound.
5. Require the idle microphone, the production audio/response/status/composer-delivery audit stages, and retain the draft. Only normal Ctrl+A / Backspace clear between cases.

Artifact: `verify-chat-dictation`. Inspect `before.png`, `action.png`, `after.png`, each `*-listening.png` / `*-delivered.png`, `*-mic.png` and `*-mic.json`, each `<method>.text.json`, `actions.json`, `doctor.json`, `build.json`, `result.json`, `process-tree.json`, and `data/roaming/ZigShell/dictation-audit.log`. The text records contain exact WM_GETTEXT, expected text, HWND/PID and elapsed milliseconds. `result.json` retains all three named cases and the explicit boundary. No screenshot has been inspected until a real run is downloaded.

Two extra cases make the provider slow on purpose (MUBO-290). The file `%APPDATA%\ZigShell\dictation-stall` makes the offline fixture transcription wait 2.5 s before it answers, so only the recording and the button can change the screen. Stop and send each start dictation, type a marker, then click the real stop or send control. Within **1000 ms** of that click the microphone must be the idle glyph with no active fill, the typed marker must still sit in the box, and the audit must show `fixture-provider-stall` without `fixture-provider-stall-end`, which proves the button returned while the background transcription was still running. The case then waits for the stall to finish: for send the armed message leaves exactly once, and only once the words are known. The stall lives inside the offline fixture boundary and cannot run outside `chat-dictation`.

## Gotchas

The recording control is an expanded pill with a stop square, elapsed timer and waveform, not merely an accented microphone. The current journey checks animation, Escape discard and restart. Live preview can update text during recording, while the offline fixture disables it. Enter while recording is stop-only; stop-and-send is a separate explicit path.


The existing `chat_dictation_engine_toggle` unit-test seam replaces the engine and cannot prove the real app's transcription/delivery path. The added `MULTIPROMPT_DICTATION_FIXTURE` boundary in `src/voice.zig` is enabled only with `GITHUB_ACTIONS=true`, `RUNNER_OS=Windows` and `MULTIPROMPT_NO_LOGIN=1`. Only this journey sets it; the harness clears inherited values for other ordinary journeys and restores the environment during cleanup.

The checked-in, checksum-pinned CMUSphinx recording is 16 kHz mono signed 16-bit PCM saying “go forward ten meters.” See `tools/fixtures/IGSH-812/README.md`, source revision and bundled license. Capture reads those actual bytes and stays listening until the real user stop changes the production recording flag. The provider boundary requires byte-for-byte matching audio before replaying a hand-authored provider-format response. It feeds the real `parseDeepgramTranscript`, UTF-8 conversion, worker completion message, stable draft-owner routing and native Edit update. Missing/mismatched fixtures fail closed; there is no fallback to live STT, API key, local server, network dependency or secret. This proves app transcription-response handling and delivery, **not acoustic recognition quality, microphone hardware or Deepgram availability**.

Red-run reasoning: pre-feature commit `f94e5952` has neither the Ctrl+D composer route nor the microphone; an identical driver with the fixture boundary supplied would fail start/active-pixel assertions. That commit also predates the boundary, so an unmodified build would fail capture readiness first, not constitute an isolated feature red run. That pre-feature control remains unclaimed. The audit regressions above use real pre-fix readers and writers. Removing Enter/second-Ctrl+D/click stop routing leaves the exact-text deadline unmet; deferred insertion or dropped/misrouted text fails exact WM_GETTEXT within 1000 ms; blocking typing fails the listening-time marker assertion; a stuck/unchanged mic fails the independent pixel checks. `tools/chat-dictation.test.js` includes source-contract mutation controls and fixture integrity checks, executed by GitHub's existing Check verification contracts step, not on the VPS.

The existing Check workspace focus journey contract remains unchanged. Check browser recovery journey contract enforces exact feature-map / ValidateSet equality and an implementation for every map, including this one. Validate journey and syntax accepts this stem, rejects release tags and parses the complete driver. Existing journeys and contract assertions are not removed or weakened.
