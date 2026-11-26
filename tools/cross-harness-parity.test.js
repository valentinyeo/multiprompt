const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { discoverTests } = require('./discover-tests.cjs');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const thisSuite = 'tools/cross-harness-parity.test.js';
const harnesses = ['claude', 'codex', 'pi', 'antigravity'];

const python = program => {
  const result = spawnSync(process.env.PYTHON || 'python3', ['-I', '-'], { input: program, cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  return JSON.parse(result.stdout);
};

const pythonFacts = () => python(String.raw`
import ast, json, tempfile
from pathlib import Path

def module(name):
    return ast.parse(Path(name).read_text(encoding='utf-8'))

def assigned(tree, name):
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == name for target in node.targets):
            return node.value
    raise SystemExit(name + ' is not assigned at module level')

def literal(name, constant):
    return list(ast.literal_eval(assigned(module(name), constant)))

def functions(tree):
    return {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}

def names(node):
    return {child.id for child in ast.walk(node) if isinstance(child, ast.Name)}

def strings(node):
    return {child.value for child in ast.walk(node) if isinstance(child, ast.Constant) and isinstance(child.value, str)}

complete = module('src/mp_complete.py')
complete_functions = functions(complete)
request = complete_functions['request']
slash = {}
for agent, table in (('claude', 'claude_interactive_builtins.tsv'), ('codex', 'codex_slash.txt'), ('pi', 'PI_BUILTINS'), ('antigravity', 'ANTIGRAVITY_BUILTINS')):
    rows = complete_functions.get(agent + '_rows')
    slash[agent] = {
        'defined': rows is not None,
        'called': agent + '_rows' in names(request),
        'gated': agent in strings(request),
        'slash_source': False if rows is None else (table in strings(rows) or table in names(rows)),
    }

reader_file = Path('src/chat_history_reader.py').read_text(encoding='utf-8')
outer = {}
exec(compile(reader_file, 'reader', 'exec'), outer)
reader = ast.parse(outer['READER_SOURCE'])
runtime = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), runtime)
with tempfile.TemporaryDirectory() as directory:
    runtime['HOME'] = Path(directory)
    def reason(query):
        reply = runtime['host_reply'](query)
        return reply.get('reason') if isinstance(reply, dict) else str(reply)
    sid = 'synthetic-parity-600'
    effort_replies = {provider: reason(dict(provider=provider, sid=sid, op='set_effort', effort='high')) for provider in ('claude', 'codex', 'pi', 'antigravity')}
    model_replies = {provider: reason(dict(provider=provider, sid=sid, op='set_model', model=model)) for provider, model in (('claude', 'opus'), ('codex', 'sol'), ('antigravity', 'neon'))}
    pi_replies = {provider: reason(dict(provider='pi', sid=sid, op='set_model', provider_name=provider, model=model)) for provider, model in (('openai-codex', 'gpt-5.6-sol'), ('opencode-go', 'deepseek-v4.1-flash'))}

print(json.dumps(dict(
    mp_send=literal('src/mp_send.py', 'PROVIDERS'),
    mp_sessions=literal('src/mp_sessions.py', 'PROVIDERS'),
    host=list(ast.literal_eval(assigned(reader, 'HOST_PROVIDERS'))),
    switch_targets=list(ast.literal_eval(assigned(reader, 'HOST_SWITCH_TARGETS'))),
    switch_order=list(ast.literal_eval(assigned(reader, 'HOST_AUTO_SWITCH_ORDER'))),
    effort=list(ast.literal_eval(assigned(reader, 'HOST_EFFORT_PROVIDERS'))),
    models=[keyword.arg for keyword in assigned(reader, 'HOST_MODEL_CHOICES').keywords],
    pi_default=list(runtime['HOST_PI_MODEL']),
    slash=slash,
    effort_replies=effort_replies,
    model_replies=model_replies,
    pi_replies=pi_replies,
)))
`);

const facts = pythonFacts();

test('MUBO-600 the shared parity suite is picked up on every pull request', () => {
  const discovered = discoverTests(root).includes(thisSuite);
  const named = [read('.github/workflows/test.yml'), read('build.zig')].some(text => text.includes(thisSuite));
  assert.ok(discovered || named, `${thisSuite} must run automatically through discover-tests.cjs or a workflow`);
});

test('MUBO-600 every provider list accepts Claude, Codex, Pi and Antigravity', async () => {
  const { PROVIDERS } = await import('../src/mp_layout.mjs');
  for (const harness of harnesses) {
    assert.ok(PROVIDERS.includes(harness), `mp_layout.mjs PROVIDERS must include ${harness}`);
    assert.ok(facts.mp_send.includes(harness), `mp_send.py PROVIDERS must include ${harness}`);
    assert.ok(facts.mp_sessions.includes(harness), `mp_sessions.py PROVIDERS must include ${harness}`);
    assert.ok(facts.host.includes(harness), `chat_history_reader.py HOST_PROVIDERS must include ${harness}`);
  }
});

test('MUBO-600 switching and automatic switch order include all four harnesses', () => {
  for (const harness of harnesses) {
    assert.ok(facts.switch_targets.includes(harness), `HOST_SWITCH_TARGETS must include ${harness}`);
    assert.ok(facts.switch_order.includes(harness), `HOST_AUTO_SWITCH_ORDER must include ${harness}`);
  }
});

test('MUBO-600 slash skill completion serves all four harnesses', () => {
  const complete = read('src/chat_complete.zig');
  assert.match(complete, /pub const Agent = enum \{ claude, codex, pi, antigravity, other \};/);
  assert.match(complete, /for \(\[_\]Agent\{ \.claude, \.codex, \.pi, \.antigravity, \.other \}\) \|agent\|/);
  assert.match(complete, /test "MUBO-589 pi slash triggers at start, mid-sentence, and inserts slash commands"/);
  assert.match(complete, /test "antigravity slash triggers at start, mid-sentence, and inserts slash commands"/);
  for (const harness of harnesses) {
    const rows = facts.slash[harness];
    assert.ok(rows.defined, `mp_complete.py must define ${harness}_rows`);
    assert.ok(rows.called, `mp_complete.py request must dispatch to ${harness}_rows`);
    assert.ok(rows.gated, `mp_complete.py request must accept the ${harness} agent`);
    assert.ok(rows.slash_source, `mp_complete.py ${harness}_rows must read slash entries`);
  }
});

test('MUBO-600 effort and model switching accept all four harnesses', () => {
  for (const harness of harnesses) {
    assert.ok(facts.effort.includes(harness), `HOST_EFFORT_PROVIDERS must include ${harness}`);
    assert.notEqual(facts.effort_replies[harness], 'unsupported_provider', `set_effort must accept ${harness}`);
  }
  for (const harness of ['claude', 'codex', 'antigravity']) {
    assert.ok(facts.models.includes(harness), `HOST_MODEL_CHOICES must include ${harness}`);
    assert.notEqual(facts.model_replies[harness], 'unsupported_provider', `set_model must accept ${harness}`);
  }
  assert.deepEqual(facts.pi_default, ['--provider', 'opencode-go', '--model', 'deepseek-v4.1-flash']);
  for (const provider of ['openai-codex', 'opencode-go']) {
    assert.notEqual(facts.pi_replies[provider], 'unsupported_provider', `set_model must accept the Pi ${provider} provider`);
  }
});

test('MUBO-600 every chat surface tells the four harness ids apart', () => {
  const transcript = read('src/chat_transcript.zig');
  assert.match(transcript, /1 => "claude",\s*2 => "codex",\s*3 => "pi",/);
  assert.match(transcript, /8 => "antigravity",/);
  assert.match(transcript, /pub fn agentId\(self: Identity\) u8 \{\s*if \(self\.agent != 0\) return self\.agent;\s*if \(self\.pi\) return 3;\s*if \(self\.codex\) return 2;\s*return 1;\s*\}/);
  const history = read('src/chat_history.zig');
  assert.match(history, /const transcript = @import\("chat_transcript\.zig"\);/);
  assert.match(history, /header_agent != key\.agentId\(\)/);
  const session = read('src/chat_session.zig');
  assert.match(session, /const chat_transcript = @import\("chat_transcript\.zig"\);/);
  assert.match(session, /key\.agentId\(\) == entry\.key\.agentId\(\)/);
  assert.match(session, /app_state\.shells\[idx\]\.ai_agent = entry\.key\.agentId\(\);/);
});
