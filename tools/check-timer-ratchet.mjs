import fs from 'node:fs';
import path from 'node:path';

try {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 1 || args[0] !== '--write')) {
    throw new Error('Usage: node tools/check-timer-ratchet.mjs [--write]');
  }
  const baselinePath = 'tools/timer-ratchet-baseline.json';
  const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
  if (!baseline || Array.isArray(baseline) || typeof baseline !== 'object' ||
      Object.entries(baseline).some(([file, count]) => !/^src\/.*\.zig$/.test(file) || !Number.isSafeInteger(count) || count < 0)) {
    throw new Error(`${baselinePath}: expected per-file nonnegative integer counts`);
  }
  const counts = {};
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = `${directory}/${entry.name}`;
      if (entry.isDirectory()) visit(file);
      else if (entry.isFile() && path.extname(file) === '.zig') {
        const source = fs.readFileSync(file, 'utf8');
        const count = [...source.matchAll(/\b(?:Sleep|SetTimer)\s*\(|\bstd\s*\.\s*Thread\s*\.\s*sleep\s*\(/g)].length;
        if (count) counts[file] = count;
      }
    }
  }
  visit('src');
  const errors = Object.entries(counts)
    .filter(([file, count]) => count > (baseline[file] ?? 0))
    .map(([file, count]) => `${file}: ${count} Sleep/std.Thread.sleep/SetTimer occurrences exceed baseline ${baseline[file] ?? 0}. Fix the root cause with event-driven or message-driven coordination instead of adding a wait. Do not raise the baseline.`);
  if (errors.length) throw new Error(errors.join('\n'));
  if (args[0] === '--write') {
    fs.writeFileSync(baselinePath, JSON.stringify(counts, null, 2) + '\n');
  }
  const total = Object.values(counts).reduce((sum, count) => sum + count, 0);
  console.log(`Timer ratchet passed: ${total} occurrences in ${Object.keys(counts).length} files. Use --write after removals to lower the baseline; it never increases limits.`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
