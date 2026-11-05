# Desktop room reply grouping

## Scope

IGSH-1732 reuses the shared reply protocol from IGSH-1334. Desktop replay retains each question ID and groups authorized answers immediately beneath that question, keeping answer arrival order within each question.

## Hosted checks

Dispatch `test.yml` against the task revision. `tools/room-reply-grouping.test.js` compiles production `acceptEvents`, its JSON helpers, message types and UUID validator with the fixture in `tools/fixtures/igsh-1732/room-replay.zig`. It runs in Windows group 3 and the portable suite. Admission runs the identical fixture against merge-base source and requires an assertion failure before the fix.

The regression calls production `acceptEvents` with two human questions, reverse-order answers and a second answer to the first question. It checks text order, speaker identity, pagination boundaries, independent full/paged replay and rejection of replaying an already consumed page without duplicate messages. The fixture starts after the room-created event with an existing member snapshot. Member hydration is unavailable in this isolated compiler harness; it does not exercise account discovery, room creation, transport or actual disk reopening.

Shared private isolation, offline retention and old-client capability contracts remain in `tools/room-agent-replies.test.js` and the Python room suites. This change does not alter those protocols.

## Accepted-send refresh

Both normal command completion and durable evidence recovery must schedule a selected-room snapshot for accepted posts, not only member edits. The bridge collects canonical replies during event reads; refreshing the catalog alone never invokes that collection. If event collection advances beyond the snapshot's sequence, publish only that bounded snapshot and immediately schedule a fresh one; never extend its member-revision boundary to absorb newer replies. The replay fixture includes this bounded-page race. The compiled recovery-path fixture exercises accepted posts and edits, room-creation exclusion, another selected room and rejected sends. Its persistence and transport functions are explicit recording boundaries, not real journal or network proof. The existing `rooms` preview journey exercises normal keyboard send with synthetic providers.

## Remaining user proof

This is a model regression, not a desktop walkthrough. Production Rooms remain disabled: `rooms-preview` defaults off and release builds reject it. IGSH-1313 owns desktop Rooms delivery. Once that prerequisite lands, drive two questions through real room input, receive answers in reverse order, switch away and reopen, then restart in the same isolated profile. Inspect native screenshots and independently read persisted events; each answer must occur once beneath its own question. Check private conversation isolation, offline pending delivery and paired Android IGSH-1694 before marking parity complete.
