# Gates: IGSH-252 opt-in cross-device sync

OWNS: build.zig, src/**, service/**, tests/**, tools/**, docs/**, openwiki/**, changelog.d/**, GATES.md

Scope: Inventory persisted fields, implement opt-in record sync through the account service, prove two-device behavior and privacy, and publish an unmerged PR with green GitHub checks. No local builds or suites, deployment, laptop access, or ticket writes.

- [x] G1: Every persisted host, workspace and session field has a documented sync policy and existing account API is traced
  CHECK: node --test tools/issue-252-inventory.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=2584cc454ccb2e3a37ffc7fa37f6b69eab9106e34c577ff0283054964206de74; exit=0; EXPECT=matched; output-sha256=f6c2e5fb18ecd54a55ab02dc920082379491c9c21892c85cc0e298966bc3fb29; output-bytes=619; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G2: Production record merge and fake-server two-device tests cover add edit delete conflict round trip offline recovery and privacy on GitHub
  CHECK: node tools/issue-252-proof.mjs protocol
  EXPECT: ISSUE-252 protocol proven
  EVIDENCE: automatic-evidence=v1; definition-sha256=14b83837638ea295e06d06aefd35d27f895f098806451deefbb3023c10af8069; exit=0; EXPECT=matched; output-sha256=1460c2c5944e0c51a46242999f34314608523fa154d5c4c726495c6fb5a20cd9; output-bytes=52; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G3: Sync defaults off, has palette and F1 surfaces, preserves local files, uses bounded retries and no disabled timer wakeups
  CHECK: node --test tools/issue-252-integration.test.js
  EXPECT: # fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=21f09b24acca2cdeebd89a5de86dac237bb99b2d0506dae2d5545755e56511fe; exit=0; EXPECT=matched; output-sha256=ff1e33714e961618fbaf642a694ab6cc5ec4b64dd32ba1f07073c8926c2b0ef5; output-bytes=812; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G4: Changed Zig and JavaScript files pass permitted syntax checks and patch whitespace validation
  CHECK: node tools/issue-252-syntax.mjs
  EXPECT: ISSUE-252 syntax verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=b293df3e397678db0cac3c414c73a4b505a9ea74dc32b0030c2331861b982fb5; exit=0; EXPECT=matched; output-sha256=b060f7edc606ae3ab21bbab29321a73c03be0eaf47e69ed590a8f491be5a6abd; output-bytes=37; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G5: Regression tests fail against the original implementation and privacy controls reject sensitive data
  CHECK: node tools/issue-252-proof.mjs regressions
  EXPECT: ISSUE-252 regression controls proven
  EVIDENCE: automatic-evidence=v1; definition-sha256=b84268530753349d02710383a8fd66456967a75916155286eb67664afd17ef96; exit=0; EXPECT=matched; output-sha256=aad218222885ba8ffd0c9cd295e6fc386f95fb639795efec93cc0e067275aa22; output-bytes=63; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [x] G6: Required changelog and shortcut documentation ship without version bumps, private data or code comments
  CHECK: node tools/issue-252-proof.mjs public
  EXPECT: ISSUE-252 public release rules verified
  EVIDENCE: automatic-evidence=v1; definition-sha256=d44d831eb3c723f43b3320f62af89e8b92268dcde7f2461c27d3e2891e4e19b8; exit=0; EXPECT=matched; output-sha256=5808e16b70b1a8b9f9e0b01df47a059dee6c7e655996c4e3dad387b7c7586c1e; output-bytes=40; shell=/bin/sh; cwd=<repository>; path=b7c9797232e1/20 entries

- [ ] G7: Ticket commit is pushed and titled PR has every GitHub check green without merge or deployment
  CHECK: node tools/issue-252-proof.mjs pr
  EXPECT: ISSUE-252 PR verified
  EVIDENCE: pending

G7 blocker: GitHub Release run 39701998938, attempts 1 and 2, was canceled by the repository account before build steps started. Check annotation 119576780844 confirms the cancellation. Test run 39701998923 passed all four Windows shards and both server shards. An uncanceled PR-only x64 and ARM64 build is required; no merge or deployment was performed.
