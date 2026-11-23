import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { publishRuntime, runtimeAsset, runtimeGeneration, runtimePayload } from './runtime-release-asset.mjs';

const root = new URL('../', import.meta.url);
const read = name => fs.readFileSync(new URL(`src/${name}`, root));

function zigBundle() {
  const source = read('chat_session.zig').toString('utf8');
  const found = /allocPrint\(allocator, "((?:[^"\\]|\\.)*)", \.\{[^}]*@embedFile\("chat_history_reader\.py"\)/.exec(source);
  assert.ok(found, 'chat_session.zig must still bundle the reader');
  return found[1].replaceAll('\\n', '\n').replaceAll('{{', '{').replaceAll('}}', '}');
}

function header(payload) {
  return payload.split('\n').slice(0, 10);
}

test('the release payload carries the same constants the desktop bundles', () => {
  const expected = [...zigBundle().matchAll(/^(\w+) = /gm)].map(match => match[1]);
  const actual = header(runtimePayload('1.2.3')).map(line => /^(\w+) = /.exec(line)?.[1]);
  assert.deepEqual(actual, expected);
});

test('every bundled constant decodes to its source file', () => {
  const decoded = new Map(header(runtimePayload('1.2.3')).map(line => {
    const [, name, value] = /^(\w+) = (.*)$/.exec(line);
    return [name, value];
  }));
  for (const [name, file] of [['MP_SEND_SOURCE', 'mp_send.py'], ['MP_HELPER_SOURCE', 'mp_helper.py'], ['FEEDBACK_SOURCE', 'multibot_feedback.py'], ['MP_SHELL_SOURCE', 'mp_shell.py'], ['MP_SESSIONS_SOURCE', 'mp_sessions.py'], ['MP_FRESH_SOURCE', 'mp_fresh.py']]) {
    assert.deepEqual(Buffer.from(/^'(.*)'$/.exec(decoded.get(name))[1], 'base64'), read(file), name);
  }
  assert.deepEqual(Buffer.from(/^'(.*)'$/.exec(decoded.get('MP_LAYOUT_SOURCE'))[1], 'base64'), read('mp_layout.mjs'));
  assert.deepEqual(Buffer.from(/^'(.*)'$/.exec(decoded.get('ZSB_SOURCE'))[1], 'base64'), read('mp_zsb.sh'));
  const connectors = /^\{'claude':'(.*)','codex':'(.*)'}$/.exec(decoded.get('CONNECTOR_SOURCES'));
  assert.deepEqual(Buffer.from(connectors[1], 'base64'), read('chat_connectors/claude.py'));
  assert.deepEqual(Buffer.from(connectors[2], 'base64'), read('chat_connectors/codex.py'));
});

test('the published asset is the runtime the desktop installs at its own generation', () => {
  const candidate = runtimePayload('1.2.3');
  assert.match(candidate, /^MULTIBOT_APP_VERSION = '1\.2\.3'$/m);
  const published = publishRuntime(candidate);
  const text = published.payload.toString('utf8');
  assert.match(text, new RegExp(`^RUNTIME_GENERATION = ${published.generation}$`, 'm'));
  assert.equal(runtimeGeneration(published.payload), published.generation);
  assert.match(text, /^CONNECTOR_SOURCES = /m);
  assert.match(text, /^def runtime_release_install\(payload\):$/m);
  const marker = "READER_SOURCE = r'''";
  const inner = candidate.slice(candidate.lastIndexOf(marker) + marker.length, candidate.indexOf("\n'''", candidate.lastIndexOf(marker)));
  assert.equal(text.trimEnd().endsWith(inner.trimEnd()), true, 'the asset ends with the bundled reader source');
});

test('the release workflow signs the runtime asset into the manifest', () => {
  const workflow = fs.readFileSync(new URL('.github/workflows/release.yml', root), 'utf8');
  assert.match(workflow, new RegExp(`node tools/runtime-release-asset\\.mjs "[^"]+" dist/${runtimeAsset.replaceAll('.', '\\.')}`));
  assert.match(workflow, new RegExp(`sha256sum -- \\*\\.exe \\*\\.zip release-notes\\.json ${runtimeAsset.replaceAll('.', '\\.')}`));
});

test('the reader verifies releases with the repository signing key', () => {
  const source = read('chat_history_reader.py').toString('utf8');
  const key = /^RUNTIME_RELEASE_SIGNING_KEY = "([A-Za-z0-9+/]{43}=)"$/m.exec(source);
  assert.ok(key, 'the reader must embed the release signing key');
  assert.equal(key[1], fs.readFileSync(new URL('src/release_signing_public_key.txt', root), 'utf8').trim());
  assert.match(source, /^RUNTIME_RELEASE_ASSET = "multiprompt-runtime\.py"$/m);
});
