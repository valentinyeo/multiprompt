---
name: verify-hosted-chat-reads
description: Exhaustive check that a live chat, hosted or running in a terminal tab, always returns its current bot replies to the desktop, for every query shape the desktop sends, for the reading user's own chats and for chats owned by another server user. Use before merging any change to how src/chat_history_reader.py picks a transcript (resolve_response_path, follow mode, owner delegation, host lookups, conversation_path) or to the desktop history query in src/chat_session.zig.
---

# Verify hosted chat reads

## The promise

For a Claude chat in a tab, run by the agent host or by Claude inside the tab's tmux pane, every history request the desktop can send for that tab returns `ok` with the tab's current chat replies, on open and after a new reply lands. It never shows an older chat that the tab ran before.

Harm when broken: the user sends a message, the bot answers on the server, and the reply never shows in the app. This happened on 6 Nov 2026 for chats owned by a second server user (IGSH-1822).

## Run it

```
python3 tools/verify-hosted-chat-reads.py
```

It prints `HOSTED_CHAT_READS PASS 72/72 cases` or one `COUNTEREXAMPLE` line per failing case, then exits 1. CI runs it in `test.yml` next to the reader suite. It takes about 15 seconds and needs only Python 3.

To check another version of the reader, for example the base of your branch:

```
git show origin/master:src/chat_history_reader.py > /tmp/reader-base.py
python3 tools/verify-hosted-chat-reads.py --reader /tmp/reader-base.py
```

## What it checks

It runs the real `response()` from `src/chat_history_reader.py` on every combination of:

| Dimension | Values | Where it comes from |
| --- | --- | --- |
| `tab` | `hosted`, `terminal` | `hosted`: an enabled agent-host config names the tab. `terminal`: Claude runs in the tab's tmux pane and `resolve_tmux_agent` finds it |
| `owner` | `same-user`, `other-user` | `conversation_owner(cwd)`: the chat folder belongs to the reading user or to another user whose `~/.claude` is closed (mode 0700) |
| `query_sid` | `sid`, `empty`, `stale` | `chatHistoryQuery` in `src/chat_session.zig` sends `key.sid`, which can be empty for a tab, or an older chat id after the pane restarted Claude (terminal tabs in follow mode only) |
| `follow` | `true`, `false` | the desktop always sends `follow: true`; older callers send none |
| `held` | `false`, `true` | the desktop adds `held` while it has outbox messages |
| `transcript` | `file`, `symlink` | disk cleanup can leave the transcript as a link to another volume (IGSH-1809) |

For each case it reads once from offset 0 and expects the first reply. Then it appends a new turn and reads the delta with the returned cache fields, and expects the new reply.

Only the operating system is replaced, and each replacement mirrors real behaviour:

- `conversation_path` raises `PermissionError` when the reading user is not the owner of that home, as a 0700 folder does.
- `owner_response` runs the same reader as the owner with `as_owner=True`, which is what the `sudo -u <owner>` subprocess does. The owner has no agent-host state, as in production.
- Hosted tabs: `resolve_tmux_agent` and `tmux_owner_process` return nothing, because a hosted chat's tab runs `sleep infinity`, not a Claude process.
- Terminal tabs: `resolve_tmux_agent` returns the pane's chat when the reading user owns it and raises `PermissionError` otherwise. `tmux_owner_process` names the other owner, and the owner's reader then finds the pane's chat.
- `start_message_worker` does nothing, so no process is started.

## Reading a result

A counterexample line reads like a story. For example:

`owner=other-user query_sid=sid follow=True ... :: open: status=['ok'] first_reply_shown=False`

This means that for a chat owned by another user, the desktop asked with the chat id in follow mode and got an `ok` answer with no replies. The app then shows an empty chat.

`status=['missing'] reason=['session transcript not found']` means the reader could not find the chat at all.

Real bug or modelling error? Open `resolve_response_path` and follow the case by hand. If a replaced function above no longer matches what the real one does (a new permission rule, or a new way to find the owner), fix the replacement in `tools/verify-hosted-chat-reads.py`. Never change the expected result to make a case pass.

## Coverage and sync

Covered code in `src/chat_history_reader.py`: `response`, `resolve_response_path`, `host_sid_for_tmux`, `host_dispatch_switch`, `host_config`, `conversation_path`, `owner_response` and `resolve_tmux_agent` and `tmux_owner_process` (as replaced above), `read_tail`, `read_window`.
Covered caller: `chatHistoryQuery` in `src/chat_session.zig` (the query fields).

Last confirmed against the code at commit `259fac8e`.

When a change touches any covered function or the query fields:

1. Run the check on your branch.
2. If you added a new query field or a new way to resolve a chat, add it as a dimension.
3. Move the commit above forward only after you have read the covered code at the new commit and confirmed the replacements still match it.

## Proof that it can fail

At commit `259fac8e` the check fails on each of these broken variants:

- `origin/master` before IGSH-1822: 52 of 72 pass. Every failure is a hosted tab. Other-user chats in follow mode show no replies, and every empty-id request is missing. All terminal cases pass there.
- Remove `follow = q["follow"] = False` for hosted chats: 64 of 72 pass.
- Remove the `host_sid_for_tmux` lookup: 56 of 72 pass.
- Replace `discovered = tmux_owner_process(...)` with `None`: 68 of 72 pass. Other-user terminal tabs say permission denied.
- Force `follow = False` everywhere: 64 of 72 pass. A terminal tab with a stale id shows the old chat.

## Not covered

- Codex, hax and pi chats. Codex has its own hosted branch in `resolve_response_path`.
- The desktop side: whether the app retries after a failed read, and how it draws rows.
- Message sending and delivery. This checks only reads.
- A live end-to-end run against a real server. Do that on a real host before you call a chat fix done.
