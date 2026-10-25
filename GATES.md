# Gates: IGSH-811 Chrome frameless measurement

OWNS: GATES.md, .github/workflows/probe-chrome-frameless.yml, tools/probe-chrome-frameless.ps1

Scope: Measure branded Chrome frame removal, navigation stability, corner input and edge hit tests on a GitHub-hosted Windows desktop without modifying the mask subsystem or running local builds or tests. Starting commit: fada2dbd. The local gate commands inspect source scope, remote workflow metadata and downloaded measurements only; they do not build or run the application or a test suite.

- [x] G0: The ledger has valid observable gates
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=c9fd2cdb0d4aba36dbf0e4410277e7a196bec0a82541d649323196a2b7d4d65e; output-bytes=259; shell=/bin/sh; cwd=/tmp/r8-IGSH-811/worktree; path=42990b3425cc/24 entries

- [x] G1: Only the self-contained probe, its workflow and this ledger differ from the starting commit
  CHECK: git diff --check && git diff fada2dbd --name-only
  EXPECT: /^\.github\/workflows\/probe-chrome-frameless\.yml\nGATES\.md\ntools\/probe-chrome-frameless\.ps1\n$/
  EVIDENCE: automatic-evidence=v1; definition-sha256=2e5e03f2e68e31fd0a85e314c8686e15d7fc0ff2981ba5611509adc780f8bbd6; exit=0; EXPECT=matched; output-sha256=3a79676ba9822625c2a2247ae889b8e76716fb116fd5fa53c7a9f77e8b08d8f4; output-bytes=87; shell=/bin/sh; cwd=/tmp/r8-IGSH-811/worktree; path=42990b3425cc/24 entries

- [x] G2: The pushed probe commit has a successful Windows run
  CHECK: gh run view 40185206556 --repo valentinyeo/multiprompt --json conclusion,headSha,url | jq -er 'select(.conclusion == "success" and .headSha == "16dd7f46e10e968630249801989564df501216f5") | .url'
  EXPECT: https://github.com/valentinyeo/multiprompt/actions/runs/40185206556
  EVIDENCE: automatic-evidence=v1; definition-sha256=648faa7b8d2b6a1bffc906424f71513ebb376e2bf5d7a0eadb227200dd22a1a0; exit=0; EXPECT=matched; output-sha256=c63753752911aef1a5b26fdbc862cfe74998a04d5f114eaa827ba6d29ca09ab0; output-bytes=68; shell=/bin/sh; cwd=/tmp/r8-IGSH-811/worktree; path=42990b3425cc/24 entries

- [x] G3: Downloaded JSON contains the exact branded browser, four style/HWND snapshots, both navigation outcomes, physical corner clicks and edge hit tests
  CHECK: jq -e '.status == "complete" and .commit == "16dd7f46e10e968630249801989564df501216f5" and .browser.brandedGoogleChrome == true and (.browser.productVersion | length > 0) and (.stages | length == 4) and (.navigation | length == 2) and ([.stages[] | (.hwnd | startswith("0x")) and (.style | test("^0x[0-9A-F]{8}$")) and (.hitTests.top.code | type == "number")] | all) and (.stages[3].cornerClicks | length == 2) and (.navigation | map(has("sameHwnd") and has("stylesStillStripped")) | all)' /tmp/r8-IGSH-811/evidence/final/result.json
  EXPECT: true
  EVIDENCE: automatic-evidence=v1; definition-sha256=9234e870ed2b63d8aa5ec9d6e04f782b71341683f3f8dfdfbb399d5d78204ebe; exit=0; EXPECT=matched; output-sha256=a17fcf0a2f50e2d495e4f90ce263410edc183add6c62699a2facbccf60410f74; output-bytes=5; shell=/bin/sh; cwd=/tmp/r8-IGSH-811/worktree; path=42990b3425cc/24 entries

- [x] G4: Visual evidence, artifact completeness, comment-free source and final verdict were reviewed against the request
  EVIDENCE: Downloaded chrome-frameless-probe artifact 12595966482 from run 40185206556 to /tmp/r8-IGSH-811/evidence/final: result.json and 12 PNGs (full, top-left, top-right for before, after-strip, after-navigation, after-link-click). Opened before-top-right.png, after-strip-top-left.png, after-strip-top-right.png and after-link-click-full.png: caption, all three buttons and border remain visible after strip and navigation. Branded Google Chrome 156.0.8078.48; HWND 0x4018A; 0x16CF0000 to 0x16000000, retained on both navigations without recreation. Physical left corner did not reach page; physical right corner closed window. After strip hit codes: caption 2, close 20, top edge 12; left/right/bottom/bottom-right 0. Baseline edge codes 10/11/15/17 establish the negative-control comparison. Verdict: no for this exact style-only technique on this build; raw style removal succeeds but UI controls remain active. Read the full new PowerShell/C# and YAML: no code comments, no mask/application/test modifications. No Hypertask writes, local builds or application/test-suite runs occurred. Only the fresh ceo/IGSH-811 worktree was written. Code commit 16dd7f46e10e968630249801989564df501216f5 is pushed; the subsequent ledger-only commit does not retrigger the path-filtered probe.
