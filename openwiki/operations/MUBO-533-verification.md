# MUBO-533 verification record

Goal: released desktop Claude rooms create, discover members, route mentions and finish durable work reliably.

## Faults for the owner to file

The worker Hypertask wrapper denies both board access and `hypertask feedback`. No board write was possible. The owner must record these repository faults on the Multi Bot Features board and view.

- The room bridge rejected the symlink that the real runtime installer publishes as `reader.py`. The bridge now verifies and uses the immutable digest file from `active.json`.
- Hosted Zig setup restored an empty archive cache. Two official downloads timed out after receiving about 9 MB of a 55 MB archive. [Failed build](https://github.com/valentinyeo/multiprompt/actions/runs/45522511900). The five-minute room-check job also expired inside installation. Python checks now run first, and the job budget includes installation. The shared installer falls back to cached compiler and library archives from the registry, pinned to version 0.16.0 and separate SHA-512 integrity values. Both sources fail closed on an integrity mismatch.
- SSH push authentication stopped working during this run. The branch was pushed over HTTPS instead.

## Hosted evidence

- [Initial Python failures](https://github.com/valentinyeo/multiprompt/actions/runs/45520435553), head `87a4de155`.
- [Initial desktop refresh, mention, creation and Restart failures](https://github.com/valentinyeo/multiprompt/actions/runs/45521131553), head `b3245eb07`.
- [Before/after checks](https://github.com/valentinyeo/multiprompt/actions/runs/45524981987), head `06bd4bd2f`. Python baseline reproduction and current Python suites passed. Canonical process and desktop results are still being checked.

No build, test suite or app verification ran on the shared server. These checks do not prove the real Windows UI or paid Claude replies. The paired phone work remains MUBO-536; Codex/Pi remains PR B.

## Regression cases

| Break | Test |
| --- | --- |
| 1 | `tools/room-reliability.test.js`: unavailable creation reports a reason |
| 2 | `tools/room-reliability.test.js`: fresh-profile room discovery probes configured hosts |
| 3 | `tools/room_bridge_test.py`: `test_member_catalog_includes_unopened_claude_chats_with_shown_names`; desktop member-parser harness |
| 5 | `tools/room-routing.test.py`: `test_displayed_name_selects_stable_member_and_alias_still_works`; Unicode-name and picker harnesses |
| 6 | `tools/room_bridge_test.py`: real runtime symlink installation, retained stderr, old running host and lost-ack tests |
| 7 | `tools/room-routing.test.py`: `test_host_schedule_completes_offline_work_once_without_room_requests`; `tools/room-agent-replies.test.js`: real host processes, no room reader |
| 8 | `tools/room-reliability.test.js`: restart refreshes older unanswered questions after a newer answer |
| 9 | `tools/room-routing.test.py`: empty/failed turn and failed-admission resend tests; hidden Restart harness |
| 10 | `tools/room-routing.test.py`: `test_agents_see_the_same_ordered_conversation` |

`test_legacy_reader_cannot_claim_capability_gated_work` runs the original helper from the hosted baseline checkout against a new store. It checks old history reads and legacy posting without allowing the old collector to submit enhanced work. Protocol receipts and events retain their original shapes.

[Run at `ab4bcfa19`](https://github.com/valentinyeo/multiprompt/actions/runs/45528029107) passed Python baseline reproduction, all current Python suites, real fixture-host completion without a reader, desktop baseline reproduction, all new desktop regression cases, source limits and timer checks. The combined run failed on a controller method name shadowing existing parameters and an older queued-command fixture missing the new request enum value. Both are corrected in the following commit; a full rerun is still required before this branch is ready to ship.

The branch’s latest [Room safety run](https://github.com/valentinyeo/multiprompt/actions/workflows/room-checks.yml?query=branch%3Amubo-533-rooms-reliable) is the source of current results. Queued or incomplete checks are not a pass. No PR was opened.

## Decisions

Fix Root Causes moved admission off history reads and corrected installed-runtime selection. Test Behavior, Not Implementation uses real store events, a real installed runtime, host-loop functions and extracted desktop logic instead of relying on recent-send flags.

## Janitor note: the fixture premise, written down before the next patch

**The premise every earlier desktop room fix assumed:** the handwritten View fixture copies in
`tools/room-creation-focus.test.js` and `tools/room-reliability.test.js` exercise the same state
machine as production, so a green fixture means the shipped room view behaves.

**Observation that contradicts it:** each production change added a member the copy did not have and
the copy was patched afterwards, in this order: `start_failed`, then `loading` and `deferred_submit`,
then `openingRoom`. Three same-gate failures on one premise means the premise is the defect, not the
copies.

**What replaced it:** `tools/room-view-harness.cjs` reads `src/room_view.zig` and emits the harness
instead of a copy. Every View field is lifted verbatim, so a new field appears in every fixture with
no edit. Every View method whose body stays inside the struct is lifted verbatim. A method that calls
the window layer is stubbed by name, with its signature taken from production and a default return,
unless the test supplies its own body. The harness fails, naming the method, when production adds a
method that calls the window layer in a way it cannot default. Nothing in a fixture now restates a
production behaviour, so a fixture cannot go green against a state machine that no longer exists.

The accepted-post fixture is a frontend copy, not a View copy. Its state setup moved into `load()` so
a test no longer depends on another test's teardown to place the reader in the room.

## Room command release and receipt scope

**Mechanism 1, a finished room send never releasing the view's action.** `view.submit()` refuses while
`view.pending` is set. `finishCommand` only told the view when the command was "visible", and the
evidence-retry path (`retryCommandEvidence`) never told it at all. A post accepted while the user was
elsewhere, or whose journal write needed a retry, left `view.pending` set for the life of that view, so
every later send was refused locally with `post rejected reason=command_pending` and nothing reached
the room. Evidence: `debug.log` at a56ae6d7b has the accepted post response at 19:36:06.781 and then
`post rejected reason=command_pending` at 19:36:23.668 and 19:36:46.661, with no room request between
them.

`releaseCommandAction` is now the only path that tells the view a command finished, and every terminal
path calls it without asking where the user is looking. `View.completeAction` already ignores a token
it is not holding, so releasing an older command cannot clear a newer action or the draft.

**Mechanism 2, a receipt from another room being drawn into the open room.** `applyAcceptedPost` checked
the item's room against the view and the loaded model, but not against the event the receipt carried, so
any accepted human event with a higher seq was appended to whatever room was open. `AcceptedHuman` now
carries the event's `room_id` and the room must match before anything is appended.

Both are covered by `tools/room-reliability.test.js`: the harness compiles the production `View`, proves
a submitted send keeps its action and draft until the completion arrives, proves an older token cannot
release a newer action, and proves `finishCommand`, `launchQueuedCommand` and `retryCommandEvidence`
release without a visibility test. The accepted-post fixture's third case proves a same-room read, a
foreign-room receipt and a refusal leave the room untouched.

## Still open, with the evidence that carries it

- Step 4/7 at a56ae6d7b: Alpha's saved transcript holds `BROADCAST534` and `Alpha says BROADCAST534`,
  the room store holds Alpha's delivery `8ceb9885` as written and accepted, and the room event seq 4 is
  still `No answer. The agent did not complete a reply.` A private chat answering while the room records
  no answer points at turn correlation in `collect_reply`, not at the composer. That needs host event
  rows for the turn, which this branch does not have yet, so no code changed for it.
- Step 3 at a56ae6d7b reports "Saved room message is not visible in the room" while the owner reads
  `BROADCAST534` on the step 3 screenshot. That is a check boundary in the journey, not missing paint;
  it belongs to the Rooms journey owner on MUBO-534 and no UI code was changed for it.
