const fs = require('node:fs');
const path = require('node:path');

function readChangelogFragment(filename, root = path.resolve(__dirname, '..')) {
  const ticket = /^([A-Z][A-Z0-9]*-\d+)-[^/\\]+\.md$/.exec(filename)?.[1];
  if (!ticket) throw new Error(`Invalid changelog fragment filename: ${filename}`);
  try {
    return fs.readFileSync(path.join(root, 'changelog.d', filename), 'utf8');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const source = fs.readFileSync(path.join(root, 'src/changelog.zig'), 'utf8');
  const bullets = [...source.matchAll(/\.\{ \.text = ("(?:\\.|[^"\\])*"), \.ticket = "([A-Z][A-Z0-9]*-\d+)" \},/g)]
    .filter(match => match[2] === ticket)
    .map(match => JSON.parse(match[1]));
  if (!bullets.length) throw new Error(`Missing changelog fragment ${filename} and released text for ${ticket}`);
  return bullets.join('\n') + '\n';
}

module.exports = { readChangelogFragment };
