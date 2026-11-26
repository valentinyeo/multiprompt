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
| 9 | `tools/room-routing.test.py`: empty/failed turn and failed-admission resend tests; the failure sentence names the member and the `@name` retry, and the room view has no restart action |
| 10 | `tools/room-routing.test.py`: `test_agents_see_the_same_ordered_conversation` |

`test_legacy_reader_cannot_claim_capability_gated_work` runs the original helper from the hosted baseline checkout against a new store. It checks old history reads and legacy posting without allowing the old collector to submit enhanced work. Protocol receipts and events retain their original shapes.

[Run at `ab4bcfa19`](https://github.com/valentinyeo/multiprompt/actions/runs/45528029107) passed Python baseline reproduction, all current Python suites, real fixture-host completion without a reader, desktop baseline reproduction, all new desktop regression cases, source limits and timer checks. The combined run failed on a controller method name shadowing existing parameters and an older queued-command fixture missing the new request enum value. Both are corrected in the following commit; a full rerun is still required before this branch is ready to ship.

The branch’s latest [Room safety run](https://github.com/valentinyeo/multiprompt/actions/workflows/room-checks.yml?query=branch%3Amubo-533-rooms-reliable) is the source of current results. Queued or incomplete checks are not a pass. Pull request 1396 carries the branch.

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

## Earlier open findings, with the evidence that carried them

The interrupted-answer finding below was diagnosed at `418f5ce81` and corrected in the recovery section at the end of this document. Its final-head hosted proof remains pending.

- Step 4/7 at a56ae6d7b: Alpha's saved transcript holds `BROADCAST534` and `Alpha says BROADCAST534`,
  the room store holds Alpha's delivery `8ceb9885` as written and accepted, and the room event seq 4 is
  still `No answer. The agent did not complete a reply.` A private chat answering while the room records
  no answer points at turn correlation in `collect_reply`, not at the composer. That needs host event
  rows for the turn, which this branch does not have yet, so no code changed for it.
- Step 3 at a56ae6d7b reports "Saved room message is not visible in the room" while the owner reads
  `BROADCAST534` on the step 3 screenshot. That is a check boundary in the journey, not missing paint;
  it belongs to the Rooms journey owner on MUBO-534 and no UI code was changed for it.

## Step 6 roles and the closed-member race at dd6331199

The run at `dd6331199` (Verify desktop rooms 45722205958) passed cases 1, private, 2, 3, 4, 5, 7, 8, 12,
14, 11 and failed 6 and 2-closed. Evidence: `step-6-state.json`, `order-before-state.json`,
`Alpha-room-history.png`, `Bravo-room-history.png`, `Alpha-transcript`, `closed-bravo-add.png`,
`closed-removed-state.json`, `closed-added-state.json` and `debug.log` from artifact `verify-rooms`.

- Case 6 asserted that every saved room reply appears as an assistant message in each member's own
  provider transcript. A member's transcript only ever holds its own assistant replies; the other
  member's reply reaches it as the room context line inside a user message
  (`step-6-state.json`: Alpha seq 6 is the delivery text `agent_3314…: Bravo says BROADCAST534`).
  Requiring the peer reply in the assistant role could only pass by forging transcripts. The canonical
  room order for that snapshot is Alpha `BROADCAST534` (seq 4), Bravo `BROADCAST534` (seq 5), Alpha
  `TARGET534` (seq 7), and the room view held all three in that order.
- The member Chat View half was a real measurement taken too early. Alpha's tab was opened at
  `23:49:26.226`, its transcript request ran at `23:49:26.674` and returned in 15 ms, and the copy had
  already run before the request. The view is correct a moment later; the driver now waits for the saved
  room turns to appear before it copies.
- Case 6 now checks the roles instead: each member's own replies appear as assistant messages in room
  order; the peer replies inside that member's delivery windows appear only as user-role room context,
  in order, and never as assistant text; and each member's own Chat View shows its own replies plus the
  room context delivered to it in the saved room order. The room view keeps the full-order check.
- Case 2-closed: `closed-removed-state.json` and `closed-added-state.json` both hold Bravo inactive at
  room revision 3, and `debug.log` has the removal edit accepted at `23:51:11.164` but no second
  `[rooms] request sent kind=edit`. The driver reopened the member editor at `23:51:11.146`, 18 ms
  before the app finished the removal. That editor seeded Bravo from the old member list and kept the
  old revision, so its save was refused locally. `Save-RoomMembers` now waits for the app's own
  `[rooms] command finished kind=edit state=accepted` and the refreshed `[rooms] view presented`
  before the next editor opens. That does not prove the re-added closed chat answers yet.
- The saved failure sentence asked the user to resend the question to the room, which asks every member
  again. It now names the member and asks for `@<name>`, so the retry asks only that chat. The room view
  had no restart control and now has no restart plumbing either.

## Recovery review at 418f5ce81

The goal is to resolve genuine recovery findings before PR 1396 merges. This fix pass is OpenAI
`gpt-6.1-sol`, not an independent verifier. The earlier DeepSeek review also overlaps an author family.

At the reviewed head, [Room safety 45727235769](https://github.com/valentinyeo/multiprompt/actions/runs/45727235769)
and [Tests 45727236830](https://github.com/valentinyeo/multiprompt/actions/runs/45727236830) succeeded.
[Native Rooms 45727275008](https://github.com/valentinyeo/multiprompt/actions/runs/45727275008) failed cases
4, 6 and 12. [PR verifier 45727373482](https://github.com/valentinyeo/multiprompt/actions/runs/45727373482)
failed case 8. These results do not cover the new fix head.

Accepted findings and corrections:

- **Collected answers were discarded.** Native `step-6-state.json` contains Bravo's assistant text
  `Bravo says BROADCAST534`. `step-12-debug.log` records delivery `cdcab94f` with `parts=1 bytes=23
  status=interrupted answered=0`, while room event seq 5 in `failed-turn-saved-state.json` is a generated
  failure. The inspected `step-4.png` shows that failure even though Bravo's sidebar preview shows the
  answer. Collection now publishes nonempty final text regardless of terminal status. Scope checks,
  delivery-derived response UUID, transactional publication and the native status remain unchanged.
- **Reopening was read too early.** The verifier's `step-8.png` still shows Alpha's private chat.
  Its saved state already contains both restart answers, and `debug.log` later presents 11 room messages
  at `00:24:50.531`. Reopens now use `Open-Room`, which waits for the real room window. `Shot-Room`
  still waits for presented history and requires both answers in pixels.
- **Generated failures are not native assistant messages.** Case 6 excludes them only from the member's
  own native-answer expectations. Peer context still includes legitimate failure replies in user role
  and saved order. The room still requires every saved reply on screen.
- **Failure counts belonged to the wrong turn.** The native artifact has failures at seq 5 and 15.
  Case 12 now selects the FAIL534 parent, requires one failure plus one successful baseline answer,
  and checks the retry recipient, three provider inputs and exactly two distinct successful members.
- **ASCII-only retry advice excluded valid names.** Failure guidance now uses the actual mention picker,
  rather than inventing a command from a display name. Regressions include spaces, punctuation, Unicode
  and duplicate names. The existing ambiguous-name rejection remains intact.
- **Reply polling was unbounded.** One observation window now uses the existing two-second, then
  fifteen-second schedule and stops after thirty minutes. Snapshot reads cannot renew it. Reopening
  or an accepted new send can restart it. Host sweeps and uncertain-command recovery are separate.
- **The PR body understated the full patch.** Its scope now includes member discovery, capabilities,
  store metadata, helper publication, transport diagnostics, the desktop journal and recorder repair.

The proposed blanket rollback after `launchBytes` returns false is rejected. `launchPrepared` also
replays records that were already uncertain. A local failure of that retry cannot prove that an older
attempt had no remote effect. `room_journal.updateLocked` deliberately forbids returning to prepared.
This pass keeps that conservative invariant, including a first local launch refusal, rather than adding
a downgrade that can lose an accepted command. Durable uncertain-before-launch and exact replay remain.
A prepared-only rollback would need a separate proven transition; this pass does not claim that optimization.

Regression coverage is wired to public hosted workflows, not executed on the shared server:

- `tools/room-routing.test.py` exercises completed, interrupted, cancelled, failed and error turns, each
  with text, empty text and whitespace. It repeats collection before and after reopening the bridge and
  checks exact text, room, member, parent and the delivery-derived response ID. Room safety restores the
  old status gate as a negative control and requires the interrupted-text case to fail.
- `tools/room-reliability.test.js` compiles the production pending-reply and delay logic with a fake clock.
  It checks fast polling, backoff, the cap, reopening and unanswered older questions. A mutation that
  restores unbounded polling must fail. The picker and parser regressions retain non-ASCII shown names.
- `tools/rooms-driver.test.ps1` executes the actual driver case bodies against controlled observations.
  It rejects early room reads, missing answer pixels, retry fanout, duplicate successful-member answers,
  a missing baseline, missing or reordered peer failure context, forged assistant roles and missing
  native answers. These checks are driver regressions, not substitute native transport proof.

Still pending: final-head Room safety, Tests and native Rooms; a verifier outside OpenAI, DeepSeek and
Google without Claude; phone read/retry proof; and controlled real-transport lost-receipt proof.
Case 13 remains UNREACHABLE. An ordinary successful send does not satisfy it. Cases 9/10 remain
UNREACHABLE. Android's bundled collectors select only `pending`, so they cannot collect desktop
`pending_features_1` deliveries. MUBO-536 remains the other owner's Todo/unassigned dependency; no Android
source was edited and neither client pair nor Rooms is Done.

Faults were reported before edits. The driver and repository-check faults route to the existing
MUBO-533 and recorder MUBO-579 tickets on board 13734, not duplicate tickets or board 2060.
This worker has no board login and made no board writes. The owner must record them there.
No local tests, syntax probes, compilers, linters or installs ran. `rooms-breaks.md` is preserved.
Manual no-comments review found no added code comments or suppressions. Deslop is unavailable.

## Driver recovery, interrupted turn and lost-receipt proof

The independent hosted verifier failed the head on the Rooms journey with `Timed out: copied chat text` in the
private-chat precondition. The artifacts show why. `actions.json` records four select-all and Ctrl+C pairs for
Bravo at 99.85s to 101.50s, and `Bravo-private.txt` was saved from an earlier copy that held the user message but
not the reply. The app copies only an active transcript selection, so the reply's re-render can drop the selection
between select-all and Ctrl+C and leave the cleared clipboard empty. The old one-shot copy turned that transient
empty clipboard into a case abort, which killed the outer wait that exists to retry until the reply arrives. The
screenshot showing the reply does not prove copy worked, so the driver keeps reading the clipboard.

Corrections in the driver and its hosted regressions:

- `Copy-Chat` is now a bounded real-UI transaction. It clears, selects all, presses Ctrl+C and reads the clipboard
  with a short window, then retries the transaction a few times. A copy that never produces text returns no text
  and writes `*-empty-copy.txt`; `Copy-Chat-Until` keeps the caller's reply wait alive across empty copies and, if no
  text was ever copied, fails with the copy diagnosis instead of the reply timeout. Copied text without the reply
  still fails on the reply. The same transaction serves the private-chat precondition and the member history check.
- The away-reply observation is now a gate. The case captures the AWAY534 parent, proves the room is closed, and
  waits bounded for both provider transcripts and both saved room replies with two distinct member ids under that
  parent while the room stays closed. The room is opened only after that passes. The old code sampled once at 684-685
  and recorded 1 of 2, which read as a product gap.
- A native interrupted-turn case sends INTERRUPT534, waits for Bravo's partial text in its real transcript, opens
  Bravo's Chat View, focuses its composer and presses Escape, which sends the host's real interrupt to the
  deterministic stream-json provider. It requires the saved host state `result.subtype` to be `interrupted`, one
  saved room answer from the interrupted member, one transcript row with that text, and exactly one answer from each
  of the two members. A duplicate, a turn that was never interrupted and a missing partial text each fail it.
- Case 13 is reachable. A disposable server-side wrapper is installed as `/usr/local/bin/python3` on the runner WSL
  for one case. It matches only the production room bootstrap and only the case's own `post_human` body, runs the
  real room helper, records the committed receipt and withholds that one reply; every later attempt passes through.
  The case requires an uncertain journal record with the exact original request, one committed human row equal to
  the withheld receipt, a real desktop restart, and the app's own saved-command retry through the same transport and
  SSH with the exact original room, command id, body and revision. The retried receipt must be accepted, the room
  must still hold one human row, each member must answer once, and an edited room draft typed during the uncertain
  window must survive the restart. The case first proves the transport resolves `python3` to `/usr/bin/python3`;
  otherwise it reports the missing capability as UNREACHABLE. It removes the wrapper at the end and fails if the
  transport still resolves to the wrapper.
- `tools/rooms-driver.test.ps1` now runs the real copy transaction against a controlled clipboard: a transient empty
  copy then the reply passes, a copy that never produces text fails with the copy diagnosis, copied text without the
  reply fails on the reply, and the private case refuses a chat whose copy never holds the reply. It also runs the
  away case (passes only when both rows are saved while closed; fails when the second row appears only after the
  room opens) and the interrupted case (passes once; fails on a duplicate, a missing interrupt and a missing partial
  answer).
- `tools/rooms-drop-receipt.test.py` runs the real wrapper file on the Linux runner with a fake room helper. It
  proves one committed receipt is withheld, the next attempt replays the same command and returns the stored
  receipt, another body or another operation keeps its receipt, and an unarmed wrapper changes nothing.
- `src/room_journal.zig` adds a real-file transition test: prepare, uncertain, prepared-only rollback, reload as a
  fresh journal read (the restart precondition), then an already uncertain retry that must not be rewound and must
  keep its exact request. A launch that fails after the record is written cannot be induced through the production
  transport without a seam, so this covers the journal state machine and its file, not a native launch refusal.

No product source changed for the copy or away findings: both are harness bugs, not product faults. The withheld
receipt surfaces the transport failure as an unknown outcome, and the app keeps the draft and recovers it, which is
the behaviour this proof now measures end to end. The final-head run links live in PR 1396's Verification section.
The owned phone read and retry cases remain UNREACHABLE under MUBO-536, not passes.
