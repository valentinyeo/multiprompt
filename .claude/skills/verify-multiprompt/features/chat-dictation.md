# Chat dictation bar

## Sub-features

- Ctrl+D replaces the message box with a stop square, elapsed m:ss and microphone-level dots, and a send arrow.
- Enter, Ctrl+D and the square finish into the draft; the arrow finishes and sends; Escape discards the recording without changing the draft.
- Ordinary message sender headers, timestamps and the working strip are absent; message corners are rounded.

## How to get to it (user POV)

Open Chat View with Alt+C, then press Ctrl+D. Speak and click the square to keep a draft, or the arrow to send. Press Escape to cancel.

## Driving it with control.ps1

Run the existing `chat-dictation` feature on the owner's Windows branch build (no release tag). Status: **not yet run**.

The journey retains the isolated profile, executable hash/version and process/window ownership gates. It uses real keyboard/mouse input and the existing checksum-pinned IGSH-812 audio/provider boundary, not a generated transcript injected into UI state. The microphone and provider are replayed; this is not live hardware/Deepgram proof.

At 1000x650 and 1400x900, it photographs the cleaned console-backed conversation, then verifies all five methods: `dictation-enter`, `dictation-ctrl-d`, `dictation-mic-click` (now the stop square), `dictation-arrow`, `dictation-escape`. It requires the native Edit to be hidden during capture, a 1:2:1 row with gaps, owned dark stop/meter pixels, a white square, a light send pill and a dark arrow. Within **1000 ms** of stopping, the native Edit must return with the exact expected draft. Only the arrow may add the exact dictated text to the durable outbox. Escape must reach the eventual transcript-discard audit.

Inspect `clean-chat-*.png`, `dictation-bar-*.png`, `*-bar.png`, `*.text.json`, actions, result, doctor and dictation-audit artifacts. The bar crop comes from screen pixels, not an offscreen rendering. No screenshot or runtime pass is claimed from this edit-only session.

## Gotchas

The IGSH-812 replay remains guarded by GITHUB_ACTIONS, RUNNER_OS=Windows and MULTIPROMPT_NO_LOGIN. Its actual recorded PCM chunks now feed the same RMS publisher as the microphone. Source contracts in `tools/grok-chat.test.js` require that data path, timer reset, controls, cancellation and reclaimed layout. They also mutate each contract in memory to ensure it rejects a missing path; these checks do not replace Windows runtime proof.

Archive, Remind me and Wait controls were already absent from this checkout's Chat View; their absence checks are regression guards, not claimed baseline failures. Cross-session sender attribution, read receipts, pending-message actions, permissions, keyboard archive/reminder commands and other views are retained.
