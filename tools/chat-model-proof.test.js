const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
assert.ok(fs.existsSync(path.join(__dirname, 'chat-model-proof.cjs')), 'model proof checker is available');
const { verify } = require('./chat-model-proof.cjs');
const source = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'model-proof-'));
  const dir = path.join(root, 'model-settings');
  fs.mkdirSync(dir);
  const write = (file, value) => fs.writeFileSync(path.join(dir, file), typeof value === 'string' ? value : JSON.stringify(value));
  write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
  write('observation.json', { error: null, draft: 'model draft retained' });
  write('doctor.json', { pid: 1, hwnd: 1, chat: true, sha256: 'a'.repeat(64) });
  const expected = ['model_haiku', 'effort_high', 'mode_ask'];
  const rows = ['model_opus', 'model_sonnet', 'model_haiku', 'effort_low', 'effort_medium', 'effort_high', 'mode_ask', 'mode_edits'].map(item => ({ item, accent: expected.includes(item) ? 40 : 0, mark: 0 }));
  write('plus-active.json', { rows, expected_active: expected, failures: [] });
  write('before-history.txt', 'start the fake session\nThe fake session is ready.');
  write('after-history.txt', 'start the fake session\nThe fake session is ready.');
  write('saved-settings.json', { model: 'fable' });
  write('config-initial.json', { enabled: true });
  write('argv-initial.jsonl', JSON.stringify({ argv: ['--model', 'opus', '--effort', 'medium'], saved_model: 'fable', aliases: {} }) + '\n');
  const defaults = ['model_opus', 'effort_medium'];
  write('plus-default.json', { expected_active: defaults, failures: [], rows: ['model_opus', 'model_fable', 'effort_medium', 'effort_low'].map(item => ({ item, mark: 0, accent: defaults.includes(item) ? 40 : 0 })) });
  for (const [name, text, amber] of [['fable', 'Fable 5.2 · medium', true], ['opus', 'Opus 5.5 · medium', false]]) {
    write(`header-${name}.json`, { text, amber, rect: [400, 30, 540, 48], titleBottom: 31, ink: 40, hand: true, pickerOpened: true });
  }
  const actions = [{ input: 'click header model', text: 'Fable 5.2 · medium' }, { input: 'click header model', text: 'Opus 5.5 · medium' }, { input: 'Enter: send with the default model' }];
  let hostLog = '';
  let argvLog = '';
  fs.mkdirSync(path.join(dir, 'host'));
  fs.mkdirSync(path.join(dir, 'stand-in'));
  write('stand-in/model-reader.jsonl', JSON.stringify({ inner_sha256: 'a'.repeat(64) }) + '\n');
  for (const [name, item, effort] of [['haiku', 'model_haiku', 'default'], ['low', 'effort_low', 'low'], ['medium', 'effort_medium', 'medium'], ['high', 'effort_high', 'high']]) {
    actions.push({ input: 'choose plus menu row', text: item });
    write(`config-${name}.json`, { enabled: true, model: 'haiku', ...(effort === 'default' ? {} : { effort }) });
    hostLog += JSON.stringify({ event: 'model_effort_settings_applied', detail: { model: 'haiku', effort } }) + '\n';
    argvLog += JSON.stringify({ argv: ['--model', 'haiku', '--effort', effort === 'default' ? 'medium' : effort] }) + '\n';
    write(`host-${name}.jsonl`, hostLog);
    write(`argv-${name}.jsonl`, argvLog);
  }
  write('host/host.events.log', hostLog);
  write('stand-in/model-argv.jsonl', argvLog);
  fs.writeFileSync(path.join(root, 'actions.json'), JSON.stringify(actions));
  const png = Buffer.alloc(1024);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  for (const name of ['model-before', 'model-after', 'model-plus-menu-active', 'model-default-menu', 'model-header-fable', 'model-header-fable-picker', 'model-header-opus', 'model-header-opus-picker', ...['haiku', 'low', 'medium', 'high'].flatMap(choice => [`model-plus-${choice}`, `model-after-${choice}`])]) fs.writeFileSync(path.join(root, `${name}.png`), png);
  return { root, dir, write };
}

test('remapped desktop drivers keep the selected journey artifact identity', () => {
  const workflow = source('.github/workflows/verify.yml');
  const upload = workflow.slice(workflow.indexOf('name: verify-${{'));
  assert.match(upload, /^name: verify-\$\{\{ matrix\.feature \}\}/);
  assert.doesNotMatch(upload.split('\n')[0], /env\.FEATURE/);
});

test('fixture launches the embedded production host and adapts Windows pipes only when opted in', () => {
  const boundary = source('tools/verify-chat-delivery/boundary.py');
  const adapter = source('tools/verify-chat-delivery/sitecustomize.py');
  const agent = source('tools/verify-chat-delivery/model-agent.py');
  assert.match(boundary, /namespace\["host_start"\]\("claude", sid, namespace\["READER_SOURCE"\]\)/);
  assert.match(boundary, /model-agent\.py/);
  assert.match(adapter, /os\.environ\.get\("CHAT_MODEL_PROOF"\) == "1"/);
  assert.match(adapter, /PeekNamedPipe/);
  assert.match(adapter, /msvcrt\.get_osfhandle/);
  assert.match(adapter, /select\.select/);
  assert.match(adapter, /get_last_error\(\) == 109/);
  assert.doesNotMatch(agent, /model_effort_settings_applied/);
});

test('synthetic agent runs and records its selected model and effort', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'model-agent-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const transcript = path.join(root, 'history.jsonl');
  fs.writeFileSync(path.join(root, 'state.json'), JSON.stringify({ transcript }));
  const argv = ['--session-id', 'a1b2c3d4-0682-4000-8000-000000000682', '--model', 'haiku', '--effort', 'high'];
  const { spawnSync } = require('node:child_process');
  const result = spawnSync('python3', [path.join(__dirname, 'verify-chat-delivery/model-agent.py'), ...argv], {
    input: JSON.stringify({ type: 'user', message: { content: 'fixture input' } }) + '\n',
    env: { ...process.env, MP_VERIFY_STATE: root }, encoding: 'utf8', timeout: 10000,
  });
  assert.equal(result.status, 0, result.stderr);
  const events = result.stdout.trim().split(/\r?\n/).map(JSON.parse);
  assert.equal(events[0].model, 'haiku');
  assert.equal(events.at(-1).type, 'result');
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'model-argv.jsonl'), 'utf8')).argv, argv);
  assert.equal(fs.readFileSync(transcript, 'utf8').trim().split(/\r?\n/).length, 2);
});

test('rejects inherited Fable, missing header clicks and a wrongly highlighted default', t => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const initial = fs.readFileSync(path.join(f.dir, 'argv-initial.jsonl'), 'utf8');
  f.write('argv-initial.jsonl', initial.replace('"opus"', '"fable"'));
  assert.throws(() => verify(f.root));
  f.write('argv-initial.jsonl', initial);
  const header = JSON.parse(fs.readFileSync(path.join(f.dir, 'header-fable.json'), 'utf8'));
  for (const wrong of [{ ...header, hand: false }, { ...header, pickerOpened: false }, { ...header, amber: false }, { ...header, ink: 0 }, { ...header, text: 'Opus 5.5 · medium' }]) {
    f.write('header-fable.json', wrong);
    assert.throws(() => verify(f.root));
  }
  f.write('header-fable.json', header);
  const menu = JSON.parse(fs.readFileSync(path.join(f.dir, 'plus-default.json'), 'utf8'));
  menu.rows.find(row => row.item === 'model_fable').accent = 40;
  f.write('plus-default.json', menu);
  assert.throws(() => verify(f.root));
});

test('requires independent settings, process flags, host log, history and cleanup', t => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  assert.deepEqual(verify(f.root).efforts, ['low', 'medium', 'high']);
  f.write('host-medium.jsonl', JSON.stringify({ event: 'init', detail: {} }) + '\n');
  assert.throws(() => verify(f.root));
});

test('rejects a wrong launched effort and missing history', t => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const original = fs.readFileSync(path.join(f.dir, 'stand-in/model-argv.jsonl'), 'utf8');
  const wrong = original.replace('"--effort","high"', '"--effort","low"');
  f.write('argv-high.jsonl', wrong);
  f.write('stand-in/model-argv.jsonl', wrong);
  assert.throws(() => verify(f.root));
  f.write('argv-high.jsonl', original);
  f.write('stand-in/model-argv.jsonl', original);
  f.write('after-history.txt', 'missing');
  assert.throws(() => verify(f.root));
});

test('rejects a plus menu that keeps a check mark or loses the active style', t => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const good = JSON.parse(fs.readFileSync(path.join(f.dir, 'plus-active.json'), 'utf8'));
  const marked = structuredClone(good);
  marked.rows.find(row => row.item === 'model_haiku').mark = 12;
  f.write('plus-active.json', marked);
  assert.throws(() => verify(f.root));
  const plain = structuredClone(good);
  plain.rows.find(row => row.item === 'effort_high').accent = 0;
  f.write('plus-active.json', plain);
  assert.throws(() => verify(f.root));
  f.write('plus-active.json', good);
  assert.deepEqual(verify(f.root).efforts, ['low', 'medium', 'high']);
});

test('journey chooses model and effort from the shipped plus menu, not the retired palette rows', () => {
  const journey = source('tools/verify-chat-delivery/model-settings.ps1');
  assert.doesNotMatch(journey, /[^\x00-\x7f]/);
  assert.match(journey, /function Plus-Click/);
  assert.match(journey, /PressClient\(\$menu, \$app\.Id, \$x, \$y\)/);
  assert.match(journey, /input='choose plus menu row'/);
  assert.doesNotMatch(journey, /Press @\(0x28\)/);
  assert.doesNotMatch(journey, /@{query='(?:model|effort)/);
  assert.match(source('tools/verify-chat-delivery/drive.ps1'), /CHAT_MODEL_PROOF -eq '1'\) \{ Add-Type -Path "\$PSScriptRoot\/chat-switch-observer\.cs"/);
});
