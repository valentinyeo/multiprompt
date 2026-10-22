# Gates: IGSH-252 opt-in cross-device sync

OWNS: build.zig, src/**, service/**, tests/**, tools/**, docs/**, openwiki/**, changelog.d/**, GATES.md

Scope: Inventory persisted fields, implement opt-in record sync through the account service, prove two-device behavior and privacy, and publish an unmerged PR with green GitHub checks. No local builds or suites, deployment, laptop access, or ticket writes.

- [x] G1: Every persisted host, workspace and session field has a documented sync policy and existing account API is traced
  CHECK: node --test tools/issue-252-inventory.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=2584cc454ccb2e3a37ffc7fa37f6b69eab9106e34c577ff0283054964206de74; exit=0; EXPECT=matched; output-sha256=c12ba59d669c66d789a7b3c028aed322b4157bd05ee9e3f0df78f3a4c2f01f18; output-bytes=620; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [ ] G2: Production record merge and fake-server two-device tests cover add edit delete conflict round trip offline recovery and privacy on GitHub
  CHECK: node tools/issue-252-proof.mjs protocol
  EXPECT: ISSUE-252 protocol proven
  EVIDENCE: pending

- [x] G3: Sync defaults off, has palette and F1 surfaces, preserves local files, uses bounded retries and no disabled timer wakeups
  CHECK: node --test tools/issue-252-integration.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=21f09b24acca2cdeebd89a5de86dac237bb99b2d0506dae2d5545755e56511fe; exit=0; EXPECT=matched; output-sha256=df7b4697ceacc7993049b54768e5277769d94430c4e9d5489af8d2249b689ced; output-bytes=813; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G4: Changed Zig and JavaScript files pass permitted syntax checks and patch whitespace validation
  CHECK: node tools/issue-252-syntax.mjs
  EXPECT: ISSUE-252 syntax verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=b293df3e397678db0cac3c414c73a4b505a9ea74dc32b0030c2331861b982fb5; exit=0; EXPECT=matched; output-sha256=64a3303cfa727e55ec7c7068b5647056d5a958b9d834c56ad23cb5726caabfe1; output-bytes=37; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [ ] G5: Regression tests fail against the original implementation and privacy controls reject sensitive data
  CHECK: node tools/issue-252-proof.mjs regressions
  EXPECT: ISSUE-252 regression controls proven
  EVIDENCE: pending

- [x] G6: Required changelog and shortcut documentation ship without version bumps, private data or code comments
  CHECK: node tools/issue-252-proof.mjs public
  EXPECT: ISSUE-252 public release rules verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=d44d831eb3c723f43b3320f62af89e8b92268dcde7f2461c27d3e2891e4e19b8; exit=0; EXPECT=matched; output-sha256=5808e16b70b1a8b9f9e0b01df47a059dee6c7e655996c4e3dad387b7c7586c1e; output-bytes=40; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [ ] G7: Ticket commit is pushed and titled PR has every GitHub check green without merge or deployment
  CHECK: node tools/issue-252-proof.mjs pr
  EXPECT: ISSUE-252 PR verified
  EVIDENCE: pending
