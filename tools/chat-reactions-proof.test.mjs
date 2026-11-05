import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspect, assertBadge } from './chat-reactions-proof.mjs';
import * as proof from './chat-reactions-proof.mjs';

test('IGSH-1590 Windows reaction scheduling uses production polling and dispatch without duplicate workers', () => {
  const boundary = new URL('./verify-chat-delivery/boundary.py', import.meta.url);
  assert.match(fs.readFileSync(boundary, 'utf8'), /def install_reaction_worker\(namespace\):/);
  const script = String.raw`
import ast, pathlib, sqlite3, sys, tempfile, threading
from contextlib import closing
source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
worker = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == 'install_reaction_worker')
with tempfile.TemporaryDirectory() as directory:
    database = pathlib.Path(directory) / 'store.sqlite3'
    def connect(tmux):
        assert tmux == 'verify-agent'
        return sqlite3.connect(database)
    with closing(connect('verify-agent')) as db:
        db.execute('CREATE TABLE shared_messages (id INTEGER, provider TEXT, sid TEXT, state TEXT)')
        db.execute("INSERT INTO shared_messages VALUES (1,'claude','sid','queued')")
        db.commit()
    entered, release, first, second = (threading.Event() for _ in range(4))
    records, delivered, polls = [], [], []
    def poll(tmux, provider, sid):
        assert (tmux, provider, sid) == ('verify-agent', 'claude', 'sid')
        polls.append(sid)
    def dispatch(query):
        assert query['op'] == 'message_dispatch'
        entered.set()
        assert release.wait(5)
        with closing(connect(query['tmux'])) as db:
            row = db.execute("SELECT id FROM shared_messages WHERE state='queued' ORDER BY id LIMIT 1").fetchone()
            if row:
                delivered.append(row[0])
                db.execute("UPDATE shared_messages SET state='accepted' WHERE id=?", row)
                db.commit()
        if row:
            (first if row[0] == 1 else second).set()
    scope = dict(record=lambda name, **row: records.append(row))
    exec(compile(ast.Module(body=[worker], type_ignores=[]), '<reaction-worker>', 'exec'), scope)
    namespace = dict(message_poll=poll, message_store_request=dispatch, message_store_db=connect)
    scope['install_reaction_worker'](namespace)
    query = dict(op='message_submit', tmux='verify-agent', provider='claude', sid='sid')
    start = namespace['start_message_worker']
    start(query, '')
    assert entered.wait(5)
    for i in range(10): start(query, '')
    assert len([row for row in records if row['stage'] == 'started']) == 1
    release.set()
    assert first.wait(5)
    with closing(connect('verify-agent')) as db:
        db.execute("INSERT INTO shared_messages VALUES (2,'claude','sid','queued')")
        db.commit()
    start(query, '')
    assert second.wait(5)
    for thread in threading.enumerate():
        if thread is not threading.current_thread():
            thread.join(5)
            assert not thread.is_alive()
    assert delivered == [1, 2], delivered
    assert len(polls) >= 2
    assert not [row for row in records if row['stage'] == 'error'], records
print('REACTION_WINDOWS_DISPATCH_PROVEN')
`;
  assert.match(execFileSync('python3', ['-I', '-c', script, fileURLToPath(boundary)], { encoding: 'utf8', timeout: 20000 }), /REACTION_WINDOWS_DISPATCH_PROVEN/);
});

test('IGSH-1590 tmux buffers preserve Unicode and paste once without submitting', () => {
  const script = String.raw`
import ast, io, pathlib, re, sys, tempfile, types
source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
node = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == 'tmux_buffer')
with tempfile.TemporaryDirectory() as directory:
    sent, records = [], []
    text = '👍 to: Same first words [mp:6d8e353d25c5fe23]\nsecond line'
    name = 'mp-send-' + 'a' * 32
    scope = dict(ROOT=pathlib.Path(directory), re=re, sys=types.SimpleNamespace(stdin=types.SimpleNamespace(buffer=io.BytesIO(text.encode('utf-8')))), fake_send=lambda argv: sent.append(argv) or True, record=lambda name, **row: records.append(row))
    exec(compile(ast.Module(body=[node], type_ignores=[]), '<tmux-buffer>', 'exec'), scope)
    def run(*args):
        scope['ARGS'] = list(args)
        return scope['tmux_buffer']()
    assert run('load-buffer', '-b', name, '-') == 0
    assert not sent
    assert run('paste-buffer', '-p', '-d', '-b', name, '-t', '=verify-agent:') == 0
    assert sent == [['send-keys', '-t', '=verify-agent:', '-l', '--', text]], sent
    assert run('paste-buffer', '-p', '-d', '-b', name, '-t', '=verify-agent:') == 1
    assert len(sent) == 1
    assert run('delete-buffer', '-b', name) == 1
    scope['sys'].stdin.buffer = io.BytesIO(b'other')
    assert run('load-buffer', '-b', name, '-') == 0
    assert run('delete-buffer', '-b', name) == 0
    assert run('load-buffer', '-b', '../outside', '-') == 95
print('REACTION_TMUX_BUFFERS_PROVEN')
`;
  assert.match(execFileSync('python3', ['-I', '-c', script, fileURLToPath(new URL('./verify-chat-delivery/boundary.py', import.meta.url))], { encoding: 'utf8', timeout: 20000 }), /REACTION_TMUX_BUFFERS_PROVEN/);
});

const area = { left: 0, top: 0, right: 300, bottom: 300 };
function fixture() {
  const image = { width: 300, height: 300, pixels: Buffer.alloc(300 * 300 * 4) };
  const fill = (left, top, right, bottom, color) => {
    for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) image.pixels.writeUIntLE(color, (y * 300 + x) * 4, 3);
  };
  fill(0, 0, 300, 300, 0x202020);
  fill(20, 10, 250, 45, 0x555555);
  fill(20, 60, 250, 150, 0x444444);
  fill(20, 165, 250, 230, 0x444444);
  fill(28, 120, 68, 142, 0x585858);
  fill(42, 126, 53, 136, 0xffffff);
  return { image, fill };
}

test('real filled badge inside the first reply accepted', () => {
  assertBadge(inspect(fixture().image, area));
});
for (const [name, mutate] of [
  ['missing badge', f => f.fill(28, 120, 68, 142, 0x444444)],
  ['empty painted pill', f => f.fill(42, 126, 53, 136, 0x585858)],
  ['badge moved to second same-prefix reply', f => { f.fill(28, 120, 68, 142, 0x444444); f.fill(28, 205, 68, 227, 0x585858); f.fill(42, 211, 53, 221, 0xffffff); }],
  ['extra assistant reaction answer', f => f.fill(20, 245, 250, 280, 0x444444)],
  ['extra normal reaction bubble', f => f.fill(20, 245, 250, 280, 0x555555)],
  ['extra pending reaction bubble', f => f.fill(20, 245, 250, 280, 0x3a3a3a)],
]) test(`reject ${name}`, () => {
  const f = fixture(); mutate(f);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});


test('gradient fills remain one bubble; shared pill shade does not split user rows', () => {
  const f = fixture();
  for (const [top, bottom, base] of [[10, 45, 53], [60, 150, 36], [165, 230, 36]]) {
    for (let step = 0; step < 8; step++) {
      const shade = 32 + base + 8 - Math.trunc(8 * step / 7);
      f.fill(20, top + Math.trunc((bottom - top) * step / 8), 250, top + Math.trunc((bottom - top) * (step + 1) / 8), shade * 0x010101);
    }
  }
  f.fill(28, 120, 68, 142, 0x585858);
  f.fill(42, 126, 53, 136, 0xffffff);
  assertBadge(inspect(f.image, area));
});

test('rounded-edge shades cannot substitute for a painted badge glyph', () => {
  const f = fixture();
  f.fill(42, 126, 53, 136, 0x585858);
  f.fill(28, 120, 31, 142, 0x484848);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});


test('small composer buttons overlapping the transcript are not queued reaction bubbles', () => {
  const f = fixture();
  f.fill(260, 245, 291, 276, 0x414141);
  assertBadge(inspect(f.image, area));
});

test('approved reader colours identify assistant replies, not the user or composer buttons', () => {
  const f = fixture();
  f.fill(0, 0, 300, 300, 0x101010);
  f.fill(120, 0, 220, 10, 0x1e1e1e);
  f.fill(0, 285, 300, 300, 0x1e1e1e);
  f.fill(20, 10, 250, 45, 0x3a3a3a);
  f.fill(20, 60, 250, 150, 0x1e1e1e);
  f.fill(20, 165, 250, 230, 0x1e1e1e);
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  f.fill(260, 245, 291, 276, 0x3a3a3a);
  const frame = inspect(f.image, area);
  assert.deepEqual(frame.agent.map(row => row.top), [60, 165]);
  assertBadge(frame);
  f.fill(20, 245, 250, 280, 0x1e1e1e);
  assert.throws(() => assertBadge(inspect(f.image, area)), assert.AssertionError);
});

test('reject a detached badge below its message', () => {
  const f = fixture();
  f.fill(20, 116, 250, 150, 0x202020);
  f.fill(28, 120, 68, 142, 0x585858);
  f.fill(42, 126, 53, 136, 0xffffff);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});

test('approved reader colors still identify the enclosed reaction', () => {
  const f = fixture();
  f.fill(0, 0, 300, 300, 0x101010);
  f.fill(20, 10, 250, 45, 0x3a3a3a);
  f.fill(20, 60, 250, 150, 0x1e1e1e);
  f.fill(20, 165, 250, 230, 0x1e1e1e);
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  assertBadge(inspect(f.image, area));
});

test('floating title is not the first reply after the setup prompt', () => {
  const f = fixture();
  f.fill(200, 5, 296, 40, 0x444444);
  const frame = inspect(f.image, area);
  assert.equal(frame.agent.length, 2);
  assert.equal(frame.agent[0].top, 60);
  assertBadge(frame);
});

test('ordinary follow-up requires the full newest pair, not just transcript data', () => {
  const f = fixture();
  f.fill(0, 0, 300, 300, 0x202020);
  f.fill(20, 10, 250, 60, 0x555555);
  f.fill(20, 80, 250, 160, 0x444444);
  const frame = inspect(f.image, area);
  assert.deepEqual(proof.assertFollowup(frame, area), { x: 50, y: 120 });
  assert.throws(() => proof.assertFollowup({ ...frame, agent: [] }, area), /one ordinary answer/);
  assert.throws(() => proof.assertFollowup({ ...frame, user: [] }, area), /question is visible/);
  assert.throws(() => proof.assertFollowup(frame, { ...area, bottom: 155 }), /fully inside the viewport/);
  assert.throws(() => proof.assertFollowup({ ...frame, agent: [...frame.agent, { ...frame.agent[0], top: 180, bottom: 230 }] }, area), /one ordinary answer/);
  assert.throws(() => proof.assertFollowup({ ...frame, dim: [frame.user[0]] }, area), /not left queued/);
});

test('reaction fixture answers only an actual idle follow-up submission', () => {
  const script = String.raw`
import ast, pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
node = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == 'fake_submit')
events, queued = [], []
scope = dict(state=lambda: dict(name='reactions'), fake_event=lambda kind, **row: events.append((kind, row)), fake_queue_event=lambda *args: queued.append(args))
exec(compile(ast.Module(body=[node], type_ignores=[]), '<reaction-followup>', 'exec'), scope)
submit = scope['fake_submit']
claude = dict(mode='busy', queue=[])
submit(claude, 'What should I do next?')
assert not events and len(queued) == 1
claude['mode'] = 'idle'
submit(claude, 'Something else')
assert [kind for kind, row in events] == ['user']
events.clear()
submit(claude, 'What should I do next?')
assert [kind for kind, row in events] == ['user', 'assistant']
assert events[1][1]['message']['content'][0]['text'] == 'The next answer stays visible after reacting.'
print('REACTION_ORDINARY_FOLLOWUP_PROVEN')
`;
  assert.match(execFileSync('python3', ['-I', '-c', script, fileURLToPath(new URL('./verify-chat-delivery/boundary.py', import.meta.url))], { encoding: 'utf8', timeout: 20000 }), /REACTION_ORDINARY_FOLLOWUP_PROVEN/);
});

test('native three-dot more glyph is visible; a missing glyph still fails', () => {
  assert.equal(typeof proof.assertHoverActions, 'function');
  const image = { width: 400, height: 200, pixels: Buffer.alloc(400 * 200 * 4) };
  const ink = (x, y) => image.pixels.writeUIntLE(0x8a8a8a, (y * image.width + x) * 4, 3);
  for (const x of [262, 290]) for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 4; dy++) ink(x + dx, 130 + dy);
  for (const x of [320, 323, 326]) { ink(x, 136); ink(x, 137); }
  const first = { left: 20, right: 250, bottom: 150 };
  assert.equal(proof.assertHoverActions(image, first).moreX, 326);
  for (const x of [320, 323, 326]) for (const y of [136, 137]) image.pixels.writeUIntLE(0, (y * image.width + x) * 4, 3);
  assert.throws(() => proof.assertHoverActions(image, first), /hover action 2 is painted/);
});


test('reaction proof measures the painted transcript, excluding the floating composer', () => {
  const driver = fs.readFileSync(new URL('./verify-chat-delivery/reactions.ps1', import.meta.url), 'utf8');
  assert.match(driver, /frame transcript/);
  assert.match(driver, /ScreenPoint\(\$main, 0, 0\)/);
  assert.match(driver, /Save \$area "\$caseDir\/area.json"/);
  const f = fixture();
  f.fill(20, 245, 250, 280, 0x444444);
  assert.throws(() => assertBadge(inspect(f.image, area)));
  assertBadge(inspect(f.image, { ...area, bottom: 235 }));
});
