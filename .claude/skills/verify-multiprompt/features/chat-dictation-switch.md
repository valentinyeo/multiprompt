# Dictation stops when the chat changes

Source files: src/console.zig, src/chat_composer.zig, src/voice.zig, src/dictation_live.zig, src/chat_drafts.zig, src/main.zig, src/session.zig, .claude/skills/verify-multiprompt/control-feature-chat-dictation-switch.ps1, .claude/skills/verify-multiprompt/control-library.ps1

## Sub-features

- Recording in one chat and switching to another chat with Ctrl+Tab stops the recording on the chat that started it.
- The switch writes one `chat-switch` stage and one `cancel` stage to the production dictation audit log, so the stop is the existing cancel path, not a second stop implementation.
- The spoken audio never reaches transcription after a chat switch: no provider response, no HTTP status and no composer or shell delivery stage is written for that recording.
- The chat that is now in front keeps an empty message box, the microphone shows its idle glyph, and returning to the chat that started the recording also shows an empty message box because the abandoned words are dropped.
- A second dictation started after the switch still records and delivers in the ordinary way.

## How to get to it (user POV)

Two local chats in one window, both already in Chat View. Open the first chat, press Ctrl+D to dictate, then press Ctrl+Tab. The recording stops when the second chat appears, its message box stays empty, and no dictated text ever arrives in either chat.

## Driving it with control.ps1

Run this journey on GitHub Windows:

```sh
gh workflow run verify.yml -f feature=chat-dictation-switch
```

Leave `tag` empty. The journey uses the same offline dictation fixture boundary as the ordinary Chat dictation journey: recorded CMUSphinx PCM and a hand-authored provider-format response replace only the microphone and provider I/O.

1. Before launch the harness writes the saved-tab file once: two local CMD tabs, both already in Chat View, with the first selected.
2. Open Chat View on the first chat with Alt+C, click the owned composer, require the idle microphone pixels and an empty native Edit.
3. Press Ctrl+D and require the recorded audio to reach the production capture worker, then require the active microphone pixels.
4. Press Ctrl+Tab and require the second tab as the selected saved session, then require the `chat-switch` stage within two seconds. This is the failing assertion on the pre-fix build.
5. Require the capture worker to finish (`audio-bytes`), require that neither `fixture-response-bytes`, `http-status`, `target-chat-composer` nor `target-shell` is ever written, and require the second chat's native Edit to stay exactly empty with idle microphone pixels.
6. Press Ctrl+Tab again, require the first chat's native Edit to stay exactly empty, and require the delivery stages to stay absent.

Artifact: `verify-chat-dictation-switch`. Inspect `before.png`, `listening.png`, `action.png`, `after.png`, every `*-mic.png` / `*-mic.json`, `switch-stop.json`, `actions.json`, `doctor.json`, `build.json`, `result.json`, `process-tree.json`, and `data/roaming/ZigShell/dictation-audit.log`.

## Gotchas

The ruled-out alternative is keeping the microphone open across a chat switch. The two existing chats prove the bug through the tab switch a user makes, not through a settings file or a private message.

The fix lives on the one path every tab switch takes, so a click on another chat row and Ctrl+Tab stop the recording the same way. Voice Mode's always-listening capture is a different surface and is left alone.

The second chat needs Chat View already on in the saved session, otherwise the switch closes the composer and the empty message box cannot be read. The composer Edit control is shared across chats, so the journey re-resolves it from the window after the switch instead of trusting the first handle.

Red proof: [run 45463197212](https://github.com/valentinyeo/multiprompt/actions/runs/45463197212) on journey commit `43191bbe` fails at the `chat-switch` wait, and its audit log holds only `start` and `fixture-audio-bytes` after the switch, so the recording kept running. Green proof: [run 45470820802](https://github.com/valentinyeo/multiprompt/actions/runs/45470820802) on fix commit `2a60b35c` passes the same recipe with `cancel` and `chat-switch` 361 ms after Ctrl+Tab, no transcription or delivery stage, and both message boxes empty.
