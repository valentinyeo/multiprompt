const fs = require('node:fs');
const path = require('node:path');

function readChangelogEntry(ticket, root = path.resolve(__dirname, '..')) {
  if (!/^[A-Z][A-Z0-9]*-\d+$/.test(ticket)) throw new Error(`Invalid changelog ticket: ${ticket}`);
  const directory = path.join(root, 'changelog.d');
  let fragments;
  try {
    fragments = fs.readdirSync(directory).filter(file => file.startsWith(`${ticket}-`) && file.endsWith('.md')).sort();
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    fragments = [];
  }
  let lines;
  if (fragments.length) {
    lines = fragments.flatMap(file => fs.readFileSync(path.join(directory, file), 'utf8').split(/\r?\n/).map(line => line.trim()).filter(Boolean));
  } else {
    const released = fs.readFileSync(path.join(root, 'src/changelog.zig'), 'utf8');
    lines = [...released.matchAll(/\.\{\s*\.text = ("(?:\\.|[^"\\])*"),\s*\.ticket = "([^"]+)"\s*\}/g)]
      .filter(match => match[2] === ticket).map(match => JSON.parse(match[1]));
  }
  if (!lines.length) throw new Error(`No changelog entry for ${ticket}`);
  return `${lines.join('\n')}\n`;
}

module.exports = { readChangelogEntry };
