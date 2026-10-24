import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { generateKeyPairSync, createPrivateKey, createPublicKey, createHash, sign } from 'node:crypto';
if (process.env.GITHUB_ACTIONS !== 'true') throw new Error('Throwaway signing runs only inside GitHub');
const root = process.argv[2];
const privateKey = process.env.MULTIPROMPT_TEST_SIGNING_KEY
  ? createPrivateKey({ key: fs.readFileSync(process.env.MULTIPROMPT_TEST_SIGNING_KEY), type: 'pkcs8', format: 'der' })
  : generateKeyPairSync('ed25519').privateKey;
const publicKey = createPublicKey(privateKey);
const rawPublic = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
fs.writeFileSync('src/release_signing_public_key.txt', rawPublic.toString('base64') + '\n');
if (root === '--prepare-key') {
  const keyPath = process.argv[3];
  fs.mkdirSync(path.dirname(keyPath), { recursive: true });
  fs.writeFileSync(keyPath, privateKey.export({ type: 'pkcs8', format: 'der' }));
  console.log('Prepared throwaway update-test signing key');
  process.exit(0);
}
const wrong = generateKeyPairSync('ed25519');
for (const [version, broken] of [['1.10.0', false], ['1.11.0', false], ['1.12.0', true], ['9.10.0', false]]) {
  const dir = path.join(root, `v${version}`);
  fs.mkdirSync(dir, { recursive: true });
  const app = Buffer.concat([fs.readFileSync(path.join(root, broken ? 'broken.exe' : 'fixture.exe')), Buffer.from(`MPVERSION=${version};`)]);
  const bridge = Buffer.concat([fs.readFileSync(path.join(root, 'fixture.exe')), Buffer.from(`BRIDGEVERSION=${version};`)]);
  const names = ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe', 'multiprompt-extension.zip'];
  for (const [i, bytes] of [app, bridge, fs.readFileSync(path.join(root, 'extension.zip'))].entries()) fs.writeFileSync(path.join(dir, names[i]), bytes);
  const releases = version === '9.10.0' ? [
    { version: '9.8.0', changes: ['Older change.'] },
    { version: '9.9.0', changes: ['Middle change.', 'Another middle change.', 'Last middle change.'] },
    { version: '10.0.0', changes: ['Not offered yet.'] },
    { version: '0.0.0', changes: ['Already installed.'] },
    { version, changes: ['Typing feels faster.', 'Chats keep your place.', 'Tabs open sooner.', 'Fix IGSH-123.', 'Fix src/main.zig.'] },
  ] : [{ version, changes: ['Typing feels faster.'] }];
  fs.writeFileSync(path.join(dir, 'release-notes.json'), JSON.stringify({ version, releases }));
  names.push('release-notes.json');
  const sums = Buffer.from(names.map(name => `${createHash('sha256').update(fs.readFileSync(path.join(dir, name))).digest('hex')}  ${name}\n`).join(''));
  fs.writeFileSync(path.join(dir, 'SHA256SUMS.txt'), sums);
  fs.writeFileSync(path.join(dir, 'SHA256SUMS.txt.sig'), sign(null, sums, privateKey));
  fs.writeFileSync(path.join(dir, 'wrong.sig'), sign(null, sums, wrong.privateKey));
}
fs.mkdirSync('dist', { recursive: true });
fs.copyFileSync(path.join(root, 'v1.10.0/SHA256SUMS.txt'), 'dist/SHA256SUMS.txt');
const seed = privateKey.export({ type: 'pkcs8', format: 'der' }).subarray(-32);
const run = spawnSync(process.execPath, ['tools/sign-release.mjs'], { encoding: 'utf8', env: { ...process.env, MULTIPROMPT_RELEASE_SIGNING_KEY: seed.toString('base64') } });
seed.fill(0);
if (run.status !== 0) throw new Error('Production release signing failed with the job-only key');
if (!fs.readFileSync('dist/SHA256SUMS.txt.sig').equals(fs.readFileSync(path.join(root, 'v1.10.0/SHA256SUMS.txt.sig')))) throw new Error('Production release signature differs from fixture signature');
const otherSeed = wrong.privateKey.export({ type: 'pkcs8', format: 'der' }).subarray(-32);
const refused = spawnSync(process.execPath, ['tools/sign-release.mjs'], { encoding: 'utf8', env: { ...process.env, MULTIPROMPT_RELEASE_SIGNING_KEY: otherSeed.toString('base64') } });
otherSeed.fill(0);
if (refused.status === 0 || !refused.stderr.includes('does not match the embedded public key')) throw new Error('Production release signer accepted a mismatching key');
console.log('Signed throwaway local-release fixtures prepared; production signer accepted matching key and rejected mismatching key');
