import fs from 'node:fs';
import crypto from 'node:crypto';
const manifest = fs.readFileSync('baseline-bin/SHA256SUMS.txt');
const raw = Buffer.from(fs.readFileSync('src/release_signing_public_key.txt', 'utf8').trim(), 'base64');
const key = crypto.createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), raw]), format: 'der', type: 'spki' });
if (!crypto.verify(null, manifest, key, fs.readFileSync('baseline-bin/SHA256SUMS.txt.sig'))) throw new Error('Invalid baseline signature');
for (const file of ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe']) {
  const lines = manifest.toString('utf8').split(/\r?\n/).filter(line => line.endsWith(`  ${file}`));
  if (lines.length !== 1 || !/^[a-f0-9]{64}  /.test(lines[0])) throw new Error(`Missing baseline checksum: ${file}`);
  const actual = crypto.createHash('sha256').update(fs.readFileSync(`baseline-bin/${file}`)).digest('hex');
  if (actual !== lines[0].slice(0, 64)) throw new Error(`Bad baseline checksum: ${file}`);
}
