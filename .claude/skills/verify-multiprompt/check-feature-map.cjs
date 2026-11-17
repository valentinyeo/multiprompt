const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

function checkFeatureMap({ files, shortcutRows, paletteSource, architectureSource }) {
  const errors = [];
  const index = files.get('README.md') || '';
  const names = [...files.keys()].filter(name => name !== 'README.md');
  const links = [...index.matchAll(/\]\(([a-z][a-z0-9-]*\.md)\)/g)].map(match => match[1]);
  for (const name of names) {
    if (links.filter(link => link === name).length !== 1) errors.push(`Index ${name} exactly once in features/README.md`);
  }
  for (const link of links) if (!files.has(link)) errors.push(`Remove dead index link ${link}`);
  const priority = ['long-session-chat', 'server-chats', 'chat-clear', 'chat-stop', 'chat-message-sending'];
  if (priority.some((name, i) => links[i] !== `${name}.md`)) errors.push('List long chats, server chats, /clear, Stop and sending first');
  const all = [...files.values()].join('\n');
  const mapped = new Map();
  for (const [name, text] of files) {
    for (const match of text.matchAll(/^\| `(SEARCH_[A-Z_0-9]+|room\.(?:new|edit)_room_target|session row)` \| (.+) \|$/gm)) {
      const previous = mapped.get(match[1]);
      if (previous) errors.push(`Map ${match[1]} once, not in both ${previous} and ${name}`);
      mapped.set(match[1], name);
      if (!/Follow `[^`]+` above|UNREACHABLE|No distinct palette row/.test(match[2])) errors.push(`Give ${match[1]} a recipe or exact unreachable prerequisite`);
    }
    for (const match of text.matchAll(/\]\(([a-z][a-z0-9-]*\.md)(?:#([^)]*))?\)/g)) {
      if (!files.has(match[1])) { errors.push(`${name}: dead feature link ${match[1]}`); continue; }
      if (match[2]) {
        const target = files.get(match[1]);
        const anchors = [...target.matchAll(/^#+ (.+)$/gm)].map(([, heading]) => heading.toLowerCase().replace(/[^\p{L}\p{N}_\- ]/gu, '').replace(/ /g, '-'));
        if (!anchors.includes(match[2])) errors.push(`${name}: missing heading ${match[1]}#${match[2]}`);
      }
    }
  }
  const update = paletteSource.indexOf('pub fn updateSearchResults()');
  if (update < 0) errors.push('Locate updateSearchResults before checking palette coverage');
  let generation = paletteSource.slice(update);
  for (const helper of ['appendGroupPaletteResults', 'appendPinnedPageResults', 'appendPaletteShellRows', 'appendWorkspaceMovePills']) {
    const start = paletteSource.indexOf(`fn ${helper}(`);
    if (start < 0) { errors.push(`Locate palette helper ${helper}`); continue; }
    generation += paletteSource.slice(start, paletteSource.indexOf('\n}\n', start));
  }
  const targets = new Set([...generation.matchAll(/\bSEARCH_[A-Z_0-9]+/g)].map(match => match[0]).filter(name => !name.endsWith('_COUNT')));
  for (const match of paletteSource.matchAll(/\.target\s*=\s*(?:app_state\.)?(SEARCH_[A-Z_0-9]+)/g)) targets.add(match[1]);
  for (const target of [...targets, 'room.new_room_target', 'room.edit_room_target', 'session row']) {
    if (!mapped.has(target)) errors.push(`Map palette row/family ${target} in its owning feature file`);
  }
  const shortcutText = files.get('shortcuts.md') || '';
  const cells = [...shortcutText.matchAll(/^\| (.+) \|$/gm)].map(match => match[1].split(/(?<!\\) \| /).map(cell => cell.replace(/\\\|/g, '|').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')));
  let section = '';
  for (const row of shortcutRows) {
    if (row.header) section = row.a;
    const action = row.header ? 'F1 section heading' : row.b;
    const found = cells.filter(parts => parts[0] === section && parts[1] === row.a && parts[2] === action);
    if (found.length !== 1) errors.push(`Map shortcut exactly once: ${section} / ${row.a} / ${action}`);
  }
  const architecture = [...architectureSource.matchAll(/^- \*\*([^*]+)\*\*/gm)].map(match => match[1]);
  const future = architectureSource.match(/## Future Features\n([^]*?)(?=\n## |$)/)?.[1] || '';
  architecture.push(...[...future.matchAll(/^- (.+)$/gm)].map(match => match[1].replace(/ \(like.*$/, '')));
  architecture.push('Favorites groups', 'Recents header', 'Chat unread boundary', 'Footprint telemetry', 'Close All Browser Panes', 'Target Footprint');
  for (const name of architecture) {
    if (!all.includes(`\`architecture:${name}\``)) errors.push(`Map architecture feature ${name}`);
  }
  return errors;
}

async function loadFeatureMap(root = path.resolve(__dirname, '../../..')) {
  const { parseShortcutRows } = await import(pathToFileURL(path.join(root, 'tools/shortcuts-doc.mjs')).href);
  const directory = path.join(root, '.claude/skills/verify-multiprompt/features');
  const files = new Map(fs.readdirSync(directory).filter(name => name.endsWith('.md')).map(name => [name, fs.readFileSync(path.join(directory, name), 'utf8')]));
  return {
    files,
    shortcutRows: parseShortcutRows(fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8')),
    paletteSource: fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8'),
    architectureSource: fs.readFileSync(path.join(root, 'openwiki/architecture/features.md'), 'utf8'),
  };
}

module.exports = { checkFeatureMap, loadFeatureMap };
if (require.main === module) loadFeatureMap().then(input => {
  const errors = checkFeatureMap(input);
  if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
  else console.log('Feature map covers every shortcut row, palette target/family and architecture item; index and recipe links are valid. This is source coverage, not a live verdict.');
}).catch(error => { console.error(error.message); process.exitCode = 1; });
