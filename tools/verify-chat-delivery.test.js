const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { names, queueName, sendName, sendTexts, sendSteps, allNames, queueTexts, queueSteps, agentBoundary, evaluateDelivery, evaluateEvidence } = require('./verify-chat-delivery/check-evidence.js');
const os = require('node:os');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const drive = read('tools/verify-chat-delivery/drive.ps1');
const workflow = read('.github/workflows/verify.yml');

const ps51Rules = [
  [/\[\s*(?:ushort|uint|ulong|short|sbyte|semver|bigint)\s*\]/i, '[ushort][char]::ToUpperInvariant($letter)'],
  [/\?\?|\?\.|\?\[/, '$value ?? $fallback'],
  [/\?(?![?.\[:])[^\r\n]*:/, '$ok ? 1 : 0'],
  [/&&|\|\|/, 'Get-Item a && Get-Item b'],
  [/(?:\bForEach-Object\b|\bforeach\b|%)[^\r\n]*-Parallel\b/i, 'ForEach-Object -Parallel { $_ }'],
  [/\[[^\r\n]*\[\s*\]\s*\]\s*::new\s*\(/i, '[Collections.Generic.List[]]::new()'],
  [/\bJoin-Path\b[^\r\n]*-AdditionalChildPath\b/i, 'Join-Path a b -AdditionalChildPath c'],
  [/\bGet-Content\b[^\r\n]*-AsByteStream\b/i, 'Get-Content file -AsByteStream'],
  [/\bConvertFrom-Json\b[^\r\n]*-(?:AsHashtable|Depth)\b/i, 'ConvertFrom-Json -AsHashtable'],
  [/-Encoding\s+['"]?utf8NoBOM\b/i, 'Out-File file -Encoding utf8NoBOM'],
];
const pathArgument = /'(?:[^']|'')*'|"(?:[^"`]|`.)*"|\([^()\r\n]*(?:\([^()\r\n]*\)[^()\r\n]*)*\)|\$[\w:]+|[\w./\\-]+/.source;
ps51Rules.push([new RegExp(String.raw`\bJoin-Path[ \t]+(?:-Path[ \t]+)?(?:${pathArgument})[ \t]+(?:-ChildPath[ \t]+)?(?:${pathArgument})[ \t]+(?:${pathArgument})`, 'i'), 'Join-Path a b c']);
const cs5Rules = [
  [/\$@?"|@\$"/, 'return $"value {value}";'],
  [/\b[\w.<>\[\]]+\s+\w+\s*\([^;{}]*\)\s*=>|\b[\w.<>\[\]]+\s+\w+\s*=>|\b(?:get|set)\s*=>/, 'public int Value() => 1;'],
  [/\bout\s+(?:var\s+\w+|_)\s*[,)]/, 'TryParse(text, out var value);'],
  [/\bnameof\s*\(/, 'nameof(value)'],
  [/\?\.|\?\[/, 'value?.ToString()'],
  [/\(\s*\w+(?:\s+\w+)?\s*,\s*\w+(?:\s+\w+)?\s*\)\s+\w+\s*[({=;]|(?:\breturn\s*|=\s*)\(\s*\w+\s*,\s*\w+\s*\)/, 'public (int X, int Y) Point() { return (1, 2); }'],
  [/\busing\s+static\b/, 'using static System.Math;'],
  [/\{\s*get;\s*(?:set;\s*)?\}\s*=/, 'public int Value { get; } = 1;'],
];
function assertsPS51(source) {
  for (const [pattern] of ps51Rules) assert.doesNotMatch(source.replace(/`\r?\n/g, ' '), pattern, `Windows PowerShell 5.1 compatibility: ${pattern}`);
}
function assertsCS5(source) {
  for (const [pattern] of cs5Rules) assert.doesNotMatch(source, pattern, `Add-Type C# 5 compatibility: ${pattern}`);
}

test('chat-delivery sources retain Windows PowerShell 5.1 and Add-Type C# 5 compatibility', () => {
  const directory = 'tools/verify-chat-delivery';
  const visit = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(entry => entry.isDirectory() ? visit(`${dir}/${entry.name}`) : [`${dir}/${entry.name}`]);
  for (const file of visit(directory)) {
    if (file.endsWith('.ps1')) assertsPS51(read(file));
    if (file.endsWith('.cs')) assertsCS5(read(file));
  }
  const control = read(skill + 'control.ps1');
  const end = control.indexOf("        'safe-updates' {");
  const start = control.indexOf("        'chat-delivery' {");
  assert.ok(start >= 0 && end > start);
  assertsPS51(control.slice(0, end));
  assert.match(drive, /\[uint16\]\[char\]::ToUpperInvariant\(\$letter\)/);
});

test('compatibility contracts reject old casts and each modern syntax control without rejecting valid 5.1/C#5 constructs', () => {
  for (const [pattern, broken] of ps51Rules) {
    assert.match(broken, pattern);
    assert.throws(() => assertsPS51(broken), /Windows PowerShell 5.1 compatibility/);
  }
  for (const broken of ['[uint]1', '[ulong]1', '[short]1', '[semver]1', '${value}?.Name', '${value}?[0]', '$value ??= 1', 'a || b', '% -Parallel { $_ }', 'Get-Content file `\n -AsByteStream', 'ConvertFrom-Json -Depth 4', 'Join-Path "a" "b" "c"', 'Join-Path -Path $root -ChildPath (Get-Location) "c"']) assert.throws(() => assertsPS51(broken));
  for (const [pattern, broken] of cs5Rules) {
    assert.match(broken, pattern);
    assert.throws(() => assertsCS5(broken), /Add-Type C# 5 compatibility/);
  }
  for (const broken of ['public int Value => 1;', 'get => value;', 'TryParse(text, out _);', 'return (left, right);', 'var pair = (1, 2);', 'public (int, int) Point() { return (1, 2); }', 'value?[0]']) assert.throws(() => assertsCS5(broken));
  assertsPS51('[uint16][char]::ToUpperInvariant($letter)\n[Collections.Generic.List[object]]::new()\n[Text.UTF8Encoding]::new($false)\nJoin-Path $env:RUNNER_TEMP (\'chat-delivery-\' + [guid]::NewGuid().ToString(\'N\'))');
  assertsCS5('public ushort Key; public int Value() { return 1; }\nEnumWindows((h,p) => { return true; }, IntPtr.Zero);\nint value; TryParse(text, out value);');
});

function gate(source) {
  const modern = source.match(/fn chatOutboxReadyToType\([^\n]+\) bool \{([\s\S]*?)\n\}/);
  let body = modern ? modern[1] : source.slice(source.indexOf('    const channel = chatTmuxSendEligible(shell_index);', source.indexOf('fn chatOutboxTrySendEntry(')), source.indexOf('    const echo_id =', source.indexOf('fn chatOutboxTrySendEntry(')));
  body = body.replace(/    const (?:channel|direct) = [^\n]+\n/g, '')
    .replaceAll('app_state.shells[shell_index].activity == .active', 'busy')
    .replaceAll('shell_index == app_state.active_shell and app_state.g_chat_screen_working', 'screen_working_here')
    .replaceAll('chatOutboxInputRowIdle(shell_index)', 'input_row_idle')
    .replaceAll('shell_index != app_state.active_shell', '!is_active_shell')
    .replaceAll(' and ', ' && ').replaceAll(' or ', ' || ');
  return new Function('channel', 'direct', 'busy', 'screen_working_here', 'input_row_idle', 'is_active_shell', body + '\nreturn true;');
}

test('811 rejects both channel scenarios while master and 821 admit them before local input gates', () => {
  const source = ref => execFileSync('git', ['show', `${ref}:src/chat_send.zig`], { cwd: root, encoding: 'utf8' });
  const old = source('v0.28.811');
  let master;
  let masterRef = 'master';
  try { master = source(masterRef); } catch { masterRef = 'origin/master'; master = source(masterRef); }
  for (const [ref, text] of [['v0.28.811', old], ['master', master], ['v0.28.821', source('v0.28.821')]]) {
    const ready = gate(text);
    assert.equal(ready(true, true, false, false, true, true), true, `${ref} blank idle positive control`);
    assert.equal(ready(true, true, true, true, true, true), ref !== 'v0.28.811', `${ref} busy channel`);
    assert.equal(ready(true, true, false, false, false, true), ref !== 'v0.28.811', `${ref} suggested input channel`);
    assert.equal(ready(false, true, false, false, false, true), false, `${ref} uncovered local suggestion gap`);
    assert.match(text, /\.op = "send"[\s\S]*chatHistoryPersistent\(job.key.host/);
    if (ref !== 'v0.28.811') assert.match(text, /"send_queued"/);
  }
  assert.match(master, /if \(entry.steer_pending\)|if \(!entry.steer_pending\)/);
  assert.match(master, /chatSteerAfterDelivery\(idx, i\)/);
  const reader = execFileSync('git', ['show', `${masterRef}:src/chat_history_reader.py`], { cwd: root, encoding: 'utf8' });
  assert.match(reader, /keys = \["C-x", "C-s"\] if op == "send_queued"/);
  assert.match(reader, /\["tmux", "send-keys", "-t", target, "-l", "--", text\]/);
  assert.match(reader, /\["tmux", "send-keys", "-t", target, "Enter"\]/);
});

const leftover = 'earlier long message about the weekly plan that keeps wrapping across rows';

function fixture(name = 'busy-send') {
  const observation = { name, text: 'typed public message', composerText: 'typed public message', actionMs: 1000, endMs: 16001, error: null, suggestion: 'Try the next step' };
  if (name === 'wrapped-leftover' || name === 'idle-suggestion') {
    const target = ['send-keys', '-t', '=verify-agent:'];
    const clear = name === 'idle-suggestion' ? ['C-u', 'C-u', 'C-k'] : ['C-u', 'C-u', 'C-u', 'C-u'];
    const rows = [...clear.map(key => [...target, key]), [...target, '-l', '--', observation.text], [...target, 'Enter']];
    return { observation, events: rows.map((argv, index) => ({ ms: 1100 + index, case: name, argv, submitted: index === rows.length - 1 ? observation.text : null, box: index === rows.length - 1 ? '' : 'box' })) };
  }
  const args = [['send-keys', '-t', '=verify-agent:', '-l', '--', observation.text], ['send-keys', '-t', '=verify-agent:', 'Enter']];
  if (name === 'steer-chord') args.push(['send-keys', '-t', '=verify-agent:', 'C-x', 'C-s']);
  return { observation, events: args.map((argv, index) => ({ ms: 1100 + index, case: name, argv })) };
}

test('buffer oracle accepts exactly typed text, Enter and the ordered steer chord', () => {
  for (const name of names) {
    const { observation, events } = fixture(name);
    assert.equal(evaluateDelivery(observation, events).writes, name === 'steer-chord' ? 3 : name === 'wrapped-leftover' ? 6 : name === 'idle-suggestion' ? 5 : 2);
  }
});

test('buffer oracle rejects busy waiting, suggestions, duplicates, missing Enter, premature chords and late delivery', () => {
  const mutations = [
    f => { f.events = []; },
    f => { f.events[0].argv[5] += ' grey suggestion'; },
    f => { f.events.push(f.events[1]); },
    f => { f.events.splice(1, 1); },
    f => { f.events.reverse(); },
    f => { f.events[0].ms = 16001; },
    f => { f.events[0].ms = 999; },
    f => { f.events[0].case = 'other'; },
    f => { f.observation.composerText = 'wrong'; },
    f => { f.observation.endMs = 15000; },
    f => { f.observation.error = 'launch failed'; },
  ];
  for (const mutate of mutations) {
    const control = fixture('steer-chord');
    evaluateDelivery(control.observation, control.events);
    mutate(control);
    assert.throws(() => evaluateDelivery(control.observation, control.events));
  }
});

test('wrapped-leftover oracle rejects the glued row, extra submissions, missing submission and late Enter', () => {
  const control = fixture('wrapped-leftover');
  evaluateDelivery(control.observation, control.events);
  const mutations = [
    f => { f.events[5].submitted = leftover.slice(0, 30) + f.observation.text; },
    f => { f.events[5].submitted = null; },
    f => { f.events[3].submitted = leftover.slice(0, 30); },
    f => { f.events.push({ ...f.events[5], ms: 1200 }); },
    f => { f.events[5].ms = 16001; },
    f => { delete f.events[5].submitted; },
    f => { f.events = []; },
  ];
  for (const mutate of mutations) {
    const broken = fixture('wrapped-leftover');
    mutate(broken);
    assert.throws(() => evaluateDelivery(broken.observation, broken.events));
  }
});

test('idle-suggestion oracle accepts clearing keys but rejects any submitted or typed suggestion', () => {
  const suggestion = 'Try the next step';
  const control = fixture('idle-suggestion');
  control.observation.suggestion = suggestion;
  evaluateDelivery(control.observation, control.events);
  const mutations = [
    f => { f.events[4].submitted = suggestion + f.observation.text; },
    f => { f.events[4].submitted = suggestion; },
    f => { f.events[3].argv[5] = suggestion + f.events[3].argv[5]; },
    f => { f.events[2].submitted = suggestion; },
    f => { f.events.pop(); },
    f => { f.events.push({ ...f.events[4], ms: 1200 }); },
  ];
  for (const mutate of mutations) {
    const broken = fixture('idle-suggestion');
    broken.observation.suggestion = suggestion;
    mutate(broken);
    assert.throws(() => evaluateDelivery(broken.observation, broken.events));
  }
});

test('missing evidence evaluates every case and never produces a false green', () => {
  const result = evaluateEvidence(path.join(root, 'tools/verify-chat-delivery/nonexistent-evidence'));
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.cases.map(row => row.name), allNames);
  assert.ok(result.cases.every(row => row.passed === false && row.detail));
  assert.equal(result.agentBoundary, agentBoundary);
});

function claudeBox(boundary, steps) {
  const script = String.raw`
import ast, json, pathlib, sys, tempfile
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
tree = ast.parse(source)
names = ("BOX_WIDTH", "box_rows", "ctrl_u", "ctrl_k")
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in names[1:] or isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "BOX_WIDTH" for target in node.targets)]
namespace = {}
exec(compile(ast.Module(body=selected, type_ignores=[]), sys.argv[1], "exec"), namespace)
cases = json.load(sys.stdin)
print(json.dumps([namespace["ctrl_u"](case) for case in cases] + [namespace["ctrl_k"](text, cursor) for text, cursor in [["a\nb", 1], ["abcdef", 1], ["x" * 70, 10], ["x" * 70, 30], ["abc", 3]]]))
`;
  return JSON.parse(execFileSync('python3', ['-I', '-c', script, boundary], { input: JSON.stringify(steps), encoding: 'utf8', timeout: 60000 }));
}

test('fake Claude box applies Ctrl+U by wrapped screen row and by trailing line break', () => {
  const boundary = path.join(root, 'tools/verify-chat-delivery/boundary.py');
  const line = leftover;
  assert.ok(line.length > 60 && line.length < 90);
  assert.deepEqual(claudeBox(boundary, [line + '\n', line, line.slice(0, 60), line.slice(0, 30), 'a\nb', 'a\n', '']), [line, line.slice(0, 60), line.slice(0, 30), '', 'a\n', 'a', '', 'ab', 'a', 'x'.repeat(10) + 'x'.repeat(40), 'x'.repeat(30) + 'x'.repeat(10), 'abc']);
  const boundarySource = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundarySource, /if stateful\(state\(\)\):\s+return box_send\(\)/);
  assert.match(boundarySource, /record\("agent-buffer.jsonl", argv=ARGS, submitted=submitted, box=buffer\)/);
  assert.match(boundarySource, /submitted = buffer if buffer.strip\(\) else None\s+buffer = ""/);
  assert.match(boundarySource, /if stateful\(value\):[\s\S]*rows = box_rows\(buffer\) if buffer else \[value\["suggestion"\]/);
  assert.match(boundarySource, /"  " \+ row \+ "\\n"/);
  assert.match(drive, /name='wrapped-leftover'; mode='busy'; text='wrapped delivery delta'; leftover='earlier long message about the weekly plan that keeps wrapping across rows'/);
  assert.match(drive, /if \(\$plan.ContainsKey\('leftover'\)\) \{ \$seed.leftover = \$plan.leftover/);
});

test('fake attach wraps every drawn line below the console width so a long draft cannot crash the redraw', () => {
  const boundary = path.join(root, 'tools/verify-chat-delivery/boundary.py');
  const script = String.raw`
import ast, json, pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "console_rows"]
namespace = {}
exec(compile(ast.Module(body=selected, type_ignores=[]), sys.argv[1], "exec"), namespace)
fixtures = json.load(sys.stdin)
print(json.dumps([namespace["console_rows"](case["lines"], case["width"]) for case in fixtures]))
`;
  const long = 'send 12 ' + 'long message about the weekly plan that keeps wrapping '.repeat(3).trim();
  assert.ok(long.length > 150);
  const cases = [
    { lines: ['Claude Code', '', '> ' + long, '-'.repeat(50)], width: 79 },
    { lines: ['  Queued: ' + long], width: 79 },
    { lines: ['', 'x'.repeat(79), 'y'.repeat(80)], width: 79 },
    { lines: ['abc'], width: 0 },
  ];
  const result = JSON.parse(execFileSync('python3', ['-I', '-c', script, boundary], { input: JSON.stringify(cases), encoding: 'utf8', timeout: 60000 }));
  for (const [index, rows] of result.entries()) {
    const width = Math.max(1, cases[index].width);
    assert.ok(rows.every(row => row.length <= width), `case ${index}`);
  }
  assert.equal(result[0].join(''), cases[0].lines.join(''));
  assert.equal(result[0].length, 2 + Math.ceil(('> ' + long).length / 79) + 1);
  assert.deepEqual(result[2], ['', 'x'.repeat(79), 'y'.repeat(79), 'y']);
  assert.deepEqual(result[3], ['a', 'b', 'c']);
  const source = read('tools/verify-chat-delivery/boundary.py');
  assert.match(source, /lines = console_rows\(shown.splitlines\(\), info.size.X - 1\)/);
  assert.match(source, /text = "\\r\\n".join\(lines\) \+ "\\r\\n"/);
});

test('boundary runs the actual supplied Python bootstrap and logs raw fake tmux writes without fabricating text', () => {
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundary, /shlex.split\(command\[python.start\(\):\]\)/);
  assert.match(boundary, /subprocess.call\(\[sys.executable, \*remote\[1:\]\], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer/);
  assert.match(boundary, /if ARGS\[:1\] == \["send-keys"\]:\s+if stateful\(state\(\)\):\s+return box_send\(\)\s+record\("agent-buffer.jsonl", argv=ARGS\)/);
  assert.match(boundary, /if ARGS\[:1\] == \["capture-pane"\]/);
  assert.match(boundary, /esc to interrupt/);
  assert.match(boundary, /\\u276f/);
  assert.match(boundary, /FillConsoleOutputAttribute\(handle, 8, len\(value\["suggestion"\]\), COORD\(2, top \+ 4\)/);
  assert.doesNotMatch(boundary, /typed public message|busy delivery alpha|idle delivery beta|steer delivery gamma/);
  const launcher = read('tools/verify-chat-delivery/launcher.c');
  assert.match(launcher, /GetCommandLineW\(\)/);
  assert.match(launcher, /CreateProcessW\(python, command, NULL, NULL, TRUE/);
});

test('background host probes are explicitly declined and unknown remote commands remain diagnostic failures', () => {
  const literals = source => [...source.matchAll(/"(?:\\.|[^"\\])*"/g)].map(match => JSON.parse(match[0]));
  const app = read('src/app_state.zig');
  const constant = name => literals(app.match(new RegExp('pub const ' + name + ' =([\\s\\S]*?);\\n'))[1]).join('');
  const poll = constant('VPS_PROBE_SCRIPT') + constant('VPS_TMUX_LIST_SCRIPT');
  const literal = (source, needle) => JSON.parse([...source.matchAll(/"(?:\\.|[^"\\\r\n])*"/g)].find(match => match[0].includes(needle))[0]);
  const vps = read('src/vps.zig');
  const loopStart = literal(vps, 'while IFS= read -r _; do { ');
  const loopEnd = literal(vps, '; } </dev/null; printf');
  assert.ok(loopStart && loopEnd);
  const relay = literal(read('src/console.zig'), 'if test -f ~/.local/state/multiprompt/relay-v1;');
  const relayCommand = relay.slice(relay.indexOf('"') + 1, -1).replace('{s}', 'fixture-0123456789abcdef');
  const ladder = literal(read('src/telemetry_panel.zig'), ' cat ~/.local/state/token-ladder/status.json').split(' {s} ')[1];
  const probes = [];
  for (const host of ['remote-1', 'remote-2', 'remote-3']) {
    const options = ['-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', host];
    for (const [remote, kind, output, code] of [
      [poll, 'capacity-poll', '', 1],
      [(loopStart + poll + loopEnd).slice(2, -1), 'capacity-poll', '', 1],
      [relayCommand, 'notification-relay', 'MP_RELAY_LEGACY\n', 0],
    ]) probes.push({ argv: [...options, remote], kind, output, code });
    for (const name of ['SSH_TUNNEL_KEEPER_OPTS', 'SSH_TUNNEL_KEEPER_OPTS_BATTERY']) {
      probes.push({ argv: [...constant(name).trim().split(' '), '-R', '19548:127.0.0.1:12345', host], kind: 'notification-forward', output: '', code: 255 });
    }
  }
  probes.push({ argv: ['-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', 'remote-2', ...ladder.split(' ')], kind: 'ladder-status', output: '', code: 1 });
  const unknown = [
    ['-T', 'remote-1', 'uname -a'],
    ['-T', 'remote-1', relayCommand + '; unexpected-operation'],
    ['-T', 'remote-2', ladder + '.unknown'],
    ['-N', '-R', '12345:127.0.0.1:12345', 'remote-1'],
    ['-N', '-R', '19548:127.0.0.1:12345', 'remote-1', 'unexpected-operation'],
  ];
  const script = String.raw`
import ast, contextlib, io, json, os, pathlib, re, shlex, sys, tempfile, time
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("state", "record", "declined_remote", "ssh") or isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "VPS_POLL_COMMAND" for target in node.targets)]
namespace = dict(json=json, os=os, re=re, shlex=shlex, sys=sys, time=time)
exec(compile(ast.Module(body=selected, type_ignores=[]), sys.argv[1], "exec"), namespace)
fixtures = json.load(sys.stdin)
with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    namespace["ROOT"] = root
    (root / "state.json").write_text(json.dumps(dict(name="busy-send")), encoding="utf-8")
    (root / "agent-buffer.jsonl").write_text("existing delivery evidence\n", encoding="utf-8")
    def rows(name):
        file = root / name
        return [json.loads(line) for line in file.read_text(encoding="utf-8").splitlines()] if file.exists() else []
    for probe in fixtures["probes"]:
        argv = probe["argv"]
        namespace["ARGS"] = argv
        assert namespace["declined_remote"](argv) == (probe["kind"], probe["output"], probe["code"]), argv
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            assert namespace["ssh"]() == probe["code"], argv
        assert output.getvalue() == probe["output"], argv
        row = rows("declined.jsonl")[-1]
        assert row["argv"] == argv and row["command"] == " ".join(argv), row
        assert row["kind"] == probe["kind"] and row["exitCode"] == probe["code"], row
        assert row["case"] == "busy-send" and row["ms"] > 0 and row["pid"] > 0, row
    assert len(rows("declined.jsonl")) == len(fixtures["probes"])
    assert not rows("unsupported.jsonl")
    for argv in fixtures["unknown"]:
        namespace["ARGS"] = argv
        assert namespace["declined_remote"](argv) is None, argv
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            assert namespace["ssh"]() == 96, argv
        assert output.getvalue() == ""
        row = rows("unsupported.jsonl")[-1]
        assert row["argv"] == argv and row["command"] == " ".join(argv), row
        assert row["operation"] == "remote command" and row["hasPython"] is False, row
    assert len(rows("unsupported.jsonl")) == len(fixtures["unknown"])
    assert len(rows("declined.jsonl")) == len(fixtures["probes"])
    assert not rows("invocations.jsonl") and not rows("capture.jsonl")
    assert (root / "agent-buffer.jsonl").read_text(encoding="utf-8") == "existing delivery evidence\n"
print("probe classification passed")
`;
  const output = execFileSync('python3', ['-I', '-c', script, path.join(root, 'tools/verify-chat-delivery/boundary.py')], { input: JSON.stringify({ probes, unknown }), encoding: 'utf8', timeout: 60000 });
  assert.equal(output.trim(), 'probe classification passed');
});

function assertsConsoleLaunch(launcher) {
  assert.match(launcher, /si.dwFlags = STARTF_USESTDHANDLES \| STARTF_USESHOWWINDOW;/);
  assert.match(launcher, /si.wShowWindow = SW_SHOWNOACTIVATE;/);
  assert.match(launcher, /CreateProcessW\(python, command, NULL, NULL, TRUE, GetConsoleWindow\(\) == NULL \? CREATE_NO_WINDOW : 0,/);
  for (const name of ['Input', 'Output', 'Error']) assert.match(launcher, new RegExp(`si.hStd${name} = GetStdHandle\\(STD_${name.toUpperCase()}_HANDLE\\)`));
  assert.doesNotMatch(launcher, /AllocConsole|FreeConsole|DETACHED_PROCESS|GetFileType/);
}

test('console-less probes cannot create an activated Python console while attached screen consoles remain inherited', () => {
  const launcher = read('tools/verify-chat-delivery/launcher.c');
  assertsConsoleLaunch(launcher);
  for (const [before, after] of [
    ['GetConsoleWindow() == NULL', 'GetFileType(si.hStdOutput) == FILE_TYPE_PIPE'],
    ['? CREATE_NO_WINDOW : 0', '? CREATE_NO_WINDOW : CREATE_NO_WINDOW'],
    ['STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW', 'STARTF_USESTDHANDLES'],
    ['SW_SHOWNOACTIVATE', 'SW_SHOW'],
  ]) {
    const broken = launcher.replace(before, after);
    assert.notEqual(broken, launcher);
    assert.throws(() => assertsConsoleLaunch(broken));
  }
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundary, /handle = kernel.GetStdHandle\(-11\)/);
  assert.match(boundary, /GetConsoleScreenBufferInfo\(handle/);
  assert.match(boundary, /ReadConsoleOutputCharacterW\(handle/);
});

function assertsForeground(desktop, driver) {
  const original = read(skill + 'control.ps1');
  const routine = source => {
    const start = source.indexOf('        Message message;', source.indexOf(' FocusOwnedWindow('));
    const end = source.indexOf('\n        }\n', source.indexOf('        } finally {', start));
    assert.ok(start >= 0 && end > start);
    return source.slice(start, end + 10).trim();
  };
  const expected = routine(original);
  assert.ok(expected.startsWith('Message message;') && expected.endsWith('}'));
  assert.equal(routine(desktop).replace('keybd_event(0x12, 0, 0, UIntPtr.Zero);', 'Key(0x12, 0, 0);').replace('keybd_event(0x12, 0, 2, UIntPtr.Zero);', 'Key(0x12, 0, 2);').replace('SetFocus(focus);', 'SetFocus(hwnd);'), expected);
  assert.match(desktop, /SetFocus\(focus\);/);
  assert.match(desktop, /actualPid != pid \|\| Class\(hwnd\) != "ZigShell"/);
  assert.match(desktop, /Owner\(focus\) != pid \|\| \(focus != hwnd && !IsChild\(hwnd, focus\)\)/);
  assert.match(desktop, /return GetForegroundWindow\(\) == hwnd && Focus\(hwnd\)\[1\] == focus.ToInt64\(\);/);
  assert.match(driver, /Wait-For 'owned app foreground' \{ \[ChatDeliveryDesktop\]::FocusOwnedWindow\(\$main, \$app.Id, \$main\) \}/);
  const press = driver.slice(driver.indexOf('function Press('), driver.indexOf('foreach ($plan in $plans)'));
  assert.match(press, /Doctor\s+if \(\[ChatDeliveryDesktop\]::GetForegroundWindow\(\) -ne \$main\) \{\s+\$target = if \(\$Chat\) \{ \$composer \} else \{ \$main \}\s+\[void\]\[ChatDeliveryDesktop\]::FocusOwnedWindow\(\$main, \$app.Id, \$target\)/);
  assert.match(press, /if \(\$Chat\) \{ Doctor \$true \}\s+if \(\[ChatDeliveryDesktop\]::GetForegroundWindow\(\) -ne \$main\) \{ throw 'Refusing keyboard input: owned app is not foreground' \}[\s\S]*::Chord\(\$Keys\)/);
  assert.doesNotMatch(driver, /::SetForegroundWindow/);
}

test('foreground uses the existing Alt and AttachThreadInput routine before keyboard input without weakening refusal', () => {
  const desktop = read('tools/verify-chat-delivery/desktop.cs');
  assertsForeground(desktop, drive);
  for (const [before, after] of [
    ['PeekMessage(out message, IntPtr.Zero, 0, 0, 0);', ''],
    ['keybd_event(0x12, 0, 0, UIntPtr.Zero);', ''],
    ['AttachThreadInput(currentThread, foregroundThread, true)', 'false'],
    ['AttachThreadInput(currentThread, targetThread, true)', 'false'],
    ['AttachThreadInput(currentThread, targetThread, false)', 'AttachThreadInput(currentThread, targetThread, true)'],
    ['SetFocus(focus);', 'SetFocus(hwnd);'],
    ['actualPid != pid', 'false'],
    ['!IsChild(hwnd, focus)', 'false'],
  ]) {
    const broken = desktop.replace(before, after);
    assert.notEqual(broken, desktop);
    assert.throws(() => assertsForeground(broken, drive));
  }
  for (const [before, after] of [
    ['[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $target)', ''],
    ["throw 'Refusing keyboard input: owned app is not foreground'", 'return'],
    ['if ($Chat) { Doctor $true }', ''],
  ]) {
    const broken = drive.replaceAll(before, after);
    assert.notEqual(broken, drive);
    assert.throws(() => assertsForeground(desktop, broken));
  }
});

test('keyboard journey isolates each case and retains Doctor, screenshots, raw evidence and owned-job cleanup', () => {
  for (const name of names) assert.ok(drive.includes(`name='${name}'`));
  assert.match(drive, /foreach \(\$plan in \$plans\) \{[\s\S]*try \{[\s\S]*catch \{[\s\S]*finally \{/);
  for (const text of ['RUNNER_TEMP', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'ssh-path.txt', 'session.json', 'tmux_host=0', "tmux_session='verify-agent'", 'MPVERSION=', 'UIAutomation', 'Get-FileHash', 'GetForegroundWindow', '::Focus($main)', 'composerText', 'agent-buffer.jsonl', 'invocations.jsonl', 'debug.log', 'cleanup.json']) assert.ok(drive.includes(text.replaceAll('\n', '`n')), text);
  assert.match(drive, /Press @\(0x11, 0x31\)/);
  assert.match(drive, /Press @\(0x12, 0x43\)/);
  assert.match(drive, /Press @\(0x0D\)/);
  assert.match(drive, /Press @\(0x11, 0x58\)[\s\S]*Press @\(0x11, 0x53\)/);
  assert.match(drive, /actionMs \+ 15000/);
  assert.match(drive, /\$job.Start\([\s\S]*\$job.Stop\(\)[\s\S]*Copy-Item \$state[\s\S]*Remove-Item -LiteralPath \$profile/);
  assert.doesNotMatch(drive, /Stop-Process|taskkill|PostMessage|SetFocus|SetWindowText|::Click|::Activate|Invoke-Expression/);
  const job = read('tools/verify-chat-delivery/job.cs');
  const control = read(skill + 'control.ps1');
  const original = control.slice(control.indexOf('public sealed class VerifyJob : IDisposable {'), control.indexOf("\n'@", control.indexOf('public sealed class VerifyJob : IDisposable {'))).trim();
  assert.ok(job.endsWith(original + '\n'), 'same owned-job implementation as control.ps1');
  assert.match(job, /limits.Basic.Flags = 0x2000/);
  assert.ok(job.indexOf('AssignProcessToJobObject(job, native.Process)') < job.indexOf('ResumeThread(native.Thread)'));
  const desktop = read('tools/verify-chat-delivery/desktop.cs');
  assert.match(desktop, /SendInput\(\(uint\)inputs.Length/);
  assert.doesNotMatch(desktop, /WriteConsoleInput|WM_SETTEXT|PostMessage/);
});

test('feature dispatch compiles only the system boundary on release runs and preserves verified executable selection', () => {
  assert.match(workflow, /FEATURE -notin @\([^\n]*'chat-delivery'/);
  assert.match(read(skill + 'control.ps1'), /'chat-delivery' \{[\s\S]*verify-chat-delivery\/drive.ps1/);
  assert.match(workflow, /if: env.RELEASE_TAG == '' \|\| env.FEATURE == 'chat-delivery'/);
  assert.match(workflow, /zig cc[^\n]*-municode[^\n]*verify-chat-delivery\/launcher.c/);
  assert.match(workflow, /zig cc[^\n]*-mwindows[^\n]*verify-bin\/tmux.exe/);
  assert.match(workflow, /actions\/setup-python@[a-f0-9]{40}/);
  assert.match(workflow, /gh release download \$env:RELEASE_TAG/);
  assert.match(workflow, /Release checksum mismatch/);
  assert.match(workflow, /name: verify-\$\{\{ env.FEATURE \}\}/);
  assert.match(workflow, /verify-chat-delivery\/drive.ps1[\s\S]*errors.Count/);
  assert.ok(workflow.includes('- tools/verify-chat-delivery/**'));
});

test('delivery maps state both the accepted boundary and uncovered local console gap', () => {
  const map = read(skill + 'features/chat-delivery.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']);
  for (const name of names) assert.ok(map.includes(name));
  assert.match(map, /v0.28.811/);
  assert.match(map, /v0.28.821/);
  assert.match(map, /local direct-input[\s\S]*suggestion/);
  assert.match(read(skill + 'features/README.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
  assert.match(read(skill + 'SKILL.md'), /\[Chat delivery\]\(features\/chat-delivery.md\)/);
  assert.match(read(skill + 'features/chat-view.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
});

test('delivery implementation adds no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [file, language] of [
    ['tools/verify-chat-delivery.test.js', 'javascript'],
    ['tools/verify-chat-delivery/check-evidence.js', 'javascript'],
    ['tools/verify-chat-delivery/drive.ps1', 'powershell'],
    ['tools/verify-chat-delivery/launcher.c', 'c'],
    ['tools/verify-chat-delivery/desktop.cs', 'c'],
    ['tools/verify-chat-delivery/job.cs', 'c'],
  ]) assert.equal(strip(read(file), language).commentLines, 0, file);
  assert.doesNotMatch(read('tools/verify-chat-delivery/boundary.py'), /^\s*#/m);
});

function queueFiles(base) {
  const t = queueTexts;
  const name = queueName;
  const out = new Map();
  const put = (file, value) => out.set(path.join(base, file), typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  const log = (file, rows) => out.set(path.join(base, file), rows.map(row => JSON.stringify(row)).join('\n'));
  const png = Buffer.alloc(15000);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  const render = (mode, queue, box, escapes) => {
    const rows = box ? box.split('\n') : [''];
    const first = mode === 'idle' && !box ? (escapes ? `\u001b[2m${t.suggestion}\u001b[0m` : t.suggestion) : rows[0];
    return ['Claude Code', '', mode === 'busy' ? 'Working... (esc to interrupt)' : 'Ready', '', ...queue.map(text => `  Queued: ${text}`), `❯ ${first}`, ...rows.slice(1).map(text => `  ${text}`), '─'.repeat(50)].join('\n') + '\n';
  };
  const script = [
    ['shell', 'text', 'busy', [], t.a], ['shell', 'key', 'busy', [t.a], ''],
    ['app', 'send-keys', 'busy', [t.a], t.b], ['app', 'send-keys', 'busy', [t.a, t.b], ''],
    ['shell', 'key', 'busy', [], `${t.a}\n${t.b}`], ['shell', 'key', 'busy', [], ''],
    ['shell', 'text', 'busy', [], t.a2], ['shell', 'key', 'busy', [t.a2], ''],
    ['shell', 'text', 'busy', [t.a2], t.b], ['shell', 'key', 'busy', [t.a2, t.b], ''],
    ['shell', 'idle', 'idle', [], ''],
    ['shell', 'text', 'idle', [], t.shellDraft], ['shell', 'key', 'idle', [], ''],
    ['app', 'send-keys', 'idle', [], t.chatDraft],
    ['shell', 'text', 'idle', [], t.chatDraft + t.agentPaste],
  ];
  log(`${name}/stand-in/frames.jsonl`, script.map(([origin, op, mode, queue, box], index) => ({
    ms: 2000 + index, case: name, origin, op, argv: [], mode, queue, box, suggestionShown: mode === 'idle' && !box,
    screen: render(mode, queue, box, false), escaped: render(mode, queue, box, true),
  })));
  const event = (type, fields) => ({ type, timestamp: '2026-10-23T10:00:00.000Z', sessionId: 'sid', ...fields });
  const queued = (operation, content, extra) => event('queue-operation', { operation, ...(content === undefined ? {} : { content }), ...extra });
  log(`${name}/transcript.jsonl`, [
    event('user', { message: { role: 'user', content: 'start' } }),
    queued('enqueue', t.a), queued('enqueue', t.b), queued('popAll', `${t.a}\n${t.b}`),
    queued('enqueue', t.a2), queued('enqueue', t.b),
    queued('remove', t.a2, { reason: 'absorbed_mid_turn' }), event('attachment', { attachment: { type: 'queued_command', prompt: t.a2 } }),
    queued('dequeue'), event('attachment', { attachment: { type: 'queued_command', prompt: t.b } }),
  ]);
  const item = (state, text) => ({ text, state });
  const views = [[item('queued', t.a)], [item('queued', t.a), item('queued', t.b)], [], [item('queued', t.a2)], [item('queued', t.a2), item('queued', t.b)], [item('sent', t.a2), item('sent', t.b)]];
  put(`${name}/debug.log`, ['2026-10-23 10:00:00.000 [chat] transcript load shell=1 ok bytes=900 ms=5', ...views.map(view => `2026-10-23 10:00:01.000 CHAT_QUEUE items=${JSON.stringify(view)}`)].join('\n'));
  put('build.json', { version: '0.0.1', sha256: 'a'.repeat(64) });
  put(`${name}/observation.json`, { name, text: t.b, mode: 'busy', actionMs: 1000, endMs: 3000, error: null, texts: t, steps: queueSteps.map(step => ({ name: step, ok: true, ms: 1500, waitedMs: 100 })) });
  put(`${name}/stand-in/state.json`, { name, mode: 'busy', suggestion: t.suggestion, fake: true });
  const send = (...argv) => ({ ms: 1500, case: name, argv: ['send-keys', '-t', '=verify-agent:', ...argv] });
  log(`${name}/stand-in/agent-buffer.jsonl`, [send('-l', '--', t.b), send('Enter'), send('C-u'), send('-l', '--', t.chatDraft)]);
  const consoleRow = (mode, box) => {
    const screen = render(mode, [], box, false);
    return { case: name, session: 'verify-agent', screen, rows: screen.trimEnd().split('\n').map(line => line.trimEnd()), greySuggestion: mode === 'idle' && !box, suggestionAttribute: mode === 'idle' && !box ? 8 : 7 };
  };
  log(`${name}/stand-in/console.jsonl`, [consoleRow('busy', ''), consoleRow('idle', '')]);
  log(`${name}/stand-in/capture.jsonl`, [{ case: name, argv: ['capture-pane', '-p', '-J'], screen: render('busy', [], '', false) }]);
  log(`${name}/stand-in/invocations.jsonl`, [
    { kind: 'attach', session: 'verify-agent' },
    { kind: 'reader', argv: ['python3', '-u', '-c', 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))', '--serve'] },
  ]);
  put(`${name}/doctor.json`, { version: '0.0.1', sha256: 'a'.repeat(64), pid: 1, hwnd: 2, composer: 3, focus: [2, 3], chat: true, tmux: true });
  put(`${name}/cleanup.json`, { remaining_owned_processes: 0, evidence_preserved: true, scratch_removed: true });
  put(`${name}/process-tree.json`, { ActiveProcesses: 0 });
  put(`${name}/session-chat.json`, { active_tab: 0, tabs: [{ kind: 'tmux', tmux_session: 'verify-agent', cv: true }] });
  for (const suffix of ['before', 'action', 'after', 'final']) out.set(path.join(base, `${name}-${suffix}.png`), png);
  const act = (input, extra) => ({ case: name, ms: 1000, input, ...extra });
  const actions = [
    act('Ctrl+1: select saved tmux tab'), act('Alt+C: open Chat View'),
    ...Array.from({ length: 10 }, () => act('shell input')),
    act('type composer text', { text: t.b }), act('type composer text', { text: t.chatDraft }),
  ];
  return { files: out, actions };
}

function sendFiles(base) {
  const name = sendName;
  const out = new Map();
  const put = (file, value) => out.set(path.join(base, file), JSON.stringify(value));
  const png = Buffer.alloc(15000);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  const event = (type, fields) => ({ type, timestamp: '2026-10-23T10:00:00.000Z', sessionId: 'sid', ...fields });
  out.set(path.join(base, `${name}/transcript.jsonl`), [event('user', { message: { role: 'user', content: 'start' } }), ...sendTexts.map(text => event('queue-operation', { operation: 'enqueue', content: text }))].map(row => JSON.stringify(row)).join('\n'));
  put(`${name}/observation.json`, {
    name, text: 'send stays gone', mode: 'busy', actionMs: 1000, endMs: 3000, error: null,
    steps: sendSteps.map(step => ({ name: step, ok: true, ms: 1500, waitedMs: 100 })),
    sends: sendTexts.map((text, i) => ({ n: i + 1, text, reached: true, reappeared: null })),
  });
  put(`${name}/outbox-final.json`, { queues: [] });
  put(`${name}/cleanup.json`, { remaining_owned_processes: 0, evidence_preserved: true, scratch_removed: true });
  out.set(path.join(base, `${name}-final.png`), png);
  const actions = sendTexts.flatMap(text => [{ case: name, ms: 1000, input: 'type composer text', text }, { case: name, ms: 1001, input: 'Enter: send composer' }]);
  return { files: out, actions };
}

function mockFiles(t, files) {
  t.mock.method(fs, 'existsSync', file => files.has(String(file)));
  t.mock.method(fs, 'readFileSync', (file, encoding) => {
    if (!files.has(String(file))) throw new Error(`Missing fixture ${file}`);
    const value = files.get(String(file));
    return encoding && Buffer.isBuffer(value) ? value.toString(encoding) : value;
  });
}


test('full evidence oracle recomputes all cases and rejects corrupt screens, identity, actions and cleanup', t => {
  const files = new Map();
  const base = path.join(root, 'tools/verify-chat-delivery/in-memory-evidence');
  const put = (file, value) => files.set(path.join(base, file), JSON.stringify(value));
  const log = (file, rows) => files.set(path.join(base, file), rows.map(row => JSON.stringify(row)).join('\n'));
  const png = Buffer.alloc(15000);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  put('build.json', { version: '0.0.1', sha256: 'a'.repeat(64) });
  const actions = [];
  for (const name of names) {
    const { observation, events } = fixture(name);
    observation.mode = name === 'idle-suggestion' ? 'idle' : 'busy';
    observation.suggestion = 'Try the next step';
    const wrapped = name === 'wrapped-leftover';
    if (wrapped) observation.leftover = leftover;
    put(`${name}/observation.json`, observation);
    log(`${name}/stand-in/agent-buffer.jsonl`, events);
    put(`${name}/stand-in/state.json`, { name, mode: observation.mode, suggestion: observation.suggestion, ...(wrapped ? { leftover } : {}) });
    const prompt = wrapped ? `${leftover.slice(0, 30)}\n  ${leftover.slice(30, 60)}\n  ${leftover.slice(60)}\n  ` : observation.mode === 'idle' ? observation.suggestion : '';
    const shown = `Claude Code\n\n${observation.mode === 'busy' ? 'Working... (esc to interrupt)' : 'Ready'}\n\n❯ ${prompt}\n${'─'.repeat(50)}\n`;
    put(`${name}/stand-in/ready.json`, { screen: shown });
    log(`${name}/stand-in/console.jsonl`, [{ screen: shown, session: 'verify-agent', rows: shown.trimEnd().split('\n').map(line => line.trimEnd()), greySuggestion: observation.mode === 'idle', suggestionAttribute: observation.mode === 'idle' ? 8 : 7 }]);
    log(`${name}/stand-in/capture.jsonl`, [{ case: name, screen: shown }, ...(wrapped ? [{ case: name, screen: `Claude Code\n\nWorking... (esc to interrupt)\n\n❯ \n${'─'.repeat(50)}\n` }] : [])]);
    log(`${name}/stand-in/invocations.jsonl`, [
      { kind: 'attach', session: 'verify-agent' },
      { kind: 'reader', argv: ['python3', '-u', '-c', 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))', '--serve'] },
    ]);
    put(`${name}/doctor.json`, { version: '0.0.1', sha256: 'a'.repeat(64), pid: 1, hwnd: 2, composer: 3, focus: [2, 3], chat: true, tmux: true });
    put(`${name}/cleanup.json`, { remaining_owned_processes: 0, evidence_preserved: true, scratch_removed: true });
    put(`${name}/process-tree.json`, { ActiveProcesses: 0 });
    put(`${name}/session-chat.json`, { active_tab: 0, tabs: [{ kind: 'tmux', tmux_session: 'verify-agent', cv: true }] });
    files.set(path.join(base, name, 'debug.log'), 'app debug evidence');
    for (const suffix of ['before', 'action', 'after', 'final']) files.set(path.join(base, `${name}-${suffix}.png`), png);
    for (const input of ['Ctrl+1: select saved tmux tab', 'Alt+C: open Chat View', 'type composer text', ...(name === 'steer-chord' ? ['Ctrl+X: steer prefix', 'Ctrl+S: steer send'] : ['Enter: send composer'])]) actions.push({ case: name, input, text: observation.text });
  }
  const queue = queueFiles(base);
  for (const [file, value] of queue.files) files.set(file, value);
  const send = sendFiles(base);
  for (const [file, value] of send.files) files.set(file, value);
  const allActions = [...actions, ...queue.actions, ...send.actions];
  put('actions.json', allActions);
  files.set(path.join(base, 'before.png'), png);
  files.set(path.join(base, 'after.png'), png);
  t.mock.method(fs, 'existsSync', file => files.has(String(file)));
  t.mock.method(fs, 'readFileSync', (file, encoding) => {
    if (!files.has(String(file))) throw new Error(`Missing fixture ${file}`);
    const value = files.get(String(file));
    return encoding && Buffer.isBuffer(value) ? value.toString(encoding) : value;
  });
  assert.equal(evaluateEvidence(base).status, 'passed');
  const positive = new Map(files);
  const mutations = [
    () => log('busy-send/stand-in/agent-buffer.jsonl', []),
    () => log('idle-suggestion/stand-in/capture.jsonl', [{ case: 'idle-suggestion', screen: '❯ blank' }]),
    () => put('idle-suggestion/stand-in/state.json', { name: 'idle-suggestion', mode: 'idle', suggestion: '' }),
    () => put('steer-chord/cleanup.json', { remaining_owned_processes: 1, evidence_preserved: true, scratch_removed: true }),
    () => put('steer-chord/doctor.json', { version: 'wrong' }),
    () => put('busy-send/session-chat.json', { active_tab: 1 }),
    () => files.set(path.join(base, 'busy-send-after.png'), Buffer.alloc(15000)),
    () => put('actions.json', allActions.filter(row => row.input !== 'Ctrl+S: steer send')),
    () => log('busy-send/stand-in/unsupported.jsonl', [{ operation: 'ignored' }]),
    () => log('wrapped-leftover/stand-in/agent-buffer.jsonl', fixture('wrapped-leftover').events.map(event => ({ ...event, submitted: event.submitted && leftover.slice(0, 30) + event.submitted }))),
    () => log('wrapped-leftover/stand-in/capture.jsonl', [{ case: 'wrapped-leftover', screen: '❯ unseeded' }]),
    () => log('idle-suggestion/stand-in/console.jsonl', [{ screen: '❯ without suggestion', session: 'verify-agent', greySuggestion: true }]),
  ];
  for (const mutate of mutations) {
    files.clear();
    for (const [file, value] of positive) files.set(file, value);
    assert.equal(evaluateEvidence(base).status, 'passed');
    mutate();
    const result = evaluateEvidence(base);
    assert.equal(result.status, 'failed');
    assert.equal(result.cases.length, allNames.length);
    assert.equal(result.cases.filter(row => !row.passed).length, 1);
  }
});


function queueRow(base) {
  return evaluateEvidence(base).cases.find(row => row.name === queueName);
}

test('queue-draft-sync evidence passes only with both views, ordered queue states, sent marks and draft sync', t => {
  const base = path.join(root, 'tools/verify-chat-delivery/in-memory-queue-evidence');
  const { files, actions } = queueFiles(base);
  files.set(path.join(base, 'actions.json'), JSON.stringify(actions));
  mockFiles(t, files);
  const green = queueRow(base);
  assert.equal(green.passed, true, JSON.stringify(green.detail));
  assert.equal(green.detail.queueViews, 6);
  const positive = new Map(files);
  const file = name => path.join(base, queueName, name);
  const mutate = (label, edit) => {
    files.clear();
    for (const [key, value] of positive) files.set(key, value);
    edit();
    const row = queueRow(base);
    assert.equal(row.passed, false, `${label} must fail`);
    return row.detail;
  };
  const debug = edit => () => files.set(file('debug.log'), edit(files.get(file('debug.log'))));
  const without = pattern => debug(text => text.split('\n').filter(line => !pattern.test(line)).join('\n'));
  const frames = edit => () => files.set(file('stand-in/frames.jsonl'), edit(files.get(file('stand-in/frames.jsonl')).split('\n')).join('\n'));
  assert.match(mutate('no queue view at all', without(/CHAT_QUEUE/)), /Chat View never listed/);
  assert.match(mutate('shell queued message never shown', without(/"shell queued alpha","state":"queued"\}\]$/)), /Chat View never listed/);
  assert.match(mutate('order swapped', debug(text => text.replace('[{"text":"shell queued alpha","state":"queued"},{"text":"chat queued beta","state":"queued"}]', '[{"text":"chat queued beta","state":"queued"},{"text":"shell queued alpha","state":"queued"}]'))), /Chat View never listed/);
  assert.match(mutate('sent never marked', debug(text => text.replaceAll('"state":"sent"', '"state":"queued"'))), /Chat View never listed/);
  assert.match(mutate('edit never reflected', without(/shell queued alpha edited/)), /Chat View never listed/);
  assert.match(mutate('transcript never read', debug(text => text.replace('transcript load shell=1 ok', 'transcript load shell=1 fail'))), /Chat View read the fake session transcript/);
  assert.match(mutate('draft never reaches shell box', frames(rows => rows.slice(0, -2))), /expected shell frame missing/);
  assert.match(mutate('draft reached the box from the shell', frames(rows => rows.map(row => row.replace('"origin":"app","op":"send-keys","argv":[],"mode":"idle"', '"origin":"shell","op":"send-keys","argv":[],"mode":"idle"')))), /expected shell frame missing|draft reached/);
  assert.match(mutate('failed journey step', () => files.set(file('observation.json'), files.get(file('observation.json')).replace('{"name":"composer-ignores-agent-paste","ok":true', '{"name":"composer-ignores-agent-paste","ok":false'))), /journey steps failed: composer-ignores-agent-paste/);
  assert.match(mutate('missing journey step', () => files.set(file('observation.json'), files.get(file('observation.json')).replace('"suggestion-not-draft"', '"renamed"'))), /every journey step ran in order/);
  assert.match(mutate('suggestion treated as text', () => files.set(file('stand-in/agent-buffer.jsonl'), files.get(file('stand-in/agent-buffer.jsonl')) + '\n' + JSON.stringify({ ms: 1, case: queueName, argv: ['send-keys', '-l', '--', queueTexts.suggestion] }))), /grey suggestion was never treated as text/);
  assert.match(mutate('Claude never took the queue', () => files.set(file('transcript.jsonl'), files.get(file('transcript.jsonl')).split('\n').slice(0, -2).join('\n'))), /./);
  assert.match(mutate('suggestion not rendered dim', frames(rows => rows.map(row => row.replaceAll('\\u001b[2m', '')))), /dim suggestion rendered/);
  assert.match(mutate('unsupported boundary operation', () => files.set(file('stand-in/unsupported.jsonl'), '{"operation":"x"}')), /no silently unsupported/);
  assert.match(mutate('shell never driven', () => files.set(path.join(base, 'actions.json'), '[]')), /./);
});

test('master-like evidence (no queue view, no composer or shell box sync) fails queue-draft-sync only', t => {
  const base = path.join(root, 'tools/verify-chat-delivery/in-memory-master-evidence');
  const { files, actions } = queueFiles(base);
  files.set(path.join(base, 'actions.json'), JSON.stringify(actions));
  const file = name => path.join(base, queueName, name);
  files.set(file('debug.log'), '2026-10-23 10:00:00.000 [chat] transcript load shell=1 ok bytes=900 ms=5');
  const observation = JSON.parse(files.get(file('observation.json')));
  const failing = ['chat-lists-shell-queued', 'chat-lists-both-in-order', 'chat-lists-edited-in-order', 'chat-marks-both-sent', 'composer-ignores-agent-paste', 'shell-box-shows-chat-draft'];
  observation.steps = observation.steps.map(step => ({ ...step, ok: !failing.includes(step.name) }));
  files.set(file('observation.json'), JSON.stringify(observation));
  mockFiles(t, files);
  const result = evaluateEvidence(base);
  const row = result.cases.find(entry => entry.name === queueName);
  assert.equal(row.passed, false);
  assert.equal(row.detail, `journey steps failed: ${failing.join(', ')}`);
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.cases.map(entry => entry.name), allNames);
});

test('fake Claude queues while busy, pops everything on Up, takes the queue FIFO and shows a dim suggestion only when empty', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fake-claude-'));
  const boundary = path.join(root, 'tools/verify-chat-delivery/boundary.py');
  try {
    const transcript = path.join(dir, 'home/.claude/projects/C--verify-work/sid-1.jsonl');
    fs.writeFileSync(path.join(dir, 'state.json'), JSON.stringify({
      name: queueName, mode: 'busy', suggestion: queueTexts.suggestion, fake: true, sid: 'sid-1', cwd: 'C:/verify/work', panePid: 4242,
      transcript, meta: path.join(dir, 'home/.claude/sessions/4242.json'), procDir: path.join(dir, 'proc/4242'),
    }));
    const run = (mode, ...args) => execFileSync('python3', ['-I', '-X', 'utf8', boundary, mode, ...args], { env: { MP_VERIFY_STATE: dir, PATH: process.env.PATH }, encoding: 'utf8' });
    const shell = (...args) => run('shell', ...args);
    const tmux = (...args) => run('tmux', ...args);
    const events = () => fs.readFileSync(transcript, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    const state = () => JSON.parse(shell('show'));
    const pane = (...flags) => tmux('capture-pane', ...flags, '-t', '=verify-agent:');
    shell('init');
    assert.equal(fs.readFileSync(path.join(dir, 'proc/4242/cmdline'), 'latin1'), 'claude\0');
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'home/.claude/sessions/4242.json'), 'utf8')).sessionId, 'sid-1');
    assert.equal(tmux('list-panes', '-t', '=verify-agent', '-F', '#{pane_pid}').trim(), '4242');
    const discovery = String.raw`
import json, os, re, sys
from pathlib import Path
dir_ = Path(sys.argv[1])
os.environ["HOME"] = str(dir_ / "home")
source = open(sys.argv[2], encoding="utf-8").read()
namespace = {"__name__": "reader"}
exec(compile(re.search(r"READER_SOURCE = r'''(.*?)'''", source, re.S).group(1), "reader", "exec"), namespace)
table = namespace["process_table"](dir_ / "proc")
pid = namespace["agent_pid_for_panes"]([4242], table, "claude")
sid, cwd = namespace["claude_session_metadata"](pid)
path = namespace["conversation_path"]("claude", sid, cwd)
print(json.dumps([pid, sid, cwd, str(path)]))
`;
    if (process.platform === 'linux') {
      const found = JSON.parse(execFileSync('python3', ['-I', '-X', 'utf8', '-c', discovery, dir, path.join(root, 'src/chat_history_reader.py')], { encoding: 'utf8' }));
      assert.deepEqual(found, [4242, 'sid-1', 'C:/verify/work', transcript], 'the production reader finds the fake transcript from the pane pid');
    }
    shell('text', 'alpha one');
    assert.match(pane('-p', '-J'), /\u276f alpha one\n/);
    shell('key', 'Enter');
    tmux('send-keys', '-t', '=verify-agent:', '-l', '--', 'beta two');
    tmux('send-keys', '-t', '=verify-agent:', 'Enter');
    assert.deepEqual(state().queue, ['alpha one', 'beta two']);
    const busyScreen = pane('-p', '-J');
    assert.ok(busyScreen.includes('Working... (esc to interrupt)') && busyScreen.indexOf('Queued: alpha one') < busyScreen.indexOf('Queued: beta two'));
    assert.ok(!busyScreen.includes(queueTexts.suggestion), 'no suggestion while busy');
    shell('key', 'Up');
    assert.deepEqual(state(), { mode: 'busy', box: 'alpha one\nbeta two', queue: [], suggestion: queueTexts.suggestion });
    assert.match(pane('-p', '-J'), /\u276f alpha one\n {2}beta two\n\u2500/);
    shell('key', 'C-u');
    shell('text', 'alpha edited');
    shell('key', 'Enter');
    tmux('send-keys', '-t', '=verify-agent:', '-l', '--', 'beta two');
    tmux('send-keys', '-t', '=verify-agent:', 'Enter');
    shell('idle');
    assert.equal(state().mode, 'idle');
    const plain = pane('-p', '-J');
    assert.ok(plain.includes(`\u276f ${queueTexts.suggestion}\n`) && !plain.includes('\u001b'));
    assert.ok(pane('-e', '-p', '-J').includes(`\u276f \u001b[2m${queueTexts.suggestion}\u001b[0m\n`));
    shell('text', 'draft');
    assert.ok(!pane('-e', '-p', '-J').includes('\u001b[2m'), 'a typed draft is not dim');
    const rows = events();
    assert.deepEqual(rows.filter(row => row.type === 'queue-operation').map(row => [row.operation, row.content, row.reason]), [
      ['enqueue', 'alpha one', undefined], ['enqueue', 'beta two', undefined], ['popAll', 'alpha one\nbeta two', undefined],
      ['enqueue', 'alpha edited', undefined], ['enqueue', 'beta two', undefined],
      ['remove', 'alpha edited', 'absorbed_mid_turn'], ['dequeue', undefined, undefined],
    ]);
    assert.deepEqual(rows.filter(row => row.type === 'attachment').map(row => [row.attachment.type, row.attachment.prompt]), [['queued_command', 'alpha edited'], ['queued_command', 'beta two']]);
    assert.ok(rows.every(row => Number.isFinite(Date.parse(row.timestamp))));
    const frames = fs.readFileSync(path.join(dir, 'frames.jsonl'), 'utf8').trim().split('\n').map(line => JSON.parse(line));
    assert.ok(frames.some(frame => frame.origin === 'app' && frame.op === 'send-keys') && frames.some(frame => frame.origin === 'shell'));
    assert.equal(tmux('send-keys', '-t', '=verify-agent:', 'C-x', 'C-s'), '');
    assert.throws(() => tmux('send-keys', '-t', '=verify-agent:', 'F13'));
    assert.ok(fs.existsSync(path.join(dir, 'unsupported.jsonl')));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('fake shell history succeeds with all fifty messages and paired tools while unknown operations still fail', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fake-history-'));
  const boundary = path.join(root, 'tools/verify-chat-delivery/boundary.py');
  try {
    const transcript = path.join(dir, 'transcript.jsonl');
    fs.writeFileSync(path.join(dir, 'state.json'), JSON.stringify({
      name: 'full-history', mode: 'busy', suggestion: queueTexts.suggestion, fake: true, sid: 'sid-history', cwd: 'C:/verify/work', panePid: 4242,
      transcript, meta: path.join(dir, 'sessions/4242.json'), procDir: path.join(dir, 'proc/4242'),
    }));
    const shell = (...args) => execFileSync('python3', ['-I', '-X', 'utf8', boundary, 'shell', ...args], { env: { MP_VERIFY_STATE: dir, PATH: process.env.PATH }, encoding: 'utf8', timeout: 60000 });
    shell('init');
    const initial = fs.readFileSync(transcript, 'utf8');
    assert.equal(shell('history'), '');
    const seeded = fs.readFileSync(transcript, 'utf8');
    assert.ok(seeded.startsWith(initial), 'history preserves the two initial messages');
    const rows = seeded.trim().split('\n').map(line => JSON.parse(line));
    const messages = rows.filter(row => typeof row.message.content === 'string' || row.message.content.some(part => part.type === 'text'));
    assert.equal(messages.length, 50);
    assert.deepEqual(messages.map(row => typeof row.message.content === 'string' ? row.message.content : row.message.content[0].text), [
      'start the fake session', 'The fake session is ready.',
      ...Array.from({ length: 24 }, (_, i) => [`IGSH815 user ${String(i).padStart(2, '0')}`, `IGSH815 assistant ${String(i).padStart(2, '0')}`]).flat(),
    ]);
    assert.equal(rows.length, 98);
    for (let i = 0; i < 24; i++) {
      const [user, assistant, tool, result] = rows.slice(2 + i * 4, 6 + i * 4);
      assert.equal(user.type, 'user');
      assert.equal(assistant.type, 'assistant');
      assert.equal(tool.type, 'assistant');
      assert.deepEqual(tool.message.content, [{ type: 'tool_use', id: `history-${i}`, name: 'Bash', input: { command: 'echo history' } }]);
      assert.equal(result.type, 'user');
      assert.deepEqual(result.message.content, [{ type: 'tool_result', tool_use_id: `history-${i}`, content: 'synthetic tool output '.repeat(12000), is_error: false }]);
    }
    assert.ok(Buffer.byteLength(seeded) > 1024 * 1024, 'history still requires transcript backfill');
    const unsupported = path.join(dir, 'unsupported.jsonl');
    assert.equal(fs.existsSync(unsupported), false, 'successful history must not be logged as unsupported');
    assert.throws(() => shell('unknown-history-operation'), error => error.status === 2);
    assert.deepEqual(fs.readFileSync(unsupported, 'utf8').trim().split('\n').map(line => JSON.parse(line)).map(row => [row.case, row.operation, row.argv]), [
      ['full-history', 'shell input', ['unknown-history-operation']],
    ]);
    assert.equal(fs.readFileSync(transcript, 'utf8'), seeded, 'unknown operations do not alter the transcript');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('queue-draft-sync is wired into the journey, the workflow fallback and the feature map', () => {
  assert.ok(drive.includes("name='queue-draft-sync'"));
  for (const step of queueSteps) assert.ok(drive.includes(`'${step}'`), step);
  for (const text of Object.values(queueTexts)) assert.ok(drive.includes(text.replaceAll("\n", "`n")), text);
  assert.match(drive, /CHAT_QUEUE items=/);
  assert.match(workflow, /@\('busy-send', 'idle-suggestion', 'steer-chord', 'wrapped-leftover', 'queue-draft-sync', 'send-stays-gone'\)/);
  assert.match(read(skill + 'features/chat-delivery.md'), /`queue-draft-sync`[\s\S]*CHAT_QUEUE items=/);
});

test('send-stays-gone is wired into the journey, the workflow fallback and the feature map', () => {
  assert.ok(drive.includes("name='send-stays-gone'"));
  for (const step of new Set(sendSteps)) assert.ok(drive.includes(`'${step}'`), step);
  assert.match(drive, /Select-Object -Last 1\) -ceq \$text/);
  assert.match(read(skill + 'features/chat-delivery.md'), /`send-stays-gone`[\s\S]*IGSH-960/);
});


test('send-stays-gone evidence fails when a sent message comes back or a send is missing', t => {
  const files = new Map();
  const base = path.join(root, 'tools/verify-chat-delivery/in-memory-send-evidence');
  const built = sendFiles(base);
  for (const [file, value] of built.files) files.set(file, value);
  files.set(path.join(base, 'actions.json'), JSON.stringify(built.actions));
  mockFiles(t, files);
  const row = () => evaluateEvidence(base).cases.find(entry => entry.name === sendName);
  assert.equal(row().passed, true, row().detail);
  assert.deepEqual(row().detail, { sends: 20, watchedSeconds: 10, longMessages: 5, delivered: 20, pending: 0, outboxStates: {} });
  const observationFile = path.join(base, `${sendName}/observation.json`);
  const original = files.get(observationFile);
  const back = JSON.parse(original);
  back.sends[6].reappeared = { kind: 'composer', text: 'send 7 sho', atMs: 3200 };
  files.set(observationFile, JSON.stringify(back));
  assert.match(row().detail, /send 7 came back into the box/);
  const draft = JSON.parse(original);
  draft.sends[2].reappeared = { kind: 'draft-file', atMs: 100 };
  files.set(observationFile, JSON.stringify(draft));
  assert.match(row().detail, /send 3 came back into the box/);
  const stale = JSON.parse(original);
  stale.steps[3].ok = false;
  files.set(observationFile, JSON.stringify(stale));
  assert.match(row().detail, /journey steps failed: send-stays-gone/);
  const late = JSON.parse(original);
  late.sends[11].reached = false;
  files.set(observationFile, JSON.stringify(late));
  assert.match(row().detail, /send 12 did not reach the agent within 10 seconds/);
  files.set(observationFile, original);
  const transcriptFile = path.join(base, `${sendName}/transcript.jsonl`);
  const transcript = files.get(transcriptFile);
  files.set(transcriptFile, transcript.split('\n').slice(0, -1).join('\n'));
  assert.match(row().detail, /none was dropped/);
  const lines = transcript.split('\n');
  const swapped = [...lines];
  const [first, second] = [swapped.findIndex(l => l.includes('send 1 short note')), swapped.findIndex(l => l.includes('send 2 short note'))];
  [swapped[first], swapped[second]] = [swapped[second], swapped[first]];
  files.set(transcriptFile, swapped.join('\n'));
  assert.match(row().detail, /exactly once and in send order/);
  files.set(transcriptFile, transcript.split('\n').slice(0, -1).join('\n'));
  const outboxFile = path.join(base, `${sendName}/outbox-final.json`);
  files.set(outboxFile, JSON.stringify({ queues: [{ messages: [{ t: sendTexts[19], s: 2 }] }] }));
  assert.match(row().detail, /exactly once and in send order/);
  files.set(outboxFile, JSON.stringify({ queues: [{ messages: [{ t: sendTexts[19], s: 3 }] }] }));
  assert.match(row().detail, /none was dropped/);
  files.set(outboxFile, JSON.stringify({ queues: [{ messages: [{ t: 'unrelated text', s: 3 }] }] }));
  assert.match(row().detail, /none was dropped/);
  files.set(outboxFile, JSON.stringify({ queues: [{ messages: [{ t: `${sendTexts[11]}${sendTexts[13]}`, s: 0 }] }] }));
  assert.match(row().detail, /came back into the box and was sent again joined to the next message/);
});


test('Windows remote reader preserves POSIX atomic replacement while its old descriptor stays readable', () => {
  assert.ok(fs.existsSync(path.join(root, 'tools/verify-chat-delivery/sitecustomize.py')), 'Windows reader needs POSIX delete sharing');
  assert.ok(fs.existsSync(path.join(root, 'tools/verify-chat-delivery/test_reader_sharing.py')), 'Windows overlap controls must ship with the fixture');
  const output = execFileSync('python3', ['-I', path.join(root, 'tools/verify-chat-delivery/test_reader_sharing.py')], { encoding: 'utf8', timeout: 60000 });
  if (process.platform === 'win32') {
    assert.match(output, /ORIGINAL_WINDOWS_READER_REJECTED/);
    assert.match(output, /POSIX_REPLACEMENT_WITH_HELD_READER_OK/);
  }
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundary, /if os.name == "nt":\s+env\["PYTHONPATH"\] = str\(Path\(__file__\).resolve\(\).parent\)/);
  assert.match(boundary, /subprocess.call\(\[sys.executable, \*remote\[1:\]\], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer/);
});

test('retention copy observes restored composer focus without injecting another Alt activation', () => {
  const copy = drive.slice(drive.indexOf('function Retention-Copy'), drive.indexOf('function Retention-Top'));
  assert.match(copy, /Press @\(0x1B\) 'Esc: clear retained selection'\s+\[void\]\(Wait-For 'retained selection returns typing focus'/);
  assert.match(copy, /\$f\[0\] -eq \$main\.ToInt64\(\) -and \$f\[1\] -eq \$composer\.ToInt64\(\)/);
  assert.doesNotMatch(copy, /FocusOwnedWindow/);
});

test('native frame sampling stays scheduled while retaining every measured gap and paint', () => {
  const sampler = read('tools/verify-chat-delivery/remote-switch.cs');
  assert.match(sampler, /new Thread\(Run\) \{ IsBackground = true, Priority = ThreadPriority\.AboveNormal \}/);
  assert.match(sampler, /gapMs = completed - last, paintMs = completed - start, painted = painted/);
  assert.match(sampler, /double remaining = start \+ 16 - clock\.Elapsed\.TotalMilliseconds/);
});

test('Windows notification stand-in keeps the supplied reader push algorithm and emits appended data', () => {
  assert.match(read('tools/verify-chat-delivery/boundary.py'), /def watch_reader\(\):/);
  const script = String.raw`
import ast,base64,ctypes,ctypes.wintypes,io,json,os,re,sys,tempfile,time,subprocess
from pathlib import Path
from unittest.mock import patch
root = Path(sys.argv[1])
tree = ast.parse((root / 'tools/verify-chat-delivery/boundary.py').read_text(encoding='utf-8'))
function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'watch_reader')
with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    cwd = str(home / 'work' / 'demo')
    path = home / '.claude/projects' / re.sub(r'[^A-Za-z0-9]', '-', cwd) / 'sid.jsonl'
    path.parent.mkdir(parents=True)
    event = lambda text: dict(type='assistant',message=dict(role='assistant',content=[dict(type='text',text=text)]))
    path.write_text(json.dumps(event('original boundary row')) + '\n')
    calls = []
    roots = []
    class Call:
        def __init__(self, fn): self.fn = fn
        def __call__(self, *args): return self.fn(*args)
    def wait(*args):
        calls.append('wait')
        if calls.count('wait') == 2: raise RuntimeError('fixture finished')
        with path.open('a') as output: output.write(json.dumps(event('appended boundary row')) + '\n')
        return 0
    kernel = type('Kernel', (), {})()
    kernel.FindFirstChangeNotificationW = Call(lambda *args: roots.append(args) or 1)
    kernel.FindNextChangeNotification = Call(lambda *args: 1)
    kernel.FindCloseChangeNotification = Call(lambda *args: calls.append('closed'))
    kernel.WaitForSingleObject = Call(wait)
    source = (root / 'src/chat_history_reader.py').read_bytes()
    q = dict(id=7,codex=False,sid='sid',tmux='term-1',cwd=cwd,cached_sid='',inode=0,offset=0,live=True)
    stream = io.TextIOWrapper(io.BytesIO(base64.b64encode(source) + b'\n' + json.dumps(q).encode() + b'\n'))
    output = io.StringIO()
    state = home / "state"
    state.mkdir()
    captures = []
    def capture_screen(escapes):
        assert escapes
        captures.append(True)
        return 'Ready\n❯ typed draft\n' + '─' * 50 + '\n'
    scope = dict(ROOT=state,ctypes=ctypes,wintypes=ctypes.wintypes,sys=sys,os=os,time=time,capture_screen=capture_screen)
    exec(compile(ast.Module(body=[function],type_ignores=[]), '<boundary-watch>', 'exec'), scope)
    with patch.dict(os.environ, HOME=str(home), USERPROFILE=str(home)), patch.object(sys,'stdin',stream), patch.object(sys,'stdout',output), patch.object(ctypes,'WinDLL',return_value=kernel,create=True), patch.object(subprocess,'run',side_effect=AssertionError('stream spawned a capture process')):
        try: scope['watch_reader']()
        except RuntimeError as error: assert str(error) == 'fixture finished'
    frames = [json.loads(line) for line in output.getvalue().splitlines()]
    assert len(frames) == 2,frames
    assert captures == [True],captures
    assert all('typed draft' in frame['wire'] for frame in frames)
    assert 'original boundary row' in frames[0]['wire']
    assert 'appended boundary row' in frames[1]['wire']
    assert 'original boundary row' not in frames[1]['wire']
    assert calls == ['wait','wait','closed'],calls
    assert roots == [(str(home), True, 0x13)],roots
print('WINDOWS_NOTIFICATION_BOUNDARY_OK')
`;
  assert.match(execFileSync('python3', ['-I', '-c', script, root], { encoding: 'utf8', timeout: 30000 }), /WINDOWS_NOTIFICATION_BOUNDARY_OK/);
});


test('retained-history recovery delivers wheel input to the verified focused HWND', () => {
  const start = drive.indexOf('function Retention-Top {');
  const end = drive.indexOf('\nfunction Assert-Retention', start);
  const recovery = drive.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(recovery, /Wait-For 'retained transcript keyboard focus'/);
  assert.match(recovery, /::Focus\(\$main\)\[1\] -eq \$transcript.ToInt64\(\)/);
  assert.match(recovery, /input='focused transcript HWND wheel'/);
  assert.match(recovery, /::WheelFocusedTranscript\(\$main, \$app.Id, \$transcript, 30000\)/);
  assert.match(recovery, /\$position\.scroll -eq 0/);
  const desktop = read('tools/verify-chat-delivery/desktop.cs');
  const first = desktop.indexOf('    public static void WheelFocusedTranscript(');
  const last = desktop.indexOf('    public static void PressOwnedTranscript(', first);
  const wheel = desktop.slice(first, last);
  assert.ok(first >= 0 && last > first);
  for (const guard of ['Owner(main) != pid', 'GetForegroundWindow() != main', 'Owner(transcript) != pid', '!IsChild(main, transcript)', 'Class(transcript) != "ZigShellChatTranscript"', '!IsWindowVisible(transcript)', 'Focus(main)[1] != transcript.ToInt64()']) assert.ok(wheel.includes(guard), guard);
  assert.match(wheel, /SendWheelMessage\(transcript, 0x020A,/);
  assert.match(wheel, /delta < short.MinValue/);
  assert.match(wheel, /delta > short.MaxValue/);
  assert.match(wheel, /delta % 120 != 0/);
  assert.match(wheel, /== IntPtr.Zero\) throw/);
  assert.doesNotMatch(wheel, /SendInput/);
});

test('remote appended-message receipt keeps the request window across delayed font logs', () => {
  const source = read('tools/verify-chat-delivery/remote-switch.ps1');
  const start = source.indexOf("Wait-For 'new remote messages applied'");
  const end = source.indexOf('} 30)', start);
  const wait = source.slice(start, end);
  assert.ok(start > 0 && end > start);
  assert.doesNotMatch(wait, /\$offset =/);
  assert.match(source.slice(0, start), /\$appendLogStart = \(Read-Shared "\$settings\/debug.log"\).Length/);
  assert.match(wait, /Substring\(\$appendLogStart\)/);
});

test('IGSH-1063 question boundary records single, multiple and Other answers exactly', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'structured-question-'));
  try {
    const transcript = path.join(dir, 'home/.claude/projects/C--verify-work/sid.jsonl');
    fs.writeFileSync(path.join(dir, 'state.json'), JSON.stringify({
      name: 'chat-options', mode: 'busy', suggestion: '', fake: true, sid: 'sid', cwd: 'C:/verify/work', panePid: 4242,
      transcript, meta: path.join(dir, 'home/.claude/sessions/4242.json'), procDir: path.join(dir, 'proc/4242'),
    }));
    const run = (mode, ...args) => {
      const result = require('node:child_process').spawnSync('python3', ['-I', '-X', 'utf8', path.join(root, 'tools/verify-chat-delivery/boundary.py'), mode, ...args], { env: { MP_VERIFY_STATE: dir, PATH: process.env.PATH }, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      return result.stdout;
    };
    const key = (...keys) => run('tmux', 'send-keys', '-t', '=verify-agent:', ...keys);
    run('shell', 'init');
    run('shell', 'plain-list');
    run('shell', 'question', path.join(root, 'tools/fixtures/IGSH-1063/questions.json'));
    assert.match(run('tmux', 'capture-pane', '-p', '-J'), /Which colour should we use\?/);
    key('2');
    key('1', '2', 'Enter');
    let answers = fs.readFileSync(path.join(dir, 'question-answers.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(answers.map(answer => answer.labels), [['Orange'], ['Desktop', 'Phone']]);
    assert.equal(JSON.parse(run('shell', 'show')).question, null);
    run('shell', 'question', path.join(root, 'tools/fixtures/IGSH-1063/questions.json'));
    key('3');
    run('tmux', 'send-keys', '-t', '=verify-agent:', '-l', '--', 'Purple');
    key('Enter');
    answers = fs.readFileSync(path.join(dir, 'question-answers.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(answers[2].labels, ['Purple']);
    assert.match(run('tmux', 'capture-pane', '-p', '-J'), /Which devices should we check\?/);
    const events = fs.readFileSync(transcript, 'utf8').trim().split('\n').map(JSON.parse);
    const calls = events.filter(event => event.message?.content?.[0]?.name === 'AskUserQuestion');
    assert.equal(calls.length, 2);
    assert.equal(events.filter(event => event.message?.content?.[0]?.tool_use_id === calls[0].message.content[0].id).length, 1);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});


test('IGSH-1063 question proof selects the saved AMOLED theme and supports published assets', () => {
  const journey = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/chat-options.ps1'), 'utf8');
  assert.match(journey, /Select-Theme 'amoled' 'theme-amoled'/);
  assert.doesNotMatch(journey, /Palette '(?:theme )?amoled'/);
  const adapter = fs.readFileSync(path.join(root, '.github/workflows/question-journey.yml'), 'utf8');
  assert.match(adapter, /types: \[structured-question-proof\]/);
  assert.match(adapter, /feature: chat-options/);
  assert.match(adapter, /tag: \$\{\{ github\.event\.client_payload\.tag \|\| '' \}\}/);
});

test('Doctor waits for visible versioned UIA state after native tab transitions without accepting another process', () => {
  const doctor = drive.slice(drive.indexOf('function Doctor('), drive.indexOf('function Press('));
  assert.match(doctor, /Wait-For 'visible versioned owned app' \{/);
  assert.match(doctor, /\$element = \[System.Windows.Automation.AutomationElement\]::FromHandle\(\$main\)/);
  assert.match(doctor, /-not \$element.Current.IsOffscreen -and \$element.Current.ProcessId -eq \$app.Id -and \$title -match/);
  assert.match(doctor, /Save .*IsOffscreen.*ProcessId.*title.*doctor-window.json/);
  assert.match(doctor, /throw 'Doctor: visible versioned UI Automation identity missing'/);
  assert.match(doctor, /Owner\(\$main\) -ne \$app.Id/);
  assert.match(doctor, /\$app.HasExited -or \$app.Path -ne \$Exe -or \(Get-FileHash \$Exe -Algorithm SHA256\).Hash -ne \$ExpectedHash/);
});
