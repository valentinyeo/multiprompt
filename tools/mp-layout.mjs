#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const DEFAULT_URL = 'https://account.multiprompt.dev';
const USAGE = `usage: mp-layout <command> [options]

commands:
  list [--json]                                    show workspaces and their sessions
  create-section <name>                            add a workspace
  move --to <workspace> [--create] <session>...    move sessions into a workspace in one change
  move --to <workspace> --match <glob> [--host N]  move every session whose name matches
  open <session> [--workspace <name>] [--host N] [--title <text>] [--no-tmux]

environment:
  MULTIPROMPT_KEY   admin or workspace key (never printed)
  MULTIPROMPT_URL   account service address (default ${DEFAULT_URL})
  MULTIPROMPT_HOST  default host slot for open (default 0)
`;

class Failure extends Error {}

const REFUSALS = {
  scope_denied: 'refused: this key may change only its own workspace',
  key_scope: 'refused: keys work only on the layout',
  device_required: 'the key was not accepted',
  workspace_not_found: 'the workspace for this key does not exist',
  invalid_layout: 'the service rejected the layout (workspace or session limits?)',
  invalid_tab: 'the service rejected a session entry',
  invalid_workspace: 'the service rejected the workspace name'
};

function parse(argv) {
  const flags = { _: [] };
  const withValue = new Set(['to', 'match', 'host', 'workspace', 'title']);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) { flags._.push(arg); continue; }
    const name = arg.slice(2);
    if (withValue.has(name)) {
      if (i + 1 >= argv.length) throw new Failure(`--${name} needs a value`);
      flags[name] = argv[++i];
    } else if (['json', 'create', 'no-tmux'].includes(name)) flags[name] = true;
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

async function call(ctx, method, body) {
  let response;
  try {
    response = await ctx.fetch(ctx.url + '/v1/layout', {
      method,
      headers: { Authorization: 'Bearer ' + ctx.key, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined
    });
  } catch (e) {
    throw new Failure('cannot reach the account service: ' + (e.cause?.code || e.message));
  }
  let data = null;
  try { data = await response.json(); } catch { data = null; }
  return { status: response.status, data };
}

function refusal(result) {
  const code = result.data?.error;
  return new Failure(REFUSALS[code] || `service answered ${result.status}${code ? ' ' + code : ''}`);
}

async function edit(ctx, mutate) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const read = await call(ctx, 'GET');
    if (read.status !== 200) throw refusal(read);
    const next = mutate(structuredClone(read.data.layout));
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
  if (flags.json) { ctx.out(JSON.stringify({ revision, workspaces: layout.workspaces.map(w => ({ name: w.name, sessions: layout.tabs.filter(t => t.workspace === w.name).map(t => ({ session: t.tmux_session, name: t.name, host: t.tmux_host })) })) })); return; }
  ctx.out(`revision ${revision}`);
  for (const w of layout.workspaces) {
    const tabs = layout.tabs.filter(t => t.workspace === w.name);
    ctx.out(`${w.name} (${tabs.length})`);
    for (const t of tabs) ctx.out(`  ${t.tmux_session}  host ${t.tmux_host}  ${t.name}`);
  }
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
  const session = flags._[0];
  if (!session || flags._.length !== 1) throw new Failure('give one session name');
  if (!/^[A-Za-z0-9_-]{1,63}$/.test(session)) throw new Failure('session names use letters, digits, - and _ (63 at most)');
  const host = hostSlot(flags.host ?? ctx.env.MULTIPROMPT_HOST ?? '0');
  const title = flags.title || session;
  let started = false;
  if (!flags['no-tmux']) started = ensureTmux(ctx, session);
  const result = await edit(ctx, layout => {
    const workspace = flags.workspace || (layout.workspaces.length === 1 ? layout.workspaces[0].name : null);
    if (!workspace) throw new Failure('give --workspace <name>');
    if (!layout.workspaces.some(w => w.name === workspace)) throw new Failure(`workspace ${workspace} not found or not visible to this key`);
    const existing = layout.tabs.find(t => tabId(t) === `${host}:${session.toLowerCase()}`);
    if (existing) {
      if (existing.workspace !== workspace) throw new Failure(`session ${session} is already open in ${existing.workspace}`);
      return null;
    }
    layout.tabs.push({ kind: 'tmux', name: title.slice(0, 64), tmux_session: session, tmux_host: host, workspace });
    return layout;
  });
  ctx.out(`${result.changed ? 'opened' : 'already open'} ${session}${started ? ' (tmux session started)' : ''} (revision ${result.revision})`);
}

export async function run(argv, overrides = {}) {
  const env = overrides.env || process.env;
  const out = overrides.out || (line => process.stdout.write(line + '\n'));
  const err = overrides.err || (line => process.stderr.write(line + '\n'));
  const [command, ...rest] = argv;
  if (!command || command === '--help' || command === 'help') { out(USAGE.trimEnd()); return command ? 0 : 2; }
  try {
    const key = env.MULTIPROMPT_KEY;
    if (!key) throw new Failure('set MULTIPROMPT_KEY');
    const ctx = {
      key, env, out,
      url: (env.MULTIPROMPT_URL || DEFAULT_URL).replace(/\/+$/, ''),
      fetch: overrides.fetch || globalThis.fetch,
      tmux: overrides.tmux || (args => spawnSync('tmux', args, { stdio: 'ignore' }))
    };
    const flags = parse(rest);
    const commands = { list, 'create-section': createSection, move, open };
    if (!commands[command]) throw new Failure(`unknown command ${command}`);
    await commands[command](ctx, flags);
    return 0;
  } catch (e) {
    if (!(e instanceof Failure)) throw e;
    err('mp-layout: ' + e.message);
    return 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) process.exitCode = await run(process.argv.slice(2));
