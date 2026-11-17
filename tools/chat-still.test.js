const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('chat source changes always run the stillness journey without an AI picker', () => {
  const workflow = read('.github/workflows/chat-still.yml');
  const trigger = workflow.slice(workflow.indexOf('  pull_request:'), workflow.indexOf('  workflow_dispatch:'));
  for (const file of ['src/chat*', 'src/app_state.zig', 'src/main.zig', 'src/layout.zig', 'src/window_layout.zig', 'src/browser_pane.zig']) {
    assert.ok(trigger.includes(`- '${file}'`), `${file} must trigger the fixed stillness gate`);
  }
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
  assert.match(observer, /AssertPixels\(pixelBaseline, pixelCurrent\)/);
  assert.match(observer, /sample\["pixels_sha256"\]/);
  assert.match(observer, /sample\["pixel_rect"\]/);
  assert.equal((driver.match(/\.Start\(/g) || []).length, 1, 'one continuous first-frame baseline must cover idle and streaming');
  assert.match(read('tools/chat-still/observer.test.ps1'), /AssertPixels\(\$pixels, \$changed\)/);
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

test('the measurement probe belongs only to the verification build', () => {
  assert.doesNotMatch(read('src/chat_render.zig'), /fn chatStillFrame\(/);
  assert.doesNotMatch(read('tools/chat-still/paint.zig'), /app_state\.\w+\s*(?:=(?!=)|[+\-*\/]=)/, 'the probe must not mutate product state');
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /inputs\.feature == 'chat-still'[\s\S]*?python tools\/chat-still\/instrument\.py \./);
  assert.match(workflow, /python tools\/chat-still\/instrument\.py app-source/);
  assert.match(workflow, /evidence\/chat-still-instrumentation\.json/);
});
