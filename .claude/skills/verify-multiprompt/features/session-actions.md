# Quit, hide and delete chats

## Sub-features

Ctrl+W quits without stopping agents. Ctrl+Shift+W deletes the selected chat once. Deletion saves its history identity before stopping it. Alt+X has no action. Right-click opens seven shared palette actions, with Delete last and red.

## How to get to it (user POV)

Press Ctrl+W, reopen, then right-click a chat. Search Ctrl+K for Copy chat ID or Hide from sidebar. Press Ctrl+Shift+W to delete the active chat.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=session-actions` on the verification branch. The dedicated hosted Windows driver launches the real app with an isolated offline profile. It seeds two saved remote tabs and distinct synthetic provider transcripts once. An explicit SSH boundary dispatches production session-end commands to two independently owned synthetic agent processes.

Require quit/reopen to keep both processes and chats. Require right-click to expose exactly the seven ordered IDs. Capture paired closed/open menu screenshots after selecting each built-in Light, AMOLED and Mid theme through real input. Delete the background chat through that menu, then delete the active chat with one shortcut. Require exactly one stop request per identity and both archive identities.

Search each deleted chat's name through Ctrl+K and reopen its existing archived resume action. The SSH boundary accepts only a resume command whose saved identity matches an ended fixture, then supplies a new console transport without modifying either original transcript. Require an owned visible native transcript, nonempty native text layout and the correct original question and answer copied through the app's Select all command. Reject the other chat's text. Save `history-Alpha.txt`, `history-Beta.txt` and matching screenshots, and verify both original transcript hashes again. Require zero remaining owned processes. Retain launch identity, actions, saved files and boundary logs in `verify-session-actions`.

The sessions journey separately uses the real Hide from sidebar palette action when removing its temporary tabs.

## Gotchas

This boundary proves native routing, lifecycle requests and transcript access through archived resume, not real SSH, paid agents, account sync or Android. Archived resume is not a read-only history viewer; the production path normally resumes the provider. The original synthetic agent processes must remain stopped during the history checks. A run that verifies only retained bytes does not pass history readability.

Pixel counts are supporting evidence only; independently review screenshots for the seven labels and red Delete. The available built-in theme is named Mid, not Graphite 2. Do not silently equate them: comparison with the approved Figma themes and independent design QA remain separate gates.
