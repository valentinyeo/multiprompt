const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const readerPath = path.join(root, 'src', 'chat_history_reader.py');
const fixture = path.join(__dirname, 'fixtures', 'SOFT-2582', 'hook-reemit.jsonl');

function runPython(body) {
  const script = `
import importlib.util, json
spec = importlib.util.spec_from_file_location('reader', ${JSON.stringify(readerPath)})
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
${body}
`;
  const run = spawnSync('python3', ['-c', script], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr || run.stdout);
  return run.stdout.trim();
}

test('SOFT-2582 hook re-emitted assistant replies appear once in reader output', () => {
  assert.ok(fs.existsSync(fixture), 'regression fixture missing');
  const stdout = runPython(`
path = ${JSON.stringify(fixture)}
rows = []
consumed = 0
with open(path, 'rb') as source:
    data = source.read()
for raw in data.splitlines(keepends=True):
    rows.extend(reader.conversation_rows(reader.load_line(raw), 'claude', consumed))
    consumed += len(raw)
paired = reader.dedupe_identity_rows(reader.pair_tool_rows(rows))
assistant = [r for r in paired if r['role'] == 'assistant' and r.get('text', '').strip()]
print(json.dumps({'count': len(assistant), 'texts': [r['text'] for r in assistant], 'ids': [r.get('id') for r in assistant]}))
`);
  const summary = JSON.parse(stdout);
  assert.equal(summary.count, 1, `expected one assistant row, got ${summary.count}: ${summary.texts.join(' | ')}`);
  assert.match(summary.texts[0], /HOOK_DEMO_LATEST/);
  assert.equal(summary.ids.filter(id => id === 'msg_hook_demo_2582').length, 1);
});

test('SOFT-2582 two separate replies with different ids stay separate', () => {
  runPython(`
rows = [
    dict(role='assistant', id='reply-a', text='first reply', offset=0, end=10),
    dict(role='assistant', id='reply-b', text='second reply', offset=20, end=30),
]
paired = reader.dedupe_identity_rows(reader.pair_tool_rows(rows))
assert len([r for r in paired if r['role']=='assistant']) == 2
`);
});