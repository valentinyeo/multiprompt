# Gates: IGSH-252 opt-in cross-device sync

OWNS: src/**, service/**, tools/**, docs/**, openwiki/**, changelog.d/**, GATES.md

Scope: Inventory persisted fields, implement opt-in record sync through the account service, prove two-device behavior and privacy, and publish an unmerged PR with green GitHub checks. No local builds or suites, deployment, laptop access, or ticket writes.

- [ ] G1: Every persisted host, workspace and session field has a documented sync policy and existing account API is traced
  CHECK: node --test tools/issue-252-inventory.test.js
  EXPECT: # fail 0
  EVIDENCE: pending

- [ ] G2: Production record merge and fake-server two-device tests cover add edit delete conflict round trip offline recovery and privacy on GitHub
  EVIDENCE: pending

- [ ] G3: Sync defaults off, has palette and F1 surfaces, preserves local files, uses bounded retries and no disabled timer wakeups
  CHECK: node --test tools/issue-252-integration.test.js
  EXPECT: # fail 0
  EVIDENCE: pending

- [ ] G4: Changed Zig and JavaScript files pass permitted syntax checks and patch whitespace validation
  CHECK: node tools/issue-252-syntax.mjs
  EXPECT: ISSUE-252 syntax verified
  EVIDENCE: pending

- [ ] G5: Regression tests fail against the original implementation and privacy controls reject sensitive data
  EVIDENCE: pending

- [ ] G6: Required changelog and shortcut documentation ship without version bumps, private data or code comments
  EVIDENCE: pending

- [ ] G7: Ticket commit is pushed and titled PR has every GitHub check green without merge or deployment
  EVIDENCE: pending
