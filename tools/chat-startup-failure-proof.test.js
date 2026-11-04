const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');

test('startup failure dispatch fits GitHub limits and selects its driver', () => {
  const root = path.join(__dirname, '..');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  const dispatch = workflow.split('  workflow_call:')[0];
  const inputs = [...dispatch.matchAll(/^      ([a-z_]+):$/gm)].map(match => match[1]);
  assert.ok(inputs.length <= 25, `workflow_dispatch has ${inputs.length} inputs`);
  assert.ok(!inputs.includes('startup_failure_proof'));
  assert.match(workflow, /CHAT_STARTUP_FAILURE_PROOF: \$\{\{ inputs\.feature == 'chat-startup-failure'/);
  assert.ok(discoverFeatures().available.includes('chat-startup-failure'));
  const control = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  assert.match(control, /ValidateSet\([^\n]*'chat-startup-failure'/);
  assert.match(control, /'chat-startup-failure' \{[\s\S]*?verify-chat-delivery\/drive\.ps1/);
  const verifyJob = workflow.split('\n  verify:\n')[1];
  for (const step of ['Install Zig 0.16.0', 'Compile chat delivery remote-shell boundary']) {
    const block = verifyJob.split(`- name: ${step}`)[1].split('\n      - ')[0];
    assert.match(block, /env\.FEATURE == 'chat-startup-failure'/);
  }
  const python = verifyJob.split('- uses: actions/setup-python@')[1].split('\n      - ')[0];
  assert.match(python, /env\.FEATURE == 'chat-startup-failure'/);
  const delivery = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/chat-delivery.md'), 'utf8');
  assert.equal((delivery.match(/^## /gm) || []).length, 4);
});

test('startup failure proof rejects duplicates, transcripts and missing events', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  assert.match(workflow, /CHAT_STARTUP_FAILURE_PROOF: \$\{\{ inputs\.feature == 'chat-startup-failure'/);
  const { verify, MESSAGE, SID } = require('./chat-startup-failure-proof.cjs');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'startup-proof-'));
  const put = (name, value) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  try {
    const observation = { error: null, noTranscript: true, copied: MESSAGE };
    const rows = [
      { stage: 'subscribed', sid: SID, provider: 'claude' },
      { stage: 'host-stopped', sid: SID, standin: 'thread', events: [
        { event: { kind: 'turn.started' } },
        { event: { kind: 'text.done', payload: { text: MESSAGE } } },
        { event: { kind: 'turn.ended', payload: { status: 'failed' } } },
      ] },
    ];
    put('startup-failure/observation.json', observation);
    put('startup-failure/stand-in/startup-failure.jsonl', rows.map(JSON.stringify).join('\n'));
    put('startup-failure-visible.png', Buffer.from('89504e470d0a1a0a', 'hex'));
    put('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
    assert.equal(verify(root).status, 'passed');
    put('startup-failure/observation.json', { ...observation, copied: MESSAGE + MESSAGE });
    assert.throws(() => verify(root), /exactly once/);
    put('startup-failure/observation.json', { ...observation, noTranscript: false });
    assert.throws(() => verify(root), /transcript/);
    put('startup-failure/observation.json', observation);
    rows[1].events.pop();
    put('startup-failure/stand-in/startup-failure.jsonl', rows.map(JSON.stringify).join('\n'));
    assert.throws(() => verify(root));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
