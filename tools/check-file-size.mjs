import fs from 'node:fs';
import path from 'node:path';

try {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 1 || args[0] !== '--write')) {
    throw new Error('Usage: node tools/check-file-size.mjs [--write]');
  }
  const cap = 6000;
  const baselinePath = 'tools/file-size-baseline.json';
  const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
  if (!baseline || Array.isArray(baseline) || typeof baseline !== 'object' ||
      Object.entries(baseline).some(([file, count]) => !/^src\/(?:[\w.-]+\/)*[\w.-]+\.zig$/.test(file) || !Number.isSafeInteger(count) || count <= cap)) {
    throw new Error(`${baselinePath}: expected per-file integer line counts above ${cap}`);
  }
  const counts = {};
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = `${directory}/${entry.name}`;
      if (entry.isDirectory()) visit(file);
      else if (entry.isFile() && path.extname(file) === '.zig') {
        const source = fs.readFileSync(file, 'utf8');
        const count = source.split('\n').length - (source.endsWith('\n') || source.length === 0 ? 1 : 0);
        if (count > cap) counts[file] = count;
      }
    }
  }
  visit('src');
  const errors = Object.entries(counts)
    .filter(([file, count]) => count > (baseline[file] ?? cap))
    .map(([file, count]) => `${file}: ${count} lines exceed limit ${baseline[file] ?? cap}. Split the file; do not raise the baseline.`);
  if (errors.length) throw new Error(errors.join('\n'));
  if (args[0] === '--write') {
    fs.writeFileSync(baselinePath, JSON.stringify(counts, null, 2) + '\n');
  }
  console.log(`File-size check passed: ${cap}-line cap, ${Object.keys(counts).length} baselined files. Use --write after splits to lower limits.`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
