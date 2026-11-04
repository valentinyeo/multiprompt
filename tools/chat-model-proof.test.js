const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
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
  write('before-history.txt', 'start the fake session\nThe fake session is ready.');
  write('after-history.txt', 'start the fake session\nThe fake session is ready.');
  const actions = [];
  let hostLog = '';
  let argvLog = '';
  fs.mkdirSync(path.join(dir, 'host'));
  fs.mkdirSync(path.join(dir, 'stand-in'));
  write('stand-in/model-reader.jsonl', JSON.stringify({ inner_sha256: 'a'.repeat(64) }) + '\n');
  for (const [name, effort] of [['haiku', 'default'], ['low', 'low'], ['medium', 'medium'], ['high', 'high']]) {
    actions.push({ input: 'type palette query', text: name === 'haiku' ? 'model haiku' : `effort ${name}` });
    write(`config-${name}.json`, { enabled: true, model: 'haiku', ...(effort === 'default' ? {} : { effort }) });
    hostLog += JSON.stringify({ event: 'model_effort_settings_applied', detail: { model: 'haiku', effort } }) + '\n';
    argvLog += JSON.stringify({ argv: ['--model', 'haiku', ...(effort === 'default' ? [] : ['--effort', effort])] }) + '\n';
    write(`host-${name}.jsonl`, hostLog);
    write(`argv-${name}.jsonl`, argvLog);
  }
  write('host/host.events.log', hostLog);
  write('stand-in/model-argv.jsonl', argvLog);
  fs.writeFileSync(path.join(root, 'actions.json'), JSON.stringify(actions));
  const png = Buffer.alloc(1024);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  for (const name of ['model-before', 'model-after', ...['haiku', 'low', 'medium', 'high'].flatMap(choice => [`model-palette-${choice}`, `model-after-${choice}`])]) fs.writeFileSync(path.join(root, `${name}.png`), png);
  return { root, dir, write };
}

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
