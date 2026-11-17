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

const test = require('node:test');
const assert = require('node:assert/strict');

const loaded = loadFeatureMap();

test('every source action has one reachable recipe or explicit missing prerequisite', async () => {
  assert.deepEqual(checkFeatureMap(await loaded), []);
});

test('missing, duplicate and dead index entries fail with the repair', async () => {
  const input = await loaded;
  const files = new Map(input.files);
  files.set('README.md', files.get('README.md').replace('- [Chat in long sessions](long-session-chat.md).', '') + '\n[dead](removed-feature.md)\n[duplicate](palette.md)\n');
  const errors = checkFeatureMap({ ...input, files });
  assert.ok(errors.includes('Index long-session-chat.md exactly once in features/README.md'));
  assert.ok(errors.includes('Index palette.md exactly once in features/README.md'));
  assert.ok(errors.includes('Remove dead index link removed-feature.md'));
});

test('new shortcut and palette actions cannot silently escape the map', async () => {
  const input = await loaded;
  const errors = checkFeatureMap({ ...input,
    shortcutRows: [...input.shortcutRows, { a: 'Ctrl+New', b: 'New visible action', header: false }],
    paletteSource: input.paletteSource + '\napp_state.g_search_results[0] = SEARCH_NEW_VISIBLE_ACTION_OFFSET;\n',
  });
  assert.ok(errors.some(error => error.includes('Ctrl+New / New visible action')));
  assert.ok(errors.includes('Map palette row/family SEARCH_NEW_VISIBLE_ACTION_OFFSET in its owning feature file'));
});

test('architecture additions and broken recipe anchors cannot masquerade as coverage', async () => {
  const input = await loaded;
  const files = new Map(input.files);
  files.set('shortcuts.md', files.get('shortcuts.md').replace('sidebar-sessions.md#select-select-and-reopen-sessions', 'sidebar-sessions.md#missing-recipe'));
  const errors = checkFeatureMap({ ...input, files, architectureSource: input.architectureSource + '\n- **New user feature**: do something.\n' });
  assert.ok(errors.includes('Map architecture feature New user feature'));
  assert.ok(errors.some(error => error.includes('missing heading sidebar-sessions.md#missing-recipe')));
});

test('server-group recipe can read and republish the same layout with its generated module', async t => {
  const fs = require('node:fs');
  const path = require('node:path');
  const os = require('node:os');
  const http = require('node:http');
  const { execFile } = require('node:child_process');
  const { promisify } = require('node:util');
  const driver = fs.readFileSync(path.join(__dirname, 'control-feature-server-open-group.ps1'), 'utf8');
  const script = driver.match(/WriteAllText\(\$bumpPath, "([^]*?)"\)/)?.[1];
  assert.ok(script, 'extract the actual generated account-layout module');
  const call = driver.match(/Invoke-ServerGroupNode @\(([^)]*\$bumpPath[^)]*)\)/)?.[1];
  assert.ok(call, 'extract the actual node invocation');
  const flags = [...call.matchAll(/'([^']+)'/g)].map(match => match[1]);
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-server-group-module-'));
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }));
  const modulePath = path.join(scratch, 'bump.mjs');
  const statePath = path.join(scratch, 'state.json');
  fs.writeFileSync(modulePath, script.replace(/`n/g, '\n'));
  fs.writeFileSync(statePath, JSON.stringify({ admin_key: 'synthetic-fixture-only' }));
  const layout = { groups: [{ id: 1, name: 'Runners' }], tabs: [{ tmux: 'fixture-session', group: 'Runners' }] };
  const requests = [];
  const server = http.createServer((request, response) => {
    let body = '';
    request.on('data', chunk => { body += chunk; });
    request.on('end', () => {
      requests.push({ method: request.method, url: request.url, authorization: request.headers.authorization, body });
      response.setHeader('Content-Type', 'application/json');
      response.end(JSON.stringify({ revision: 7, layout }));
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  let exitCode = 0;
  try {
    await promisify(execFile)(process.execPath, [...flags, modulePath], { timeout: 10000, env: { ...process.env, MP_STATE: statePath, MP_URL: `http://127.0.0.1:${server.address().port}` } });
  } catch (error) {
    exitCode = error.code;
  }
  assert.equal(exitCode, 0, 'the generated layout module must complete its read/write roundtrip');
  assert.deepEqual(requests.map(request => [request.method, request.url]), [['GET', '/v1/layout'], ['PUT', '/v1/layout']]);
  assert.ok(requests.every(request => request.authorization === 'Bearer synthetic-fixture-only'));
  assert.deepEqual(JSON.parse(requests[1].body), { base_revision: 7, layout });
});
