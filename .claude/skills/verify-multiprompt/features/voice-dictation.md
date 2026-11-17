# Voice and dictation

Journeys: chat-dictation

## Sub-features

The recipes below name the user actions, expected result and exact boundary.

## How to get to it (user POV)

Use the entry paths in the action table below on a disposable owned profile.

## Driving it with drive.ps1

Preconditions: a healthy GitHub Windows instance and the selected journey prerequisites.

Use `verify.yml` with the named executable journey, not this map stem. A journey is a recipe, not a claim of a live pass.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### voice: Voice and dictation

Start dictation with Ctrl+D, microphone and Ctrl+Shift+Space. Alt+V reads replies, a later press selects an older reply, and a double-press stops playback. Enter while recording is stop-only; use an explicit send action afterward. Type while recording; stop with the documented method, send or Escape-discard separately. Read a reply with Alt+V and Alt+R, select older/newer replies with Alt+[/], cycle Voice Speed, interrupt speech and toggle always-listening modes.

Observable proof: Recording state and exact draft insertion agree; Escape inserts nothing and stopping does not accidentally send. Speech reads the selected reply and stops when requested. Speed/policy persist without changing chat identity or draft.

Journey: chat-dictation proves recorded PCM/provider replay, not live recognition or audible speech. UNREACHABLE for real recognition until an owned microphone and valid saved disposable Deepgram credential are available. Playback can use credential-free Windows SAPI, but audible proof still needs owned audio output and acoustic capture. Native navigation/stop/speed assertions are also missing; journey.mp4 records no audio.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_DICTATION_OFFSET` | Ctrl+K, type **dictation**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_ALWAYS_OFF_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_VOICE_ALWAYS_ON_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_VOICE_MODE_OFF_OFFSET` | Ctrl+K, type **voice**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_MODE_ON_OFFSET` | Ctrl+K, type **voice**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_REPLAY_OFFSET` | Ctrl+K, type **read**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_SPEED_100_OFFSET` | Ctrl+K, type **voice speed**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_SPEED_125_OFFSET` | No distinct palette row. Cycle **Voice Speed** to this value; use the recipe above. |
| `SEARCH_VOICE_SPEED_140_OFFSET` | No distinct palette row. Cycle **Voice Speed** to this value; use the recipe above. |
| `SEARCH_VOICE_SPEED_150_OFFSET` | No distinct palette row. Cycle **Voice Speed** to this value; use the recipe above. |
| `SEARCH_VOICE_STOP_OFFSET` | Ctrl+K, type **stop speaking**, then select the matching action with Up/Down and Enter. Follow `voice` above. |
| `SEARCH_VOICE_PREVIOUS_OFFSET` | UNREACHABLE as a distinct palette row: the retained label/handler has no current result insertion. Use Alt+[ to read the previous reply. |
| `SEARCH_VOICE_NEXT_OFFSET` | UNREACHABLE as a distinct palette row: the retained label/handler has no current result insertion. Use Alt+] to read the next reply. |

## Gotchas

Never treat an offline, synthetic or diagnostic check as authenticated end-to-end proof.
