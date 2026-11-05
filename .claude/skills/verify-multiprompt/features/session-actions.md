# Quit, hide and delete chats

## Sub-features

Ctrl+W quits without stopping agents. Ctrl+Shift+W deletes the selected chat once. Deletion saves its history identity before stopping it. Alt+X has no action. Right-click opens seven shared palette actions, with Delete last and red.

## How to get to it (user POV)

Press Ctrl+W, reopen, then right-click a chat. Search Ctrl+K for Copy chat ID or Hide from sidebar. Press Ctrl+Shift+W to delete the active chat.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=session-actions` on the verification branch. The dedicated hosted Windows driver launches the real app with an isolated offline profile. It seeds two saved remote tabs and distinct synthetic provider transcripts once. An explicit SSH boundary dispatches production session-end commands to two independently owned synthetic agent processes.

Require quit/reopen to keep both processes and chats. Require right-click to expose exactly the seven ordered IDs. Delete the background chat through that menu, then delete the active chat with one shortcut. Require exactly one stop request per identity, both archive identities, unchanged original transcript bytes, and zero remaining owned processes. Retain screenshots, launch identity, actions, saved files and boundary logs in `verify-session-actions`.

The sessions journey separately uses the real Hide from sidebar palette action when removing its temporary tabs.

## Gotchas

This boundary proves native routing and lifecycle requests, not real SSH, paid agents, account sync or Android. Transcript retention is not proof of readable history in the native UI. That acceptance gate remains open until the deleted transcript is opened and read through the app. Pixel counts are supporting evidence only; independently review screenshots for the seven labels and red Delete. Theme comparisons and independent design QA remain separate gates.
