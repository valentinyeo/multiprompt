import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash, createPublicKey, verify } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const sourceRepository = 'valentinyeo/multibot';
export const legacyRepository = 'valentinyeo/multiprompt';
const required = ['multiprompt-x64.exe', 'multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe', 'multiprompt-extension.zip', 'release-notes.json'];
const version = tag => {
  const match = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.exec(tag);
  if (!match) throw new Error('Invalid release version');
  return match.slice(1).map(BigInt);
};

export function newer(candidate, current) {
  const next = version(candidate);
  const previous = version(current);
  const index = next.findIndex((part, i) => part !== previous[i]);
  return index !== -1 && next[index] > previous[index];
}

export function releaseAssets(release, repository) {
  version(release.tag_name);
  if (release.draft || release.prerelease || release.author?.login !== 'github-actions[bot]') throw new Error('Untrusted release author or channel');
  const assets = new Map();
  for (const asset of release.assets) {
    const name = asset.name;
    if (!/^(?:(?:multiprompt(?:-dev)?|zigshell-bridge)-(?:x64|arm64)\.exe|multiprompt-extension\.zip|release-notes\.json|SHA256SUMS\.txt(?:\.sig)?)$/.test(name)) continue;
    if (assets.has(name) || asset.browser_download_url !== `https://github.com/${repository}/releases/download/${release.tag_name}/${name}`) throw new Error('Untrusted or duplicate asset URL');
    if (!Number.isSafeInteger(asset.size) || asset.size <= 0 || asset.size > 256 * 1024 * 1024) throw new Error('Invalid asset size');
    assets.set(name, asset);
  }
  for (const name of [...required, 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig']) {
    if (!assets.has(name)) throw new Error(`Missing release asset: ${name}`);
  }
  return assets;
}

export function signedFiles(manifest, signature, rawKey) {
  const key = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), rawKey]), format: 'der', type: 'spki' });
  if (manifest.length > 1048576 || signature.length !== 64 || !verify(null, manifest, key, signature)) throw new Error('Invalid release manifest signature');
  const files = new Map();
  for (const line of manifest.toString('utf8').trimEnd().split('\n')) {
    const match = /^([a-f0-9]{64}) [ *]((?:multiprompt(?:-dev)?|zigshell-bridge)-(?:x64|arm64)\.exe|multiprompt-extension\.zip|release-notes\.json)$/.exec(line);
    if (!match || files.has(match[2])) throw new Error('Invalid or duplicate manifest entry');
    files.set(match[2], match[1]);
  }
  for (const name of required) if (!files.has(name)) throw new Error(`Missing signed checksum: ${name}`);
  return files;
}

export function assertLegacyOrigin(repository, workflow) {
  if (repository.full_name !== legacyRepository || repository.archived !== false || workflow.state !== 'active') throw new Error('Permanent legacy update repository or workflow is unavailable; restore it before releasing');
}

const command = (file, args) => execFileSync(file, args, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).trim();
const downloadAsset = async asset => {
  const response = await fetch(asset.browser_download_url, { signal: AbortSignal.timeout(60000) });
  if (!response.ok) throw new Error(`Download failed: ${asset.name} (${response.status})`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length !== asset.size) throw new Error(`Asset size mismatch: ${asset.name}`);
  return bytes;
};

export async function mirrorRelease({ gh = args => command('gh', args), git = args => command('git', args), download = downloadAsset, rawKey = Buffer.from(fs.readFileSync('src/release_signing_public_key.txt', 'utf8').trim(), 'base64'), bootstrap = process.env.LEGACY_FEED_BOOTSTRAP === 'true' } = {}) {
  const destination = process.env.GITHUB_REPOSITORY;
  if (destination !== legacyRepository && !(bootstrap && destination === sourceRepository)) throw new Error('Run only in the permanent legacy repository, or explicitly bootstrap the new source');
  const origin = destination === legacyRepository ? sourceRepository : legacyRepository;
  let releases;
  let current;
  if (destination === sourceRepository) {
    releases = JSON.parse(gh(['api', '--paginate', '--slurp', `repos/${destination}/releases?per_page=100`])).flat();
    if (releases.some(release => !release.draft)) return 'New source already seeded';
  } else {
    current = JSON.parse(gh(['api', `repos/${destination}/releases/latest`]));
    releaseAssets(current, destination);
  }
  const source = JSON.parse(gh(['api', `repos/${origin}/releases/latest`]));
  const assets = releaseAssets(source, origin);
  if (current && !newer(source.tag_name, current.tag_name)) return 'Legacy update feed already current';
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'multibot-legacy-release-'));
  try {
    const manifest = await download(assets.get('SHA256SUMS.txt'));
    const signature = await download(assets.get('SHA256SUMS.txt.sig'));
    const files = signedFiles(manifest, signature, rawKey);
    fs.writeFileSync(path.join(directory, 'SHA256SUMS.txt'), manifest);
    fs.writeFileSync(path.join(directory, 'SHA256SUMS.txt.sig'), signature);
    for (const [name, expected] of files) {
      if (!assets.has(name)) throw new Error(`Missing signed asset: ${name}`);
      const bytes = await download(assets.get(name));
      if (createHash('sha256').update(bytes).digest('hex') !== expected) throw new Error(`Checksum mismatch: ${name}`);
      if (name === 'release-notes.json' && JSON.parse(bytes).version !== source.tag_name.slice(1)) throw new Error('Release notes version mismatch');
      if (name === 'multiprompt-x64.exe' || name === 'multiprompt-arm64.exe') {
        if (!bytes.includes(Buffer.from(`MPVERSION=${source.tag_name.slice(1)};`))) throw new Error('Executable version mismatch');
      }
      fs.writeFileSync(path.join(directory, name), bytes);
    }
    git(['fetch', '--no-tags', `https://github.com/${origin}.git`, `refs/tags/${source.tag_name}`]);
    const sha = git(['rev-parse', '--verify', 'FETCH_HEAD^{commit}']);
    if (!/^[a-f0-9]{40}$/.test(sha)) throw new Error('Invalid release commit');
    git(['push', 'origin', `${sha}:refs/tags/${source.tag_name}`]);
    releases ??= JSON.parse(gh(['api', '--paginate', '--slurp', `repos/${destination}/releases?per_page=100`])).flat();
    const existing = releases.find(release => release.tag_name === source.tag_name);
    const paths = fs.readdirSync(directory).map(name => path.join(directory, name));
    if (existing) {
      if (!existing.draft || existing.prerelease || existing.author?.login !== 'github-actions[bot]') throw new Error('Refusing to change an existing published or untrusted release');
      gh(['release', 'upload', source.tag_name, ...paths, '--repo', destination, '--clobber']);
    } else {
      gh(['release', 'create', source.tag_name, ...paths, '--repo', destination, '--verify-tag', '--draft', '--title', `Multibot ${source.tag_name}`, '--notes', `Signed update from https://github.com/${origin}/releases/tag/${source.tag_name}`]);
    }
    gh(['release', 'edit', source.tag_name, '--repo', destination, '--draft=false', '--latest']);
    const published = JSON.parse(gh(['api', `repos/${destination}/releases/tags/${source.tag_name}`]));
    releaseAssets(published, destination);
    return `LEGACY_UPDATE_PUBLISHED ${source.tag_name} ${sha}`;
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv[2] === '--check-origin') {
    const api = route => JSON.parse(command('gh', ['api', `repos/${legacyRepository}${route}`]));
    assertLegacyOrigin(api(''), api('/actions/workflows/legacy-update-feed.yml'));
    console.log('LEGACY_UPDATE_ORIGIN_ACTIVE');
  } else {
    console.log(await mirrorRelease());
  }
}
