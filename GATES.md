# Gates: IGSH-815 fair full-history backfill

Scope: Preserve automatic complete transcript loading across restart without shared-worker starvation or growing per-page UI work. No local app build, app execution, bench execution, version edits, zig-out edits, board writes, or code comments.

- [x] G0: ledger contains decisive outcome checks
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=7a7922f0e3f69de36db176b084b74091e068cc8772d7b0d01d49001e587c54e0; output-bytes=150; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [x] G1: repository has no forbidden code comments
  CHECK: node tools/strip-comments.mjs --check
  EXPECT: No code comments found.
  EVIDENCE: automatic-evidence=v1; definition-sha256=cd5bd956f38c93d1655fd41ff1510256fd5e63a749f3a2451a2ca1d60307dc61; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [x] G2: existing chat session and reader wiring checks pass
  CHECK: node --test --test-name-pattern="^(remote reader preserves|missing transcript reason|ISSUE-268 find intercepts|ISSUE-268 sticky find|status todo|background retries|persistent reader bootstrap|disk reads are bounded|UI completion never parses|switch restores)" tools/chat-history-reader.test.js tools/chat-transcript-history.test.js tools/chat-history-connection.test.js tools/chat-cache-bound.test.js tools/chat-cpu.test.js tools/chat-switch.test.js
  EXPECT: fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=816538d8b719c717c3ee73084f9a97bd0b60f52ffe78a282bdace424133a8d9b; exit=0; EXPECT=matched; output-sha256=bcdf7b830dff5b463b71198c0602a4478846418c68f336f3ff75f8458b8a9cd1; output-bytes=2551; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [x] G3: fair backfill, full-history retention, and bounded per-page integration pass static and lightweight regression checks, including negative controls
  CHECK: node --test tools/chat-backfill-fairness.test.js
  EXPECT: fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=ac6f7dd205397674fd86866b9b55e08f8bef61d6e78fdfd1ba9b1241f33cb630; exit=0; EXPECT=matched; output-sha256=da0bc1e51ec4e31a31390b96999ff6c36a95740fc3a67392f6dd8b68261d467b; output-bytes=1353; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [x] G4: changed paths contain no version or generated output edits and the end-user changelog is present
  CHECK: git diff origin/master --check && node --test tools/chat-view-everywhere-policy.test.js
  EXPECT: fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=fcb3d49c76ba6f314b98a84f62fdf34cb11a9ffc7718498c7043475a6e216d65; exit=0; EXPECT=matched; output-sha256=7a8533d30e66c31fc2d2411b91988d72e52a473c5e5fb185c9c08a7fa8e0cc82; output-bytes=536; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [x] G5: implementation review preserves all-message loading after restart, immediate cached/tail paint, fair shared-worker turns, and bounded per-page work
  EVIDENCE: Source review 2026-10-25: chatFileRequestForDelivery still loads disk before remote acquisition; chatFileOnReady retains disk/start continuation and only clears before on stalled pages. chatFetchAcquire serializes oldest live pending selection and same-tick served-order tiebreak under the original shared mutex; chatFetchRelease wakes the oldest contender. Older apply uses an empty cursor with deferred rendering; Backfill.stage owns only this page, finish reverses chunks and renders once at start-of-file or explicit scroll/find demand. Merely reading in the middle cannot publish each page. Staged completion flushes invalid paint before another asynchronous page turn. Retirement and failed fetches free staged ownership; retry returns to the stored start. Source and model checks are not Windows runtime/CPU proof; G7 remains a required handoff.

- [x] G6: ticket-prefixed commits are pushed on the requested branch and origin matches local HEAD
  CHECK: test "$(git branch --show-current)" = ceo/IGSH-815-fair-backfill && test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/ceo/IGSH-815-fair-backfill | cut -f1)" && git log origin/master..HEAD --format=%s | python3 -c 'import sys; s=sys.stdin.read().splitlines(); assert s and all(x.startswith("IGSH-815: ") for x in s); print("PUSH VERIFIED")'
  EXPECT: PUSH VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=93c51f4d6ba64e81a4bb4641fe7fef5f19349a46060c73283976ed7771d61ee4; exit=0; EXPECT=matched; output-sha256=23b03a4ce2954d9fa3106592568b3c7a6d2c2c736bf933aa1b4a008453550fca; output-bytes=14; shell=/bin/sh; cwd=/tmp/r7-IGSH-815/wt; path=42990b3425cc/24 entries

- [ ] G7: released Windows bench meets idle CPU below 10%, all 40 cold/warm captures, warm tab 11 cached rows below 1000 ms, and every transcript parsed
  EVIDENCE: pending

G7 is a required release handoff, not a local execution permission; app builds and bench execution are prohibited on this VPS. Record the outstanding live acceptance explicitly rather than claim source checks prove it.

G2 selects existing source/wiring checks only; compiled Zig harnesses and app suites are excluded by the VPS hard limit. G3 adds scheduler/staging source contracts and negative controls; neither gate claims live Windows performance.

Initial G2 selection accidentally matched the compiled `ISSUE-268 oldest match` tool harness; its subprocess failed on the installed Zig stdlib (`ascii.isPunctuation` unavailable). No app build or app execution occurred. The corrected anchored selection excludes every compiled harness; no further compiler subprocess is authorized.

ABANDON: G7 Release-owner handoff: local Windows app builds/execution and bench are explicitly forbidden; no release was requested or performed. Run the full-history 50-message open/restart journey and the released Windows bench remotely. Require idle CPU below 10%, all 40 tabs captured in both cold and warm phases, warm tab 11 cached rows under 1000 ms, and every transcript parsed. These runtime promises are unverified, not passed.

Formatting note: syntax/format checks pass for the changed session/history/state/find files. chat_render.zig has an existing formatter finding also reproduced on origin/master; its only production change here is the explicit older-page demand flag.

Source delivery: e36fcc0843f74fc1658becdd599b5ed43d660c5e pushed to origin/ceo/IGSH-815-fair-backfill. Final runnable checks were re-executed by `node /home/valentin/.agents/skills/unlazy/scripts/gate-check.mjs --reverify GATES.md`: G0/G1/G2/G3/G4/G6 passed; G5 source review met; G7 is the explicit release handoff. Seventeen selected lightweight Node tests passed (10 existing wiring, 5 new static/model, 2 existing policy). The new compiled history/scheduler harness coverage was updated for remote CI but was not executed locally.
