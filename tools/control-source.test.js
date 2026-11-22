const test = require('node:test');
const assert = require('node:assert/strict');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const directory = path.join(root, '.claude/skills/verify-multiprompt');
const controller = path.join(directory, 'control.ps1');
const read = name => fs.readFileSync(path.join(directory, name), 'utf8');
const imported = () => [...read('control.ps1').matchAll(/Join-Path \$PSScriptRoot '(control-feature-[a-z0-9-]+\.ps1)'/g)].map(match => match[1]);

function copyControls(t) {
  const copy = fs.mkdtempSync(path.join(os.tmpdir(), 'feature-controls-'));
  t.after(() => fs.rmSync(copy, { recursive: true, force: true }));
  for (const file of ['control.ps1', 'control-library.ps1', 'control-native.cs', ...imported()]) fs.copyFileSync(path.join(directory, file), path.join(copy, file));
  return copy;
}

test('each ordinary feature dispatches to its own file, keeping aliases and delegated commands', () => {
  const source = read('control.ps1');
  const main = source.match(/switch \(\$driveFeature\) \{([\s\S]*?)\n    \}/)?.[1];
  assert.ok(main, 'The existing feature dispatcher remains');
  const routes = [...main.matchAll(/'([a-z0-9-]+)'\s*\{([^]*?)\}/g)];
  assert.ok(routes.length > 0);
  assert.equal(new Set(routes.map(match => match[1])).size, routes.length);
  for (const [, name, body] of routes) {
    const file = body.trim().match(/^\.\s+(?:\(Join-Path \$PSScriptRoot '([^']+)'\)|"\$PSScriptRoot\/([^"]+)")$/);
    assert.ok(file, `${name} must not share an inline control body`);
    assert.ok(fs.existsSync(path.join(directory, file[1] || file[2])), name);
  }
  const features = [...source.match(/ValidateSet\(([^)]*)\)/)[1].matchAll(/'([^']+)'/g)].map(match => match[1]);
  const delegated = [...source.slice(0, source.indexOf('$Evidence = [IO.Path]::GetFullPath($Evidence)', source.indexOf('switch ($Feature)'))).matchAll(/'([a-z0-9-]+)'\s*\{/g)].map(match => match[1]);
  const registered = new Set([...routes.map(match => match[1]), ...delegated, 'composer-buttons']);
  for (const name of features) assert.ok(registered.has(name), `${name} lost its dispatch`);
  assert.match(source, /'composer-buttons' \{ \$driveFeature = 'chat-view' \}/);
  assert.doesNotMatch(source, /^function /m);
  assert.match(source, /\. \(Join-Path \$PSScriptRoot 'control-library.ps1'\)/);
  assert.match(source, /Add-Type[^\n]+control-native\.cs/);
  const graph = spawnSync(process.execPath, ['tools/split-feature-controls.mjs', '--check'], { cwd: root, encoding: 'utf8', timeout: 30000 });
  assert.equal(graph.status, 0, graph.stdout + graph.stderr);
  assert.match(graph.stdout, /CONTROL_SOURCE_GRAPH_VERIFIED/);
});

test('source contracts follow edited feature files instead of a stale monolithic copy', t => {
  const copy = copyControls(t);
  const before = readControlSource(path.join(copy, 'control.ps1'));
  assert.equal(before, readControlSource(controller));
  const leaf = path.join(copy, imported()[0]);
  fs.appendFileSync(leaf, "\n            Write-Output 'feature-ownership-probe'\n        ");
  const changed = readControlSource(path.join(copy, 'control.ps1'));
  assert.notEqual(changed, before);
  assert.ok(changed.includes("Write-Output 'feature-ownership-probe'"));
  assert.equal(readControlSource(controller), before, 'An isolated mutation must not alter shared checkout source');
});

test('missing and cyclic control imports fail rather than silently losing commands', t => {
  const copy = copyControls(t);
  const first = path.join(copy, imported()[0]);
  const saved = fs.readFileSync(first, 'utf8');
  fs.unlinkSync(first);
  assert.throws(() => readControlSource(path.join(copy, 'control.ps1')), /ENOENT/);
  fs.writeFileSync(first, saved);
  fs.writeFileSync(path.join(copy, 'control-library.ps1'), ". (Join-Path $PSScriptRoot 'control-library.ps1')\n");
  assert.throws(() => readControlSource(path.join(copy, 'control.ps1')), /Control import cycle/);
});

test('every split PowerShell control parses on the hosted Windows path', t => {
  const shell = process.env.PWSH || (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
  const available = spawnSync(shell, ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'], { encoding: 'utf8' });
  if (available.error?.code === 'ENOENT' && process.platform !== 'win32') return t.skip('PowerShell syntax is required by Windows CI');
  assert.equal(available.status, 0, available.stdout + available.stderr);
  const copy = fs.mkdtempSync(path.join(os.tmpdir(), 'control-parser-'));
  t.after(() => fs.rmSync(copy, { recursive: true, force: true }));
  const output = path.join(copy, 'ast.json');
  const parsed = spawnSync(shell, ['-NoProfile', '-File', path.join(root, 'tools/split-feature-controls.ps1'), '-Path', controller, '-Output', output], { encoding: 'utf8', timeout: 30000 });
  assert.equal(parsed.status, 0, parsed.stdout + parsed.stderr);
  const ast = JSON.parse(fs.readFileSync(output, 'utf8').replace(/^\uFEFF/, ''));
  const files = fs.readdirSync(directory).filter(name => /^control.*\.ps1$/.test(name));
  assert.equal(ast.parsedFiles, files.length, 'Every physical feature and shared control must parse');
  const invalid = copyControls(t);
  fs.appendFileSync(path.join(invalid, imported()[0]), '\nfunction Broken {\n');
  const rejected = spawnSync(shell, ['-NoProfile', '-File', path.join(root, 'tools/split-feature-controls.ps1'), '-Path', path.join(invalid, 'control.ps1'), '-Output', path.join(copy, 'invalid.json')], { encoding: 'utf8', timeout: 30000 });
  assert.notEqual(rejected.status, 0, 'An invalid feature file must fail before app launch');
  assert.match(rejected.stdout + rejected.stderr, /Missing closing|MissingEndCurlyBrace/);

});

test('existing native workflows run their features through shared controls', () => {
  const controllerSource = read('control.ps1');
  assert.match(controllerSource, /\. \(Join-Path \$PSScriptRoot 'control-library\.ps1'\)/);
  assert.match(controllerSource, /Add-Type[^\n]+control-native\.cs/);
  for (const [file, feature, control] of [['browser-corners.yml', 'browser-corners', 'browser-corners.ps1'], ['window-controls.yml', 'window-controls', 'window-controls.ps1'], ['palette-dialog-design.yml', 'command-palette', 'control-feature-command-palette.ps1']]) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    assert.match(source, /^  workflow_dispatch:/m, file);
    assert.match(source, /^  schedule:/m, file);
    assert.match(source, new RegExp(`control\\.ps1 -Feature ${feature} -Exe \\$exe`), file);
    assert.match(source, /if \(\$LASTEXITCODE -ne 0\) \{ throw/, file);
    const route = controllerSource.match(new RegExp(`'${feature}'\\s*\\{([^}]+)\\}`));
    assert.ok(route && route[1].includes(control), feature);
    assert.ok(fs.existsSync(path.join(directory, control)), feature);
  }
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  assert.match(workflow, /tools\/split-feature-controls\.ps1 -Path[^\n]+control-ast\.json/);
});
