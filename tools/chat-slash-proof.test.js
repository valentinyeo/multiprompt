const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');

test('slash proof keeps the production host mode handler and replaces only its agent transport', () => {
  const fixture = 'tools/verify-chat-delivery/slash_host.py';
  assert.ok(fs.existsSync(fixture), 'slash proof has an isolated host transport');
  const script = `
import importlib.util, json, tempfile
from pathlib import Path

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

reader = load('reader', 'src/chat_history_reader.py')
fixture = load('slash_host', '${fixture}')
with tempfile.TemporaryDirectory() as folder:
    root = Path(folder)
    reader.HOME = root
    reader.host_owned = lambda *args: False
    reader.host_request = lambda *args, **kwargs: {'status': 'unavailable'}
    sid = 'slash-test-session'
    (root / 'state.json').write_text(json.dumps({'sids': {'live-slash': sid}}))
    records = []
    fixture.install(reader.__dict__, root, lambda file, **row: records.append((file, row)))
    for mode in ('plan', 'manual', 'acceptEdits'):
        reply = reader.host_reply(dict(op='set_permission_mode', provider='claude', sid=sid, mode=mode))
        assert reply['status'] == 'ok', reply
        assert json.loads((root / 'slash-mode.json').read_text())['mode'] == mode
    controls = [row['request'] for file, row in records if file == 'slash-control.jsonl']
    assert controls == [dict(subtype='set_permission_mode', mode=mode) for mode in ('plan', 'manual', 'acceptEdits')], controls
    reply = reader.host_reply(dict(op='set_permission_mode', provider='claude', sid=sid, mode='unsupported'))
    assert reply['status'] == 'refused', reply
    assert json.loads((root / 'slash-mode.json').read_text())['mode'] == 'acceptEdits'
    assert not reader.host_owned('claude', 'other-session')
print('SLASH_HOST_TRANSPORT_OK')
`;
  const run = spawnSync('python3', ['-B', '-c', script], { encoding: 'utf8', timeout: 10000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stdout, /SLASH_HOST_TRANSPORT_OK/);
});

test('live slash screenshot journey drives every requested command and checks independent mode receipts', () => {
  const driver = '.claude/skills/verify-multiprompt/chat-slash.ps1';
  assert.ok(fs.existsSync(driver), 'live slash keyboard journey exists');
  const text = fs.readFileSync(driver, 'utf8');
  for (const command of ['/plan', '/permissions', '/model', '/resume', '/rewind']) assert.ok(text.includes(`'${command}'`), command);
  for (const receipt of ['slash-control.jsonl', 'slash-mode.json', 'slash-replies.jsonl']) assert.ok(text.includes(receipt), receipt);
  assert.match(text, /controls\.Count -ne 3/);
  assert.match(text, /plan,manual,acceptEdits/);
  assert.match(text, /ordinarySends = 0/);
  assert.match(text, /Snapshot 'slash-plan-picker'/);
  assert.match(text, /Snapshot 'slash-permissions-picker'/);
  assert.ok(fs.readFileSync('.claude/skills/verify-multiprompt/control.ps1', 'utf8').includes("'chat-slash.ps1'"));
  const workflow = fs.readFileSync('.github/workflows/verify.yml', 'utf8');
  assert.match(workflow, /Build the Windows app once for this push[^]*?run: zig build -Drelease=false -Dcpu=x86_64_v3/);
  assert.ok(workflow.includes('version: ${{ steps.identity.outputs.version }}'));
  assert.ok(workflow.includes("$version = '${{ needs.build-app.outputs.version }}'"));
});
