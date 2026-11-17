# Chat view and composer

Read conversations, compose replies, attach files, search, dictate, and switch supported terminal tabs between chat and shell.

Journeys: chat-focus, chat-view, chat-composer-text, chat-still

## Sub-features
- `read` displays history, Find matches, selection, copied text, and unread boundaries.
- `compose` retains drafts and sends replies, reactions, attachments, and dictated text.
- `view-focus` switches supported terminal views and restores typing focus.

## How to get to it (user POV)
- Select a chat; type in its message box; Enter sends and Shift+Enter adds a line; Ctrl+F finds; Ctrl+D dictates; plus/paste/drop attaches; right-click replies/reacts; Alt+C switches terminal views.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=chat-focus`. [Chat focus](chat-focus.md), [Chat View](chat-view.md), and [composer text](chat-composer-text.md) provide exact key sequences and native text reads.
- Require typed draft equality, visible transcript/composer screenshots, saved conversation state, and the named journey result. Only the selected journey is covered. Download `verify-chat-focus` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Live chats have no shell toggle. Sending, attachments, provider login, and real delivery need their own live prerequisites; focus proof does not cover them.
