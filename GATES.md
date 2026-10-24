# Gates: IGSH-760 composer flicker

OWNS: GATES.md, src/chat_composer.zig, src/chat_composer_text.zig, tools/composer-paint-audit.mjs, tools/chat-composer-text-proof.test.js, tools/fixtures/IGSH-760/**

Scope: Remove typing-induced incomplete composer frames while retaining IGSH-731 smooth text and immediate input. Only this worktree and branch may be changed; no local builds, native runs, test suites, pushes, PRs, or board writes.

- [x] G0: This ledger has valid, falsifiable source-check definitions.
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=7a7922f0e3f69de36db176b084b74091e068cc8772d7b0d01d49001e587c54e0; output-bytes=150; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-760; path=433695eed2f1/23 entries

- [x] G1: The exact shipped source exposes the whole-client invalidation path for each key message.
  CHECK: node tools/composer-paint-audit.mjs --source=tools/fixtures/IGSH-760
  EXPECT: "fullClientInvalidations": 3
  EVIDENCE: automatic-evidence=v1; definition-sha256=50e574f5afdfa44fee6d1a2b2b12d50e85e4f2029bf5e7a8577c2ce525ec072e; exit=0; EXPECT=matched; output-sha256=e0c4fa511f882b9f5ac9bc144b0bd2db75749a0e9f466befb9c1fa4827c628d2; output-bytes=369; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-760; path=433695eed2f1/23 entries

- [x] G2: The fixed source guards native inline drawing, stages background and smooth text offscreen, presents one completed frame and preserves the glyph/selection painter byte-for-byte.
  CHECK: node tools/composer-paint-audit.mjs --require-buffered
  EXPECT: COMPOSER PAINT CONTRACT VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=b6ae495803af17052800fab3272e11a3e581624b340947abdcc9c73e169d38c0; exit=0; EXPECT=matched; output-sha256=f2339197cbc509c1c4404229135199ba5c63ed3bbbb07fa9fbd3b98cbcc05ca3; output-bytes=370; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-760; path=433695eed2f1/23 entries

- [x] G3: The same source oracle rejects the shipped direct-paint implementation for its visible background clear, not for missing fixtures or parse errors.
  CHECK: node -e "const {spawnSync}=require('node:child_process'); const a=require('node:assert/strict'); const r=spawnSync(process.execPath,['tools/composer-paint-audit.mjs','--source=tools/fixtures/IGSH-760','--require-buffered'],{encoding:'utf8'}); a.equal(r.status,1); a.match(r.stderr,/composer clears the visible text area/); console.log('BROKEN COMPOSER REJECTED');"
  EXPECT: BROKEN COMPOSER REJECTED
  EVIDENCE: automatic-evidence=v1; definition-sha256=cf7775d9cf7ec824ea47cdf9198ce46b90b7ae01927715017414725b68101e12; exit=0; EXPECT=matched; output-sha256=a14234b4db3951d9428177a231e1859ef1491d332cc7916036aa3f4e982b0397; output-bytes=25; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-760; path=433695eed2f1/23 entries

- [x] G4: Whitespace, JavaScript syntax, source-range integration and the repository no-comments lint pass without building or running a test suite.
  CHECK: git diff --check 42cecfd3 && node --check tools/composer-paint-audit.mjs && node --check tools/chat-composer-text-proof.test.js && node tools/app-source.js > /dev/null && node tools/strip-comments.mjs --check
  EXPECT: No code comments found.
  EVIDENCE: automatic-evidence=v1; definition-sha256=e8b5b5d2b16279bd097bab570f65f3acfb45e12b101b5e4353beea5a9e91cb19; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-760; path=433695eed2f1/23 entries

- [x] G5: The reviewed authored change is committed on the requested branch in the designated worktree without main-checkout edits or remote mutation.
  EVIDENCE: Code commit 1282376f (IGSH-760: present completed composer frames while typing) succeeded with the normal secret-scan hooks on ceo/IGSH-760. pwd and git branch identify /home/valentin/projects/multiprompt-760 and ceo/IGSH-760. git show --stat records exactly the two composer sources, the existing Node regression, source auditor and four frozen input/provenance files; no production main/dwrite/layout changes. No commit bypass, build/test suite, push, PR or board command was issued. GATES.md is delivered in the subsequent evidence-only commit. Independently appearing untracked files are left untouched.

- [ ] G6: Windows-native before/after paint counts and on-screen typing prove no flash of the box, border, background, caret or text, including empty transitions and wrapping.
  EVIDENCE: Not executed. The task forbids local native builds, test suites and app runs, and forbids pushing the code needed for GitHub execution. Native and visual outcomes cannot honestly be certified here.

ABANDON: G6 Required handoff to the authorized GitHub/Windows runner; execute the new native test, existing smoothing/geometry proof and live typing-frame verification. This is not a passing gate or a claim of completed visual QA.

## Root cause and measured evidence

Baseline is origin/master 42cecfd3e88e78f3c44f0b30917a8629c8e94f8f (v0.28.860). Its composer implementation is identical to 7260d1b5a977af1baa6062f70bfa175c34527ec9. Frozen exact excerpts and SHA-256 provenance are in tools/fixtures/IGSH-760; the automated regression never depends on Git history being present.

IGSH-731 sets native EDIT ink equal to its background in main.zig, calls the original WM_PAINT first, then obtains an unclipped window DC with GetDC. Its new painter FillRect clears the full formatting rectangle before DirectWrite renders visible lines. Its deferred invalidateAfter invalidates the entire child client (null rectangle, erase=false) on key-down, character and key-up, regardless of whether the composer height changed. Thus invalidation repeatedly exposes a native hidden-ink paint and a subsequent unbuffered clear/line-by-line overlay. Native synchronous EDIT drawing during input is an additional suspected contributor, isolated by the new Windows-native red/green control; its runtime count remains unmeasured here.

The audit measures source call paths, NOT actual Windows paint deliveries, timings, or captured frames. A key cycle is WM_KEYDOWN, WM_CHAR, WM_KEYUP, each dispatched once; pending invalidations may coalesce in the OS. Counts are independently extracted from the actual message switch and drawing call sites.

| Source-derived count | Shipped | Fixed |
| --- | ---: | ---: |
| Whole-client invalidation requests per key cycle | 3 | 3 |
| Key messages with redraw suppression around native dispatch | 0 | 3 |
| Native screen-paint dispatch before smooth overlay per paint | 1 | 0 |
| Unbuffered full-text-area background clear sites per paint | 1 | 0 |
| Completed-frame presentation blit sites per paint | 0 | 1 |

No reduction in invalidation requests is claimed. The fix changes what gets presented, not when input is accepted: matching native messages are redraw-guarded with WM_SETREDRAW; the original invalidation timing remains. WM_PAINT uses BeginPaint/EndPaint, suppresses separate background erasure and stages native background, placeholder, smooth text and selection into a DIB before one BitBlt. The visible-style guard avoids showing an originally hidden composer and prevents nested messages from re-enabling redraw prematurely. Ordinary native rendering remains the existing failure/IGSH_731=0 fallback.

No IGSH-731 glyph rendering is reverted. Its paint function, DirectWrite shaping/cache code, native positions, selection drawing and caret hide/show logic are unchanged. Only the unsafe visible native-WM_PAINT/GetDC overlay presentation is replaced. Auto-grow, input handlers, autocomplete, layout, themes, timers, settings and main.zig are untouched. No new switch, cap, delay, timeout or code comment is added.

## Native regression prepared for GitHub

src/chat_composer.zig contains `IGSH-760 typing presents completed smooth frames without native inline paints`. It creates a real visible multiline EDIT, masks native ink like production, sends four complete key cycles and counts synchronous native control-color requests, WM_PAINTs, offscreen native prints, window-directed native prints and DirectWrite runs. The unguarded negative control must produce native inline requests; the guarded path must produce zero inline requests, four paints, four offscreen prints, zero window prints and four smooth runs. It also checks immediate text contents, focus, visibility and editing an originally hidden control. These are assertions awaiting execution, NOT measured before/after results.

Existing nine-scale/DPI smoothing and wrapped tabs/selection/scroll/undo geometry tests remain unchanged. The Node source-contract regression is wired through the existing chat-composer-text-proof.test.js workflow entry. No test suite or native process ran on this VPS.

## Scope and delivery

A changelog.d/IGSH-760-composer-flicker.md file and .unlazy-hook-state.json appeared independently during this session; neither was authored, modified, removed or included in this change. All authored edits are under /home/valentin/projects/multiprompt-760 on ceo/IGSH-760. Final commit and scope inspection are recorded in G5 after committing.
