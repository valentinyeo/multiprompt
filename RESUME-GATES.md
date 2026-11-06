# Gates: HYCI-144 release follow-through

OWNS: RESUME-GATES.md

Scope: Verify the existing merged reporting change, matching hosted checks, released binaries and updater visibility before closing HYCI-144.

- [x] R1: Existing merged PR preserves timing budgets and reporting regression evidence.
  EVIDENCE: Reviewed resume-pr.json, src/chat_perf_test.zig and tools/chat-perf-reporting.test.js on 2026-11-06T19:57Z. PR832 merged fb0ea7d2f68f82f3e281fbbd2b3c92841b4ddf2e; strict 3000/100/1000ms limits retained. Regression tests execute production helper and build launch snippet with below-limit success and boundary/+7ms failures. Original historical phase and overage remain unrecoverable, explicitly disclosed in PR. Hosted PR run42273765076 passed all22 checks; merge Windows2 also success.

- [ ] R2: Hosted Tests and auto-release finish successfully for the exact merge SHA.
  CHECK: python3 -c 'import json,pathlib; p=pathlib.Path("/tmp/hyci-144-evidence"); sha="fb0ea7d2f68f82f3e281fbbd2b3c92841b4ddf2e"; runs=[json.loads((p/n).read_text()) for n in ("resume-tests.json","resume-release-run.json")]; assert all(r["headSha"]==sha and r["conclusion"]=="success" for r in runs); print("matching-merge-runs-success")'
  EXPECT: matching-merge-runs-success
  EVIDENCE: pending

- [x] R3: Published release contains the merge and usable signed updater assets.
  EVIDENCE: resume-latest-release.json shows public non-draft non-prerelease v0.28.1564 published19:31:44Z, all12 assets uploaded with nonzero size including x64/arm64 binaries, bridges, extension, release-notes.json, SHA256SUMS.txt and 64-byte signature. resume-compare.json status identical, zero ahead/behind versus merged SHA. resume-release-run.json success for same SHA. src/update_release.ps1 uses exactly this releases/latest endpoint and names. Publication proof only, not installation on Valentin's desktop.

- [ ] R4: Ticket records measured results, honest historical limitations and verified Done state.
  EVIDENCE: Not met: ticket remains AI Review, read back in resume-ticket.json. resume-agent-log.json contains recheck20:25Z and exact failed check; existing timing evidence retained. No Done claim.

ABANDON: R2 Mandatory end after rerun dispatch; Tests42278949684 attempt1 failed IGSH-1089 bitmap CreateFileW assertion. Failed jobs rerun requested; next run must verify attempt2 at2026-11-06T20:25:00Z. Release already succeeded.
ABANDON: R4 Done withheld until remaining merge-check gate succeeds. Handoff recorded and read back on HYCI-144 in AI Review.
