# Gates: IGSH-805 composer line regression

OWNS: GATES.md, src/chat_composer.zig, tools/chat-composer-text-proof.test.js, changelog.d/IGSH-805-composer-line.md

Scope: Trace the newly visible composer line to its introducing commit, remove only its cause, preserve smoothing and buffered painting, add a headless regression assertion, and commit locally on ceo/IGSH-805 without pushing or opening a PR.

- [x] G1: the ledger has valid, measurable gates
  CHECK: node "$HOME/.agents/skills/unlazy/scripts/gate-lint.mjs" GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=2e01e6cb0c2b57862b4f4acfd1b3fed2fbbc2f8a6db901d2d3d3bf8d4170f7fb; exit=0; EXPECT=matched; output-sha256=fa1a5d8a8995b697473fd5e92589b000eee0caa74b695a4ac1e88e4844c6c3cb; output-bytes=901; shell=/bin/sh; cwd=/home/valentin/worktrees/IGSH-805; path=433695eed2f1/23 entries

- [x] G2: history identifies the exact introducing commit, PR and drawing property
  EVIDENCE: Inspected git log --oneline -40 and git log -p -2 -- src/chat_composer.zig src/chat_composer_text.zig. f3a9c8d247404936c15621cf864464ff4c05aaea, "IGSH-760: stop the message box flickering while typing" (#344), introduced chatComposerPaintBuffered: a fresh full-client DIB, WM_PRINTCLIENT (0x0318) with only PRF_CLIENT (4), and a full-client BitBlt. Background erasure (PRF_ERASEBKGND, 8) was omitted, allowing uncovered pixels to appear black. The earlier 7260d1b5 smoothing implementation (#336) painted directly into the existing window DC instead. git show f3a9c8d2:src/chat_composer.zig confirms the exact broken call before var probe. The supplied screenshot shows a black strip inside the input, not a new card border. Windows message documentation defines PRF_ERASEBKGND as erasing the background before drawing (https://learn.microsoft.com/en-us/windows/win32/gdi/wm-printclient).

- [x] G3: the minimal production diff removes the line's missing-background-erase cause without reverting smoothing, buffered painting or layout
  EVIDENCE: git diff 96180917 -- src/chat_composer.zig contains exactly one removed and one added line at 1153: the initial off-screen WM_PRINTCLIENT flags change from 4 to 4 | 8 (PRF_CLIENT | PRF_ERASEBKGND). This requests the existing native input background, not a new fill or border. git diff 96180917 -- src/chat_composer_text.zig src/main.zig src/window_layout.zig is empty. Native redraw suspension, BeginPaint/EndPaint, bitmap allocation, one BitBlt, placeholder, DirectWrite, selection/caret handling and geometry are unchanged. Visual outcome is not claimed as executed proof.

- [x] G4: an existing headless check asserts the corrected property and would reject the original source
  EVIDENCE: Static review of tools/chat-composer-text-proof.test.js:132-139: backgroundPrint requires the initial native print followed by var probe to use 4 | 8. The fixed source at src/chat_composer.zig:1153-1154 has that exact token sequence; the original f3a9c8d2 source has 4 alone and cannot match. The test recreates that exact client-only call by replacement, requires the replacement to change the input, and requires the same assertion to throw AssertionError on it. No Git-history runtime input or new harness is introduced. Existing IGSH-731/760 tests are unchanged. Test execution, including the negative control, runs on GitHub; none ran here.

- [x] G5: diff formatting is clean
  CHECK: git diff --check 96180917 && git diff --cached --check && printf 'DIFF FORMAT VERIFIED\n'
  EXPECT: DIFF FORMAT VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=cb4b102aba06b9558144e71ec4a4082eda2d48cfe79dfcc88e127303d76e881e; exit=0; EXPECT=matched; output-sha256=626406b0fff1b6a05aa1cacb6db108fb997e1bcd1d6d7b5280603b04fa0c497e; output-bytes=21; shell=/bin/sh; cwd=/home/valentin/worktrees/IGSH-805; path=433695eed2f1/23 entries

- [x] G6: build and test gates are assigned to existing GitHub checks, not executed on this VPS
  EVIDENCE: Read .github/workflows/verify.yml:14-39,138: pull requests changing src/** or tools/chat-composer-text-proof.test.js run the existing composer Node suite. Read .github/workflows/test.yml:3-7,113,534,540: desktop test shards and architecture builds run on GitHub on PRs (or workflow dispatch/master push), not automatically on an un-PR'd feature-branch push. verify.yml:270-282 also supports the dedicated chat-composer-text Windows rendering journey via workflow dispatch; it is not in the automatic PR feature matrix. No workflow was dispatched, build/test command executed, push performed or PR created. These gates prove wiring/handoff only, not successful execution.

- [x] G7: the requested local commit exists on ceo/IGSH-805 with only the scoped files and no new code comments
  EVIDENCE: git log -1 and git show --stat 38032900 identify "IGSH-805: erase the native composer background in buffered frames" on ceo/IGSH-805. Its three files are src/chat_composer.zig, tools/chat-composer-text-proof.test.js and changelog.d/IGSH-805-composer-line.md; GATES.md is the only additional delivery artifact. Reviewed all added Zig/JavaScript lines: one flags expression and a nine-line test, no comments. Git's normal secret-scanning hooks passed without bypass. The ledger is committed separately so it can record proof of the fix commit.

## GitHub execution gates — runs on GitHub

The following are intentionally not local execution claims:

- Headless regression: `node --test --test-name-pattern='^IGSH-805 ' tools/chat-composer-text-proof.test.js`. Expect one passing test, including rejection of the client-only flag mutation. The existing full composer suite must also pass.
- Build/test: existing `.github/workflows/test.yml` desktop shards, VPS shards and x64/ARM64 build jobs. **Runs on GitHub** when the caller integrates the branch through the normal PR workflow.
- Native/visual acceptance: existing `verify.yml` feature `chat-composer-text`, with no release tag, plus inspection of the whole input with empty and typed drafts. **Runs on GitHub** on caller dispatch; full-client absence of the black strip remains visually unproved here.

No builds or tests ran on this VPS, including Node tests. Only file/history inspection, static reasoning, diff checks, normal commit secret scans and ledger metadata validation ran here. Seven local gates distinguish source/handoff proof from the unexecuted GitHub gates above. No push or PR creation is authorized.
