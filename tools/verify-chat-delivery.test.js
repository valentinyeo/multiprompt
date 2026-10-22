const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { names, agentBoundary, evaluateDelivery, evaluateEvidence } = require('./verify-chat-delivery/check-evidence.js');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const drive = read('tools/verify-chat-delivery/drive.ps1');
const workflow = read('.github/workflows/verify.yml');

function gate(source) {
  const modern = source.match(/fn chatOutboxReadyToType\([^\n]+\) bool \{([\s\S]*?)\n\}/);
  let body = modern ? modern[1] : source.slice(source.indexOf('    const channel = chatTmuxSendEligible(shell_index);', source.indexOf('fn chatOutboxTrySendEntry(')), source.indexOf('    const echo_id =', source.indexOf('fn chatOutboxTrySendEntry(')));
  body = body.replace(/    const (?:channel|direct) = [^\n]+\n/g, '')
    .replaceAll('app_state.shells[shell_index].activity == .active', 'busy')
    .replaceAll('shell_index == app_state.active_shell and app_state.g_chat_screen_working', 'screen_working_here')
    .replaceAll('chatOutboxInputRowIdle(shell_index)', 'input_row_idle')
    .replaceAll('shell_index != app_state.active_shell', '!is_active_shell')
    .replaceAll(' and ', ' && ').replaceAll(' or ', ' || ');
  return new Function('channel', 'direct', 'busy', 'screen_working_here', 'input_row_idle', 'is_active_shell', body + '\nreturn true;');
}

test('811 rejects both channel scenarios while master and 821 admit them before local input gates', () => {
  const source = ref => execFileSync('git', ['show', `${ref}:src/chat_send.zig`], { cwd: root, encoding: 'utf8' });
  const old = source('v0.28.811');
  let master;
  let masterRef = 'master';
  try { master = source(masterRef); } catch { masterRef = 'origin/master'; master = source(masterRef); }
  for (const [ref, text] of [['v0.28.811', old], ['master', master], ['v0.28.821', source('v0.28.821')]]) {
    const ready = gate(text);
    assert.equal(ready(true, true, false, false, true, true), true, `${ref} blank idle positive control`);
    assert.equal(ready(true, true, true, true, true, true), ref !== 'v0.28.811', `${ref} busy channel`);
    assert.equal(ready(true, true, false, false, false, true), ref !== 'v0.28.811', `${ref} suggested input channel`);
    assert.equal(ready(false, true, false, false, false, true), false, `${ref} uncovered local suggestion gap`);
    assert.match(text, /\.op = "send"[\s\S]*chatHistoryPersistent\(job.key.host/);
    if (ref !== 'v0.28.811') assert.match(text, /"send_queued"/);
  }
  assert.match(master, /if \(entry.steer_pending\)|if \(!entry.steer_pending\)/);
  assert.match(master, /chatSteerAfterDelivery\(idx, i\)/);
  const reader = execFileSync('git', ['show', `${masterRef}:src/chat_history_reader.py`], { cwd: root, encoding: 'utf8' });
  assert.match(reader, /keys = \["C-x", "C-s"\] if op == "send_queued"/);
  assert.match(reader, /\["tmux", "send-keys", "-t", target, "-l", "--", text\]/);
  assert.match(reader, /\["tmux", "send-keys", "-t", target, "Enter"\]/);
});

function fixture(name = 'busy-send') {
  const observation = { name, text: 'typed public message', composerText: 'typed public message', actionMs: 1000, endMs: 16001, error: null };
  const args = [['send-keys', '-t', '=verify-agent:', '-l', '--', observation.text], ['send-keys', '-t', '=verify-agent:', 'Enter']];
  if (name === 'steer-chord') args.push(['send-keys', '-t', '=verify-agent:', 'C-x', 'C-s']);
  return { observation, events: args.map((argv, index) => ({ ms: 1100 + index, case: name, argv })) };
}

test('buffer oracle accepts exactly typed text, Enter and the ordered steer chord', () => {
  for (const name of names) {
    const { observation, events } = fixture(name);
    assert.equal(evaluateDelivery(observation, events).writes, name === 'steer-chord' ? 3 : 2);
  }
});

test('buffer oracle rejects busy waiting, suggestions, duplicates, missing Enter, premature chords and late delivery', () => {
  const mutations = [
    f => { f.events = []; },
    f => { f.events[0].argv[5] += ' grey suggestion'; },
    f => { f.events.push(f.events[1]); },
    f => { f.events.splice(1, 1); },
    f => { f.events.reverse(); },
    f => { f.events[0].ms = 16001; },
    f => { f.events[0].ms = 999; },
    f => { f.events[0].case = 'other'; },
    f => { f.observation.composerText = 'wrong'; },
    f => { f.observation.endMs = 15000; },
    f => { f.observation.error = 'launch failed'; },
  ];
  for (const mutate of mutations) {
    const control = fixture('steer-chord');
    evaluateDelivery(control.observation, control.events);
    mutate(control);
    assert.throws(() => evaluateDelivery(control.observation, control.events));
  }
});

test('missing evidence evaluates every case and never produces a false green', () => {
  const result = evaluateEvidence(path.join(root, 'tools/verify-chat-delivery/nonexistent-evidence'));
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.cases.map(row => row.name), names);
  assert.ok(result.cases.every(row => row.passed === false && row.detail));
  assert.equal(result.agentBoundary, agentBoundary);
});

test('boundary runs the actual supplied Python bootstrap and logs raw fake tmux writes without fabricating text', () => {
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundary, /shlex.split\(command\[python.start\(\):\]\)/);
  assert.match(boundary, /subprocess.call\(\[sys.executable, \*remote\[1:\]\], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer/);
  assert.match(boundary, /if ARGS\[:1\] == \["send-keys"\]:\s+record\("agent-buffer.jsonl", argv=ARGS\)/);
  assert.match(boundary, /if ARGS\[:1\] == \["capture-pane"\]/);
  assert.match(boundary, /esc to interrupt/);
  assert.match(boundary, /\\u276f/);
  assert.match(boundary, /FillConsoleOutputAttribute\(handle, 8, len\(value\["suggestion"\]\), COORD\(2, top \+ 4\)/);
  assert.doesNotMatch(boundary, /typed public message|busy delivery alpha|idle delivery beta|steer delivery gamma/);
  const launcher = read('tools/verify-chat-delivery/launcher.c');
  assert.match(launcher, /GetCommandLineW\(\)/);
  assert.match(launcher, /CreateProcessW\(python, command, NULL, NULL, TRUE/);
});

test('keyboard journey isolates each case and retains Doctor, screenshots, raw evidence and owned-job cleanup', () => {
  for (const name of names) assert.ok(drive.includes(`name='${name}'`));
  assert.match(drive, /foreach \(\$plan in \$plans\) \{[\s\S]*try \{[\s\S]*catch \{[\s\S]*finally \{/);
  for (const text of ['RUNNER_TEMP', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'ssh-path.txt', 'session.json', 'tmux_host=0', "tmux_session='verify-agent'", 'MPVERSION=', 'UIAutomation', 'Get-FileHash', 'GetForegroundWindow', '::Focus($main)', 'composerText', 'agent-buffer.jsonl', 'invocations.jsonl', 'debug.log', 'cleanup.json']) assert.ok(drive.includes(text), text);
  assert.match(drive, /Press @\(0x11, 0x31\)/);
  assert.match(drive, /Press @\(0x12, 0x43\)/);
  assert.match(drive, /Press @\(0x0D\)/);
  assert.match(drive, /Press @\(0x11, 0x58\)[\s\S]*Press @\(0x11, 0x53\)/);
  assert.match(drive, /actionMs \+ 15000/);
  assert.match(drive, /\$job.Start\([\s\S]*\$job.Stop\(\)[\s\S]*Copy-Item \$state[\s\S]*Remove-Item -LiteralPath \$profile/);
  assert.doesNotMatch(drive, /Stop-Process|taskkill|PostMessage|SetFocus|SetWindowText|::Click|::Activate|Invoke-Expression/);
  const job = read('tools/verify-chat-delivery/job.cs');
  const control = read(skill + 'control.ps1');
  const original = control.slice(control.indexOf('public sealed class VerifyJob : IDisposable {'), control.indexOf("\n'@", control.indexOf('public sealed class VerifyJob : IDisposable {'))).trim();
  assert.ok(job.endsWith(original + '\n'), 'same owned-job implementation as control.ps1');
  assert.match(job, /limits.Basic.Flags = 0x2000/);
  assert.ok(job.indexOf('AssignProcessToJobObject(job, native.Process)') < job.indexOf('ResumeThread(native.Thread)'));
  const desktop = read('tools/verify-chat-delivery/desktop.cs');
  assert.match(desktop, /SendInput\(\(uint\)inputs.Length/);
  assert.doesNotMatch(desktop, /WriteConsoleInput|WM_SETTEXT|PostMessage/);
});

test('feature dispatch compiles only the system boundary on release runs and preserves verified executable selection', () => {
  assert.match(workflow, /FEATURE -notin @\([^\n]*'chat-delivery'/);
  assert.match(read(skill + 'control.ps1'), /'chat-delivery' \{[\s\S]*verify-chat-delivery\/drive.ps1/);
  assert.match(workflow, /if: env.RELEASE_TAG == '' \|\| env.FEATURE == 'chat-delivery'/);
  assert.match(workflow, /zig cc[^\n]*-municode[^\n]*verify-chat-delivery\/launcher.c/);
  assert.match(workflow, /zig cc[^\n]*-mwindows[^\n]*verify-bin\/tmux.exe/);
  assert.match(workflow, /actions\/setup-python@[a-f0-9]{40}/);
  assert.match(workflow, /gh release download \$env:RELEASE_TAG/);
  assert.match(workflow, /Release checksum mismatch/);
  assert.match(workflow, /name: verify-\$\{\{ env.FEATURE \}\}/);
  assert.match(workflow, /verify-chat-delivery\/drive.ps1[\s\S]*errors.Count/);
  assert.ok(workflow.includes('- tools/verify-chat-delivery/**'));
});

test('delivery maps state both the accepted boundary and uncovered local console gap', () => {
  const map = read(skill + 'features/chat-delivery.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']);
  for (const name of names) assert.ok(map.includes(name));
  assert.match(map, /v0.28.811/);
  assert.match(map, /v0.28.821/);
  assert.match(map, /local direct-input[\s\S]*suggestion/);
  assert.match(read(skill + 'features/README.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
  assert.match(read(skill + 'SKILL.md'), /\[Chat delivery\]\(features\/chat-delivery.md\)/);
  assert.match(read(skill + 'features/chat-view.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
});

test('delivery implementation adds no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [file, language] of [
    ['tools/verify-chat-delivery.test.js', 'javascript'],
    ['tools/verify-chat-delivery/check-evidence.js', 'javascript'],
    ['tools/verify-chat-delivery/drive.ps1', 'powershell'],
    ['tools/verify-chat-delivery/launcher.c', 'c'],
    ['tools/verify-chat-delivery/desktop.cs', 'c'],
    ['tools/verify-chat-delivery/job.cs', 'c'],
  ]) assert.equal(strip(read(file), language).commentLines, 0, file);
  assert.doesNotMatch(read('tools/verify-chat-delivery/boundary.py'), /^\s*#/m);
});

test('full evidence oracle recomputes all cases and rejects corrupt screens, identity, actions and cleanup', t => {
  const files = new Map();
  const base = path.join(root, 'tools/verify-chat-delivery/in-memory-evidence');
  const put = (file, value) => files.set(path.join(base, file), JSON.stringify(value));
  const log = (file, rows) => files.set(path.join(base, file), rows.map(row => JSON.stringify(row)).join('\n'));
  const png = Buffer.alloc(15000);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  put('build.json', { version: '0.0.1', sha256: 'a'.repeat(64) });
  const actions = [];
  for (const name of names) {
    const { observation, events } = fixture(name);
    observation.mode = name === 'idle-suggestion' ? 'idle' : 'busy';
    observation.suggestion = 'Try the next step';
    put(`${name}/observation.json`, observation);
    log(`${name}/stand-in/agent-buffer.jsonl`, events);
    put(`${name}/stand-in/state.json`, { name, mode: observation.mode, suggestion: observation.suggestion });
    const shown = `Claude Code\n\n${observation.mode === 'busy' ? 'Working... (esc to interrupt)' : 'Ready'}\n\n❯ ${observation.mode === 'idle' ? observation.suggestion : ''}\n${'─'.repeat(50)}\n`;
    put(`${name}/stand-in/ready.json`, { screen: shown });
    log(`${name}/stand-in/console.jsonl`, [{ screen: shown, session: 'verify-agent', rows: shown.trimEnd().split('\n').map(line => line.trimEnd()), greySuggestion: observation.mode === 'idle', suggestionAttribute: observation.mode === 'idle' ? 8 : 7 }]);
    log(`${name}/stand-in/capture.jsonl`, [{ case: name, screen: shown }]);
    log(`${name}/stand-in/invocations.jsonl`, [
      { kind: 'attach', session: 'verify-agent' },
      { kind: 'reader', argv: ['python3', '-u', '-c', 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))', '--serve'] },
    ]);
    put(`${name}/doctor.json`, { version: '0.0.1', sha256: 'a'.repeat(64), pid: 1, hwnd: 2, composer: 3, focus: [2, 3], chat: true, tmux: true });
    put(`${name}/cleanup.json`, { remaining_owned_processes: 0, evidence_preserved: true, scratch_removed: true });
    put(`${name}/process-tree.json`, { ActiveProcesses: 0 });
    put(`${name}/session-chat.json`, { active_tab: 0, tabs: [{ kind: 'tmux', tmux_session: 'verify-agent', cv: true }] });
    files.set(path.join(base, name, 'debug.log'), 'app debug evidence');
    for (const suffix of ['before', 'action', 'after', 'final']) files.set(path.join(base, `${name}-${suffix}.png`), png);
    for (const input of ['Ctrl+1: select saved tmux tab', 'Alt+C: open Chat View', 'type composer text', ...(name === 'steer-chord' ? ['Ctrl+X: steer prefix', 'Ctrl+S: steer send'] : ['Enter: send composer'])]) actions.push({ case: name, input, text: observation.text });
  }
  put('actions.json', actions);
  files.set(path.join(base, 'before.png'), png);
  files.set(path.join(base, 'after.png'), png);
  t.mock.method(fs, 'existsSync', file => files.has(String(file)));
  t.mock.method(fs, 'readFileSync', (file, encoding) => {
    if (!files.has(String(file))) throw new Error(`Missing fixture ${file}`);
    const value = files.get(String(file));
    return encoding && Buffer.isBuffer(value) ? value.toString(encoding) : value;
  });
  assert.equal(evaluateEvidence(base).status, 'passed');
  const positive = new Map(files);
  const mutations = [
    () => log('busy-send/stand-in/agent-buffer.jsonl', []),
    () => log('idle-suggestion/stand-in/capture.jsonl', [{ case: 'idle-suggestion', screen: '❯ blank' }]),
    () => put('idle-suggestion/stand-in/state.json', { name: 'idle-suggestion', mode: 'idle', suggestion: '' }),
    () => put('steer-chord/cleanup.json', { remaining_owned_processes: 1, evidence_preserved: true, scratch_removed: true }),
    () => put('steer-chord/doctor.json', { version: 'wrong' }),
    () => put('busy-send/session-chat.json', { active_tab: 1 }),
    () => files.set(path.join(base, 'busy-send-after.png'), Buffer.alloc(15000)),
    () => put('actions.json', actions.filter(row => row.input !== 'Ctrl+S: steer send')),
    () => log('busy-send/stand-in/unsupported.jsonl', [{ operation: 'ignored' }]),
    () => log('idle-suggestion/stand-in/console.jsonl', [{ screen: '❯ without suggestion', session: 'verify-agent', greySuggestion: true }]),
  ];
  for (const mutate of mutations) {
    files.clear();
    for (const [file, value] of positive) files.set(file, value);
    assert.equal(evaluateEvidence(base).status, 'passed');
    mutate();
    const result = evaluateEvidence(base);
    assert.equal(result.status, 'failed');
    assert.equal(result.cases.length, 3);
    assert.equal(result.cases.filter(row => !row.passed).length, 1);
  }
});
