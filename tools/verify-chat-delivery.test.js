const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { names, agentBoundary, evaluateDelivery, evaluateEvidence } = require('./verify-chat-delivery/check-evidence.js');
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

function fixture(name = 'busy-send') {
  const observation = { name, text: 'typed public message', composerText: 'typed public message', actionMs: 1000, endMs: 16001, error: null };
  const args = [['send-keys', '-t', '=verify-agent:', '-l', '--', observation.text], ['send-keys', '-t', '=verify-agent:', 'Enter']];
  if (name === 'steer-chord') args.push(['send-keys', '-t', '=verify-agent:', 'C-x', 'C-s']);
  return { observation, events: args.map((argv, index) => ({ ms: 1100 + index, case: name, argv })) };
}

test('buffer oracle accepts exactly typed text, Enter and the ordered steer chord', () => {
  for (const name of names) {
    const { observation, events } = fixture(name);
    assert.equal(evaluateDelivery(observation, events).writes, name === 'steer-chord' ? 3 : 2);
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

test('missing evidence evaluates every case and never produces a false green', () => {
  const result = evaluateEvidence(path.join(root, 'tools/verify-chat-delivery/nonexistent-evidence'));
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.cases.map(row => row.name), names);
  assert.ok(result.cases.every(row => row.passed === false && row.detail));
  assert.equal(result.agentBoundary, agentBoundary);
});

test('boundary runs the actual supplied Python bootstrap and logs raw fake tmux writes without fabricating text', () => {
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assert.match(boundary, /shlex.split\(command\[python.start\(\):\]\)/);
  assert.match(boundary, /subprocess.call\(\[sys.executable, \*remote\[1:\]\], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer/);
  assert.match(boundary, /if ARGS\[:1\] == \["send-keys"\]:\s+record\("agent-buffer.jsonl", argv=ARGS\)/);
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
  const output = execFileSync('python3', ['-I', '-c', script, path.join(root, 'tools/verify-chat-delivery/boundary.py')], { input: JSON.stringify({ probes, unknown }), encoding: 'utf8', timeout: 10000 });
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
  for (const text of ['RUNNER_TEMP', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'ssh-path.txt', 'session.json', 'tmux_host=0', "tmux_session='verify-agent'", 'MPVERSION=', 'UIAutomation', 'Get-FileHash', 'GetForegroundWindow', '::Focus($main)', 'composerText', 'agent-buffer.jsonl', 'invocations.jsonl', 'debug.log', 'cleanup.json']) assert.ok(drive.includes(text), text);
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
    put(`${name}/observation.json`, observation);
    log(`${name}/stand-in/agent-buffer.jsonl`, events);
    put(`${name}/stand-in/state.json`, { name, mode: observation.mode, suggestion: observation.suggestion });
    const shown = `Claude Code\n\n${observation.mode === 'busy' ? 'Working... (esc to interrupt)' : 'Ready'}\n\n❯ ${observation.mode === 'idle' ? observation.suggestion : ''}\n${'─'.repeat(50)}\n`;
    put(`${name}/stand-in/ready.json`, { screen: shown });
    log(`${name}/stand-in/console.jsonl`, [{ screen: shown, session: 'verify-agent', rows: shown.trimEnd().split('\n').map(line => line.trimEnd()), greySuggestion: observation.mode === 'idle', suggestionAttribute: observation.mode === 'idle' ? 8 : 7 }]);
    log(`${name}/stand-in/capture.jsonl`, [{ case: name, screen: shown }]);
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
  put('actions.json', actions);
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
    () => put('actions.json', actions.filter(row => row.input !== 'Ctrl+S: steer send')),
    () => log('busy-send/stand-in/unsupported.jsonl', [{ operation: 'ignored' }]),
    () => log('idle-suggestion/stand-in/console.jsonl', [{ screen: '❯ without suggestion', session: 'verify-agent', greySuggestion: true }]),
  ];
  for (const mutate of mutations) {
    files.clear();
    for (const [file, value] of positive) files.set(file, value);
    assert.equal(evaluateEvidence(base).status, 'passed');
    mutate();
    const result = evaluateEvidence(base);
    assert.equal(result.status, 'failed');
    assert.equal(result.cases.length, 3);
    assert.equal(result.cases.filter(row => !row.passed).length, 1);
  }
});
