import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { ASSET_NAME, BUNDLE_SOURCES, buildRuntimeBundle, checkVersion, readAppVersion } from './build-runtime-bundle.mjs';

const root = `${fileURLToPath(new URL('..', import.meta.url))}`;

function desktopBundle() {
  const zig = fs.readFileSync(`${root}src/chat_session.zig`, 'utf8');
  const start = zig.indexOf('pub fn chatReaderBundle');
  assert.ok(start > 0, 'src/chat_session.zig must assemble the helper bundle');
  const body = zig.slice(start, zig.indexOf('fn uiThreadBusy', start));
  const embeds = new Map([...body.matchAll(/const (\w+) = @embedFile\("([^"]+)"\);/g)].map(match => [match[1], match[2]]));
  const encoded = new Map([...body.matchAll(/const (\w+) = allocator\.alloc\(u8, std\.base64\.standard\.Encoder\.calcSize\((\w+)\.len\)\)/g)].map(match => [match[1], match[2]]));
  const call = /allocPrint\(allocator, "((?:[^"\\]|\\.)*)", \.\{ ([^}]*) \}\) catch null;/.exec(body);
  assert.ok(call, 'chatReaderBundle must build its bundle with one allocPrint template');
  const template = call[1].replace(/\\n/g, '\n').replace(/\\'/g, "'").replace(/\{\{/g, '{').replace(/\}\}/g, '}');
  const files = call[2].split(',').map(argument => argument.trim()).map(argument => {
    const embedded = /^@embedFile\("([^"]+)"\)$/.exec(argument);
    if (embedded) return `src/${embedded[1]}`;
    if (argument === '@import("main.zig").APP_VERSION') return 'src/main.zig';
    const source = encoded.get(argument) || (argument.endsWith('64') ? argument.slice(0, -2) : argument);
    assert.ok(embeds.has(source), `chatReaderBundle argument ${argument} has no embedded file`);
    return `src/${embeds.get(source)}`;
  });
  return { template, files };
}

function assemble(template, files, version) {
  const values = files.map(file => {
    if (file === 'src/main.zig') return Buffer.from(version, 'utf8');
    const bytes = fs.readFileSync(`${root}${file}`);
    return file === 'src/chat_history_reader.py' ? bytes : Buffer.from(bytes.toString('base64'), 'utf8');
  });
  const parts = template.split('{s}');
  assert.equal(parts.length - 1, values.length, 'every bundle placeholder needs one desktop argument');
  return Buffer.concat(parts.flatMap((part, index) => index === 0
    ? [Buffer.from(part, 'utf8')]
    : [values[index - 1], Buffer.from(part, 'utf8')]));
}

test('the release bundle is byte for byte what the desktop embeds', () => {
  const version = readAppVersion(root);
  const { template, files } = desktopBundle();
  assert.deepEqual(files, ['src/room_service.py', 'src/room_bridge.py', 'src/chat_connectors/claude.py', 'src/chat_connectors/codex.py',
    'src/mp_send.py', 'src/multibot_feedback.py', 'src/mp_helper.py', 'src/mp_shell.py', 'src/mp_sessions.py', 'src/mp_layout.mjs',
    'src/mp_fresh.py', 'src/mp_zsb.sh', 'src/main.zig', 'src/chat_history_reader.py']);
  assert.deepEqual(Object.values(BUNDLE_SOURCES), files.slice(0, 12));
  const desktop = assemble(template, files, version);
  const release = buildRuntimeBundle({ version, root });
  assert.ok(desktop.equals(release), 'the published helper bundle must match the desktop bundle exactly');
});

test('the helper bundle carries the reader, the connector map and its release version', () => {
  const bundle = buildRuntimeBundle({ version: '0.28.900', root }).toString('utf8');
  const reader = fs.readFileSync(`${root}src/chat_history_reader.py`, 'utf8');
  assert.ok(bundle.endsWith(reader), 'the bundle ends with the canonical reader source');
  assert.ok(bundle.startsWith("ROOM_SERVICE_SOURCE = '"), 'the bundle starts with the room service source');
  assert.ok(bundle.includes("CONNECTOR_SOURCES = {'claude':'"), 'the connector map stays inline');
  assert.ok(bundle.includes("MULTIBOT_APP_VERSION = '0.28.900'\n"), 'the bundle carries its release version');
});

test('the bundle version always comes from the release tag or main.zig', () => {
  assert.equal(checkVersion('0.28.900'), '0.28.900');
  assert.throws(() => checkVersion('v0.28.900'));
  assert.throws(() => checkVersion('0.28'));
  assert.throws(() => checkVersion('0.028.900'));
  assert.throws(() => buildRuntimeBundle({ version: 'latest', root }));
});

test('the release workflow publishes and checksums the helper bundle', () => {
  const workflow = fs.readFileSync(`${root}.github/workflows/release.yml`, 'utf8');
  assert.ok(workflow.includes('node tools/build-runtime-bundle.mjs dist/multiprompt-runtime.py'), 'the release job must assemble the helper bundle');
  const checksums = workflow.split('\n').find(line => line.includes('> SHA256SUMS.txt'));
  assert.match(checksums, /sha256sum .*multiprompt-runtime\.py/);
  assert.match(workflow, /gh release create "\$TAG" dist\/\*/);
  assert.equal(ASSET_NAME, 'multiprompt-runtime.py');
});
