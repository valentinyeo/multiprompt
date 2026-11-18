#!/usr/bin/env node
import { spawnSync, spawn as childSpawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, statSync, lstatSync, openSync, closeSync, writeFileSync, renameSync, unlinkSync, constants } from 'node:fs';
import { basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { setTimeout as wait } from 'node:timers/promises';

const DEFAULT_URL = 'https://account.multiprompt.dev';
const USAGE = `usage: mp-layout <command> [options]

commands:
  list [--json]                                    show workspaces and their sessions
  create-section <name>                            add a workspace
  move --to <workspace> [--create] <session>...    move sessions into a workspace in one change
  move --to <workspace> --match <glob> [--host N]  move every session whose name matches
  spawn --name NAME --folder DIR --workspace WORKSPACE [--group GROUP] [--mode visible|headless] [--provider claude|hax] [--task TEXT] [--host N]  create or reveal a live chat
  open <session> [--workspace <name>] [--host N] [--title <text>|--name <text>] [--group <group>] [--star] [--move] [--no-tmux]
  open --kind shell --tmux <session> --name <title> --workspace <name> [--group <group>] [--host N] [--star] [--move] [--no-tmux]
  open --kind chat --name NAME --folder DIR --workspace WORKSPACE [--group GROUP] [--mode visible|headless] [--provider claude|hax] [--task TEXT] [--host N]

environment:
  MULTIPROMPT_KEY   admin or workspace key (never printed)
  MULTIPROMPT_URL   account service address (default ${DEFAULT_URL})
  MULTIPROMPT_HOST  default host slot for open and spawn (default 0)
  MULTIPROMPT_READER  path to the installed host reader
`;

const SESSION_USAGE = `usage: mp session <command> [options]

  new --name X --folder Y [--workspace W] [--group G] [--task -] [--helper]
  star X [--host N]
  unstar X [--host N]
  move X --workspace W [--group G] [--host N]
  list [--json]

New chats are visible, top-level sessions in the first account workspace.
An existing name is reused, including after moving it. --helper places a
chat below the calling MULTIPROMPT_TAB, inheriting its workspace and group.
--task - reads stdin. Identical task retries are sent only once.
New also accepts --host N and --provider claude|hax (default claude).
The server reads its approved account key with yeo-key; no key is passed in.
`;

class Failure extends Error {}

function loadSessionKey(env) {
  const result = spawnSync('yeo-key', ['Multiprompt Layout Admin Key Mini Boss CEO', 'MULTIPROMPT_KEY'], {
    env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 90000, maxBuffer: 4096
  });
  if (result.status !== 0 || !/^mpk_a_[A-Za-z0-9_-]{43}$/.test(result.stdout.trim())) throw new Failure('cannot read the approved account key with yeo-key');
  return result.stdout.trim();
}

function sessionFlags(argv, verb) {
  const allowed = {
    new: ['name', 'folder', 'workspace', 'group', 'task', 'helper', 'host', 'provider'],
    star: ['host'], unstar: ['host'], move: ['workspace', 'group', 'host'], list: ['json']
  }[verb];
  if (!allowed) throw new Failure('unknown session command; use mp session --help');
  const seen = new Set();
  for (let i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    const flag = argv[i].slice(2);
    if (!allowed.includes(flag) || seen.has(flag)) throw new Failure('invalid or repeated session option');
    seen.add(flag);
    if (!['helper', 'json'].includes(flag)) {
      if (!argv[i + 1] || argv[i + 1].startsWith('--')) throw new Failure(`--${flag} needs a value`);
      i++;
    }
  }
  const flags = parse(argv, verb);
  if (verb === 'new' && (flags._.length || !flags.name || !flags.folder)) throw new Failure('new needs --name and --folder');
  if (verb === 'list' && flags._.length) throw new Failure('list takes no session name');
  if (['star', 'unstar', 'move'].includes(verb) && flags._.length !== 1) throw new Failure('give one session name');
  if (verb === 'move' && !flags.workspace) throw new Failure('move needs --workspace');
  return flags;
}

const REFUSALS = {
  scope_denied: 'refused: this key may change only its own workspace',
  key_scope: 'refused: keys work only on the layout',
  device_required: 'the key was not accepted',
  workspace_not_found: 'the workspace for this key does not exist',
  invalid_layout: 'the service rejected the layout (workspace or session limits?)',
  invalid_tab: 'the service rejected a session entry',
  invalid_workspace: 'the service rejected the workspace name'
};

function parse(argv, command) {
  const flags = { _: [] };
  const withValue = new Set(['to', 'match', 'host', 'workspace', 'title', 'name', 'folder', 'task', 'group', 'mode', 'provider', 'kind', 'tmux']);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) { flags._.push(arg); continue; }
    const name = arg.slice(2);
    if (command === 'spawn' && (!['name', 'folder', 'workspace', 'task', 'host', 'group', 'mode', 'provider'].includes(name) || Object.hasOwn(flags, name))) throw new Failure('invalid spawn option');
    if (withValue.has(name)) {
      if (i + 1 >= argv.length || (command === 'spawn' && argv[i + 1].startsWith('--'))) throw new Failure(`--${name} needs a value`);
      flags[name] = argv[++i];
    } else if (['json', 'create', 'no-tmux', 'star', 'move', 'helper'].includes(name)) flags[name] = true;
    else throw new Failure(`unknown option --${name}`);
  }
  return flags;
}

const tabId = tab => `${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`;
const globToRegExp = glob => new RegExp('^' + glob.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.') + '$', 'i');
const hostSlot = text => {
  const n = Number(text);
  if (!Number.isInteger(n) || n < 0 || n > 2) throw new Failure('host must be 0, 1 or 2');
  return n;
};

function normalizedGroup(value) {
  if (value === undefined) return null;
  const group = value.normalize('NFC').trim();
  if (!group || group.length > 64 || /[\p{Cc}\p{Cs}]/u.test(group)) throw new Failure('invalid group');
  return group;
}

async function call(ctx, method, body) {
  const features = ctx.session ? 'groups,favorite,muted' : ctx.command === 'spawn' ? 'groups' : ctx.command === 'open' ? (ctx.features || 'groups') : '';
  let response;
  try {
    response = await ctx.fetch(ctx.url + '/v1/layout', {
      method,
      headers: { Authorization: 'Bearer ' + ctx.key, 'Content-Type': 'application/json', ...(features ? { 'X-Layout-Features': features } : {}) },
      body: body ? JSON.stringify(body) : undefined,
      ...(ctx.command === 'spawn' || ctx.session ? { signal: AbortSignal.timeout(8000) } : {})
    });
  } catch (e) {
    throw new Failure('cannot reach the account service: ' + (e.cause?.code || e.message));
  }
  let data = null;
  try { data = await response.json(); } catch { data = null; }
  const featuresSupported = new Set((response.headers?.get('X-Layout-Features') || '').split(',').map(feature => feature.trim()));
  return { status: response.status, data, groupsSupported: featuresSupported.has('groups'), featuresSupported };
}

function refusal(result) {
  const code = result.data?.error;
  return new Failure(REFUSALS[code] || `service answered ${result.status}`);
}

async function edit(ctx, mutate) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const read = await call(ctx, 'GET');
    if (read.status !== 200) throw refusal(read);
    const next = mutate(structuredClone(read.data.layout), read);
    if (!next) return { changed: false, revision: read.data.revision };
    const write = await call(ctx, 'PUT', { base_revision: read.data.revision, layout: next });
    if (write.status === 200) return { changed: true, revision: write.data.revision };
    if (write.status !== 409) throw refusal(write);
  }
  throw new Failure('the layout kept changing; try again');
}

async function list(ctx, flags) {
  const read = await call(ctx, 'GET');
  if (read.status !== 200) throw refusal(read);
  const { revision, layout } = read.data;
  if (flags.json) { ctx.out(JSON.stringify({ revision, workspaces: layout.workspaces.map(w => ({ name: w.name, sessions: layout.tabs.filter(t => t.workspace === w.name).map(t => ({ session: t.tmux_session, name: t.name, host: t.tmux_host, ...(ctx.session ? { group: t.group || null, starred: t.favorite === true } : {}) })) })) })); return; }
  ctx.out(`revision ${revision}`);
  for (const w of layout.workspaces) {
    const tabs = layout.tabs.filter(t => t.workspace === w.name);
    ctx.out(`${w.name} (${tabs.length})`);
    for (const t of tabs) ctx.out(`  ${t.tmux_session}  host ${t.tmux_host}  ${t.name}${ctx.session && t.group ? '  group ' + t.group : ''}${ctx.session && t.favorite ? '  starred' : ''}`);
  }
}

function namedSession(layout, name, host) {
  const wanted = name.normalize('NFC').trim().toLowerCase();
  const matches = layout.tabs.filter(tab => (host === undefined || tab.tmux_host === host) && (tab.tmux_session.toLowerCase() === wanted || tab.name.normalize('NFC').trim().toLowerCase() === wanted));
  if (matches.length > 1) throw new Failure('session name is ambiguous; use --host or the session id');
  return matches[0];
}

async function visibleSession(ctx, host, session, matches = () => true) {
  for (let attempt = 0; attempt < 20; attempt++) {
    if (attempt) await ctx.wait(250);
    const read = await call(ctx, 'GET');
    if (read.status !== 200) throw refusal(read);
    const tab = read.data.layout.tabs.find(tab => tab.tmux_host === host && tab.tmux_session === session);
    if (tab && read.data.layout.workspaces.some(workspace => workspace.name === tab.workspace) && matches(tab)) return { tab, revision: read.data.revision };
  }
  throw new Failure('session is not visible in the requested account layout; retry the same command');
}

async function changeSession(ctx, flags) {
  const host = flags.host === undefined ? undefined : hostSlot(flags.host);
  const group = normalizedGroup(flags.group);
  let target;
  const result = await edit(ctx, (layout, read) => {
    if (ctx.command !== 'move' && !read.featuresSupported.has('favorite')) throw new Failure('account service does not support Starred');
    if (group !== null && !read.groupsSupported) throw new Failure('account service does not support groups');
    const tab = namedSession(layout, flags._[0], host);
    if (!tab) throw new Failure('session not found; use mp session list');
    target = { host: tab.tmux_host, session: tab.tmux_session };
    if (ctx.command !== 'move') {
      const wanted = ctx.command === 'star';
      if (tab.favorite === wanted) return null;
      tab.favorite = wanted;
    } else {
      if (!layout.workspaces.some(workspace => workspace.name === flags.workspace)) throw new Failure('workspace not found; use mp session list');
      if (tab.workspace === flags.workspace && (tab.group || null) === group) return null;
      tab.workspace = flags.workspace;
      if (group === null) delete tab.group;
      else tab.group = group;
    }
    return layout;
  });
  const verified = await visibleSession(ctx, target.host, target.session, tab => ctx.command === 'move'
    ? tab.workspace === flags.workspace && (tab.group || null) === group
    : (tab.favorite === true) === (ctx.command === 'star'));
  ctx.out(JSON.stringify({ ok: true, visible: true, session: target.session, workspace: verified.tab.workspace, group: verified.tab.group || null, starred: verified.tab.favorite === true, changed: result.changed, revision: verified.revision }));
}

async function createSection(ctx, flags) {
  const name = flags._[0];
  if (!name || flags._.length !== 1) throw new Failure('give one section name');
  const result = await edit(ctx, layout => {
    if (layout.workspaces.some(w => w.name === name)) return null;
    layout.workspaces.push({ name });
    return layout;
  });
  ctx.out(result.changed ? `created section ${name} (revision ${result.revision})` : `section ${name} already exists (revision ${result.revision})`);
}

async function move(ctx, flags) {
  const target = flags.to;
  if (!target) throw new Failure('move needs --to <workspace>');
  const names = flags._.map(s => s.toLowerCase());
  if (!names.length && !flags.match) throw new Failure('give session names or --match <glob>');
  if (names.length && flags.match) throw new Failure('use session names or --match, not both');
  const pattern = flags.match ? globToRegExp(flags.match) : null;
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  let moved = 0;
  const result = await edit(ctx, layout => {
    if (!layout.workspaces.some(w => w.name === target)) {
      if (!flags.create) throw new Failure(`workspace ${target} not found or not visible to this key (use --create to add it)`);
      layout.workspaces.push({ name: target });
    }
    const picked = layout.tabs.filter(t => (pattern ? pattern.test(t.tmux_session) : names.includes(t.tmux_session.toLowerCase())) && (host === null || t.tmux_host === host));
    const missing = names.filter(n => !picked.some(t => t.tmux_session.toLowerCase() === n));
    if (missing.length) throw new Failure(`no such session: ${missing.join(', ')}`);
    if (!picked.length) throw new Failure('no session matched');
    const ids = new Set(picked.map(tabId));
    for (const t of picked) t.workspace = target;
    layout.tabs = [...layout.tabs.filter(t => !ids.has(tabId(t))), ...picked];
    moved = picked.length;
    return layout;
  });
  ctx.out(`moved ${moved} session${moved === 1 ? '' : 's'} to ${target} (revision ${result.revision})`);
}

function ensureTmux(ctx, session) {
  if (ctx.tmux(['has-session', '-t', '=' + session]).status === 0) return false;
  const created = ctx.tmux(['new-session', '-d', '-s', session]);
  if (created.status !== 0) throw new Failure('could not start the tmux session');
  return true;
}

async function open(ctx, flags) {
  const positional = flags._;
  const session = flags.tmux || positional[0];
  if (!session || positional.length > 1 || (flags.tmux && positional.length === 1 && positional[0] !== flags.tmux)) throw new Failure('give one session name');
  if (!/^[A-Za-z0-9_-]{1,63}$/.test(session)) throw new Failure('session names use letters, digits, - and _ (63 at most)');
  const host = hostSlot(flags.host ?? ctx.env.MULTIPROMPT_HOST ?? '0');
  const title = flags.name || flags.title || session;
  const group = normalizedGroup(flags.group);
  ctx.features = flags.star ? 'groups,favorite' : 'groups';
  if (group !== null) {
    const probe = await call(ctx, 'GET');
    if (probe.status !== 200) throw refusal(probe);
    if (!probe.groupsSupported) throw new Failure('account service does not support groups');
  }
  let started = false;
  if (!flags['no-tmux']) started = ensureTmux(ctx, session);
  const result = await edit(ctx, layout => {
    const workspace = flags.workspace || (layout.workspaces.length === 1 ? layout.workspaces[0].name : null);
    if (!workspace) throw new Failure('give --workspace <name>');
    if (!layout.workspaces.some(w => w.name === workspace)) throw new Failure(`workspace ${workspace} not found or not visible to this key`);
    const existing = layout.tabs.find(t => tabId(t) === `${host}:${session.toLowerCase()}`);
    if (existing) {
      let changed = false;
      if (existing.workspace !== workspace) {
        if (!flags.move) throw new Failure(`session ${session} is already open in ${existing.workspace}`);
        existing.workspace = workspace;
        changed = true;
      }
      if (group !== null && (existing.group || null) !== group) {
        existing.group = group;
        changed = true;
      }
      if (flags.star && existing.favorite !== true) {
        existing.favorite = true;
        changed = true;
      }
      return changed ? layout : null;
    }
    layout.tabs.push({ kind: 'tmux', name: title.slice(0, 64), tmux_session: session, tmux_host: host, workspace, ...(group === null ? {} : { group }), ...(flags.star ? { favorite: true } : {}) });
    return layout;
  });
  ctx.out(`${result.changed ? 'opened' : 'already open'} ${session}${started ? ' (tmux session started)' : ''} (revision ${result.revision})`);
}

const hash = value => createHash('sha256').update(value).digest('hex');

function spawnLock(path, env) {
  return new Promise((resolve, reject) => {
    const child = childSpawn('flock', ['-w', '8', path, 'sh', '-c', 'printf "locked\\n"; cat >/dev/null'], {
      env, stdio: ['pipe', 'pipe', 'ignore']
    });
    let ready = false;
    child.stdin.on('error', () => {});
    child.stdout.once('data', () => { ready = true; resolve(() => { if (!child.stdin.destroyed) child.stdin.end(); }); });
    child.once('error', () => reject(new Failure('could not acquire setup lock')));
    child.once('exit', () => { if (!ready) reject(new Failure('could not acquire setup lock')); });
  });
}

async function spawnSession(ctx, flags) {
  if (flags._.length || !flags.name || !flags.folder || (!ctx.session && !flags.workspace)) throw new Failure('spawn needs name, folder and workspace');
  const name = flags.name.normalize('NFC').trim();
  let group = normalizedGroup(flags.group);
  const mode = flags.mode ?? 'visible';
  if (!['visible', 'headless'].includes(mode)) throw new Failure('mode must be visible or headless');
  let provider = flags.provider ?? 'claude';
  if (!['claude', 'hax'].includes(provider)) throw new Failure('provider must be claude or hax');
  if (!name || name.length > 64 || /[\p{Cc}\p{Cs}]/u.test(name)) throw new Failure('invalid session name');
  if (flags.workspace !== undefined && (!flags.workspace.trim() || Buffer.byteLength(flags.workspace, 'utf8') > 31 || /[\p{Cc}\p{Cs}]/u.test(flags.workspace))) throw new Failure('invalid workspace');
  if (flags.task !== undefined && (!flags.task.trim() || flags.task.includes('\0') || Buffer.byteLength(flags.task, 'utf8') > 65536)) throw new Failure('invalid task');
  const hostText = flags.host ?? ctx.env.MULTIPROMPT_HOST ?? '0';
  if (!/^[0-2]$/.test(hostText)) throw new Failure('host must be 0, 1 or 2');
  const host = hostSlot(hostText);
  let folder;
  try { folder = ctx.resolveFolder(flags.folder); }
  catch { throw new Failure('invalid folder'); }
  if (!/^[A-Za-z0-9_./~+-]{1,220}$/.test(folder)) throw new Failure('invalid folder');
  const runtime = (args, input) => {
    let result;
    try { result = ctx.runtime(args, input); } catch { throw new Failure('host operation failed'); }
    if (result.status !== 0) throw new Failure('host operation failed');
    try { return result.stdout.trim().split('\n').filter(Boolean).map(line => JSON.parse(line)); } catch { throw new Failure('invalid host response'); }
  };
  const initial = await call(ctx, 'GET');
  if (initial.status !== 200) throw new Failure(initial.status === 401 || initial.status === 403 ? 'key not authorized' : 'account read failed');
  let parent;
  if (flags.helper) {
    if (!ctx.env.MULTIPROMPT_TAB) throw new Failure('--helper needs a calling MULTIPROMPT_TAB');
    parent = initial.data.layout.tabs.find(tab => tab.tmux_host === host && tab.tmux_session === ctx.env.MULTIPROMPT_TAB);
    if (!parent) throw new Failure('calling session is not visible in the account layout');
    if (flags.workspace && flags.workspace !== parent.workspace) throw new Failure('a helper must use the calling workspace');
    if (group !== null && group !== (parent.group || null)) throw new Failure('a helper must use the calling group');
    flags.workspace = parent.workspace;
    group = parent.group || null;
  }
  const existingName = ctx.session ? namedSession(initial.data.layout, name, host) : null;
  if (ctx.session) {
    flags.workspace ||= existingName?.workspace || initial.data.layout.workspaces[0]?.name;
    if (!flags.workspace) throw new Failure('no account workspace exists');
    if (existingName && flags.group === undefined && !flags.helper) group = existingName.group || null;
  }
  if (group !== null && !initial.groupsSupported) throw new Failure('account service does not support groups');
  const digest = hash(JSON.stringify(parent ? [host, parent.tmux_session, name.toLowerCase()] : [host, name.toLowerCase()]));
  const bytes = Buffer.from(digest.slice(0, 32), 'hex');
  bytes[6] = (bytes[6] & 15) | 128;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = bytes.toString('hex');
  let sid = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  let session = 'live-' + hex;
  if (existingName) {
    const [listing] = runtime(['host', 'list']);
    const chats = listing?.chats?.filter(chat => chat.name === existingName.tmux_session) || [];
    if (chats.length > 1) throw new Failure('existing session has ambiguous host ownership');
    if (chats.length === 1) {
      const chat = chats[0];
      if (flags.provider && flags.provider !== chat.provider) throw new Failure('existing session uses another provider');
      sid = chat.sid; provider = chat.provider; session = chat.name;
    } else if (existingName.tmux_session !== session) {
      if (flags.task !== undefined || ctx.tmux(['has-session', '-t', '=' + existingName.tmux_session]).status !== 0) throw new Failure('existing session has no restartable live host');
      const verified = await visibleSession(ctx, host, existingName.tmux_session);
      ctx.out(JSON.stringify({ ok: true, visible: true, session: existingName.tmux_session, host, name: existingName.name, workspace: verified.tab.workspace, group: verified.tab.group || null, changed: false, revision: verified.revision }));
      return;
    }
  }
  const token = 'mp-spawn-' + (ctx.session && flags.task !== undefined ? hash(sid + ':' + flags.task) : hex);
  const check = layout => {
    if (!layout.workspaces.some(w => w.name === flags.workspace)) throw new Failure('workspace not found or not visible to this key');
    const existing = layout.tabs.find(t => t.tmux_host === host && t.tmux_session?.toLowerCase() === session);
    const sameName = layout.tabs.find(t => t.tmux_host === host && typeof t.name === 'string' && t.name.normalize('NFC').trim().toLowerCase() === name.toLowerCase() && t !== existing);
    if (sameName || (existing && (existing.kind !== 'tmux' || (!ctx.session && existing.workspace !== flags.workspace) || typeof existing.name !== 'string' || existing.name.normalize('NFC').trim().toLowerCase() !== name.toLowerCase()))) throw new Failure('session collision');
    if (existing && mode === 'headless') throw new Failure('session is already visible');
    if (!ctx.session && existing && (existing.group || null) !== group) throw new Failure('group collision');
    return existing;
  };
  check(initial.data.layout);
  const home = ctx.env.HOME;
  if (!home) throw new Failure('HOME is required');
  const root = join(home, '.local/state/multiprompt/agent-host');
  const stateKey = hash(provider + ':' + sid).slice(0, 32);
  if (process.platform === 'win32' && !ctx.mockFolder) throw new Failure('spawn requires a Unix host');
  const unsafeMode = st => process.platform !== 'win32' && ((st.mode & 0o077) || (process.getuid && st.uid !== process.getuid()));
  const lockPath = join(root, stateKey + '.spawn.lock');
  try {
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const dir = lstatSync(root);
    if (!dir.isDirectory() || dir.isSymbolicLink() || unsafeMode(dir)) throw 0;
    const fd = openSync(lockPath, constants.O_CREAT | constants.O_RDWR | (constants.O_NOFOLLOW || 0), 0o600);
    closeSync(fd);
    const lock = lstatSync(lockPath);
    if (!lock.isFile() || lock.isSymbolicLink() || unsafeMode(lock)) throw 0;
  } catch { throw new Failure('cannot access host state'); }
  const release = await ctx.lock(lockPath, ctx.childEnv);
  try {
    const readState = suffix => {
      try { const file = join(root, stateKey + suffix); const st = lstatSync(file); if (!st.isFile() || st.isSymbolicLink() || unsafeMode(st)) throw 0; const value = JSON.parse(readFileSync(file, 'utf8')); if (!value || typeof value !== 'object' || Array.isArray(value)) throw 0; return value; }
      catch (e) { if (e.code === 'ENOENT') return null; throw new Failure('invalid host state'); }
    };
    const config = readState('.config.json');
    const owner = readState('.owner.json');
    if (owner?.owner === 'terminal') throw new Failure('session is owned by terminal');
    if (config && (config.cwd !== folder || config.tmux !== session || (!ctx.session && config.spawn_workspace !== flags.workspace) || (!ctx.session && config.spawn_name !== name.toLowerCase()) || (!ctx.session && (config.spawn_group ?? null) !== group))) throw new Failure('host configuration collision');
    if (mode === 'headless' && config && config.spawn_mode !== 'headless') throw new Failure('session is already visible');
    const current = await call(ctx, 'GET');
    if (current.status !== 200) throw new Failure(current.status === 401 || current.status === 403 ? 'key not authorized' : 'account read failed');
    check(current.data.layout);
    const parked = ctx.tmux(['has-session', '-t', '=' + session]).status === 0;
    if (parked && !config) throw new Failure('terminal collision');
    if (parked && mode === 'headless') throw new Failure('parking session already exists');
    if (!config) {
      const target = join(root, stateKey + '.config.json');
      const temporary = target + '.' + process.pid + '.' + Math.random().toString(16).slice(2);
      try {
        writeFileSync(temporary, JSON.stringify({ enabled: false, cwd: folder, tmux: session, spawn_workspace: flags.workspace, spawn_name: name.toLowerCase(), spawn_group: group, spawn_mode: mode }), { mode: 0o600, flag: 'wx' });
        renameSync(temporary, target);
      } catch { try { unlinkSync(temporary); } catch {} throw new Failure('cannot write host state'); }
    }
    if (!config || config.enabled !== true) {
      const [enabled] = runtime(['host', 'enable', provider, sid, '--tmux', session, '--cwd', folder, ...(provider === 'claude' ? ['--permission-mode', 'bypassPermissions'] : [])]);
      if (enabled?.status !== 'enabled') throw new Failure('host enable failed');
    }
    const result = mode === 'headless' ? { changed: false, revision: current.data.revision } : await edit(ctx, layout => {
      if (check(layout)) return null;
      const tab = { kind: 'tmux', name, tmux_session: session, tmux_host: host, workspace: flags.workspace, manual: true, ...(group === null ? {} : { group }) };
      if (parent) {
        const index = layout.tabs.findIndex(tab => tab.tmux_host === host && tab.tmux_session === parent.tmux_session);
        if (index < 0) throw new Failure('calling session is no longer visible');
        layout.tabs.splice(index + 1, 0, tab);
      } else layout.tabs.push(tab);
      return layout;
    });
    const [started] = runtime(['host', 'start', provider, sid]);
    if (!['started', 'already'].includes(started?.status)) throw new Failure('host start failed');
    if (flags.task !== undefined) {
      const base = { message_protocol: 1, provider, sid, tmux: session };
      const requests = [{ ...base, id: 1, op: 'message_submit', message_id: token, text: flags.task }, { ...base, id: 2, op: 'message_dispatch' }];
      const replies = runtime(['--serve'], requests.map(x => JSON.stringify(x)).join('\n') + '\n');
      const submitted = replies.find(r => r.id === 1)?.result?.message;
      const dispatched = replies.find(r => r.id === 2)?.result;
      if (submitted?.id !== token || submitted.text !== flags.task || !dispatched || submitted.state === 'failed' || dispatched.message?.state === 'failed') throw new Failure('task submission failed');
    }
    const verified = ctx.session ? await visibleSession(ctx, host, session) : null;
    ctx.out(JSON.stringify({ ok: true, sid, session, host, name, workspace: verified?.tab.workspace || flags.workspace, group: verified ? verified.tab.group || null : group, mode, provider, first_task_id: flags.task === undefined ? null : token, revision: verified?.revision ?? result.revision, changed: result.changed, ...(ctx.session ? { visible: true } : {}) }));
  } finally { release(); }
}

export async function run(argv, overrides = {}) {
  const env = overrides.env || process.env;
  const out = overrides.out || (line => process.stdout.write(line + '\n'));
  const err = overrides.err || (line => process.stderr.write(line + '\n'));
  let [command, ...rest] = argv;
  if (!command || command === '--help' || command === 'help') { out(USAGE.trimEnd()); return command ? 0 : 2; }
  const session = command === 'session';
  if (session) {
    [command, ...rest] = rest;
    if (!command || command === '--help' || command === 'help') { out(SESSION_USAGE.trimEnd()); return 0; }
  }
  try {
    const flags = session ? sessionFlags(rest, command) : parse(rest, command);
    if (session && flags.task === '-') flags.task = (overrides.readTask || (() => readFileSync(0, 'utf8')))();
    const childEnv = { HOME: env.HOME, PATH: env.PATH || '/usr/bin:/bin', LANG: 'C.UTF-8' };
    let key;
    if (session) {
      try { key = await (overrides.loadKey || loadSessionKey)(childEnv); }
      catch { throw new Failure('cannot read the approved account key with yeo-key'); }
      if (!key) throw new Failure('cannot read the approved account key with yeo-key');
      if (command === 'new') command = 'spawn';
    } else key = env.MULTIPROMPT_KEY;
    if (!key) throw new Failure('set MULTIPROMPT_KEY');
    if (command === 'open' && flags.kind === 'chat') {
      command = 'spawn';
      if (flags._.length || flags.tmux || flags.title || flags.star || flags.move || flags['no-tmux']) throw new Failure('invalid spawn option');
    } else if (command === 'open' && flags.kind !== undefined && flags.kind !== 'shell') throw new Failure('kind must be shell or chat');
    const ctx = {
      key, env, out, command, session,
      url: session ? DEFAULT_URL : (env.MULTIPROMPT_URL || DEFAULT_URL).replace(/\/+$/, ''),
      fetch: overrides.fetch || globalThis.fetch,
      childEnv,
      wait: overrides.wait || wait,
      lock: overrides.lock || spawnLock,
      mockFolder: Boolean(overrides.resolveFolder),
      resolveFolder: overrides.resolveFolder || (value => { const folder = realpathSync(value); if (!statSync(folder).isDirectory()) throw new Error(); return folder; }),
      runtime: overrides.runtime || ((args, input) => spawnSync('python3', [env.MULTIPROMPT_READER || join(env.HOME, '.multiprompt-runtime/reader.py'), ...args], { input, encoding: 'utf8', timeout: 30000, env: { HOME: env.HOME, PATH: env.PATH || '/usr/bin:/bin', LANG: 'C.UTF-8' }, maxBuffer: 1048576 })),
      tmux: overrides.tmux || (args => spawnSync('tmux', args, { ...(command === 'spawn' ? { timeout: 5000 } : {}), stdio: command === 'spawn' && args[0] === 'display-message' ? ['ignore', 'pipe', 'ignore'] : 'ignore', encoding: 'utf8', ...(command === 'spawn' ? { env: { HOME: env.HOME, PATH: env.PATH || '/usr/bin:/bin', LANG: 'C.UTF-8' } } : {}) }))
    };
    const commands = session ? { list, star: changeSession, unstar: changeSession, move: changeSession, spawn: spawnSession } : { list, 'create-section': createSection, move, open, spawn: spawnSession };
    if (!commands[command]) throw new Failure(`unknown command ${command}`);
    await commands[command](ctx, flags);
    return 0;
  } catch (e) {
    if (command === 'spawn' || session) { err(JSON.stringify({ ok: false, error: e instanceof Failure && !e.message.startsWith('cannot reach') && !e.message.startsWith('service answered') ? e.message : session ? 'session command failed' : 'spawn failed' })); return 1; }
    if (!(e instanceof Failure)) throw e;
    err('mp-layout: ' + e.message);
    return 1;
  }
}

if (process.argv[1] && import.meta.url === import.meta.resolve(pathToFileURL(process.argv[1]).href)) {
  const argv = process.argv.slice(2);
  process.exitCode = await run(basename(process.argv[1]) === 'mp' && (!argv.length || ['--help', 'help'].includes(argv[0])) ? ['session', '--help'] : argv);
}
