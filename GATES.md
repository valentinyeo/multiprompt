# Gates: IGSH-720

OWNS: GATES.md, src/chat_history_reader.py, tools/chat-history-reader-test.py, src/chat_shell_sync.zig, src/chat_composer.zig, src/chat_send.zig, src/chat_render.zig, src/chat_session.zig, src/chat_history.zig, tools/chat-transcript-history.test.js, openwiki/operations/chat-delivery.md, changelog.d/IGSH-720-chat-draft-scroll.md

Scope: prevent duplicate or reordered shell drafts and preserve a scrolled-up transcript without changing send behavior or app version.

Validation boundary: local test suites and builds are forbidden. Gates below require implementation and static regression review, not a claim of executed behavioral tests. Only Python syntax compilation and the comment checker may run locally; behavioral execution belongs to GitHub. Gate evidence is manually recorded to avoid running additional validation tools.

- [x] G1: both reader operations share clearing; Draft requires an empty box and retains its unchanged-text early exit; Send behavior is unchanged.
  EVIDENCE: Reviewed src/chat_history_reader.py:1425-1483 and :1497-1526 against the original diff: the extracted loop is unchanged; Send retains its stalled fallback; Draft checks the returned box before typing, returns box_not_clear otherwise, and retains the initial equality check.

- [x] G2: lagging-render draft regression and failure-to-clear regression are authored and reviewed against the old implementation.
  EVIDENCE: Static old/new trace of tools/chat-history-reader-test.py:1814 and :1841: the first capture exposes only one of two rows. Old Draft clears once and produces old firstnew draft; the shared loop recaptures and clears the remaining row. A permanently stuck box previously received literal text and returned ok; the new branch returns box_not_clear after C-u/C-u/C-k without a literal write. These are authored regressions, not executed suite results.

- [x] G3: draft pushes have one atomic in-flight owner, retain pending edits, and release ownership on every completion or launch failure.
  EVIDENCE: Reviewed src/chat_shell_sync.zig:172-241, src/chat_composer.zig:1616-1634 and src/chat_send.zig:2629-2671. UI-only pushDue reserves the atomic flag, checks it before consuming edit_pending, and tab initialization never overwrites it. The worker release-store is deferred before any allocation or request; every failed launch returns to the composer, which releases and restores edit_pending. Only the flag is accessed by the worker; all other Draft fields remain UI-owned.

- [x] G4: draft ordering regressions are authored and reviewed to reject the old implementation.
  EVIDENCE: Static review of src/chat_shell_sync.zig:420 and :439: old pushDue returns true on the intermediate/newer attempt and consumes edit_pending before the first worker completes. Both tests reject that result. The second also exercises shell replacement while the older operation owns the reservation; the first verifies coalescing to the latest edit after release. Execution deferred to GitHub.

- [x] G5: a single pure follow decision preserves scrolled-up position, cancels stale pending jumps, and covers all scroll-state writes.
  EVIDENCE: Reviewed every assignment found by rg for g_chat_scroll_y, g_chat_scrolled_up and g_chat_scroll_bottom_pending across src. Refresh and preserving relayout use chat_history.followBottom; dirty composer and outbox layout both call preserving relayout. User scroll cancels pending jumps on movement and older-page request; refresh consumes pending even with unchanged blocks. Remaining writes are tab initialization, find navigation, explicit voice replay, viewport clamping, or test setup, not new-message bottom jumps.

- [x] G6: scroll regressions cover new messages, bottom following, and send-then-scroll-up; applicable JavaScript model coverage rejects the old implementation.
  EVIDENCE: Reviewed three IGSH-720 pure cases at src/chat_history.zig:1232-1245 and the production-extracting case at tools/chat-transcript-history.test.js:411-460. Coverage includes anchored reading, bottom following followed by scroll-up, send-then-scroll-up, unchanged refresh consuming pending, forced refresh, and relayout. The JavaScript case includes the old refresh expression/reset order as a negative control: its unchanged refresh retains pending and fails TestUnexpectedResult. The old complete implementation also fails the earlier scroll cancellation assertion. The pure cases encode the new reader-priority policy, absent from the old code; behavioral execution remains for GitHub.

- [x] G7: permitted Python syntax and comment checks succeed; no forbidden build or test suite is run.
  EVIDENCE: Executed python3 -m py_compile src/chat_history_reader.py tools/chat-history-reader-test.py: exit 0. Executed node tools/strip-comments.mjs --check: exit 0, No code comments found. Repeated both after the final code edits. No build, Zig execution, Node test harness, Wine, Gradle, preflight or other test suite was run.

- [x] G8: delivery documentation and end-user changelog match the fixes; no app version, credentials, private data, or code comments are introduced.
  EVIDENCE: Reviewed the complete diff and changelog.d/README.md. The fragment contains two short end-user sentences; openwiki/operations/chat-delivery.md adds one line per rule. APP_VERSION has no diff. No new timeouts, caps, sleeps, code comments, credentials, private host names, emails or internal paths are present in the changes.

- [x] G9: final diff is reviewed and committed only on the requested branch with the required message prefix; no remote or board mutations occur.
  EVIDENCE: Implementation committed as f92a0ba0 (IGSH-720: serialize verified draft updates and preserve chat scroll) on ceo/IGSH-720; git show confirms the eleven intended implementation, regression and documentation files, with no APP_VERSION change. git status --short is clean before this ledger-only commit. Both commits use the required prefix. No board, push, PR, merge, branch or destructive Git command was used.

Result: nine implementation/static-review gates met, zero unmet, zero abandoned. Behavioral regression execution is not claimed and must occur in GitHub; only the two expressly permitted local checks were executed.
