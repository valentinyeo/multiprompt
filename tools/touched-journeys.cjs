const fs = require('node:fs');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');

function touchedJourneys(files, directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features')) {
  const { available } = discoverFeatures(directory);
  const selected = new Set();
  const unmapped = [];
  const maps = available.map(feature => {
    const text = fs.readFileSync(path.join(directory, `${feature}.md`), 'utf8');
    const sources = text.match(/^Source files: (.+)$/m)?.[1].split(', ') || [];
    return { feature, sources };
  });
  for (const file of files) {
    const matches = maps.filter(map => map.sources.some(source => {
      const pattern = source.split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*');
      return new RegExp(`^${pattern}$`).test(file);
    }));
    for (const map of matches) selected.add(map.feature);
    if (!matches.length && !/^\.claude\/skills\/verify-multiprompt\/.*\.md$/.test(file) && /^(src\/|extension\/|build\.zig(?:\.zon)?$|tools\/verify-[^/]+(?:\/|\.ps1$)|\.claude\/skills\/verify-multiprompt\/)/.test(file)) unmapped.push(file);
  }
  return { features: unmapped.length ? available : [...selected].sort(), unmapped };
}

module.exports = { touchedJourneys };

if (require.main === module) {
  const { execFileSync } = require('node:child_process');
  const files = execFileSync('git', ['diff', '--name-only', '-z', `${process.argv[2]}...${process.argv[3] || 'HEAD'}`], { encoding: 'utf8' }).split('\0').filter(Boolean);
  const result = touchedJourneys(files);
  for (const [name, value] of Object.entries(result)) {
    const line = `${name}=${JSON.stringify(value)}\n`;
    if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, line);
    process.stdout.write(line);
  }
}
