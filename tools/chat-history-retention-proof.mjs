import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2]);
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(read(name));
let result;
try {
  assert.equal(json('full-history/observation.json').error, null);
  const source = read('full-history/retention-expected.jsonl').trim().split(/\r?\n/).map(JSON.parse);
  assert.equal(source.length, 2200);
  const messages = source.map(row => typeof row.message.content === 'string' ? row.message.content : row.message.content.find(part => part.type === 'text').text);
  for (const [stage, count] of [['open', 2000], ['empty', 2120], ...Array.from({ length: 10 }, (_, i) => [`burst-${i + 1}`, 2020 + i * 20]), ['final', 2200]]) {
    const copied = read(`full-history/${stage}-copied.txt`);
    let offset = 0;
    for (const text of messages.slice(0, count)) {
      const at = copied.indexOf(text, offset);
      assert.ok(at >= offset, `${stage}: missing or reordered ${text}`);
      assert.equal(copied.indexOf(text, at + text.length), -1, `${stage}: duplicate ${text}`);
      offset = at + text.length;
    }
  }
  for (const name of ['before', 'after', ...Array.from({ length: 10 }, (_, i) => `burst-${i + 1}`)]) {
    const bytes = fs.readFileSync(path.join(root, `retention-${name}.png`));
    assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(bytes.length > 10000);
  }
  const anchors = json('full-history/retention-anchors.json');
  assert.equal(anchors.length, 10);
  assert.ok(anchors.every(row => row.unknown === 0 && row.scroll === anchors[0].scroll && row.marker !== '0'));
  const log = read('full-history/retention-arrival.log');
  const arrival = [...log.matchAll(/PERF\[chat\]: receive to paint ms=(\d+) size=(\d+)/g)].map(m => +m[1]);
  assert.ok(arrival.length >= 10, 'arrival timings missing');
  assert.ok(Math.max(...arrival) < 100, `arrival exceeded 100ms: ${arrival}`);
  const switches = [...read('full-history/retention-switch.log').matchAll(/\[switch\] chat painted in (\d+) ms/g)].map(m => +m[1]);
  assert.ok(switches.length >= 5, 'switch timings missing');
  assert.ok(Math.max(...switches) < 150, `switch exceeded 150ms: ${switches}`);
  const build = json('build.json');
  const doctor = json('full-history/doctor.json');
  assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.equal(doctor.version, build.version);
  assert.equal(json('cleanup.json').remaining_owned_processes, 0);
  assert.equal(json('cleanup.json').scratch_removed, true);
  result = { status: 'passed', messages: source.length, bursts: 10, arrival_ms: arrival, switch_ms: switches };
} catch (error) {
  result = { status: 'failed', error: error.message };
}
fs.writeFileSync(path.join(root, 'retention.json'), JSON.stringify(result, null, 2) + '\n');
fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-full-history', ...result }) + '\n');
console.log(JSON.stringify(result));
process.exitCode = result.status === 'passed' ? 0 : 1;
