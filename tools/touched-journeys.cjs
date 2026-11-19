const fs = require('node:fs');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');

function touchedJourneys(files, directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features')) {
  const { available } = discoverFeatures(directory);
  const selected = new Set();
  const ciWorkflows = new Set();
  const unmapped = [];
  const maps = fs.readdirSync(directory).filter(file => file.endsWith('.md')).flatMap(file => {
    const feature = path.basename(file, '.md');
    const text = fs.readFileSync(path.join(directory, file), 'utf8');
    const ciWorkflow = text.match(/^CI workflow: ([a-z0-9-]+\.yml)$/m)?.[1];
    if (!available.includes(feature) && !ciWorkflow) return [];
    const sources = text.match(/^Source files: (.+)$/m)?.[1].split(', ') || [];
    const covers = text.match(/^Covers: (.+)$/m)?.[1].split(', ').filter(entry => /^(?:src|tools|extension|\.github|\.claude)\//.test(entry)) || [];
    return [{ feature, ciWorkflow, sources: [...sources, ...covers] }];
  });
  for (const file of files) {
    if (/(?:\.test\.[cm]?js|(?:\.test|-test)\.py)$/.test(file)) continue;
    const matches = maps.filter(map => file === `.claude/skills/verify-multiprompt/features/${map.feature}.md` || map.sources.some(source => {
      const pattern = source.split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*');
      return new RegExp(`^${pattern}$`).test(file);
    }));
    for (const map of matches) {
      if (map.ciWorkflow) ciWorkflows.add(map.ciWorkflow);
      else selected.add(map.feature);
    }
    if (!matches.length) unmapped.push(file);
  }
  const nearest = [];
  if (!selected.size && !ciWorkflows.size && files.length) {
    const tokens = value => new Set(value.toLowerCase().split(/[^a-z0-9]+/).filter(word => word.length > 2 && !['src', 'tools', 'github', 'workflows', 'claude', 'skill', 'skills', 'verify', 'multiprompt', 'feature', 'features', 'control', 'test', 'readme', 'zig', 'ps1', 'cjs', 'mjs', 'yml'].includes(word)));
    const ranked = maps.filter(map => !map.ciWorkflow).flatMap(map => {
      const names = tokens(map.feature);
      const sources = tokens(map.sources.join(' '));
      return (unmapped.length ? unmapped : files).map(file => {
        const score = [...tokens(file)].reduce((sum, word) => sum + (names.has(word) ? 10 : 0) + (sources.has(word) ? 1 : 0), 0);
        return { feature: map.feature, file, score };
      });
    }).sort((a, b) => b.score - a.score || Number(b.feature === 'appearance') - Number(a.feature === 'appearance') || a.feature.localeCompare(b.feature) || a.file.localeCompare(b.file));
    selected.add(ranked[0].feature);
    nearest.push({ file: ranked[0].file, feature: ranked[0].feature });
  }
  return { features: [...selected].sort(), unmapped, ...(nearest.length ? { nearest } : {}), ...(ciWorkflows.size ? { ciWorkflows: [...ciWorkflows].sort() } : {}) };
}

async function touchedJourneysForDiff(baseRef, headRef = 'HEAD', directory, root = process.cwd()) {
  const { execFileSync } = require('node:child_process');
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  const head = git('rev-parse', '--verify', `${headRef}^{commit}`).trim();
  const base = git('merge-base', baseRef, head).trim();
  const files = git('diff', '--name-only', '-z', base, head).split('\0').filter(Boolean);
  if (!files.some(file => /^src\/[^/]+\.zig$/.test(file))) return touchedJourneys(files, directory);
  const { nativeTestParts } = await import('./native-test-parts.mjs');
  const scratch = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'journey-diff-'));
  const checkouts = [];
  try {
    for (const [name, revision] of [['base', base], ['head', head]]) {
      const checkout = path.join(scratch, name);
      git('worktree', 'add', '--quiet', '--detach', checkout, revision);
      checkouts.push(checkout);
    }
    const productionFiles = files.filter(file => {
      if (!/^src\/[^/]+\.zig$/.test(file)) return true;
      try {
        const parts = checkouts.map(checkout => {
          const source = path.join(checkout, file);
          if (!fs.lstatSync(source).isFile()) throw new Error('Not a regular Zig source file');
          return nativeTestParts(fs.readFileSync(source, 'utf8'));
        });
        return !(parts[0].names.length > 0 && JSON.stringify(parts[0].names) === JSON.stringify(parts[1].names) && parts[0].outside === parts[1].outside);
      } catch {
        return true;
      }
    });
    return touchedJourneys(productionFiles, directory);
  } finally {
    for (const checkout of checkouts.reverse()) git('worktree', 'remove', '--force', checkout);
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

module.exports = { touchedJourneys, touchedJourneysForDiff };

if (require.main === module) {
  touchedJourneysForDiff(process.argv[2], process.argv[3]).then(result => {
    for (const [name, value] of Object.entries(result)) {
      const line = `${name}=${JSON.stringify(value)}\n`;
      if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, line);
      process.stdout.write(line);
    }
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
