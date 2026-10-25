# Gates: IGSH-789 remote-session notifier help

OWNS: src/workspaces.zig, tools/verify-multiprompt.test.js, changelog.d/IGSH-789-remote-notification-help.md, GATES.md

Scope: Replace unauthenticated remote-session ACTIVE/DONE help with the installed notifier, add source-only regression coverage alongside existing workspace tests, and open the requested PR without changing relay authorization or dispatching verification workflows.

- [x] G1: this ledger states measurable outcomes
  CHECK: node "$HOME/.agents/skills/unlazy/scripts/gate-lint.mjs" GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=2e01e6cb0c2b57862b4f4acfd1b3fed2fbbc2f8a6db901d2d3d3bf8d4170f7fb; exit=0; EXPECT=matched; output-sha256=436c0377481d53ed71d9ed3f38baa6fd551d84a9ba38e5c494cd426c226793d0; output-bytes=268; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-wt/r3-IGSH-789; path=433695eed2f1/23 entries

- [x] G2: remote-session help accurately describes notifier session selection and the unchanged reverse tunnel
  EVIDENCE: Read tools/agent-notifications/notify.py before editing. target() uses TMUX_PANE with tmux display-message session_name when TMUX is set; only outside tmux does it fall back to MULTIPROMPT_TAB. Both remote targets use port 19548. The new text states those boundaries, keeps localhost:19548 tunnel mapping, requires the installed Python notifier, and removes manual label substitution. The remote format string has no placeholders and uses an empty argument tuple; local help is unchanged.

- [x] G3: the existing workspaces source-test harness accepts notifier help and excludes raw ACTIVE/DONE TCP instructions
  CHECK: node --test --test-name-pattern='^IGSH-789:' tools/verify-multiprompt.test.js
  EXPECT: /# pass 1\b[\s\S]*# fail 0\b/
  EVIDENCE: automatic-evidence=v1; definition-sha256=4996be38b1b9c846789d0c9cda19fe9c6879bd9f4be19e927f186c7bc11ad5b4; exit=0; EXPECT=matched; output-sha256=95bed18b8eafa7eba23c6fd417038f37c3c5b6a33bbba59c224bf9f3aadd45eb; output-bytes=340; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-wt/r3-IGSH-789; path=433695eed2f1/23 entries

- [x] G4: only the intended help, regression, changelog and ledger change, with no relay changes or code comments
  CHECK: git diff --check && git diff --cached --check && node --input-type=module -e "import a from 'node:assert/strict'; import fs from 'node:fs'; import {execFileSync as git} from 'node:child_process'; import {tokenize} from './tools/strip-comments.mjs'; const names=git('git',['diff','--name-only','540f0bf8'],{encoding:'utf8'}).trim().split('\n').sort(); a.deepEqual(names,['GATES.md','changelog.d/IGSH-789-remote-notification-help.md','src/workspaces.zig','tools/verify-multiprompt.test.js'].sort()); for(const [file,language] of [['src/workspaces.zig','zig'],['tools/verify-multiprompt.test.js','javascript']]) a.equal(tokenize(fs.readFileSync(file,'utf8'),language).comments.length,0); const before=git('git',['show','540f0bf8:src/workspaces.zig'],{encoding:'utf8'}); const after=fs.readFileSync('src/workspaces.zig','utf8'); const strip=s=>s.replace(/            \"NOTE: this is a REMOTE[\s\S]*?(?=\n    else\n)/,''); a.notEqual(strip(before),before); a.equal(strip(after),strip(before)); console.log('SCOPED COMMENT-FREE DIFF VERIFIED');"
  EXPECT: SCOPED COMMENT-FREE DIFF VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=1a24fbf7f7612f7d5a412c855e4df50553657885c305d1fca68906c5b1bf16a9; exit=0; EXPECT=matched; output-sha256=ebdd563811523a2405aa56b617c8e924faa61b96396b73772a3eabfa3e61f4ad; output-bytes=34; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-wt/r3-IGSH-789; path=433695eed2f1/23 entries

- [x] G5: remote-session activity verification coverage is reported honestly without dispatching a workflow
  EVIDENCE: Read .claude/skills/verify-multiprompt/SKILL.md, features/README.md, sessions.md, workspaces.md, inbox.md, status-card.md, coverage.md and verify.yml's feature allowlist. No feature key covers remote-session ACTIVE/DONE relay activity. coverage.md explicitly records IGSH-514 remote activity as none / not covered, requiring actual tmux hooks, relay and an attached client. The inbox key covers a local manual blue-dot toggle only, not remote activity. No workflow dispatch command was run. The PR must name this gap, not imply inbox or session-open covers it. GitHub PR-triggered checks and reviewer-owned runtime verification are outside local proof.

- [x] G6: the requested branch is pushed and has an open PR with the exact title, relay boundary, regression and coverage gap
  CHECK: node -e "const a=require('node:assert/strict'),c=require('node:child_process'); const run=args=>c.execFileSync('git',args,{encoding:'utf8'}).trim(); a.equal(run(['branch','--show-current']),'ceo/IGSH-789'); a.equal(run(['rev-parse','HEAD']),run(['ls-remote','origin','refs/heads/ceo/IGSH-789']).split(/\s/)[0]); const pr=JSON.parse(c.execFileSync('gh',['pr','view','ceo/IGSH-789','--repo','valentinyeo/multiprompt','--json','title,state,headRefName,headRefOid,baseRefName,body,url'],{encoding:'utf8'})); a.equal(pr.title,'IGSH-789: remote-session help sends ACTIVE and DONE through the notifier'); a.equal(pr.state,'OPEN'); a.equal(pr.headRefName,'ceo/IGSH-789'); a.equal(pr.headRefOid,run(['rev-parse','HEAD'])); a.equal(pr.baseRefName,'master'); for(const text of ['relay','IGSH-789:','verify.yml','not covered','TMUX_PANE','MULTIPROMPT_TAB']) a.ok(pr.body.includes(text),text); console.log('REQUESTED OPEN PR VERIFIED');"
  EXPECT: REQUESTED OPEN PR VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=0c5055aac4f8ded4a97ca41e2200d9276d267a7958706e7e381a84d9b0867795; exit=0; EXPECT=matched; output-sha256=255567b6d1a3638b06879937af2db05d12555dd7734a6ece14f0335cdac71e11; output-bytes=27; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-wt/r3-IGSH-789; path=433695eed2f1/23 entries

## Regression evidence and execution boundary

Before changing src/workspaces.zig, the new IGSH-789 source-text regression exited 1 on the ACTIVE/DONE /dev/tcp absence assertion against the actual original help. Its local transcript is .unlazy/IGSH-789/old-help.tap. After the help edit, that same filtered test passed (one test, no build). This is a regex source-text check in tools/verify-multiprompt.test.js beside existing workspace tests, already wired into verify.yml. No new harness was added.

The full tracked-source search found exactly the two original printf help lines in src/workspaces.zig and no extra ACTIVE/DONE help instructions targeting 19548. No credential value, credential path, sensitive value, flags, limits, notifier behavior or relay authorization changes were added. A plain end-user changelog fragment is required by the repository's app-change policy.

Only source inspections and the requested lightweight source-text regression ran locally. No Zig, Gradle, Wine, app execution, builds, full test suites, or workflow dispatch. The Claude reviewer owns runtime verification and merging. Verification feature key: none (remote-session activity is not covered by verify.yml).
