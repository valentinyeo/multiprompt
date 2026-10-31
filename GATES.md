# Gates: ISSUE-252 review corrections

OWNS: .claude/skills/verify-multiprompt/control.ps1, src/**, service/**, tests/**, tools/**, docs/**, changelog.d/**, GATES.md

Scope: Merge master, preserve automatic layout and security behavior, fix record bootstrap, SSH safety, retention, field merge and protocol safeguards, push PR 139 with green non-release checks. No local builds or suites, comments, merge, deploy or laptop access. This ledger stays uncommitted.

- [x] G1: Automatic layout and device security remain compatible with master; sync records have disjoint field ownership
  CHECK: node --test --test-name-pattern="ISSUE-252 A" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=f9df63e28bba7a2761d662b06c397125b87ad559c2ecc79e3e17ff0f9b560ac8; exit=0; EXPECT=matched; output-sha256=535d01455afc7ff16ce7f2ab204a8a385f444f0a514110c53f3e0b2756a4e746; output-bytes=370; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G2: First enable adopts remote records before observing local values
  CHECK: node --test --test-name-pattern="ISSUE-252 B" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=74c61e9f51fdb931fd736ce47e8eb29eb5345cd5132c13789e7d7a36e776d51c; exit=0; EXPECT=matched; output-sha256=11327f28db86a84e7478cd1fff65438370b553b58c4755d13c37c8e26ef71559; output-bytes=340; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G3: SSH rewrites preserve unmanaged directives, back up before writes and never delete on failed resolution
  CHECK: node --test --test-name-pattern="ISSUE-252 C" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=1d94f8e7b55467763f1626a04ee1b2e64755e9b6e67adfd97cb8132ff0448c16; exit=0; EXPECT=matched; output-sha256=f0ef915b6bfd5e8f451c5cec2cfa7f51383bacca091e8f1b9368340be9b5ec6a; output-bytes=601; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G4: Records expire tombstones, push deltas within service limits, and reject dropped records
  CHECK: node --test --test-name-pattern="ISSUE-252 D" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=fc7e2f0b0acd9376a6889137b0be8491f75f73ead40515aeb6a3856503027cc1; exit=0; EXPECT=matched; output-sha256=966bb2129b7e95fc0bff76b4e89396d37b6b10ad456cd10998b766e3cefc59df; output-bytes=347; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G5: Session activity merges independently of names and favorites
  CHECK: node --test --test-name-pattern="ISSUE-252 E" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=8092ba42e4a96502f57fbe04f2d8c986f92c14a694e9ef7a8dd6f1654b0c1a17; exit=0; EXPECT=matched; output-sha256=37cca092c52d1496e5c82601728678e2cbe8b29174b3f1496a0499cd61c82be9; output-bytes=321; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G6: Token device binding, corrected visible clock skew, SSH cache and once-per-push persistence are covered
  CHECK: node --test --test-name-pattern="ISSUE-252 N" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=2fe8ded3b705929a6d37bad9fa51bb27f4a2882d23f80a5c0904aca91f9f193c; exit=0; EXPECT=matched; output-sha256=42d5aef45fd9876d0f80844e5a3925b3687945a4a38bb1934ed21117a87bd2be; output-bytes=365; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G7: Each review regression fails against the pre-fix implementation
  CHECK: node tools/issue-252-review-proof.mjs regressions
  EXPECT: ISSUE-252 review negative controls verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=496fd63d91f3aa28570a8c80c36e65306eaef036a4fd708b05cbef5ddd7bb9a8; exit=0; EXPECT=matched; output-sha256=e07cc8ffa13a80351e7414dfcc23d5edd8c913e2602fc713572dc06b228e8514; output-bytes=44; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G8: Permitted syntax checks and patch checks pass
  CHECK: node tools/issue-252-syntax.mjs
  EXPECT: ISSUE-252 syntax verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=b293df3e397678db0cac3c414c73a4b505a9ea74dc32b0030c2331861b982fb5; exit=0; EXPECT=matched; output-sha256=73dea1a464243f6629ec1a96102cdc830d47fb6ccc2d8d2d4205e4fb2f6eea39; output-bytes=37; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G9: PR 139 contains the pushed commit and every non-release check passes
  CHECK: node tools/issue-252-review-proof.mjs pr
  EXPECT: ISSUE-252 review PR verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=44a8c8bee587999bf980e6a2c2ff371d40575702e582614464b0ce956ba07c5b; exit=0; EXPECT=matched; output-sha256=dbb3fae5366791cfd0481cfd4a45a7e9558ccbef7c1b8ff9826b4789f51f33ae; output-bytes=103; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G10: Gate definitions are well formed
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=48630b7361dd44ee870917b12c3d19b9d7bdea738aaca16bb04d4cab83b772d2; output-bytes=8; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries

- [x] G11: Desktop journey input refocuses only the identity-checked app and still guards foreground before sending keys
  CHECK: node --test --test-name-pattern="ISSUE-252 CI" tools/issue-252-review.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=14637c9db67c66401fdef79335632eab78779068c5baeb4583d585f4d2c6bdb8; exit=0; EXPECT=matched; output-sha256=d9106a5a556d0ca1e5f21540eb8b28e7acac9e98e52207cd9c2c02e04b1c21cb; output-bytes=354; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-252; path=b7c9797232e1/20 entries
