const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(process.env.PORTABLE_PATHS_ROOT || path.join(__dirname, '..'));

function files(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === 'node_modules' ? [] : files(full);
    return /\.(?:js|mjs|cjs|py)$/.test(entry.name) ? [full] : [];
  });
}

test('test tools find zig on PATH or in ZIG, never in one machine home folder', () => {
  const offenders = ['tools', 'tests', 'extension']
    .flatMap(dir => files(path.join(root, dir)))
    .filter(file => /\/home\/[^/'"]+\/zig\//.test(fs.readFileSync(file, 'utf8')))
    .map(file => path.relative(root, file));
  assert.deepEqual(offenders, [], "use process.env.ZIG || 'zig' or os.environ.get('ZIG', 'zig') instead of a home-folder zig path");
});
