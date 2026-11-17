const fs = require('node:fs');
const path = require('node:path');

function discoverFeatures(directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features')) {
  const result = { full: [], pr: [], available: [] };
  for (const file of fs.readdirSync(directory).sort()) {
    if (!/^[a-z][a-z0-9-]*\.md$/.test(file)) continue;
    const text = fs.readFileSync(path.join(directory, file), 'utf8');
    const metadata = text.match(/^Verify on: (.+)$/m);
    if (!/^## Driving it with control\.ps1\r?$/m.test(text)) {
      if (metadata) throw new Error(`Automatic journey needs a control.ps1 recipe: ${file}`);
      continue;
    }
    const feature = path.basename(file, '.md');
    result.available.push(feature);
    if (!metadata) continue;
    const events = metadata[1].trim().split(', ');
    if (new Set(events).size !== events.length || events.some(event => !['push', 'pull_request'].includes(event))) {
      throw new Error(`Invalid Verify on events: ${file}`);
    }
    if (events.includes('push')) result.full.push(feature);
    if (events.includes('pull_request')) result.pr.push(feature);
  }
  if (!result.full.length || !result.pr.length) throw new Error('Desktop journey matrices must not be empty');
  for (const features of Object.values(result)) features.sort();
  return result;
}

module.exports = { discoverFeatures };

if (require.main === module) {
  const features = discoverFeatures();
  const selected = process.argv[2];
  if (process.argv.length > 3) throw new Error('Expected at most one feature');
  if (selected) {
    if (!features.available.includes(selected)) throw new Error(`Unsupported desktop journey: ${selected}`);
    console.log(JSON.stringify([selected]));
  } else {
    for (const name of ['full', 'pr']) {
      const line = `${name}=${JSON.stringify(features[name])}\n`;
      if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, line);
      process.stdout.write(line);
    }
  }
}
