# Room admission store

Rooms keep one authoritative home on a configured account host. Released desktop builds include the room screen. MUBO-533 makes Claude rooms reliable; MUBO-536 tracks the paired Android changes. Codex and Pi admission are separate work.

Each recipient keeps its stable delivery UUID as its canonical message ID. A room delivery freezes the store UUID, room, human parent event and member. Canonical admission persists this scope beside the message. The host serializes a room turn against every other turn in that agent session, including private messages, rather than mixing their replies. Private messages still use their existing behavior outside a room turn. Room delivery never falls back to terminal typing.

Only top-level text from the exact scoped message and session becomes an agent reply. Thinking, tools, unscoped private turns and other rooms are not copied. The bridge persists its cursor, ordered final text parts and completion in the room store. Reply admission and cursor completion commit together. Reopening cannot publish a second copy. A failed admission, failed turn or completed turn with no text publishes a visible “No answer” reply. Send the question again to retry with a new delivery identity. The unavailable Restart button is hidden.

Message protocol 1 and room protocol 1 stay compatible. Room scope is immutable on a message ID. A client opts into scoped replies with `room_messages: 1` and requires `room_reply_protocol: 1`. The bridge also advertises `room_features: [1]` to opted-in clients. New desktop sends require that capability and include `room_features: 1`. Running hosts must also advertise `room_features: [1]` in their ping; that proves the host holds the sweep helpers and can advance room work on its own. A host started without those helpers loads them from the runtime the app published on that host, so a publish does not need a chat restart. A host that still reports no features is running an older helper and needs a restart. It enables displayed-name mentions and shared conversation context. The choice is stored beside the human event, not as a new event field, so legacy readers keep the same event shape. Enhanced delivery intents use a private `pending_features_1` state that old collectors cannot claim. Current protocol responses still expose `pending`, and membership removal cancels both kinds of intent. Older helpers can read the shared history and post legacy messages without admitting enhanced work with the wrong context. Requests without it retain alias-only routing and legacy context rules. Older Android helpers do not claim this capability; their alignment belongs to MUBO-536. An unavailable selected runtime or an old running host produces a recovery reason. Accepted command receipts can still be recovered when the runtime is unavailable. Command IDs are durable on desktop: a saved post whose outcome is unknown is resent with its own command ID and body, so the store answers with the original receipt or admits it once. Only a post that never left the app, proven by its `prepared` state, is replaced, and a definite refusal keeps its error code.

Every room request sweeps pending work across the account store. A successful post also starts admission without a history reader. Bundled Claude hosts run a per-session sweep from their existing host-loop schedule, on a background worker so socket handling stays responsive. No new host timer is added. Returning offline agents admit and collect durable work once even with no desktop reader. Each member waits for its earlier room turn to finish before a later turn is admitted. Membership is checked again before admission. Desktop refresh uses stored human events and member replies for every unanswered question in the open room. Reopening, switching back and restarting resume refresh without a recent-send marker or a thirty-minute cutoff.

An accepted send is drawn from its own receipt event before the room is read again, so the message appears as soon as the store accepts it. A send made while a room is still opening is held and sent once that same room's first model is presented, rather than refused; the hold belongs to the room that was opening and is dropped when you open another one. Only an action already in flight is reported as busy. A room that has not finished its first read carries no load failure and no empty-state text until the read finishes; the failure appears only after a read fails.

Membership is rechecked under the room write transaction before canonical admission. Removing a recipient first prevents its admission. Already-admitted canonical work may finish; a later removal suppresses publication into the room.

The bridge still refuses client-supplied `agent_reply` and `delivery_work` operations. Its collector alone derives reply provenance from canonical host events. The lower-level store interface below remains a trusted home-side admission interface, not a client authentication boundary.

## Storage and interface

The store requires a private POSIX directory. Its owner must have exclusive access. The database must also be owner-only. Protect parent directories and local access separately. This interface does not authenticate callers. Treat callers as trusted home-side components. The persisted host UUID identifies this store. Members must use this store's host UUID. Other hosts return `different_host`. Bindings include provider, SID, and session identity. Provider must be `claude` or `codex`. Native SID identifies the provider conversation. Session identity is supplied binding metadata. Its source requires future adapter verification. No canonical session-identity API is assumed. This store validates shape, not authority. That adapter must capability-gate actual store fields. Process restarts must not replace member identity. A resumed SID remains the same conversation. Never substitute array positions or pane names. This draft has no tmux locator field.

Run `python3 src/room_service.py --serve --state-dir PATH`. Send one JSON object per line. Each line receives one JSON response. Lines permit 131072 bytes, including newline. Oversized lines are drained before continuing. Success uses `{"ok":true,"result":...}`. Failure uses `{"ok":false,"error":"..."}`. Storage failures terminate the process. Use `RoomStore(path).execute(request)` for embedding. Import calls return results or raise `RoomError`. Invalid Unicode produces `invalid_json`. Close each store after use. Each concurrent thread needs its own store.

Requests require exactly the documented fields. Unknown fields are rejected. IDs are lowercase canonical UUID strings. Generate fresh command and response UUIDs. The server generates other IDs. Text must be nonempty and contain no NUL. Names and display names permit 256 UTF-8 bytes. Session binding strings permit 512 bytes. Message text permits 65536 bytes. Requests permit 131072 encoded bytes. Member lists permit 64 entries. Aliases match `[a-z][a-z0-9_-]{0,31}`. Legacy aliases are case-sensitive and unique per room. Conversations must also be unique per room. Uniqueness uses host, provider, and native SID. Session identity never creates another conversation.

## Requests

Capability discovery and room listing:

```json
{"op":"capabilities"}
{"op":"list","after":0,"through":null,"limit":100}
```

Capabilities return `room_protocol`, `host_uuid`, and `store_only`. Lists return `rooms` with room metadata. Metadata includes `creation_seq`, `id`, `name`, `revision`, `seq`. Creation sequence orders rooms across this store. The first page captures `through`. Reuse that watermark for subsequent pages. Pass `next_after` as the next `after`. Newer rooms stay outside that listing. Room metadata reflects each page's current state.

Create a room with complete member bindings:

```json
{"op":"create","command_id":"10000000-0000-4000-8000-000000000001","name":"Planning","members":[{"alias":"alpha","display_name":"Alpha","host_uuid":"20000000-0000-4000-8000-000000000001","provider":"claude","provider_sid":"session-alpha","session_identity":"session-alpha-incarnation-1"}]}
```

Creation starts membership revision one. The receipt contains `event` and `deliveries`. Creation produces no delivery intents. Each event includes `id`, `room_id`, `seq`, `type`. The creation event includes name and membership. Members receive server-generated stable IDs.

Inspect current membership and delivery intents:

```json
{"op":"snapshot","room_id":"30000000-0000-4000-8000-000000000001"}
{"op":"events","room_id":"30000000-0000-4000-8000-000000000001","after":0,"limit":100}
{"op":"deliveries","room_id":"30000000-0000-4000-8000-000000000001","after":0,"through":null,"limit":100}
```

Snapshots return room metadata and active members. Snapshot `seq` captures the room watermark. Events return `events` and `next_after`. Event sequences start at one per room. Pass `next_after` for the next page. Limits range from one through 200. Event responses also cap at 262144 bytes. That cap includes the JSON success envelope. Pages may contain fewer events than requested. A skipped event starts the next page. An empty page preserves the cursor. An oversized single event returns `event_too_large`.

Deliveries use a separate store-wide monotonic `delivery_seq`. Each delivery records its room `event_seq`. The first page captures room sequence `through`. Alternatively, supply snapshot `seq` as `through`. Later pages must reuse that watermark. Pass `next_after` as the next `after`. Newer admissions never enter those pages. Pending and cancelled intents both appear. Status reflects each page's current database state. Cancellation after capture can change later pages. Earlier page results do not update automatically. Request a fresh page to observe cancellation. Watermarks and cursors survive store restart. Start new pages with `after` zero. A null watermark requires `after` zero. Future watermarks are rejected.

Replace the complete active membership:

```json
{"op":"edit_members","command_id":"10000000-0000-4000-8000-000000000002","room_id":"30000000-0000-4000-8000-000000000001","expected_revision":1,"members":[{"alias":"alpha","display_name":"Alpha renamed","host_uuid":"20000000-0000-4000-8000-000000000001","provider":"claude","provider_sid":"session-alpha","session_identity":"session-alpha-incarnation-1"}]}
```

Each successful edit increments the revision. Display names can change without changing aliases. Active bindings cannot change under an alias. This includes provider changes. Different providers distinguish otherwise identical conversations. Changed session metadata cannot duplicate a conversation. Active binding metadata remains immutable. Explicit removal and readdition creates new IDs. Do not readd merely for process restarts. Removing members cancels their pending intents. Existing intents never gain new recipients.

Admit a human message:

```json
{"op":"post_human","command_id":"10000000-0000-4000-8000-000000000003","room_id":"30000000-0000-4000-8000-000000000001","expected_revision":2,"text":"Hello @alpha","recipients":["alpha"]}
```

Without `room_features`, the recipients array contains explicit mentioned aliases. It must exactly match detected unique mentions. No mentions require an empty recipients array. No mentions target every active member. Explicit mentions target only matching members. Unknown aliases and mismatches are errors. Ambiguous aliases cannot enter active membership. No invalid mention silently fans out.

With `room_features: 1`, mentions match shown names or stable aliases case-insensitively, including names with spaces. The longest complete name wins; duplicate shown names return `ambiguous_mentions`. An empty `recipients` array lets the host resolve names; a nonempty array must agree with its resolved aliases. Events always freeze stable member IDs.

A mention begins with an unescaped `@`. Its preceding character cannot be alphanumeric, underscore, `@`, `.`, `+`, `-`, or backslash. Its alias consumes ASCII letters, digits, underscores, and hyphens. Legacy mention aliases must match exactly. Email addresses therefore are not mentions. A backslash directly before `@` suppresses detection. Escape literal standalone addresses with a backslash. Text remains unchanged in stored events.

Receipts include the human event and intents. Events freeze recipient member IDs. Each intent includes `id`, `room_id`, `event_id`, `event_seq`, `delivery_seq`, `member_id`, `status`. Initial intent status is `pending`. Removed members' pending intents become `cancelled`. Intents describe admission, not actual delivery.

Inspect one pending intent's frozen work:

```json
{"op":"delivery_work","room_id":"30000000-0000-4000-8000-000000000001","delivery_id":"70000000-0000-4000-8000-000000000001"}
```

The result text ends with the original message. With `room_features: 1`, prior human questions addressed to other members and peer replies since this member’s previous delivery appear first, in room event order. `@name` chooses who answers; it does not make that exchange private. The next answering turn sees the shared conversation, including questions it was not asked to answer. Context uses the existing 24000-byte budget, 4000 characters per prior entry and 60000-byte delivery budget. Oldest entries are dropped first. Without the capability, legacy posts retain their earlier context selection. Context never creates new delivery intents or automatic reply loops.

Admit an explicitly scoped agent response:

```json
{"op":"agent_reply","command_id":"10000000-0000-4000-8000-000000000004","room_id":"30000000-0000-4000-8000-000000000001","parent_event_id":"40000000-0000-4000-8000-000000000001","member_id":"50000000-0000-4000-8000-000000000001","response_id":"60000000-0000-4000-8000-000000000001","text":"Here is my answer."}
```

The parent must target that active member. Its matching intent must remain pending. Replies contain no new delivery intents. They never trigger agent delivery loops. Response IDs deduplicate per room and member. Identical response retries return the original receipt. Changed response bodies cause `response_conflict`.

## Concurrency and errors

Commands use atomic SQLite write transactions. Events and intents commit together. Revision checks reject stale membership changes. Command IDs are globally unique per store. Identical command retries return their original receipts. Changed bodies cause `command_conflict`. Failed commands leave no receipt or event. Retry an uncertain command using identical JSON values. Object key order does not matter.

Expected errors include `invalid_fields`, `invalid_id`, `invalid_text`, `invalid_number`, `invalid_json`, `request_too_large`, `unknown_op`, `room_not_found`, `invalid_members`, `invalid_alias`, `invalid_provider`, `invalid_cursor`, `duplicate_member`, `binding_immutable`, `revision_conflict`, `invalid_recipients`, `invalid_mentions`, `invalid_scope`, `response_conflict`, and `command_conflict`. Unexpected storage errors are not delivery evidence. There is no native history merging. No inference or provider calls occur here.

## Room safety checks

Run these checks on GitHub-hosted runners through the Room safety workflow, never on the shared server:

```sh
gh workflow run room-checks.yml --ref mubo-533-rooms-reliable -f baseline=true
```

These checks cover store and bridge behavior, the installed runtime, fixture-agent host processes and extracted desktop logic. They do not prove native UI interactions or real Claude replies. The baseline option runs the same regression tests against the pre-fix source and records the expected failures.

The [Room safety workflow](https://github.com/valentinyeo/multiprompt/actions/workflows/room-checks.yml) runs daily and manually. These runs are report-only, not a required release gate. Each run links its logs and revision in the job summary and the `room-safety-results` artifact.
