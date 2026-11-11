import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import test from 'node:test';

const { privateKey, publicKey } = generateKeyPairSync('ed25519');
const rawKey = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
const names = ['multiprompt-x64.exe', 'multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe', 'multiprompt-extension.zip', 'release-notes.json'];
const sha = 'a'.repeat(40);
const feedReady = fs.existsSync(new URL('./legacy-update-feed.mjs', import.meta.url));

test('release preparation keeps the permanent legacy origin', () => {
  const release = fs.readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
  assert.equal(release.includes('node tools/legacy-update-feed.mjs --check-origin'), true);
  assert.equal(fs.existsSync(new URL('../.github/workflows/legacy-update-feed.yml', import.meta.url)), true);
  assert.equal(feedReady, true);
});

if (feedReady) {
  const { assertLegacyOrigin, legacyRepository, mirrorRelease, newer, releaseAssets, signedFiles, sourceRepository } = await import('./legacy-update-feed.mjs');
  process.env.GITHUB_REPOSITORY = legacyRepository;

  function fixture(repository = sourceRepository, tag = 'v1.2.4') {
    const bytes = new Map(names.map(name => [name, Buffer.from(name === 'release-notes.json' ? JSON.stringify({ version: tag.slice(1) }) : `MPVERSION=${tag.slice(1)};${name}`)]));
    const manifest = Buffer.from([...bytes].map(([name, data]) => `${createHash('sha256').update(data).digest('hex')}  ${name}\n`).join(''));
    bytes.set('SHA256SUMS.txt', manifest);
    bytes.set('SHA256SUMS.txt.sig', sign(null, manifest, privateKey));
    return {
      bytes,
      release: { tag_name: tag, draft: false, prerelease: false, author: { login: 'github-actions[bot]' }, assets: [...bytes].map(([name, data]) => ({ name, size: data.length, browser_download_url: `https://github.com/${repository}/releases/download/${tag}/${name}` })) },
    };
  }

  function harness() {
    const source = fixture();
    const current = fixture(legacyRepository, 'v1.2.3').release;
    const published = fixture(legacyRepository).release;
    const calls = [];
    const uploaded = new Map();
    const state = { source, current, published, calls, uploaded, releases: [], origin: sourceRepository };
    state.gh = args => {
      calls.push(['gh', ...args]);
      if (args[0] === 'api') {
        if (args.includes('--slurp')) return JSON.stringify([state.releases]);
        if (args[1].includes('/releases/tags/')) return JSON.stringify(state.published);
        return JSON.stringify(args[1].startsWith(`repos/${state.origin}/`) ? state.source.release : state.current);
      }
      if (['create', 'upload'].includes(args[1])) {
        for (const file of args.slice(3).filter(value => value.startsWith('/'))) uploaded.set(file.split('/').at(-1), fs.readFileSync(file));
      }
      return '';
    };
    state.git = args => { calls.push(['git', ...args]); return args[0] === 'rev-parse' ? sha : ''; };
    state.download = async asset => Buffer.from(state.source.bytes.get(asset.name));
    return state;
  }

  const publish = (state, bootstrap = false) => mirrorRelease({ gh: state.gh, git: state.git, download: state.download, rawKey, bootstrap });
  const writes = state => state.calls.filter(call => call[0] === 'git' && call[1] === 'push' || call[0] === 'gh' && call[1] === 'release');

  test('copies exact signed bytes to the legacy feed after the source name changes', async () => {
    const state = harness();
    assert.equal(await publish(state), `LEGACY_UPDATE_PUBLISHED v1.2.4 ${sha}`);
    assert.deepEqual(state.uploaded, state.source.bytes);
    assert.deepEqual(state.calls.find(call => call[0] === 'git' && call[1] === 'push'), ['git', 'push', 'origin', `${sha}:refs/tags/v1.2.4`]);
    const create = state.calls.find(call => call[1] === 'release' && call[2] === 'create');
    assert.ok(create.includes('--draft'));
    assert.equal(create[create.indexOf('--repo') + 1], legacyRepository);
    assert.deepEqual(state.calls.find(call => call[1] === 'release' && call[2] === 'edit'), ['gh', 'release', 'edit', 'v1.2.4', '--repo', legacyRepository, '--draft=false', '--latest']);
  });

  test('a retry is a no-op once the legacy feed is current, and never downgrades it', async () => {
    for (const tag of ['v1.2.4', 'v1.2.5', 'v2.0.0']) {
      const state = harness();
      state.current = fixture(legacyRepository, tag).release;
      assert.equal(await publish(state), 'Legacy update feed already current');
      assert.deepEqual(writes(state), []);
    }
    assert.equal(newer('v1.10.0', 'v1.9.99'), true);
    assert.throws(() => newer('v1.2.4-beta', 'v1.2.3'), /Invalid release version/);
  });

  test('recovers a partial draft without overwriting published releases', async () => {
    const state = harness();
    state.releases = [{ ...state.published, draft: true }];
    await publish(state);
    assert.ok(state.calls.some(call => call[1] === 'release' && call[2] === 'upload' && call.includes('--clobber')));
    assert.ok(!state.calls.some(call => call[1] === 'release' && call[2] === 'create'));
    assert.deepEqual(state.uploaded, state.source.bytes);
    for (const change of [{ draft: false }, { draft: true, author: { login: 'someone-else' } }, { draft: true, prerelease: true }]) {
      const refused = harness();
      refused.releases = [{ ...refused.published, ...change }];
      await assert.rejects(publish(refused), /Refusing to change/);
      assert.ok(!refused.calls.some(call => call[1] === 'release'));
    }
  });

  test('refuses wrong URLs, authors, channels, duplicate and missing assets before any publication', async () => {
    const changes = [
      release => { release.author.login = 'someone-else'; },
      release => { release.draft = true; },
      release => { release.prerelease = true; },
      release => { release.assets[0].browser_download_url = release.assets[0].browser_download_url.replace('/multibot/', '/multibot-evil/'); },
      release => { release.assets[0].browser_download_url += '?redirect=elsewhere'; },
      release => { release.assets.push(release.assets[0]); },
      release => { release.assets.shift(); },
      release => { release.assets[0].size = 0; },
    ];
    for (const change of changes) {
      const state = harness();
      change(state.source.release);
      await assert.rejects(publish(state));
      assert.deepEqual(writes(state), []);
    }
  });

  test('rejects tampering, wrong signatures, absent signed files and a mismatched version', async () => {
    for (const name of ['SHA256SUMS.txt', 'SHA256SUMS.txt.sig', ...names]) {
      const state = harness();
      state.source.bytes.set(name, Buffer.from('tampered'));
      await assert.rejects(publish(state));
      assert.deepEqual(writes(state), []);
    }
    const original = fixture();
    const manifest = original.bytes.get('SHA256SUMS.txt');
    const wrong = generateKeyPairSync('ed25519').privateKey;
    assert.throws(() => signedFiles(manifest, sign(null, manifest, wrong), rawKey), /signature/);
    for (const malformed of [Buffer.from('../../evil\n'), Buffer.concat([manifest, manifest]), Buffer.from('')]) {
      assert.throws(() => signedFiles(malformed, sign(null, malformed, privateKey), rawKey));
    }
    for (const name of ['multiprompt-x64.exe', 'release-notes.json']) {
      const state = harness();
      state.source.bytes.set(name, Buffer.from(name === 'release-notes.json' ? '{"version":"9.9.9"}' : 'MPVERSION=9.9.9;'));
      const sums = Buffer.from(names.map(file => `${createHash('sha256').update(state.source.bytes.get(file)).digest('hex')}  ${file}\n`).join(''));
      state.source.bytes.set('SHA256SUMS.txt', sums);
      state.source.bytes.set('SHA256SUMS.txt.sig', sign(null, sums, privateKey));
      await assert.rejects(publish(state), /version mismatch/);
      assert.deepEqual(writes(state), []);
    }
  });

  test('new-source releases require an active, unrenamed legacy feed', () => {
    const repository = { full_name: legacyRepository, archived: false };
    const workflow = { state: 'active' };
    assert.doesNotThrow(() => assertLegacyOrigin(repository, workflow));
    for (const changed of [{ ...repository, full_name: sourceRepository }, { ...repository, archived: true }]) {
      assert.throws(() => assertLegacyOrigin(changed, workflow), /restore it before releasing/);
    }
    for (const state of ['disabled_inactivity', 'disabled_manually', 'deleted']) {
      assert.throws(() => assertLegacyOrigin(repository, { state }), /restore it before releasing/);
    }
  });

  test('explicitly seeds the new repository once using the existing signed release', async () => {
    process.env.GITHUB_REPOSITORY = sourceRepository;
    try {
      const state = harness();
      state.origin = legacyRepository;
      state.source = fixture(legacyRepository);
      state.published = fixture(sourceRepository).release;
      await publish(state, true);
      assert.deepEqual(state.uploaded, state.source.bytes);
      const create = state.calls.find(call => call[1] === 'release' && call[2] === 'create');
      assert.equal(create[create.indexOf('--repo') + 1], sourceRepository);
      state.calls.length = 0;
      state.releases = [state.published];
      assert.equal(await publish(state, true), 'New source already seeded');
      assert.deepEqual(writes(state), []);
    } finally { process.env.GITHUB_REPOSITORY = legacyRepository; }
  });

  test('refuses running from the renamed repository and checks the final published URLs', async () => {
    process.env.GITHUB_REPOSITORY = sourceRepository;
    try { await assert.rejects(publish(harness()), /permanent legacy repository/); }
    finally { process.env.GITHUB_REPOSITORY = legacyRepository; }
    const state = harness();
    state.published = state.source.release;
    await assert.rejects(publish(state), /asset URL/);
    assert.equal(releaseAssets(fixture(legacyRepository).release, legacyRepository).size, 8);
  });
}
