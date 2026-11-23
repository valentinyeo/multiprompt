const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function verify(root) {
  const dir = path.join(root, 'antigravity-chats');
  const read = name => fs.readFileSync(path.join(dir, name), 'utf8');
  const json = name => JSON.parse(read(name));
  const png = name => fs.readFileSync(path.join(dir, `${name}.png`)).subarray(0, 8).toString('hex');
  assert.equal(json('observation.json').error, null);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  for (const shot of ['antigravity-chat-before', 'antigravity-switch-palette', 'antigravity-switched-chat',
    'antigravity-new-session-palette', 'antigravity-new-session']) {
    assert.equal(png(shot), '89504e470d0a1a0a', `missing screenshot ${shot}`);
  }
  const config = json('antigravity-config.json');
  assert.equal(config.provider, 'antigravity');
  assert.equal(config.enabled, true);
  assert.equal(config.tmux, 'verify-agent');
  assert.equal(config.switched_from.provider, 'claude');
  const history = read('antigravity-history.jsonl').trim().split('\n').map(line => JSON.parse(line));
  const texts = history.map(row => (row.row ? row.row.text : '') || '');
  assert.ok(texts.some(text => text.includes('earlier claude question')), 'earlier message missing after the switch');
  assert.ok(texts.some(text => text.includes('Switched AI: Claude to Antigravity')), 'switch divider missing');
  assert.ok(texts.some(text => text.includes('Antigravity stand-in reply')), 'fixture reply missing after the switch');
  const seed = json('seed-session.json');
  const afterSwitch = json('session-after-switch.json');
  assert.equal(afterSwitch.tabs.length, seed.tabs.length, 'the switch changed the chat rows');
  assert.equal(afterSwitch.tabs[0].name, seed.tabs[0].name, 'the switch renamed the chat');
  const received = read('stand-in/antigravity-deliver.jsonl').trim().split('\n').filter(Boolean);
  assert.ok(received.some(line => line.includes('after the switch')), 'the Antigravity host never received the new message');
  assert.ok(read('claude-history.jsonl').includes('Claude stand-in answer'), 'the earlier message was not answered before the switch');
  const agent = read('stand-in/agy-agent.jsonl').trim().split('\n').map(line => JSON.parse(line));
  assert.ok(agent.some(line => line.argv.some(part => part.includes('stream-json'))), 'the fixture was not started through the Antigravity argv');
  assert.ok(read('stand-in/invocations.jsonl').includes('antigravity'), 'the new session did not route an Antigravity launch');
  const after = json('session-new-session.json');
  assert.equal(after.tabs.length, seed.tabs.length + 1, 'the new Antigravity session did not add one row');
  const fresh = after.tabs.find(tab => tab.name === 'Antigravity');
  assert.ok(fresh, 'the new row is not named Antigravity');
  assert.equal(fresh.cv, true, 'the new Antigravity row did not open in Chat View');
  assert.match(fresh.tmux_session, /^live-/);
  const doctor = json('doctor.json');
  assert.ok(Number.isSafeInteger(doctor.pid) && doctor.pid > 0, 'doctor identity missing');
  assert.equal(doctor.hwnd > 0, true);
  return {
    feature: 'antigravity-chats',
    status: 'passed',
    boundary: 'Antigravity is a repository stand-in that speaks the production stream-json protocol; SSH and the remote shell are stand-ins, the app, keyboard input and the production reader host are real.',
    cases: [{
      name: 'antigravity-chats',
      passed: true,
      detail: { switched: config.switched_from.provider + ' to ' + config.provider, historyRows: history.length, newSession: fresh.tmux_session },
    }],
  };
}

module.exports = { verify };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const result = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('ANTIGRAVITY_OK');
  } catch (error) {
    console.error(error.stack);
    process.exitCode = 1;
  }
}
