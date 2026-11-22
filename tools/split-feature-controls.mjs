import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import appSource from './app-source.js';

const root = path.resolve(import.meta.dirname, '..');
const directory = path.join(root, '.claude/skills/verify-multiprompt');
const control = path.join(directory, 'control.ps1');
const fixture = path.join(root, 'tools/fixtures/IGSH-1109/control-source.json');
const digest = text => crypto.createHash('sha256').update(text).digest('hex');

function check(original = false) {
  const source = fs.readFileSync(control, 'utf8');
  const imports = [...source.matchAll(/Join-Path \$PSScriptRoot '(control-feature-[a-z0-9-]+\.ps1)'/g)].map(match => match[1]).sort();
  const files = fs.readdirSync(directory).filter(name => /^control-feature-[a-z0-9-]+\.ps1$/.test(name)).sort();
  assert.ok(imports.length > 0, 'Feature bodies must have separate files');
  assert.deepEqual(imports, files, 'Feature files must each have one physical dispatcher');
  const expanded = appSource.readControlSource(control);
  assert.ok(expanded.length > source.length, 'Control imports must resolve to real implementation');
  if (original) {
    const manifest = JSON.parse(fs.readFileSync(fixture, 'utf8'));
    assert.equal(digest(expanded), manifest.sha256, 'The migration must preserve the original source exactly');
    console.log('CONTROL_SOURCE_ROUNDTRIP_VERIFIED');
  }
  console.log('CONTROL_SOURCE_GRAPH_VERIFIED');
}

function split(metadata) {
  const source = fs.readFileSync(control, 'utf8');
  if (source.includes(". (Join-Path $PSScriptRoot 'control-library.ps1')")) {
    check();
    return;
  }
  const tree = JSON.parse(fs.readFileSync(metadata, 'utf8').replace(/^\uFEFF/, ''));
  const edits = [];
  const files = new Map();
  const features = [];
  for (const entry of tree.clauses) {
    assert.match(entry.name, /^'[a-z0-9-]+'$/);
    assert.ok(Number.isSafeInteger(entry.start) && Number.isSafeInteger(entry.end));
    assert.ok(entry.start >= tree.start && entry.end <= tree.end && entry.end > entry.start);
    assert.equal(source[entry.start], '{');
    assert.equal(source[entry.end - 1], '}');
    assert.ok(entry.returns.every(item => item.nested), `${entry.name} contains a controller-level return`);
    const name = entry.name.slice(1, -1);
    const body = source.slice(entry.start + 1, entry.end - 1);
    const existing = body.trim().match(/^\.\s+(?:\(Join-Path \$PSScriptRoot '([^']+)'\)|"\$PSScriptRoot\/([^"]+)")$/);
    const file = existing ? existing[1] || existing[2] : `control-feature-${name}.ps1`;
    features.push({ name, file, generated: !existing });
    if (existing) continue;
    files.set(file, body);
    edits.push({ start: entry.start + 1, end: entry.end - 1, text: `\n            . (Join-Path $PSScriptRoot '${file}')\n        ` });
  }
  assert.equal(new Set(features.map(entry => entry.name)).size, features.length);

  const libraryStart = source.indexOf('function Save-Json(');
  const libraryEnd = source.indexOf('\ntry {', libraryStart) + 1;
  assert.ok(libraryStart > 0 && libraryEnd > libraryStart);
  files.set('control-library.ps1', source.slice(libraryStart, libraryEnd));
  edits.push({ start: libraryStart, end: libraryEnd, text: ". (Join-Path $PSScriptRoot 'control-library.ps1')\n" });

  const header = "Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition @'\n";
  const nativeStart = source.indexOf(header);
  const nativeEnd = source.indexOf("\n'@\n", nativeStart + header.length);
  assert.ok(nativeStart > 0 && nativeEnd > nativeStart);
  files.set('control-native.cs', source.slice(nativeStart + header.length, nativeEnd + 1));
  edits.push({ start: nativeStart, end: nativeEnd + 4, text: "Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition (Get-Content (Join-Path $PSScriptRoot 'control-native.cs') -Raw)\n" });

  let output = source;
  for (const edit of edits.sort((a, b) => b.start - a.start)) output = output.slice(0, edit.start) + edit.text + output.slice(edit.end);
  for (const [name, text] of files) {
    const target = path.join(directory, name);
    if (fs.existsSync(target)) assert.equal(fs.readFileSync(target, 'utf8'), text, `Refusing to overwrite ${name}`);
    else fs.writeFileSync(target, text);
  }
  const staged = control + '.split.tmp';
  try {
    fs.writeFileSync(staged, output);
    assert.equal(appSource.readControlSource(staged), source, 'The extraction changed controller source');
    fs.mkdirSync(path.dirname(fixture), { recursive: true });
    fs.writeFileSync(fixture, JSON.stringify({ sha256: digest(source), features }, null, 2) + '\n');
    fs.renameSync(staged, control);
  } finally {
    fs.rmSync(staged, { force: true });
  }
  check(true);
  console.log(`Split ${features.filter(entry => entry.generated).length} feature bodies; retained ${features.length} routes`);
}

if (process.argv[2] === '--check' && (process.argv.length === 3 || process.argv[3] === '--original' && process.argv.length === 4)) check(process.argv[3] === '--original');
else if (process.argv.length === 3) split(process.argv[2]);
else throw new Error('Usage: node tools/split-feature-controls.mjs <PowerShell AST JSON>|--check [--original]');
