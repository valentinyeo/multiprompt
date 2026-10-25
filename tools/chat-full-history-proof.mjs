import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2]);
const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
let result;
try {
  const observation = json('full-history/observation.json');
  assert.equal(observation.error, null);
  const source = fs.readFileSync(path.join(root, 'full-history/transcript.jsonl'), 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
  const messages = source.filter(row => typeof row.message?.content === 'string' || row.message?.content?.some(part => part.type === 'text')).map(row => typeof row.message.content === 'string' ? row.message.content : row.message.content.find(part => part.type === 'text').text);
  assert.equal(messages.length, 50);
  for (const stage of ['open', 'restart']) {
    const measured = json(`full-history/${stage}.json`);
    const copied = fs.readFileSync(path.join(root, `full-history/${stage}-copied.txt`), 'utf8');
    assert.equal(measured.messages, messages.length);
    assert.equal(measured.blocks, messages.length + 24);
    let offset = 0;
    for (const message of messages) {
      const at = copied.indexOf(message, offset);
      assert.ok(at >= offset, `${stage}: missing or reordered ${message}`);
      assert.equal(copied.indexOf(message, at + message.length), -1, `${stage}: duplicated ${message}`);
      offset = at + message.length;
    }
    for (const edge of ['first', 'last']) {
      const bytes = fs.readFileSync(path.join(root, `full-history-${stage}-${edge}.png`));
      assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
      assert.ok(bytes.length > 10000);
    }
  }
  const build = json('build.json');
  const doctor = json('full-history/doctor.json');
  assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.equal(doctor.version, build.version);
  assert.ok(doctor.chat && doctor.tmux && doctor.pid > 0);
  assert.deepEqual(doctor.focus, [doctor.hwnd, doctor.composer]);
  assert.equal(json('full-history/restart-process-tree.json').ActiveProcesses, 0);
  assert.equal(json('full-history/process-tree.json').ActiveProcesses, 0);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(cleanup.scratch_removed, true);
  result = { feature: 'chat-full-history', status: 'passed', checks: [{ name: 'IGSH-815 all messages on open and restart', passed: true, messages: messages.length }] };
} catch (error) {
  result = { feature: 'chat-full-history', status: 'failed', error: error.message, checks: [{ name: 'IGSH-815 all messages on open and restart', passed: false, reason: error.message }] };
}
fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result));
process.exitCode = result.status === 'passed' ? 0 : 1;
