const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const read = file => {
  const full = path.join(__dirname, '..', file);
  assert.ok(fs.existsSync(full), `The stillness gate requires ${file}`);
  return fs.readFileSync(full, 'utf8');
};

test('chat source changes always run the stillness journey without an AI picker', () => {
  const map = read('.claude/skills/verify-multiprompt/features/chat-still.md');
  const owned = map.match(/^Source files: (.+)$/m)[1].split(', ');
  for (const file of ['src/chat*', 'src/app_state.zig', 'src/main.zig', 'src/layout.zig', 'src/window_layout.zig', 'src/browser_pane.zig']) {
    assert.ok(owned.includes(file), `${file} must select the stillness journey in the PR verifier`);
  }
  assert.match(map, /^Verify on: pull_request$/m, 'the stillness journey must stay selected for chat source pull requests');
  const workflow = read('.github/workflows/chat-still.yml');
  assert.match(workflow, /^  schedule:\n    - cron: '0 5 \* \* \*'$/m, 'the full stillness drive runs nightly');
  assert.match(workflow, /^  workflow_dispatch:$/m);
  const desktop = workflow.slice(workflow.indexOf('  desktop:'), workflow.indexOf('  comment-review:'));
  assert.match(desktop, /uses: \.\/\.github\/workflows\/verify\.yml/);
  assert.match(desktop, /feature: chat-still/);
  assert.doesNotMatch(desktop, /\bif:|\bneeds:|picker|selection/);
});

test('stillness checks real pixels on display frames, not only paint logs', () => {
  const observer = read('tools/chat-still/observer.cs');
  const driver = read('.claude/skills/verify-multiprompt/control-feature-chat-still.ps1');
  assert.match(observer, /CopyFromScreen\(/);
  assert.match(observer, /if \(kind == "display-frame"\) CapturePixels\(/);
  assert.match(observer, /AssertPixels\(pixelBaseline, pixelCurrent, pixelImage\.Width, pixelRect, overlay\)/);
  assert.match(observer, /sample\["pixels_sha256"\]/);
  assert.match(observer, /sample\["pixel_rect"\]/);
  assert.equal((driver.match(/\.Start\(/g) || []).length, 1, 'one continuous first-frame baseline must cover idle and streaming');
  assert.match(read('tools/chat-still/observer.test.ps1'), /AssertPixels\(\$pixels, \$changed/);
});

test('the pixel oracle masks only the floating new-message pill the app declares', () => {
  const observer = read('tools/chat-still/observer.cs');
  assert.match(observer, /new messages count=\(\\d\+\) visible=\(\\d\+\) up=\(\\d\+\) rect=/, 'the oracle reads the app\'s own pill rectangle');
  assert.match(observer, /public static void AssertPixels\(byte\[\] baseline, byte\[\] current, int width, int\[\] crop, int\[\] overlay\)/);
  assert.match(observer, /if \(x < overlay\[0\] \|\| x >= overlay\[2\] \|\| y < overlay\[1\] \|\| y >= overlay\[3\]\) throw/, 'a change outside the declared pill still fails');
  const test_driver = read('tools/chat-still/observer.test.ps1');
  assert.match(test_driver, /declared pill/, 'the observer test proves both sides of the pill mask');
  assert.match(read('.claude/skills/verify-multiprompt/features/chat-still.md'), /new-message pill/, 'the journey records why the pill is outside the message');
});

test('comment review rejects an unfinished or merely launched Comment Sicko', t => {
  const workflow = read('.github/workflows/chat-still.yml');
  const script = workflow.split("          python3 - <<'PYTHON'\n")[1].split('          PYTHON')[0].replace(/^ {10}/gm, '');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-still-comments-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const execution = path.join(dir, 'execution.json');
  const report = { completed_review: true, deletion_count: 0, restored_comments: 0, must_kill: [], report: 'Completed review; no findings.' };
  for (const [name, background, toolError, complete, expected] of [
    ['completed foreground review', false, false, true, 0],
    ['background launch is not a review', true, false, true, 1],
    ['failed reviewer', false, true, true, 1],
    ['incomplete report', false, false, false, 1],
    ['original missing completion field', false, false, undefined, 1],
  ]) {
    fs.writeFileSync(execution, JSON.stringify([
      { type: 'tool_use', id: 'review', name: 'Agent', input: { subagent_type: 'pstack:comment-sicko', run_in_background: background } },
      { type: 'tool_result', tool_use_id: 'review', is_error: toolError, content: background ? 'Async agent launched successfully' : 'Review completed; no findings.' },
    ]));
    const result = spawnSync(process.platform === 'win32' ? 'python' : 'python3', ['-c', script], {
      cwd: dir,
      env: { ...process.env, EXECUTION: execution, REVIEW: JSON.stringify({ ...report, completed_review: complete }) },
      encoding: 'utf8',
    });
    assert.equal(result.status, expected, `${name}\n${result.stderr}`);
  }
});

test('both formal CI gates compare against the event baseline after mutations and replay', () => {
  for (const name of ['test.yml', 'chat-still.yml']) {
    const workflow = read(`.github/workflows/${name}`);
    assert.match(workflow, /CHAT_STILL_BASE: \$\{\{ github\.event\.pull_request\.base\.sha/);
    assert.match(workflow, /github\.event_name == 'workflow_dispatch' && 'origin\/master'/, 'manual checks compare with the unchanged master baseline');
    assert.match(workflow, /tools\/verify-chat-still --self-test --replay --inherit-from "\$CHAT_STILL_BASE"/);
  }
});

test('formal findings inherit only when the base source reports the same findings', { skip: process.platform === 'win32' }, t => {
  read('tools/chat-still/verify.py');
  const root = path.join(__dirname, '..');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-still-inherited-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'zig'), '#!/bin/sh\nexit 7\n', { mode: 0o755 });
  for (const variant of ['changed', 'drift', 'unrelated']) {
    copyZig(['src/chat_session.zig', 'src/chat_history.zig'], path.join(dir, variant), root);
  }
  const session = path.join(dir, 'changed/src/chat_session.zig');
  fs.writeFileSync(session, fs.readFileSync(session, 'utf8').replace(
    'if (old_content_h <= viewport_h) null else if (anchor_top)', 'if (old_content_h >= 0) null else if (anchor_top)'));
  const history = path.join(dir, 'drift/src/chat_history.zig');
  fs.writeFileSync(history, fs.readFileSync(history, 'utf8').replace('pub fn scrollAnchor(', 'pub fn renamedScrollAnchor('));
  const unrelated = path.join(dir, 'unrelated/src/chat_session.zig');
  fs.writeFileSync(unrelated, fs.readFileSync(unrelated, 'utf8') + '\npub fn chatStillProbe() void {}\n');
  for (const [name, args, expected] of [
    ['raw findings remain failures', [], 1],
    ['unchanged source is inherited', ['--inherit-from', 'HEAD'], 0],
    ['changed source is not inherited', ['--inherit-from', 'HEAD', '--source-root', path.join(dir, 'changed')], 1],
    ['source that keeps every finding is inherited', ['--inherit-from', 'HEAD', '--source-root', path.join(dir, 'unrelated')], 0],
    ['model drift still fails', ['--inherit-from', 'HEAD', '--source-root', path.join(dir, 'drift')], 2],
    ['replay errors cannot inherit', ['--inherit-from', 'HEAD', '--replay'], 2],
    ['missing baseline still fails', ['--inherit-from', 'refs/heads/nonexistent-chat-still-test'], 2],
  ]) {
    const output = path.join(dir, 'report.json');
    fs.rmSync(output, { force: true });
    const result = spawnSync('bash', ['tools/verify-chat-still', ...args, '--output', output], {
      cwd: root, encoding: 'utf8', timeout: 60000,
      env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}` },
    });
    assert.equal(result.status, expected, `${name}\n${result.stdout}\n${result.stderr}`);
    if (expected < 2) {
      const report = JSON.parse(fs.readFileSync(output, 'utf8'));
      assert.ok(report.failures.length > 0 && report.counterexamples.length > 0, name);
      assert.equal(Boolean(report.inherited_from), expected === 0, name);
    }
  }
});

test('local Claude detection waits cover the production polling and coalescing interval', () => {
  const power = read('src/power.zig');
  const intervals = [...power.matchAll(/TIMER_NAME_POLL, ([\d_]+)\)/g)].map(match => Number(match[1].replaceAll('_', '')));
  assert.ok(intervals.length > 0);
  const divisor = Number(power.match(/interval_ms \/ (\d+)/)[1]);
  const latestPoll = Math.max(...intervals.map(ms => ms + Math.max(32, Math.floor(ms / divisor))));
  const journey = read('.claude/skills/verify-multiprompt/control-feature-chat-view.ps1');
  const configured = Number(journey.match(/\$agentDetectionSeconds\s*=\s*(\d+)/)?.[1]);
  const waits = [...journey.matchAll(/\}\s+'[^']*claude\.exe detected as Claude[^']*'\s+-Seconds (\d+|\$agentDetectionSeconds)/g)];
  assert.equal(waits.length, 2);
  for (const [, value] of waits) {
    const seconds = value.startsWith('$') ? configured : Number(value);
    assert.ok(seconds * 1000 > latestPoll, `${seconds}s cannot cover the ${latestPoll}ms production poll window`);
  }
});

test('the measurement probe belongs only to the verification build', () => {
  assert.doesNotMatch(read('src/chat_render.zig'), /fn chatStillFrame\(/);
  assert.doesNotMatch(read('tools/chat-still/paint.zig'), /app_state\.\w+\s*(?:=(?!=)|[+\-*\/]=)/, 'the probe must not mutate product state');
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /matrix\.profile == 'chat-still'\n        run: python \$\{\{ inputs\.app_revision && 'probe-source\/' \|\| '' \}\}tools\/chat-still\/instrument\.py \./);
  assert.match(workflow, /matrix\.profile == 'chat-still' && inputs\.app_revision != ''[\s\S]*?ref: \$\{\{ inputs\.revision \|\| github\.sha \}\}\n          path: probe-source/);
  assert.match(workflow, /evidence\/chat-still-instrumentation\.json/);
});
