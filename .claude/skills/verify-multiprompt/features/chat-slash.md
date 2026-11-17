# Live chat commands

Covers: palette:SEARCH_CHAT_MODE_PLAN_OFFSET, palette:SEARCH_CHAT_MODE_MANUAL_OFFSET, palette:SEARCH_CHAT_MODE_EDITS_OFFSET, palette:SEARCH_CHAT_MODE_BYPASS_OFFSET, palette:SEARCH_CHAT_PLUS_MENU_OFFSET
Covers: shortcut:palette-actions/ctrl-k-chat-view-plus-menu, shortcut:palette-actions/plan-or-permissions-in-live-chat-or-ctrl-k-chat-view-plus-menu

## Sub-features

- `/plan` and `/permissions` open the permission picker. Plan, Ask, Accept edits and Bypass apply to the originating live chat.
- The same four modes work through their global Ctrl+K entries and the permission section of Plus Menu.
- Palette and Plus selections preserve an existing draft. Acknowledged slash choices clear the slash draft. Escape cancels Plus without another request.
- In non-Pi chats, `/model`, `/resume` and `/rewind` keep the draft editable and explain their limits without entering the outbox. Pi `/model` opens its provider model picker.

## How to get to it (user POV)

Type `/plan` or `/permissions` in live chat. Press Enter, then choose a mode. Alternatively, open Ctrl+K and select **Chat permission mode: Plan**, **Ask**, **Accept edits**, or **Bypass**. Ctrl+K, **Chat View: Plus Menu**, opens the same permission choices alongside model and effort choices.

Pi `/login` opens provider authentication. This journey does not cover every Pi/provider path.

## Driving it with control.ps1

Use the automatic PR verifier's `chat-slash` Windows journey. It invokes `control.ps1 -Feature chat-slash` against the PR head. Do not dispatch a second run while that verifier is active.

1. Select the isolated live chat. Type all five slash commands through the owned composer. Require visible pickers and notices.
2. Choose Plan and Ask, then Accept edits and Bypass through `/permissions`. Require one successful acknowledgement per choice and an empty composer after each acknowledgement.
3. Type `Keep this mode draft`. Select each of the four global palette mode entries through Ctrl+K, search, arrows and Enter. Require that exact draft after every acknowledgement.
4. Open **Chat View: Plus Menu** through Ctrl+K for each mode. From its initial unselected state, press Up twice for Plan, four times for Ask, three times for Accept edits and once for Bypass. Press Enter. Require the same draft and one acknowledgement per choice.
5. Open Plus again and press Escape. Require the unchanged draft and no thirteenth control.
6. Require exactly twelve receiving controls and twelve successful acknowledgements for the saved originating SID. The ordered modes are `plan,manual,acceptEdits,bypassPermissions`, repeated for slash, palette and Plus. No slash command may enter the ordinary outbox.

The driver runs `chat-control-coverage.test.cjs --mode-evidence <evidence>` against the retained raw controls, replies, resulting mode and `mode-inputs.json`. Inspect each `mode-<route>-<mode>-received.png`, picker screenshots, notices, `doctor.json`, actions and zero-process cleanup. Receipt checks establish native routing, not visual polish or real provider execution.

## Gotchas

Two saved remote tabs and one transcript round are seeded once before launch. The app-supplied reader runs the production host mode handler. SSH, host ownership and agent control transport are stand-ins. No shared session, credentials or paid agent is used. This journey does not claim direct model or effort palette coverage. Real SSH and provider work belongs to the separate server-chat journey.
