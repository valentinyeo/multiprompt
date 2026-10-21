const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
assert.ok(root, 'usage: node tools/verify-reconnect/check-evidence.js EVIDENCE_ROOT');
function load(mode) {
  const dir = path.join(root, mode);
  const json = file => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
  const text = file => fs.readFileSync(path.join(dir, file), 'utf8');
  const summary = json('summary.json');
  assert.deepEqual(summary.map(s => s.case), ['A', 'F', 'B']);
  const provenance = json('provenance.json');
  const run = json('run.json');
  assert.equal(run.event, 'workflow_dispatch');
  assert.equal(run.headSha, provenance.revision);
  assert.equal(String(run.databaseId), provenance.run_id);
  assert.equal(run.url, provenance.run_url);
  assert.equal(provenance.exe_source, mode);
  assert.match(provenance.exe_sha256, /^[a-f0-9]{64}$/);
  assert.ok(!fs.existsSync(path.join(dir, 'error.txt')), 'infrastructure error is not a regression');
  const doctor = json('doctor.json');
  assert.ok([doctor.main, doctor.input_surface].includes(doctor.focus[0]));
  assert.ok(doctor.focus[1] === doctor.input_surface || doctor.focus[0] === doctor.input_surface);
  assert.equal(doctor.two_transports, true);
  assert.ok(json('layout-control.json').layout_positive_control > 0);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.evidence_preserved, true);
  const measured = (name, file, index) => {
    const log = text(`case-${name}.log`);
    const reposition = log.split('\n').filter(l => /\[reposition\]|posBrowser|posMasks/.test(l)).length;
    const focus = json(file);
    assert.ok(focus.samples.length > 1);
    const sampled = focus.samples.some(s => s.foreground !== focus.before[0] || s.focus !== focus.before[1]);
    const events = focus.events.filter(e => (e.ev === 3 && e.hwnd !== focus.before[0]) || (e.ev === 0x8005 && e.hwnd !== focus.before[1])).length;
    const changed = sampled || events > 0;
    let lost = 0;
    if (focus.typed !== '') {
      const added = focus.text.startsWith(focus.base_text) ? focus.text.slice(focus.base_text.length) : '';
      lost = added === focus.typed ? 0 : Math.max(1, focus.typed.length - added.length);
    }
    const s = summary[index];
    assert.equal(s.case, name);
    assert.equal(s.reposition_lines, reposition);
    assert.equal(s.focus_events, events);
    assert.equal(s.focus_changed, changed);
    assert.equal(s.typed_chars, focus.typed.length);
    assert.equal(s.typed_chars_lost, lost);
    assert.equal(s.reconnected, true);
    assert.match(log, /respawnShellInPlace ok kind=tmux idx=1 new_id=\d+/);
    assert.match(log, /ssh-reconnect ok id=\d+/);
    assert.equal(s.pass, reposition === 0 && !changed && lost === 0);
    return log;
  };
  const a = measured('A', 'focus.json', 0);
  const chat = json('doctor-F.json');
  assert.equal(chat.chat_view, true);
  assert.equal(chat.focus[0], chat.main);
  assert.equal(chat.focus[1], chat.composer);
  measured('F', 'focus-F.json', 1);
  assert.ok(summary[1].typed_chars > 0);
  const b = text('case-B.log');
  const gone = [...b.matchAll(/ssh-reconnect ended id=(\d+) reason=session-gone/g)];
  assert.equal(summary[2].session_gone_count, gone.length);
  const id = gone.length ? gone[0][1] : '\\d+';
  const attempts = [...text('after-gone.log').matchAll(new RegExp(`ssh-reconnect attempt=\\d+ id=${id}\\b`, 'g'))].length;
  assert.equal(summary[2].attempts_after_gone, attempts);
  assert.ok(summary[2].observed_seconds >= 60);
  assert.equal(summary[2].pass, gone.length === 1 && attempts === 0);
  for (const shot of ['before.png', 'case-A.png', 'before-F.png', 'case-F.png', 'case-B-session-ended.png', 'final.png']) {
    const png = fs.readFileSync(path.join(dir, shot));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 10000);
  }
  for (const action of ['A', 'F', 'B']) assert.ok(json(`action-${action}.json`).pid > 0);
  assert.ok(text('debug.log').length >= a.length);
  return { summary, run, provenance };
}
const green = load('build');
const red = load('v0.28.788');
assert.equal(green.run.conclusion, 'success');
assert.equal(red.run.conclusion, 'failure');
assert.equal(green.provenance.revision, red.provenance.revision, 'same harness revision required');
assert.equal(green.provenance.revision, require('node:child_process').execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim());
assert.ok(green.summary.every(s => s.pass));
assert.equal(red.summary[0].pass, false, 'released case A must catch the layout regression');
assert.ok(red.summary[0].reposition_lines > 0);
assert.ok(red.summary.slice(0, 2).some(s => s.focus_changed), 'released build must show a keyboard focus change');
for (const run of [green, red]) {
  console.log(run.run.url);
  for (const s of run.summary) console.log(`${s.pass ? 'PASS' : 'FAIL'} case=${s.case} reposition_lines=${s.reposition_lines} focus_changed=${s.focus_changed} focus_events=${s.focus_events} typed_chars_lost=${s.typed_chars_lost} session_gone_count=${s.session_gone_count} attempts_after_gone=${s.attempts_after_gone}`);
}
console.log('GitHub green/red evidence verified');
