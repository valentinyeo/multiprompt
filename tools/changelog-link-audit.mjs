import assert from 'node:assert/strict';
import fs from 'node:fs';
import { releaseNotes } from './release-notes.mjs';
const emptyRelease = '.{ .ver = "0.28.1027", .items = &.{\n    } },';
const guard = { fixture: 'synthetic strict-version empty items', rejected: false };
const [manifestPath, tag, output] = process.argv.slice(2);
if (!manifestPath || !/^v\d+\.\d+\.\d+$/.test(tag || '') || !output) {
  throw new Error('Usage: node tools/changelog-link-audit.mjs <manifest> <tag> <output>');
}
try {
  assert.throws(() => releaseNotes(emptyRelease, 'v0.28.1027'), /needs plain ticketed lines/);
  guard.rejected = true;
} finally {
  fs.writeFileSync(output, JSON.stringify(guard, null, 2) + '\n');
}
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8').replace(/^\uFEFF/, ''));
assert.equal(manifest.version, tag.slice(1), 'Manifest version differs from release tag');
assert.ok(Array.isArray(manifest.releases) && manifest.releases.length, 'Manifest has no releases');
assert.equal(manifest.releases[0].version, manifest.version, 'First release differs from manifest version');
const threshold = [0, 28, 1027];
let versions = 0;
let tickets = 0;
const seen = new Set();
for (const release of manifest.releases) {
  assert.match(release.version, /^\d+\.\d+\.\d+$/, 'Invalid release version');
  assert.ok(!seen.has(release.version), 'Duplicate release version');
  seen.add(release.version);
  const parts = release.version.split('.').map(Number);
  const comparison = parts[0] - threshold[0] || parts[1] - threshold[1] || parts[2] - threshold[2];
  if (comparison < 0) continue;
  assert.ok(Array.isArray(release.changes) && release.changes.length > 0, `Empty release ${release.version}`);
  assert.ok(release.changes.every(change => typeof change === 'string' && change.trim()), `Blank change in ${release.version}`);
  assert.ok(Array.isArray(release.tickets) && release.tickets.length === release.changes.length, `Ticket count mismatch in ${release.version}`);
  assert.ok(release.tickets.every(ticket => typeof ticket === 'string' && /^https:\/\/app\.hypertask\.ai\/detail\/project-2060\/\d+$/.test(ticket)), `Noncanonical ticket in ${release.version}`);
  versions++;
  tickets += release.tickets.length;
}
assert.ok(versions > 0, 'No recent releases audited');
assert.ok(Array.isArray(manifest.releases[0].tickets) && manifest.releases[0].tickets.length, 'Current release has no audited tickets');
const oldIndex = manifest.releases.findIndex(release => release.version === '0.28.1048');
assert.ok(oldIndex >= 0, 'Release 0.28.1048 missing');
fs.writeFileSync(output, JSON.stringify({ ...guard, tag, versions, tickets, oldIndex, currentTicket: manifest.releases[0].tickets[0], oldTicket: manifest.releases[oldIndex].tickets[0] }, null, 2) + '\n');
