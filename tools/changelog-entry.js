const fs = require('node:fs');
const path = require('node:path');
const { parseTicketId, fragmentTicketId } = require('./ticket-id.js');

function readChangelogEntry(ticket, root = path.resolve(__dirname, '..')) {
  const parsed = parseTicketId(ticket);
  if (!parsed) throw new Error(`Invalid changelog ticket: ${ticket}`);
  ticket = parsed.id;
  const directory = path.join(root, 'changelog.d');
  let fragments;
  try {
    fragments = fs.readdirSync(directory).filter(file => file !== 'README.md' && file.endsWith('.md') && fragmentTicketId(`changelog.d/${file}`) === ticket).sort();
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
      .filter(match => parseTicketId(match[2])?.id === ticket).map(match => JSON.parse(match[1]));
  }
  if (!lines.length) throw new Error(`No changelog entry for ${ticket}`);
  return `${lines.join('\n')}\n`;
}

module.exports = { readChangelogEntry };
