const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const modes = ['plan', 'manual', 'acceptEdits', 'bypassPermissions'];
const json = (dir, file) => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8').replace(/^\uFEFF/, ''));
const lines = (dir, file) => fs.readFileSync(path.join(dir, file), 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));

function screenshot(dir, name) {
  assert.match(name, /^[a-z0-9-]+\.png$/i);
  const png = fs.readFileSync(path.join(dir, name));
  assert.ok(png.length > 24 && png.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), name);
  assert.ok(png.readUInt32BE(16) > 0 && png.readUInt32BE(20) > 0, name);
  const doctor = json(dir, 'doctor.json');
  assert.ok(Number.isInteger(doctor.pid) && doctor.pid > 0);
  assert.match(doctor.sha256, /^[a-f0-9]{64}$/i);
  assert.ok(doctor.version && doctor.hwnd);
  const tree = json(dir, name.replace(/\.png$/, '.uia.json'));
  assert.ok(tree.length > 0 && tree.every(node => node.pid === doctor.pid), 'screenshot belongs to the verified app');
}

function permissionEvidence(dir) {
  const proof = json(dir, 'permission-inputs.json');
  const raw = fs.readFileSync(path.join(dir, 'stub-keys.txt'), 'utf8');
  assert.ok(Number.isInteger(proof.keyOffset) && proof.keyOffset >= 0 && proof.keyOffset <= raw.length);
  assert.equal(raw.slice(proof.keyOffset), '124124124124', 'independent console choices');
  assert.equal(proof.providerDigits, '124124124124');
  assert.equal(proof.inputs.length, 12);
  const events = fs.readFileSync(path.join(dir, 'stub-events.txt'), 'utf8');
  assert.ok(Number.isInteger(proof.keyDownOffset) && proof.keyDownOffset >= 0);
  assert.equal((events.match(/KEY .*down=1/g) || []).length - proof.keyDownOffset, 12, 'one keydown per answer');
  for (const [index, row] of proof.inputs.entries()) {
    const entry = ['click', 'key', 'alt', 'palette'][Math.floor(index / 3)];
    assert.equal(row.entry, entry);
    assert.equal(row.choice, index % 3);
    assert.equal(row.digit, ['1', '2', '4'][index % 3]);
    assert.equal(row.received, '124124124124'.slice(0, index + 1));
    assert.equal(row.draft, entry === 'key' ? '' : 'Keep this draft');
    assert.equal(row.screenshot, `${entry}-${index % 3 + 1}-picked.png`);
    screenshot(dir, row.screenshot);
  }
}

function modeEvidence(dir) {
  const inputs = json(dir, 'mode-inputs.json');
  const controls = lines(dir, 'slash-control.jsonl');
  const replies = lines(dir, 'slash-replies.jsonl').filter(row => row.op === 'set_permission_mode');
  const seed = json(dir, 'seed-session.json');
  const sid = seed.tabs.find(tab => tab.tmux_session === 'live-slash')?.csid;
  assert.ok(sid, 'originating chat has a saved identity');
  assert.equal(inputs.length, 12);
  assert.equal(controls.length, 12, 'one received control per choice');
  assert.equal(replies.length, 12, 'one acknowledgement per choice');
  for (const [index, row] of inputs.entries()) {
    const entry = ['slash', 'palette', 'plus'][Math.floor(index / 4)];
    const mode = modes[index % 4];
    assert.equal(row.entry, entry);
    assert.equal(row.mode, mode);
    assert.equal(row.receipt, index + 1);
    assert.equal(row.draft, entry === 'slash' ? '' : 'Keep this mode draft');
    assert.equal(row.screenshot, `mode-${entry}-${mode}-received.png`);
    assert.equal(controls[index].sid, sid, 'control targets the originating chat');
    assert.deepEqual(controls[index].request, { subtype: 'set_permission_mode', mode });
    assert.equal(replies[index].sid, sid);
    assert.equal(replies[index].reply.status, 'ok');
    screenshot(dir, row.screenshot);
  }
  assert.equal(json(dir, 'slash-mode.json').mode, 'bypassPermissions');
  screenshot(dir, 'mode-plus-cancel.png');
}

function stopEvidence(dir) {
  const inputs = json(dir, 'stop-inputs.json');
  const raw = fs.readFileSync(path.join(dir, 'stop-stdin.bin'));
  assert.deepEqual([...raw], [27, 27, 27], 'only three Stop inputs reach the receiving console');
  assert.equal(inputs.length, 3);
  for (const [index, row] of inputs.entries()) {
    const entry = ['escape', 'click', 'palette'][index];
    assert.equal(row.entry, entry);
    assert.equal(row.before, index);
    assert.equal(row.after, index + 1);
    assert.equal(row.draftBefore, ['x', '', 'Keep stop draft'][index]);
    assert.equal(row.draftAfter, row.draftBefore, 'Stop preserves the unsent draft');
    assert.equal(row.screenshot, `stop-${entry}-received.png`);
    screenshot(dir, row.screenshot);
  }
}

const checks = { '--permission-evidence': permissionEvidence, '--mode-evidence': modeEvidence, '--stop-evidence': stopEvidence };
if (process.argv[2]) {
  assert.ok(checks[process.argv[2]] && process.argv.length === 4, 'expected evidence mode and directory');
  checks[process.argv[2]](process.argv[3]);
  console.log('CHAT_CONTROL_EVIDENCE_OK');
} else {
  const driver = file => fs.readFileSync(path.join(__dirname, file), 'utf8');
  test('permission journey drives mouse, numbers, Alt and palette through the receiving console', () => {
    const text = driver('permission-rows.ps1');
    assert.match(text, /foreach \(\$entry in @\('click', 'key', 'alt', 'palette'\)\)/);
    assert.match(text, /Press @\(0x12, \$case.alt\)/);
    assert.match(text, /Invoke-JourneyCommand \$case.command/);
    assert.match(text, /--permission-evidence \$Evidence/);
    assert.match(text, /keyDownOffset=\$permissionKeyDowns/);
  });
  test('mode journey drives four modes through slash, global palette and Plus with receipts', () => {
    const text = driver('chat-slash.ps1');
    assert.match(text, /controls.Count -ne 12/);
    assert.match(text, /bypassPermissions/);
    assert.match(text, /FindWindowEx\(\$script:window, \[IntPtr\]::Zero, 'MultiPromptPlusMenu'/);
    assert.match(text, /Press @\(0x26\)/);
    assert.match(text, /Wait-SlashMode \$choice.mode 'Keep this mode draft' 'palette'/);
    assert.match(text, /Wait-SlashMode \$choice.mode 'Keep this mode draft' 'plus'/);
    assert.match(text, /--mode-evidence \$Evidence/);
  });
  test('Stop journey requires exact receiving bytes for Escape, button and palette', () => {
    const text = driver('control-feature-chat-view.ps1');
    assert.match(text, /foreach \(\$entry in @\('click', 'palette'\)\)/);
    assert.match(text, /Invoke-JourneyCommand 'Chat View: Stop the agent'/);
    assert.match(text, /\$stopBytes.Length -eq \$stopBefore \+ 1 -and \$stopBytes\[\$stopBefore\] -eq 0x1B/);
    assert.match(text, /--stop-evidence \$Evidence/);
    assert.ok(text.indexOf('--stop-evidence') < text.indexOf('$stopCheck.sendClicked'), 'record Stop bytes before the separate Send action');
  });
  test('all new global commands resolve through the public journey command catalog', () => {
    const run = spawnSync(process.execPath, ['tools/journey-commands.mjs'], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stderr);
    const catalog = JSON.parse(run.stdout);
    for (const name of ['Chat permission mode: Plan', 'Chat permission mode: Ask', 'Chat permission mode: Accept edits', 'Chat permission mode: Bypass', 'Chat View: Plus Menu', 'Chat View: Allow', 'Chat View: Always allow', 'Chat View: Deny', 'Chat View: Stop the agent']) {
      assert.ok(Number.isInteger(catalog[name.toLowerCase()]?.target), name);
    }
    const palette = fs.readFileSync('src/command_palette.zig', 'utf8');
    for (const name of ['Chat View: Allow', 'Chat View: Always allow', 'Chat View: Deny']) {
      const label = palette.match(new RegExp(`asciiContainsQueryInsensitive\\("(${name})"`))?.[1];
      assert.ok(label, name);
      assert.ok(label.toLowerCase().includes(catalog[name.toLowerCase()].query.toLowerCase()), `${name} query reaches its actual result-insertion condition`);
    }
  });

  function fixture(run) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-control-proof-'));
    const write = (file, data) => fs.writeFileSync(path.join(dir, file), typeof data === 'string' || Buffer.isBuffer(data) ? data : JSON.stringify(data));
    const image = name => {
      const png = Buffer.alloc(25);
      Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
      png.writeUInt32BE(640, 16);
      png.writeUInt32BE(480, 20);
      write(name, png);
      write(name.replace('.png', '.uia.json'), [{ pid: 42, class: 'Edit' }]);
    };
    write('doctor.json', { pid: 42, hwnd: 1234, sha256: 'a'.repeat(64), version: 'test' });
    try { run(dir, write, image); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  test('permission evidence rejects missing routes, duplicate receipts and changed drafts', () => fixture((dir, write, image) => {
    const proof = { keyOffset: 2, keyDownOffset: 1, providerDigits: '124124124124', inputs: [] };
    for (let index = 0; index < 12; index++) {
      const entry = ['click', 'key', 'alt', 'palette'][Math.floor(index / 3)];
      const screenshot = `${entry}-${index % 3 + 1}-picked.png`;
      proof.inputs.push({ entry, choice: index % 3, digit: ['1', '2', '4'][index % 3], received: '124124124124'.slice(0, index + 1), draft: entry === 'key' ? '' : 'Keep this draft', screenshot });
      image(screenshot);
    }
    write('stub-keys.txt', 'xx124124124124');
    write('stub-events.txt', 'KEY down=1\n'.repeat(13));
    write('permission-inputs.json', proof);
    permissionEvidence(dir);
    proof.inputs[9].draft = '';
    write('permission-inputs.json', proof);
    assert.throws(() => permissionEvidence(dir), assert.AssertionError);
    proof.inputs[9].draft = 'Keep this draft';
    write('permission-inputs.json', proof);
    write('stub-keys.txt', 'xx1241241241244');
    assert.throws(() => permissionEvidence(dir), assert.AssertionError);
    write('stub-keys.txt', 'xx124124124124');
    proof.inputs.pop();
    write('permission-inputs.json', proof);
    assert.throws(() => permissionEvidence(dir), assert.AssertionError);
  }));
  test('mode evidence rejects wrong chat, failed acknowledgements, missing Plus and draft loss', () => fixture((dir, write, image) => {
    const inputs = [], controls = [], replies = [];
    for (let index = 0; index < 12; index++) {
      const entry = ['slash', 'palette', 'plus'][Math.floor(index / 4)], mode = modes[index % 4];
      const screenshot = `mode-${entry}-${mode}-received.png`;
      inputs.push({ entry, mode, receipt: index + 1, draft: entry === 'slash' ? '' : 'Keep this mode draft', screenshot });
      controls.push({ sid: 'origin', request: { subtype: 'set_permission_mode', mode } });
      replies.push({ sid: 'origin', op: 'set_permission_mode', reply: { status: 'ok' } });
      image(screenshot);
    }
    const save = () => {
      write('mode-inputs.json', inputs);
      write('slash-control.jsonl', controls.map(row => JSON.stringify(row)).join('\n'));
      write('slash-replies.jsonl', replies.map(row => JSON.stringify(row)).join('\n'));
    };
    write('seed-session.json', { tabs: [{ tmux_session: 'live-slash', csid: 'origin' }] });
    write('slash-mode.json', { mode: 'bypassPermissions' });
    image('mode-plus-cancel.png');
    save();
    modeEvidence(dir);
    controls[4].sid = 'neighbor'; save();
    assert.throws(() => modeEvidence(dir), assert.AssertionError);
    controls[4].sid = 'origin'; replies[8].reply.status = 'refused'; save();
    assert.throws(() => modeEvidence(dir), assert.AssertionError);
    replies[8].reply.status = 'ok'; inputs[8].draft = ''; save();
    assert.throws(() => modeEvidence(dir), assert.AssertionError);
    inputs[8].draft = 'Keep this mode draft'; inputs.pop(); save();
    assert.throws(() => modeEvidence(dir), assert.AssertionError);
  }));
  test('Stop evidence rejects double delivery, draft loss and screenshots from another process', () => fixture((dir, write, image) => {
    const inputs = ['escape', 'click', 'palette'].map((entry, index) => ({ entry, before: index, after: index + 1, draftBefore: ['x', '', 'Keep stop draft'][index], draftAfter: ['x', '', 'Keep stop draft'][index], screenshot: `stop-${entry}-received.png` }));
    for (const row of inputs) image(row.screenshot);
    write('stop-inputs.json', inputs);
    write('stop-stdin.bin', Buffer.from([27, 27, 27]));
    stopEvidence(dir);
    write('stop-stdin.bin', Buffer.from([27, 27, 27, 27]));
    assert.throws(() => stopEvidence(dir), assert.AssertionError);
    write('stop-stdin.bin', Buffer.from([27, 27, 27]));
    inputs[2].draftAfter = ''; write('stop-inputs.json', inputs);
    assert.throws(() => stopEvidence(dir), assert.AssertionError);
    inputs[2].draftAfter = inputs[2].draftBefore; write('stop-inputs.json', inputs);
    write('stop-palette-received.uia.json', [{ pid: 99 }]);
    assert.throws(() => stopEvidence(dir), assert.AssertionError);
  }));
}
