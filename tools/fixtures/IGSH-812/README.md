# IGSH-812 recorded dictation fixture

`goforward.pcm` is the unmodified CMUSphinx/PocketSphinx recorded utterance “go forward ten meters”, copied from `test/data/goforward.raw` at revision `f20ff1b7a5db64c5e892a798479e20df86e79a35`:

https://github.com/cmusphinx/pocketsphinx/blob/f20ff1b7a5db64c5e892a798479e20df86e79a35/test/data/goforward.raw

Format: 16000 Hz, mono, signed 16-bit little-endian raw PCM; 89160 bytes (2.78625 seconds). SHA-256: `f15c60ec54059d8b66e410d0064945a0b0a04ea56e1ddca1958e493c0cf70e71`. `source.json` records provenance; `LICENSE.pocketsphinx` preserves the upstream license. The workflow consumes checked-in bytes, never downloads audio or a recognizer.

`response.json` is a hand-authored provider-format response matching the recording, not a claimed live Deepgram recording or an acoustic recognizer. The real transcription worker passes PCM to the offline provider boundary, which checks those bytes against the recording before the production provider-response parser handles the response. CI replaces only microphone capture and provider I/O; it never writes composer text, transcript globals or saved app state. The three independent stop cases must deliver `Go forward ten meters.` through the production completion and draft-routing path while preserving user typing.

No new network dependency, API key or secret is needed. This fixture proves app response parsing and delivery, not speech recognition accuracy or microphone hardware.
