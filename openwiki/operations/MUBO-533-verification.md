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
