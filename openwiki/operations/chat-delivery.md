# Chat View delivery (ISSUE-349, v0.28.716)

VPS tmux tabs use the existing persistent SSH reader with a JSON `send` request.
`ISSUE_349_TMUX_SEND` in `src/chat_send.zig` controls this path. Sending runs on a
worker, sharing the reader's 15-second request budget. Hidden consoles, tab locks
and background activity do not gate it. Local and plain SSH tabs retain console
input. A request that was not written falls back to console input once; a written
request never falls back, even if its acknowledgement is lost.

The reader validates session names, targets the exact session, sends literal text
or a named bracketed-paste buffer, waits 150 ms, then sends Enter separately.
Arguments never pass through a shell. If bracketed paste is unsupported, the
multiline text is sent literally in one operation.

Positive outbox confirmation follows transcript evidence, not console visibility
or activity alone. Outstanding matching enqueue facts show `Queued, session is
busy` without a timeout. Matching user blocks (including normalized queued-command
attachments) retire the echo through the existing one-to-one assignment logic.
Without evidence, the app waits while the session is busy, then allows twenty
seconds of idle grace and requires a fresh transcript before showing
`Delivery unconfirmed`. It never automatically retransmits the text. Queue removal
uses the strict partial-history rules; an unrelated dequeue cannot clear a known
pending message. Background pending sends request transcript updates even while
Chat View is hidden. Late transcript evidence can still settle an unconfirmed echo.

`zig build test-vps` includes reader validation, executable routing checks, pure
status tests and a detached real-tmux delivery test. The latter uses an isolated
server, never attaches, checks exact received text and cleans up its session.

## Old pending entries (ISSUE-349, v0.28.722)

`ISSUE_349_FULL_SETTLE` enables a full-transcript check for remote tmux entries
that have waited at least one minute: delivered entries without queue evidence,
or unconfirmed entries whose write already started. Local shells, never-written
messages, queued/sending entries and younger entries retain their existing paths.

A background worker uses the same persistent reader channel and identity lookup
as history. Only one full-settlement request runs at once, with a thirty-second
cooldown per outbox shell key. Each batch contains at most sixteen texts and
rotates through larger outboxes so unmatched entries cannot starve later ones.
The reader streams the entire JSONL file without changing the history tail
window. It matches normalized user turns and queued-command attachment prompts,
including slash-command markup and pasted-content wrappers, with five seconds
of timestamp tolerance. Queue operations alone are not delivery evidence.

Confirmed entries are removed from the outbox and saved; their user turns remain
at their actual transcript position when older history is loaded. Failed lookups
and absent matches leave entries untouched. Completion checks entry identity,
shell key and send timestamp to avoid applying an old result to a later retry.
`tools/chat-settle-test.py` covers the wire protocol and a timed 30 MB scan;
`tools/chat-full-settle.test.js` executes the production worker and completion
with a real background thread and a stubbed reader channel.

## Missing conversation note (IGSH-973)

A keyed session (tmux or remote) never shows terminal rows as chat. When its
conversation is missing or cannot be read and no messages are loaded, Chat View
paints the plain note `Chat not available for this session, use the shell view`
below the working dots and retries once a minute. The reader's reason goes to the
debug log as `[chat] transcript not reachable: <reason>`. Keyless tabs retain the
agent-screen capture path. The launch snapshot no longer restores chat blocks for tmux
tabs, so an older terminal block cannot return after an update. This replaces the
terminal-block fallback of ISSUE-301 (v0.28.734).

## Model, context and todo header

History replies may include one JSON row with `role: "status"`, `model`, optional `percent_left` and optional `todos` (`text`, `status`).
The reader searches newest-first in bounded chunks, reusing question look-back reads and sharing the existing 8 MiB scan cap.
Claude uses the latest assistant model and input/cache token usage, with a 200k window or explicit 1m context; Codex uses turn context, token-count events and update-plan calls.
At most 50 todo texts of 200 characters cross the wire. JSON escapes tabs and newlines.
Old history renderers skip the unknown role without changing conversation blocks; the legacy `transcript` protocol is unchanged.
The strip omits unknown fields and stays hidden if nothing is known. The todo toggle and list scroll position belong to the tab, not the shared remote-history cache.
The separate list viewport is capped at half the available conversation height, leaving message scrolling, selection and links in the transcript's own coordinates.

## Local tab identity

Local and plain SSH Chat View queues and drafts use a random nonzero `chat_id`
persisted with the tab, rather than its name or runtime shell counter. Tmux keys
are unchanged. Old name-based queues and drafts migrate only when exactly one
restored tab matches; ambiguous old keys never select the first same-named tab.

## Desktop tables and nested lists

Pipe Markdown and complete terminal box grids share a source-fragment table model
in `src/chat_markdown.zig`. Box separators group wrapped cell lines; without body
separators each body line is a row. Malformed grids stay ordinary text. Capture
must preserve grid borders through tool filtering, reflow and composer trimming.

`src/chat_render.zig` paints rich cells in the normal chat font with bold headers,
content-sized columns and clipped horizontal scrolling. Shift+wheel and horizontal
wheel input scroll only the table under the pointer, including while the composer
has focus. Selection, links and find retain original transcript offsets.

Table geometry is cached by block offset, text hash, viewport width, font size and
UI scale. Repeated paints and hit tests reuse column widths and row heights.
List depth follows the parent indentation stack rather than a fixed spaces count.
With debug logging enabled, layout builds emit
`CHAT_TABLE rows=<body rows> columns=<n> header_bold=1 content_w=<px> view_w=<px> source=<pipe|box>`
and first nested-list layouts emit `CHAT_LIST depth=<n>`.

The shared fixtures live only in `src/testdata/chat-table-fixture.md` and
`src/testdata/chat-table-fixture.terminal.txt`. Native parser/cache tests and
`tools/chat-tables.test.js` / `tools/igsh421-tables.test.js` cover parsing, capture,
rich painting, source-aware scrolled hit testing, input routing and trace reuse.

## Unconfirmed message actions (IGSH-442)

Every not-sent message, including a send whose text write already started, has
Send again and Remove buttons and matching right-click items. Send again first
checks anchored transcript matches and queued delivery evidence. A confirmed
message is retired; a queued message resumes waiting without another write.
Text still in the terminal input box receives only Enter. Otherwise the entry
returns to the normal outbox queue with its write reservation and delivery watch
reset. Remove saves the outbox immediately and rolls back if saving fails.

When console verification runs out while the session is busy and input is absent
or unknown, it hands the message to the delivery watch rather than declaring it
not sent. Transcript evidence and the existing fresh-history idle grace decide
settlement. A visibly held prompt retains the bounded Enter retry behavior.

## Shared queue and draft (IGSH-682)

Claude Code is the single source of truth for a tmux Claude tab. The history reader replays the transcript's `queue-operation` events in order (enqueue adds, dequeue takes the front, remove takes the named message, popAll clears) and returns the shell queue plus the messages Claude just took as `queue` and `sent` on the status row, only when the app asks with `live`. It also reads the prompt box with `tmux capture-pane -p -e -J` and drops dim or grey runs so Claude's suggestion is never treated as a draft.

Chat View lists the shell queue in order after the transcript and merges its own outbox entries into it: an outbox message whose text matches a shell queue item is that item, never a second row. Every change of that list writes one `CHAT_QUEUE items=[{"text":...,"state":"queued"|"sent"}]` line to the debug log.

The draft follows the focused side. Edits in the Chat View box are pushed 500 ms after the last keystroke with the reader's `draft` op (clear the box, type the text, no Enter), never while a send is in flight. The shell box text fills the Chat View box only for ten seconds after Ctrl+K "Chat View: Edit Queued Messages" (IGSH-930); text another agent types or pastes into the shell box never shows in the Chat View box, so the box holds only what the human typed. Unsent text is not erased by a shell clear. Ctrl+K "Chat View: Edit Queued Messages" sends Claude's Up key through the `edit_queued` op so Claude moves its queue into the box, and the draft sync shows it. The chat-delivery verify journey case `queue-draft-sync` proves all of this. The case `send-stays-gone` (IGSH-960) proves that after each of 20 sends, including long wrapped ones, the sent text never returns to the Chat View box and no draft file holds text for 10 seconds.

Unconfirmed written messages remain outbox-owned until settled or removed; shell draft sync cannot restore them into the composer.
Draft updates verify the shell prompt box is empty before typing; a failed clear leaves the new draft untyped.
Scrolling up cancels pending bottom jumps; new messages and layout changes preserve the reader’s position. Sending again or forcing a transcript refresh still shows the bottom.

## First unread message (IGSH-814)

Chat View saves `last_read_message_id` per tab in the existing session JSON and launch snapshot. It is a stable fingerprint of the conversation ID and source message ID; timestamped source records without IDs (including Codex records) use a canonical-record fingerprint. History re-syncs and source-offset changes do not move it. Existing cache files refresh from the source once to acquire read identities before a marker can be saved. Leaving a chat advances it only past fully visible messages without moving it backwards. Reopening waits for the existing history request to complete before choosing a boundary, so an old disk cache cannot silently consume offline arrivals. One NEW line is laid out above the first newer message, without counting Markdown blocks or tool activity. A missing anchor shows only “Earlier read position is unknown”. Bottom and sending save the loaded tail and remove the line. The below-fold message pill keeps its separate count, dismiss and jump behavior. Screen-copy fallback has no stable source message identity and does not invent read anchors.
