# Hidden agent steps

## Sub-features

- One grey line per consecutive group of tool calls, closed by default.
- A real mouse click opens commands with short output. Another click folds the same group.
- Other groups stay folded. Assistant messages remain separate and unchanged.
- The existing palette action opens or folds every group. Ctrl+Shift+J offers the same action.
- Composer text stays untouched. Source commands and outputs remain in the app-written cache.

## How to get to it (user POV)

Open a conversation in Chat View. Click the grey steps count between messages. Click again to fold it. Use Ctrl+K and search `tool steps`, or press Ctrl+Shift+J, to open or fold every group.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-hidden-steps`.

The journey uses the existing chat-delivery isolated remote-shell boundary. Its synthetic agent writes ordinary source transcript events containing two tool groups of two and one calls. The real embedded reader, cache, native layout and painter process them. The harness never writes the app transcript cache.

The owned app is resized for readable evidence. For Light, AMOLED and Mid, native keyboard input selects the theme. The driver captures closed, clicked-open and clicked-folded frames, then exercises the palette action both ways. Every state requires fresh geometry from actual painted disclosure headers. Input targets must belong to the owned transcript HWND.

Retain `steps-<theme>-closed.png`, `steps-<theme>-open.png`, `steps-<theme>-folded.png`, their BMP pixel sources, per-frame metadata, the independent source transcript, app-written cache, actions, Doctor, provenance and cleanup. The screenshot oracle rejects invisible headers, incorrect counts/states, fake expansion, changed composer text and a collapse that does not restore the closed pixels.

Inspect the screenshots against design A on https://www.figma.com/design/8Yzu3N21UlCL7lA3YXm45D?node-id=187-93 and https://screencast2.com/yUU4S.png. The builder supplies evidence; the lead independently owns design QA.

## Gotchas

- This replaces only the external agent/remote-shell boundary, not UI actions or rendering. It is not proof of a signed-in production provider.
- No local builds or desktop execution. All desktop screenshots come from GitHub Windows.
- The themes are existing app choices. Do not add a new theme or invent a token to match a mockup.
- Step groups are disclosure controls, not a third live-chat status. They must not reintroduce status ticks or badges.
