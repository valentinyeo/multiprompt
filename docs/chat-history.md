# Chat View history

## User-facing changes

- Conversations return immediately when switching tabs or restarting, even if
  the server is slow or unavailable.
- Refreshes add new messages without erasing the conversation. Failed reads
  retry automatically; an uncached conversation explains that it is retrying.
- Older messages are retained, and scrolling reaches the beginning of the chat.
  Loading an image no longer moves the message being read.
- Without a visible browser, Chat View fills the content area instead of sitting
  in a narrow centered card.

## Cache and source resolution

The app uses one cache
for parsed per-session remote history and local-console snapshots. Host,
provider and tmux identity survive runtime shell-id/cwd changes and sid adoption;
a changed known sid starts a different entry. Disk files live in
`%APPDATA%\ZigShell\chatcache\<host/provider/session hash>.jsonl`. A versioned
header validates host/provider/tmux/sid (even if hash paths collide), inode,
mtime, a 64-byte source-boundary digest and the consumed JSONL byte offset.
Subsequent lines contain only normalized user/assistant messages, timestamps
and message ids. Writes are atomic. These are personal conversation files, not
repository assets; never commit or publish them.

As of **0.28.707 (issue)**, each new durable snapshot is capped at 512 KiB.
Legacy files up to 16 MiB are accepted, but only their retained tail is parsed.
A partial/legacy header requests a bounded remote tail, never an automatic
full-source rebuild. Older history is fetched only on upward scrolling. Writes
are atomic and debounced to 30 seconds; an unchanged poll flushes a dirty final
delta after that deadline. Directory eviction above 64 MiB runs at most once a
minute. Only workers write/prune. Personal files and directories are not eviction
targets. Offline restarts can only show the retained snapshot; older pages need
the original source to be reachable again.

On opening/switching, parsed memory is restored before first paint. A cold disk
snapshot is read/decoded on a worker after that paint, published independently
of the remote transaction, then refreshed; it cannot block on SSH or hold the
browser-swap paint barrier. A separate background SSH process runs the
executable's embedded
`src/chat_history_reader.py` through stdin. It installs nothing and does not
need changes to the existing `mp_complete.py` deployment or its shared channel.
A saved sid selects exactly `~/.claude/projects/<encoded cwd>/<sid>.jsonl`
(with a root-confined sid lookup for alternate cwd encodings), or Codex's
`~/.codex/sessions/**/rollout-*-<sid>.jsonl`. Missing sids/files resolve the
named tmux pane's live agent descendant and Claude's
`~/.claude/sessions/<pid>.json` map; the existing cwd-based discovery fallback
remains for harnesses without that map. No unscoped active tmux session is used.

Cold loads seek to the last 512 KiB and align to complete JSONL records.
Subsequent reads seek to the cached offset and parse only the changed suffix,
including adjacent streamed fragments. Scroll-up fetches one older page and
preserves the reader's position, including when fragments join the first loaded
message. A record larger than the cold-load budget is fetched whole only on
explicit upward scrolling (the response safety limit is 64 MiB). A giant appended
tool record can reset to a recent bounded tail instead of pinning the cursor.
Sid/inode changes, truncation, rewrites and changed append boundaries also reset
to a tail. Invalid, timed-out, truncated or empty-reset responses preserve the
last good history. Retry delays are 1, 2, 4, 8, 16, then at most 30 seconds;
forward backlog pages wait at least one second rather than immediately rearming.
A named worker reservation serializes disk/fetch/parse work across all windows.
Only the selected tab of each visible Chat View is scheduled; foreground requests
reserve priority, and background windows may poll only after five seconds without
input. Late results cannot appear under another tab.
First-ever uncached loads still need a successful remote read; no cache can
recover history that has never been read. That case shows Loading or the retry
message rather than silently falling back to one cropped terminal message.

With debug logging enabled, starts include shell id/offset and every finished
remote transaction records:
`[chat] transcript load shell=X ok|fail bytes=N ms=M`.

## Mask timer: investigated, unchanged

At the original revision, `armBrowserEdgeMaskRaise` (`src/main.zig:30479–30499`)
coalesces an active raise and starts only ten 40 ms ticks. The timer body
(`src/main.zig:68346–68365`) decrements and kills it. Repeated owned-window
foreground callbacks (`src/main.zig:6225–6242`), WM_ACTIVATEAPP and WM_ACTIVATE
(`src/main.zig:67876–67917`) can start another burst; the timer does not rearm
itself. The supplied repeating log alone cannot identify which activation is
feeding that chain. Stopping it safely requires browser focus/z-order evidence,
not a speculative change to the mask countdown. The port preserves issue's
successful-paint barrier, coalesced deferred browser swap, nonactivating foreign
window workers and composer focus. Refresh/ready callbacks still stand down
until the final target paints; history workers start after the swap barrier.
Pending entries pin immutable worker inputs through the release/acquire result
handoff, including close/detach. No browser authorization or mask countdown
logic is changed.

## Verification

Native Zig tests cover the persistent codec, stable identities, deltas, empty
and malformed replies, uncapped history, backoff, visible overlap on negative
monitor coordinates and scroll anchors. Local Python fixtures execute the
embedded reader, including paged full reads, long messages, interrupted records,
exact process metadata and stdin delivery. A native Zig harness executes the
production switch/refresh/completion/capacity/scroll functions with only Win32
and remote IO substituted. Its acceptance assertions fail against the actual
v0.28.704 blanking defer and v0.28.702 thumbnail relayout, then pass for the fix.
The requested Windows cross-build and Node suites are the final gates.
No live Windows GUI acceptance is claimed.
