const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');

test('Rooms preview boundary retains legacy refusal and binds two broadcasts to their synthetic replies', () => {
  assert.equal(process.env.GITHUB_ACTIONS, 'true', 'GitHub-hosted only');
  assert.ok(fs.existsSync(path.join(root, 'tools/verify-rooms/boundary.py')), 'The executable Rooms preview boundary must exist');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'rooms-preview-boundary-'));
  const source = ['src/room_service.py', 'src/room_bridge.py'].map(file => fs.readFileSync(path.join(root, file)).toString('base64'));
  function request(query) {
    const result = spawnSync(process.platform === 'win32' ? 'python' : 'python3', [path.join(root, 'tools/verify-rooms/boundary.py'), 'ssh', 'room_service'], {
      cwd: root, env: { ...process.env, MP_VERIFY_STATE: directory },
      input: [...source, 'a'.repeat(64), JSON.stringify(query), ''].join('\n'), encoding: 'utf8', timeout: 30000,
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    return JSON.parse(result.stdout);
  }
  try {
    const capabilities = request({ op: 'capabilities', room_messages: 1 }).result;
    assert.equal(capabilities.live_send, false);
    const host = capabilities.host_uuid;
    const members = ['alpha', 'beta'].map(alias => {
      const sid = randomUUID();
      return { alias: `agent_${alias}`, display_name: alias, host_uuid: host, provider: 'claude', provider_sid: sid, session_identity: `claude:${sid}` };
    });
    const created = request({ op: 'create', host_uuid: host, command_id: randomUUID(), name: 'Synthetic proof', members });
    assert.equal(created.ok, true, JSON.stringify(created));
    const room = created.result.event.room_id;
    const listed = request({ op: 'list', host_uuid: host, after: 0, through: null, limit: 100 });
    assert.equal(listed.ok, true, JSON.stringify(listed));
    assert.deepEqual(listed.result.rooms.map(row => row.id), [room]);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(directory, 'catalog-observed.json'), 'utf8')).room_ids, [room]);
    const post = { op: 'post_human', host_uuid: host, command_id: randomUUID(), room_id: room, expected_revision: 1, text: 'Both synthetic agents, reply once.', recipients: [] };
    assert.deepEqual(request(post), { ok: false, error: 'unsupported_remote_capability' });
    fs.writeFileSync(path.join(directory, 'live-replies'), 'synthetic providers only');
    assert.equal(request({ op: 'capabilities', room_messages: 1 }).result.live_send, true);
    const receipt = request(post);
    assert.equal(receipt.ok, true, JSON.stringify(receipt));
    assert.equal(receipt.result.deliveries.length, 2);
    const query = { op: 'events', host_uuid: host, room_id: room, after: 0, limit: 200 };
    const page = request(query);
    assert.equal(page.ok, true, JSON.stringify(page));
    const events = page.result.events;
    assert.equal(events.filter(event => event.type === 'human').length, 1);
    const replies = events.filter(event => event.type === 'agent_reply');
    assert.equal(replies.length, 2);
    assert.equal(new Set(replies.map(reply => reply.member_id)).size, 2);
    assert.ok(replies.every(reply => reply.parent_event_id === receipt.result.event.id));
    assert.deepEqual(replies.map(reply => reply.text).sort(), ['Synthetic Alpha reply: Ready.', 'Synthetic Beta reply: Ready.']);
    assert.deepEqual(request(post), receipt);
    assert.deepEqual(request(query), page);
    const second = { ...post, command_id: randomUUID(), text: 'Second room question: both agents, reply once.' };
    const secondReceipt = request(second);
    assert.equal(secondReceipt.ok, true, JSON.stringify(secondReceipt));
    const secondPage = request(query);
    assert.equal(secondPage.ok, true, JSON.stringify(secondPage));
    assert.equal(secondPage.result.events.filter(event => event.type === 'human').length, 2);
    const allReplies = secondPage.result.events.filter(event => event.type === 'agent_reply');
    assert.equal(allReplies.length, 4);
    const secondReplies = allReplies.filter(reply => reply.parent_event_id === secondReceipt.result.event.id);
    assert.equal(new Set(secondReplies.map(reply => reply.member_id)).size, 2);
    assert.deepEqual(secondReplies.map(reply => reply.text).sort(), ['Synthetic Alpha reply: Second ready.', 'Synthetic Beta reply: Second ready.']);
    assert.deepEqual(request(second), secondReceipt);
    assert.deepEqual(request(query), secondPage);
    const witness = JSON.parse(fs.readFileSync(path.join(directory, 'witness.json'), 'utf8'));
    assert.equal(witness.rooms.length, 1);
    assert.equal(witness.canonical_events.filter(row => row.event.kind === 'turn.ended').length, 4);
    assert.equal(witness.canonical_events.filter(row => row.event.kind === 'turn.started').length, 4);
    assert.ok(witness.canonical_events.filter(row => row.event.kind === 'turn.ended').every(row => [receipt.result.event.id, secondReceipt.result.event.id].includes(row.event.room_scope.parent_event_id)));
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
