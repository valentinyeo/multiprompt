#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, renameSync, unlinkSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { run as layoutRun } from './mp-layout.mjs';

const DEFAULT_URL = 'https://account.multiprompt.dev';
const LAYOUT_FEATURES = 'groups,bot_appearance,bot_palette8,workspace_color,bot_photo';
const USAGE = `usage: mb <command> [options]

commands:
  list [--json]
  open --kind shell|chat --tmux <name> --workspace <name> [--group <group>] [--title <text>] [--host N] [--folder DIR] [--star] [--face N] [--color N] [--photo FILE]
  close <name> [--host N]
  rename <name> <title> [--host N]
  move <name> [--group <group>] [--workspace <name>] [--host N]
  style <name> [--face N] [--color N] [--photo FILE] [--host N]
  star <name> on|off [--host N]
  mute <name> on|off [--host N]
  manual <name> on|off [--host N]
  settings <frequent|favorites|all|frequent_first> on|off
  pull [--json]
  workspace list
  workspace create <name> [--color N]
  workspace rename <old> <new>
  workspace delete <name>
  workspace color <name> <color>
  group list
  group create <name>
  group rename <old> <new>
  group delete <name>
  roster apply <file> [--dry-run]

environment:
  MULTIPROMPT_KEY   admin or workspace key (never printed)
  MULTIPROMPT_URL   account service address (default ${DEFAULT_URL})
  MULTIPROMPT_HOST  default host slot (default 0)
  MULTIPROMPT_READER  path to the installed host reader
`;

class Failure extends Error {}

const REFUSALS = {
  scope_denied: 'refused: this key may change only its own workspace',
  key_scope: 'refused: keys work only on the layout',
  device_required: 'the key was not accepted',
  workspace_not_found: 'the workspace for this key does not exist',
  invalid_layout: 'the service rejected the layout (workspace or session limits?)',
  invalid_tab: 'the service rejected a session entry',
  invalid_workspace: 'the service rejected the workspace name',
  invalid_photo: 'the service rejected the photo'
};

function parse(argv) {
  const flags = { _: [] };
  const withValue = new Set(['kind', 'tmux', 'group', 'workspace', 'title', 'host', 'folder', 'provider', 'model', 'face', 'color', 'photo']);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) { flags._.push(arg); continue; }
    const name = arg.slice(2);
    if (withValue.has(name)) {
      if (i + 1 >= argv.length || argv[i + 1].startsWith('--')) throw new Failure(`--${name} needs a value`);
      flags[name] = argv[++i];
    } else if (['star', 'dry-run', 'json', 'no-tmux'].includes(name)) flags[name] = true;
    else throw new Failure(`unknown option --${name}`);
  }
  return flags;
}

const hostSlot = text => {
  const n = Number(text);
  if (!Number.isInteger(n) || n < 0 || n > 2) throw new Failure('host must be 0, 1 or 2');
  return n;
};
const clean = value => value.normalize('NFC').trim();
function workspaceName(value) {
  const name = clean(String(value));
  if (!name || name.length > 32 || Buffer.byteLength(name) > 31 || /[\p{Cc}\p{Cs}]/u.test(name)) throw new Failure('invalid workspace');
  return name;
}
function groupName(value) {
  if (value === undefined || value === null) return null;
  const group = clean(String(value));
  if (!group || group.length > 64 || /[\p{Cc}\p{Cs}]/u.test(group)) throw new Failure('invalid group');
  return group;
}
function titleName(value) {
  const name = clean(String(value));
  if (!name || name.length > 64 || /[\p{Cc}\p{Cs}]/u.test(name)) throw new Failure('invalid title');
  return name;
}
function sessionName(value) {
  const name = String(value);
  if (!/^[A-Za-z0-9_-]{1,63}$/.test(name)) throw new Failure('session names use letters, digits, - and _ (63 at most)');
  return name;
}
function faceIndex(value) {
  if (value === undefined) return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0 || n > 19) throw new Failure('invalid face');
  return n;
}
function paletteColor(value) {
  if (value === undefined) return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0 || n > 7) throw new Failure('invalid color');
  return n;
}
const tabId = tab => `${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`;
function photoKey(host, session) {
  const prefix = Buffer.from('ZigShell bot avatar v1\0remote\0', 'utf8');
  const name = Buffer.from(session.toLowerCase(), 'utf8');
  return createHash('sha256').update(Buffer.concat([prefix, Buffer.from([host]), name])).digest('hex');
}
const blankOwners = () => ({ sessions: {}, workspaces: {}, groups: {} });

function readOwners(ctx) {
  try {
    const data = JSON.parse(readFileSync(ctx.ownerPath, 'utf8'));
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Failure('invalid owner record');
    data.sessions ||= {};
    data.workspaces ||= {};
    data.groups ||= {};
    return data;
  } catch (e) {
    if (e.code === 'ENOENT') return blankOwners();
    if (e instanceof Failure) throw e;
    throw new Failure('invalid owner record');
  }
}
function writeOwners(ctx, owners) {
  const text = JSON.stringify(owners);
  mkdirSync(dirname(ctx.ownerPath), { recursive: true });
  const temporary = ctx.ownerPath + '.tmp';
  writeFileSync(temporary, text, { mode: 0o600 });
  renameSync(temporary, ctx.ownerPath);
}

async function call(ctx, method, path, body, features = ctx.features) {
  let response;
  try {
    response = await ctx.fetch(ctx.url + path, {
      method,
      headers: { Authorization: 'Bearer ' + ctx.key, 'Content-Type': 'application/json', ...(features ? { 'X-Layout-Features': features } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  } catch (e) {
    throw new Failure('cannot reach the account service: ' + (e.cause?.code || e.message));
  }
  let data = null;
  try { data = await response.json(); } catch { data = null; }
  const advertised = new Set((response.headers?.get('X-Layout-Features') || '').split(',').map(feature => feature.trim()).filter(Boolean));
  return { status: response.status, data, features: advertised };
}
const refusal = result => new Failure(REFUSALS[result.data?.error] || `service answered ${result.status}${result.data?.error ? ' ' + result.data.error : ''}`);
function requireFeature(read, token) {
  if (!read.features.has(token)) throw new Failure(`account service does not support ${token}`);
}

async function edit(ctx, mutate) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const read = await call(ctx, 'GET', '/v1/layout');
    if (read.status !== 200) throw refusal(read);
    const next = mutate(structuredClone(read.data.layout), read);
    if (!next) return { changed: false, revision: read.data.revision };
    const write = await call(ctx, 'PUT', '/v1/layout', { base_revision: read.data.revision, layout: next });
    if (write.status === 200) return { changed: true, revision: write.data.revision };
    if (write.status !== 409) throw refusal(write);
  }
  throw new Failure('the layout kept changing; try again');
}

async function readLayout(ctx) {
  const read = await call(ctx, 'GET', '/v1/layout');
  if (read.status !== 200) throw refusal(read);
  return read;
}

function choose(layout, name, host) {
  const wanted = clean(name).toLowerCase();
  const tabs = layout.tabs.filter(tab => (host === null || tab.tmux_host === host) && (tab.tmux_session.toLowerCase() === wanted || clean(tab.name || '').toLowerCase() === wanted));
  if (tabs.length > 1) throw new Failure('give --host');
  return tabs[0] || null;
}
const defaultHost = (ctx, flags) => hostSlot(flags?.host ?? ctx.env.MULTIPROMPT_HOST ?? '0');

function ensureSession(ctx, session, command) {
  if (ctx.tmux(['has-session', '-t', '=' + session]).status === 0) return false;
  const argv = command ? command.split(/\s+/).filter(Boolean) : ['sleep', 'infinity'];
  const created = ctx.tmux(['new-session', '-d', '-s', session, ...argv]);
  if (created.status !== 0 && ctx.tmux(['has-session', '-t', '=' + session]).status !== 0) throw new Failure('could not start the tmux session');
  return true;
}
function paneLines(ctx, session) {
  const panes = ctx.tmux(['list-panes', '-t', '=' + session, '-F', '#{pane_current_command}']);
  if (panes.status !== 0) return null;
  return String(panes.stdout || '').trim().split('\n').filter(Boolean);
}
function restartable(lines, command) {
  const argv0 = command ? command.split(/\s+/).filter(Boolean)[0] : 'sleep';
  return lines.length === 1 && (lines[0] === 'sleep' || lines[0] === 'sh' || lines[0] === argv0);
}

async function syncPhoto(ctx, host, session, png, dry) {
  requireFeature(await readLayout(ctx), 'bot_photo');
  const key = photoKey(host, session);
  const current = await call(ctx, 'GET', '/v1/bot-photos/' + key, undefined, 'bot_photo');
  if (current.status === 200 && current.data?.png === png) return false;
  if (current.status !== 200 && current.status !== 404) throw refusal(current);
  if (dry) return true;
  const saved = await call(ctx, 'PUT', '/v1/bot-photos/' + key, { png }, 'bot_photo');
  if (saved.status !== 200) throw refusal(saved);
  return true;
}
function pngFromFile(file) {
  const bytes = readFileSync(file);
  if (bytes.length < 8 || bytes[0] !== 137 || bytes.toString('ascii', 1, 4) !== 'PNG') throw new Failure('invalid photo');
  return bytes.toString('base64');
}

async function list(ctx, flags) {
  ctx.features = LAYOUT_FEATURES + ',favorite,muted';
  const read = await readLayout(ctx);
  const { revision, layout } = read.data;
  const sessions = layout.tabs.map(tab => ({ session: tab.tmux_session, name: tab.name, host: tab.tmux_host, workspace: tab.workspace, group: tab.group || null, face: tab.face ?? null, color: tab.color ?? null, photo: tab.photo ?? null, favorite: tab.favorite === true, muted: tab.muted === true }));
  if (flags.json) { ctx.out(JSON.stringify({ revision, workspaces: layout.workspaces, sessions })); return; }
  ctx.out(`revision ${revision}`);
  for (const workspace of layout.workspaces) {
    const tabs = sessions.filter(tab => tab.workspace === workspace.name);
    ctx.out(`${workspace.name}${workspace.color === undefined ? '' : ' color ' + workspace.color} (${tabs.length})`);
    for (const tab of tabs) ctx.out(`  ${tab.session}  host ${tab.host}  ${tab.name}${tab.group ? '  group ' + tab.group : ''}${tab.face === null ? '' : '  face ' + tab.face}${tab.color === null ? '' : '  color ' + tab.color}${tab.favorite ? '  star' : ''}${tab.muted ? '  mute' : ''}`);
  }
}

async function placeShell(ctx, flags) {
  const session = sessionName(flags.tmux);
  const host = defaultHost(ctx, flags);
  const workspace = workspaceName(flags.workspace);
  const group = flags.group === undefined ? null : groupName(flags.group);
  const title = flags.title === undefined ? null : titleName(flags.title);
  const face = faceIndex(flags.face);
  const color = paletteColor(flags.color);
  if (group !== null) requireFeature(await readLayout(ctx), 'groups');
  if (face !== null || color !== null) requireFeature(await readLayout(ctx), 'bot_appearance');
  if (color === 7) requireFeature(await readLayout(ctx), 'bot_palette8');
  if (flags.star) ctx.features = LAYOUT_FEATURES + ',favorite';
  if (!flags['no-tmux']) ensureSession(ctx, session, null);
  const result = await edit(ctx, layout => {
    const existing = layout.tabs.find(tab => tabId(tab) === `${host}:${session.toLowerCase()}`);
    if (existing && existing.workspace !== workspace) throw new Failure(`session ${session} is already open in ${existing.workspace}`);
    if (!layout.workspaces.some(item => item.name === workspace)) throw new Failure(`workspace ${workspace} not found or not visible to this key`);
    if (existing) {
      let changed = false;
      if (group !== null && (existing.group || null) !== group) { existing.group = group; changed = true; }
      if (title !== null && existing.name !== title) { existing.name = title; changed = true; }
      if (face !== null && existing.face !== face) { existing.face = face; changed = true; }
      if (color !== null && existing.color !== color) { existing.color = color; changed = true; }
      if (flags.star && existing.favorite !== true) { existing.favorite = true; changed = true; }
      return changed ? layout : null;
    }
    layout.tabs.push({ kind: 'tmux', name: title || session, tmux_session: session, tmux_host: host, workspace, ...(group === null ? {} : { group }), ...(face === null ? {} : { face }), ...(color === null ? {} : { color }), ...(flags.star ? { favorite: true } : {}) });
    return layout;
  });
  ctx.features = LAYOUT_FEATURES;
  const photoChanged = flags.photo ? await syncPhoto(ctx, host, session, pngFromFile(flags.photo), false) : false;
  const revision = photoChanged ? (await readLayout(ctx)).data.revision : result.revision;
  ctx.out(`${result.changed || photoChanged ? 'opened' : 'already open'} ${session} (revision ${revision})`);
  return 0;
}

async function open(ctx, flags) {
  if (flags.kind !== 'shell' && flags.kind !== 'chat') throw new Failure('kind must be shell or chat');
  if (flags.kind === 'chat') {
    const name = flags.title || flags.tmux;
    if (!name || !flags.folder || !flags.workspace) throw new Failure('chat open needs a title, folder and workspace');
    const args = ['open', '--kind', 'chat', '--name', name, '--folder', flags.folder, '--workspace', flags.workspace];
    if (flags.group) args.push('--group', flags.group);
    if (flags.host !== undefined) args.push('--host', String(flags.host));
    if (flags.provider) args.push('--provider', flags.provider);
    if (flags.model === 'claude' || flags.model === 'hax') args.push('--provider', flags.model);
    const code = await layoutRun(args, { env: ctx.env, fetch: ctx.fetch, out: ctx.out, err: line => ctx.err(line.replace(/^mp-layout: /, 'mb: ')), tmux: ctx.tmux, runtime: ctx.runtime, lock: ctx.lock, resolveFolder: ctx.resolveFolder });
    if (code !== 0) return code;
    if (flags.face !== undefined || flags.color !== undefined || flags.photo) return style(ctx, { ...flags, _: [name] });
    return 0;
  }
  if (!flags.tmux || !flags.workspace) throw new Failure('shell open needs --tmux and --workspace');
  return placeShell(ctx, flags);
}

async function close(ctx, flags) {
  const name = flags._[0];
  if (!name || flags._.length !== 1) throw new Failure('give one session name');
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  const owners = readOwners(ctx);
  const result = await edit(ctx, layout => {
    const tab = choose(layout, name, host);
    if (!tab) return null;
    layout.tabs = layout.tabs.filter(item => item !== tab);
    return layout;
  });
  const session = name;
  const owned = Object.values(owners.sessions).find(item => item.owner === 'mb' && (item.session.toLowerCase() === clean(session).toLowerCase() || clean(item.name || '').toLowerCase() === clean(session).toLowerCase()) && (host === null || item.host === host));
  if (owned) await releaseOwned(ctx, owners, owned);
  ctx.out(`${result.changed ? 'closed' : 'already closed'} ${clean(name)}${result.changed ? ` (revision ${result.revision})` : ''}`);
}

async function releaseOwned(ctx, owners, owned) {
  const id = `${owned.host}:${owned.session.toLowerCase()}`;
  if (owned.provider && owned.sid) {
    const disabled = ctx.runtime(['host', 'disable', owned.provider, owned.sid]);
    if (disabled.status !== 0) throw new Failure('host disable failed');
  }
  const exists = ctx.tmux(['has-session', '-t', '=' + owned.session]).status === 0;
  if (exists) {
    const lines = paneLines(ctx, owned.session) || [];
    if (restartable(lines, owned.command)) ctx.tmux(['kill-session', '-t', '=' + owned.session]);
    else { ctx.out(`left ${owned.session}`); return; }
  }
  delete owners.sessions[id];
  writeOwners(ctx, owners);
}

async function renameSession(ctx, flags) {
  if (flags._.length !== 2) throw new Failure('rename needs a session and a title');
  const title = titleName(flags._[1]);
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  const result = await edit(ctx, layout => {
    const tab = choose(layout, flags._[0], host);
    if (!tab) throw new Failure('no such session');
    if (tab.name === title) return null;
    tab.name = title;
    return layout;
  });
  ctx.out(result.changed ? `renamed ${flags._[0]} (revision ${result.revision})` : `already renamed ${flags._[0]}`);
}

async function moveSession(ctx, flags) {
  if (flags._.length !== 1) throw new Failure('move needs one session');
  if (flags.group === undefined && flags.workspace === undefined) throw new Failure('give --group or --workspace');
  const group = flags.group === undefined ? null : groupName(flags.group);
  const workspace = flags.workspace === undefined ? null : workspaceName(flags.workspace);
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  if (group !== null) requireFeature(await readLayout(ctx), 'groups');
  const result = await edit(ctx, layout => {
    const tab = choose(layout, flags._[0], host);
    if (!tab) throw new Failure('no such session');
    if (workspace && !layout.workspaces.some(item => item.name === workspace)) throw new Failure(`workspace ${workspace} not found or not visible to this key`);
    let changed = false;
    if (workspace && tab.workspace !== workspace) { tab.workspace = workspace; changed = true; }
    if (group !== null && (tab.group || null) !== group) { tab.group = group; changed = true; }
    return changed ? layout : null;
  });
  ctx.out(result.changed ? `moved ${flags._[0]} (revision ${result.revision})` : `already moved ${flags._[0]}`);
}

async function style(ctx, flags) {
  if (flags._.length !== 1) throw new Failure('style needs one session');
  const face = faceIndex(flags.face);
  const color = paletteColor(flags.color);
  if (face === null && color === null && !flags.photo) throw new Failure('give --face, --color or --photo');
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  if (face !== null || color !== null) requireFeature(await readLayout(ctx), 'bot_appearance');
  if (color === 7) requireFeature(await readLayout(ctx), 'bot_palette8');
  let pictured = null;
  const result = await edit(ctx, layout => {
    const tab = choose(layout, flags._[0], host);
    if (!tab) throw new Failure('no such session');
    pictured = tab;
    let changed = false;
    if (face !== null && tab.face !== face) { tab.face = face; changed = true; }
    if (color !== null && tab.color !== color) { tab.color = color; changed = true; }
    return changed ? layout : null;
  });
  let photoChanged = false;
  if (flags.photo) photoChanged = await syncPhoto(ctx, pictured.tmux_host, pictured.tmux_session, pngFromFile(flags.photo), false);
  const revision = photoChanged ? (await readLayout(ctx)).data.revision : result.revision;
  ctx.out(result.changed || photoChanged ? `styled ${flags._[0]} (revision ${revision})` : `already styled ${flags._[0]}`);
}

async function workspaceCommand(ctx, sub, flags) {
  if (sub === 'list') {
    const { data } = await readLayout(ctx);
    if (flags.json) { ctx.out(JSON.stringify(data.layout.workspaces)); return; }
    for (const workspace of data.layout.workspaces) ctx.out(workspace.color === undefined ? workspace.name : `${workspace.name} color ${workspace.color}`);
    return;
  }
  if (sub === 'create') {
    if (flags._.length !== 1) throw new Failure('give one workspace name');
    const name = workspaceName(flags._[0]);
    const color = paletteColor(flags.color);
    if (color !== null) requireFeature(await readLayout(ctx), 'workspace_color');
    if (color === 7) requireFeature(await readLayout(ctx), 'bot_palette8');
    const owners = readOwners(ctx);
    const result = await edit(ctx, layout => {
      if (layout.workspaces.some(item => item.name === name)) return null;
      layout.workspaces.push({ name, ...(color === null ? {} : { color }) });
      return layout;
    });
    if (result.changed) { owners.workspaces[name] = { owner: 'mb' }; writeOwners(ctx, owners); }
    ctx.out(result.changed ? `created workspace ${name} (revision ${result.revision})` : `workspace ${name} already exists (revision ${result.revision})`);
    return;
  }
  if (sub === 'rename') {
    if (flags._.length !== 2) throw new Failure('rename needs the old name and the new name');
    const from = workspaceName(flags._[0]);
    const to = workspaceName(flags._[1]);
    const owners = readOwners(ctx);
    const result = await edit(ctx, layout => {
      const current = layout.workspaces.find(item => item.name === from);
      const target = layout.workspaces.find(item => item.name === to);
      if (!current && target) return null;
      if (!current) throw new Failure('no such workspace');
      if (from === to) return null;
      if (target) throw new Failure('workspace exists');
      current.name = to;
      for (const tab of layout.tabs) if (tab.workspace === from) tab.workspace = to;
      return layout;
    });
    if (owners.workspaces[from]) { owners.workspaces[to] = owners.workspaces[from]; delete owners.workspaces[from]; writeOwners(ctx, owners); }
    ctx.out(result.changed ? `renamed workspace ${from} to ${to} (revision ${result.revision})` : `workspace ${from} already renamed to ${to} (revision ${result.revision})`);
    return;
  }
  if (sub === 'delete') {
    if (flags._.length !== 1) throw new Failure('give one workspace name');
    const name = workspaceName(flags._[0]);
    const owners = readOwners(ctx);
    const seen = await readLayout(ctx);
    if (!seen.data.layout.workspaces.some(item => item.name === name)) { ctx.out(`already deleted workspace ${name}`); return; }
    if (owners.workspaces[name]?.owner !== 'mb') throw new Failure('not owned');
    const result = await edit(ctx, layout => {
      const foreign = layout.tabs.some(tab => tab.workspace === name && owners.sessions[tabId(tab)]?.owner !== 'mb');
      if (foreign) throw new Failure('not owned');
      const next = layout.tabs.filter(tab => tab.workspace !== name);
      if (next.length === layout.tabs.length && layout.workspaces.every(item => item.name !== name)) return null;
      layout.tabs = next;
      layout.workspaces = layout.workspaces.filter(item => item.name !== name);
      return layout;
    });
    for (const owned of Object.values(owners.sessions).filter(item => item.workspace === name)) await releaseOwned(ctx, owners, owned);
    delete owners.workspaces[name];
    writeOwners(ctx, owners);
    ctx.out(`deleted workspace ${name} (revision ${result.revision})`);
    return;
  }
  if (sub === 'color') {
    if (flags._.length !== 2) throw new Failure('give a workspace and a color');
    const name = workspaceName(flags._[0]);
    const color = paletteColor(flags._[1]);
    requireFeature(await readLayout(ctx), 'workspace_color');
    if (color === 7) requireFeature(await readLayout(ctx), 'bot_palette8');
    const result = await edit(ctx, layout => {
      const workspace = layout.workspaces.find(item => item.name === name);
      if (!workspace) throw new Failure('no such workspace');
      if (workspace.color === color) return null;
      workspace.color = color;
      return layout;
    });
    ctx.out(result.changed ? `colored workspace ${name} (revision ${result.revision})` : `workspace ${name} already colored ${color} (revision ${result.revision})`);
    return;
  }
  throw new Failure('workspace needs create, rename, delete, list or color');
}

async function groupCommand(ctx, sub, flags) {
  const owners = readOwners(ctx);
  if (sub === 'list') {
    const { data } = await readLayout(ctx);
    const names = new Set([...data.layout.tabs.map(tab => tab.group).filter(Boolean), ...Object.keys(owners.groups)]);
    for (const name of [...names].sort()) ctx.out(name);
    return;
  }
  if (sub === 'create') {
    if (flags._.length !== 1) throw new Failure('give one group name');
    const name = groupName(flags._[0]);
    requireFeature(await readLayout(ctx), 'groups');
    const { data } = await readLayout(ctx);
    if (data.layout.tabs.some(tab => tab.group === name) || owners.groups[name]) { ctx.out(`group ${name} already exists`); return; }
    owners.groups[name] = { owner: 'mb' };
    writeOwners(ctx, owners);
    ctx.out(`created group ${name}`);
    return;
  }
  if (sub === 'rename') {
    if (flags._.length !== 2) throw new Failure('rename needs the old name and the new name');
    const from = groupName(flags._[0]);
    const to = groupName(flags._[1]);
    requireFeature(await readLayout(ctx), 'groups');
    const moved = Boolean(owners.groups[from]);
    const result = await edit(ctx, layout => {
      const used = layout.tabs.some(tab => tab.group === from) || moved;
      const target = layout.tabs.some(tab => tab.group === to) || owners.groups[to];
      if (!used && target) return null;
      if (!used) throw new Failure('no such group');
      if (from === to) return null;
      let changed = false;
      for (const tab of layout.tabs) if (tab.group === from) { tab.group = to; changed = true; }
      return changed ? layout : null;
    });
    if (moved) { owners.groups[to] = owners.groups[from]; delete owners.groups[from]; writeOwners(ctx, owners); }
    ctx.out(result.changed || moved ? `renamed group ${from} to ${to}` : `group ${from} already renamed to ${to}`);
    return;
  }
  if (sub === 'delete') {
    if (flags._.length !== 1) throw new Failure('give one group name');
    const name = groupName(flags._[0]);
    const seen = await readLayout(ctx);
    const present = seen.data.layout.tabs.some(tab => tab.group === name) || owners.groups[name];
    if (!present) { ctx.out(`already deleted group ${name}`); return; }
    if (owners.groups[name]?.owner !== 'mb') throw new Failure('not owned');
    const result = await edit(ctx, layout => {
      let changed = false;
      for (const tab of layout.tabs) {
        if (tab.group === name && owners.sessions[tabId(tab)]?.owner === 'mb') { delete tab.group; changed = true; }
      }
      return changed ? layout : null;
    });
    delete owners.groups[name];
    writeOwners(ctx, owners);
    ctx.out(`deleted group ${name}${result.changed ? ` (revision ${result.revision})` : ''}`);
    return;
  }
  throw new Failure('group needs create, rename, delete or list');
}

function loadRoster(text, file) {
  let data;
  try { data = JSON.parse(text); } catch { throw new Failure('invalid roster'); }
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Failure('invalid roster');
  const workspaces = [];
  for (const entry of data.workspaces || []) {
    if (typeof entry === 'string') workspaces.push({ name: workspaceName(entry), color: null });
    else if (entry && typeof entry.name === 'string') workspaces.push({ name: workspaceName(entry.name), color: entry.color === undefined ? null : paletteColor(entry.color) });
    else throw new Failure('invalid roster');
  }
  const groups = (data.groups || []).map(groupName);
  if (!Array.isArray(data.runners || [])) throw new Failure('invalid roster');
  const runners = [];
  const seen = new Set();
  for (const row of data.runners || []) {
    if (!row || typeof row !== 'object') throw new Failure('invalid roster');
    const kind = row.kind || 'shell';
    if (!['shell', 'chat'].includes(kind)) throw new Failure('invalid roster');
    const name = kind === 'shell' ? sessionName(row.name) : titleName(row.name);
    if (seen.has(name.toLowerCase())) throw new Failure('invalid roster');
    seen.add(name.toLowerCase());
    const workspace = workspaceName(row.workspace);
    const group = row.group === undefined ? null : groupName(row.group);
    const title = row.title === undefined ? name : titleName(row.title);
    const command = row.command === undefined ? null : String(row.command).trim();
    if (command !== null && (!command || /[\p{Cc}\p{Cs}]/u.test(command))) throw new Failure('invalid roster');
    const model = row.model === undefined ? null : String(row.model).trim();
    if (model !== null && (!model || model.length > 64 || /[\p{Cc}\p{Cs}]/u.test(model))) throw new Failure('invalid roster');
    const photo = row.photo === undefined ? null : resolve(dirname(file), String(row.photo));
    runners.push({ name, kind, workspace, group, title, command, model, host: row.host === undefined ? null : hostSlot(String(row.host)), folder: row.folder || null, face: row.face === undefined ? null : faceIndex(row.face), color: row.color === undefined ? null : paletteColor(row.color), photo });
    if (!workspaces.some(item => item.name === workspace)) workspaces.push({ name: workspace, color: null });
  }
  return { workspaces, groups: [...new Set([...groups, ...runners.map(runner => runner.group).filter(Boolean)])], runners };
}

function rosterDiff(layout, owners, roster, hostDefault) {
  const next = structuredClone(layout);
  let changed = false;
  const actions = [];
  const createdWorkspaces = [];
  for (const workspace of roster.workspaces) {
    const current = next.workspaces.find(item => item.name === workspace.name);
    if (!current) {
      next.workspaces.push({ name: workspace.name, ...(workspace.color === null ? {} : { color: workspace.color }) });
      changed = true;
      createdWorkspaces.push(workspace.name);
      actions.push(`create workspace ${workspace.name}`);
    } else if (workspace.color !== null && current.color !== workspace.color) {
      current.color = workspace.color;
      changed = true;
      actions.push(`color workspace ${workspace.name}`);
    } else actions.push(`unchanged workspace ${workspace.name}`);
  }
  const tabGroups = new Set(next.tabs.map(tab => tab.group).filter(Boolean));
  for (const name of roster.groups) {
    if (tabGroups.has(name) || owners.groups[name]) actions.push(`unchanged group ${name}`);
    else { actions.push(`create group ${name}`); }
  }
  const wanted = new Set();
  const opened = [];
  const updates = [];
  for (const runner of roster.runners) {
    if (runner.kind === 'chat') {
      const matches = next.tabs.filter(tab => clean(tab.name || '').toLowerCase() === runner.name.toLowerCase() && (runner.host === null || tab.tmux_host === runner.host));
      if (matches.length > 1) throw new Failure('give --host');
      if (!matches.length) { actions.push(`open ${runner.name}`); continue; }
      const tab = matches[0];
      wanted.add(tabId(tab));
      let differ = tab.workspace !== runner.workspace || (runner.group !== null && (tab.group || null) !== runner.group) || (runner.title !== runner.name && tab.name !== runner.title) || (runner.face !== null && tab.face !== runner.face) || (runner.color !== null && tab.color !== runner.color);
      if (differ) {
        tab.workspace = runner.workspace;
        if (runner.group !== null) tab.group = runner.group;
        if (runner.title !== runner.name) tab.name = runner.title;
        if (runner.face !== null) tab.face = runner.face;
        if (runner.color !== null) tab.color = runner.color;
        changed = true;
        actions.push(`update ${runner.name}`);
      } else actions.push(`unchanged ${runner.name}`);
      continue;
    }
    const host = runner.host ?? hostDefault;
    const id = `${host}:${runner.name.toLowerCase()}`;
    wanted.add(id);
    const tab = next.tabs.find(item => item.tmux_host === host && item.tmux_session.toLowerCase() === runner.name.toLowerCase());
    const owned = owners.sessions[id];
    const commandChanged = Boolean(owned && ((owned.command || null) !== runner.command || (owned.model || null) !== runner.model));
    if (!tab) {
      next.tabs.push({ kind: 'tmux', name: runner.title, tmux_session: runner.name, tmux_host: host, workspace: runner.workspace, ...(runner.group ? { group: runner.group } : {}), ...(runner.face === null ? {} : { face: runner.face }), ...(runner.color === null ? {} : { color: runner.color }) });
      changed = true;
      opened.push(runner);
      actions.push(`open ${runner.name}`);
    } else {
      const differ = tab.name !== runner.title || tab.workspace !== runner.workspace || (runner.group !== null && (tab.group || null) !== runner.group) || (runner.face !== null && tab.face !== runner.face) || (runner.color !== null && tab.color !== runner.color);
      if (differ) {
        tab.name = runner.title;
        tab.workspace = runner.workspace;
        if (runner.group !== null) tab.group = runner.group;
        if (runner.face !== null) tab.face = runner.face;
        if (runner.color !== null) tab.color = runner.color;
        changed = true;
        updates.push(runner);
        actions.push(`update ${runner.name}`);
      } else if (commandChanged) {
        updates.push(runner);
        actions.push(`update ${runner.name}`);
      } else actions.push(`unchanged ${runner.name}`);
    }
  }
  const closed = [];
  for (const [id, owned] of Object.entries(owners.sessions)) {
    if (owned.owner !== 'mb' || wanted.has(id)) continue;
    if (roster.runners.some(runner => runner.kind === 'chat' && clean(runner.name).toLowerCase() === clean(owned.name || '').toLowerCase())) continue;
    const before = next.tabs.length;
    next.tabs = next.tabs.filter(tab => tabId(tab) !== id);
    if (next.tabs.length !== before) changed = true;
    closed.push(owned);
    actions.push(`close ${owned.session}`);
  }
  return { actions, layout: changed ? next : null, createdWorkspaces, opened, updates, closed };
}

function runnerTab(layout, runner, hostDefault) {
  if (runner.kind === 'chat') {
    const matches = layout.tabs.filter(tab => clean(tab.name || '').toLowerCase() === runner.name.toLowerCase() && (runner.host === null || tab.tmux_host === runner.host));
    return matches.length === 1 ? matches[0] : null;
  }
  const host = runner.host ?? hostDefault;
  return layout.tabs.find(tab => tab.tmux_host === host && tab.tmux_session.toLowerCase() === runner.name.toLowerCase()) || null;
}

async function applyRoster(ctx, file, dry) {
  const roster = loadRoster(readFileSync(file, 'utf8'), file);
  const owners = readOwners(ctx);
  const originalOwners = JSON.stringify(owners);
  const read = await readLayout(ctx);
  if (roster.groups.length) requireFeature(read, 'groups');
  if (roster.workspaces.some(item => item.color !== null)) requireFeature(read, 'workspace_color');
  if (roster.runners.some(item => item.face !== null || item.color !== null)) requireFeature(read, 'bot_appearance');
  if (roster.workspaces.some(item => item.color === 7) || roster.runners.some(item => item.color === 7)) requireFeature(read, 'bot_palette8');
  const hostDefault = defaultHost(ctx, {});
  const plan = rosterDiff(read.data.layout, owners, roster, hostDefault);
  if (dry) ctx.out('dry-run');
  for (const line of plan.actions) ctx.out(line);
  const photos = [];
  for (const runner of roster.runners) {
    if (!runner.photo) continue;
    const host = runner.host ?? hostDefault;
    const png = pngFromFile(runner.photo);
    const tab = runnerTab(read.data.layout, runner, hostDefault);
    if (!tab) { photos.push({ runner, host, png, changed: true }); ctx.out(`photo ${runner.name}`); continue; }
    const changed = await syncPhoto(ctx, tab.tmux_host, tab.tmux_session, png, true);
    photos.push({ runner, host: tab.tmux_host, session: tab.tmux_session, png, changed });
    if (changed) ctx.out(`photo ${runner.name}`);
  }
  for (const runner of roster.runners.filter(item => item.kind === 'shell')) {
    const host = runner.host ?? hostDefault;
    const owned = owners.sessions[`${host}:${runner.name.toLowerCase()}`];
    if (!owned || (owned.command || null) === runner.command) continue;
    if (ctx.tmux(['has-session', '-t', '=' + runner.name]).status !== 0) continue;
    if (!restartable(paneLines(ctx, runner.name) || [], owned.command)) {
      ctx.out(`busy ${runner.name}`);
      if (!dry) throw new Failure(`session is busy: ${runner.name}`);
    }
  }
  if (dry) { ctx.out(`revision ${read.data.revision}`); return; }
  for (const runner of [...plan.opened, ...plan.updates]) {
    if (runner.kind !== 'shell') continue;
    const owned = owners.sessions[`${runner.host ?? hostDefault}:${runner.name.toLowerCase()}`];
    if (!plan.opened.includes(runner) && !owned) continue;
    if (owned && (owned.command || null) !== runner.command && ctx.tmux(['has-session', '-t', '=' + runner.name]).status === 0) {
      const lines = paneLines(ctx, runner.name) || [];
      if (!restartable(lines, owned.command)) throw new Failure(`session is busy: ${runner.name}`);
      ctx.tmux(['kill-session', '-t', '=' + runner.name]);
    }
    ensureSession(ctx, runner.name, runner.command);
  }
  const result = await edit(ctx, layout => rosterDiff(layout, owners, roster, hostDefault).layout);
  for (const line of plan.actions) if (line.startsWith('create group ')) owners.groups[line.slice('create group '.length)] = { owner: 'mb' };
  if (result.changed) for (const name of plan.createdWorkspaces) owners.workspaces[name] = { owner: 'mb' };
  if (result.changed) for (const runner of plan.opened) {
    const host = runner.host ?? hostDefault;
    owners.sessions[`${host}:${runner.name.toLowerCase()}`] = { owner: 'mb', name: runner.name, session: runner.name, host, kind: runner.kind, command: runner.command, model: runner.model, workspace: runner.workspace, provider: runner.model === 'claude' || runner.model === 'hax' ? runner.model : null, sid: null };
  }
  for (const runner of plan.updates) {
    const host = runner.host ?? hostDefault;
    const id = `${host}:${runner.name.toLowerCase()}`;
    if (owners.sessions[id]) Object.assign(owners.sessions[id], { command: runner.command, model: runner.model, workspace: runner.workspace });
  }
  for (const runner of roster.runners.filter(item => item.kind === 'chat' && !runnerTab(read.data.layout, item, hostDefault))) {
    if (!runner.folder) throw new Failure('chat open needs a title, folder and workspace');
    const previous = ctx.out;
    let last = '';
    ctx.out = line => { if (line.startsWith('{')) last = line; previous(line); };
    try {
      const code = await open(ctx, { kind: 'chat', title: runner.name, tmux: runner.name, folder: runner.folder, workspace: runner.workspace, group: runner.group || undefined, host: runner.host === null ? undefined : String(runner.host), model: runner.model || undefined, face: runner.face === null ? undefined : String(runner.face), color: runner.color === null ? undefined : String(runner.color), _: [] });
      if (code) throw new Failure('chat open failed');
    } finally { ctx.out = previous; }
    let body = null;
    try { body = JSON.parse(last); } catch { body = null; }
    if (body?.session) owners.sessions[`${body.host}:${String(body.session).toLowerCase()}`] = { owner: 'mb', name: runner.name, session: body.session, host: body.host, kind: 'chat', command: runner.command, model: runner.model, workspace: runner.workspace, provider: body.provider || null, sid: body.sid || null };
  }
  for (const owned of plan.closed) await releaseOwned(ctx, owners, owned);
  for (const photo of photos) {
    if (!photo.changed) continue;
    let host = photo.host;
    let session = photo.session || photo.runner.name;
    if (photo.runner.kind === 'chat' && !photo.session) {
      const current = runnerTab((await readLayout(ctx)).data.layout, photo.runner, hostDefault);
      if (!current) throw new Failure('no such session');
      host = current.tmux_host;
      session = current.tmux_session;
    }
    await syncPhoto(ctx, host, session, photo.png, false);
  }
  if (JSON.stringify(owners) !== originalOwners) writeOwners(ctx, owners);
  const revision = photos.some(photo => photo.changed) ? (await readLayout(ctx)).data.revision : result.revision;
  ctx.out('applied');
  ctx.out(`revision ${revision}`);
}

function onOff(word, value) {
  if (value === 'on') return true;
  if (value === 'off') return false;
  throw new Failure(`${word} needs on or off`);
}

async function setTabBool(ctx, flags, field, feature, word) {
  if (flags._.length !== 2) throw new Failure(`${word} needs <name> on|off`);
  const value = onOff(word, flags._[1]);
  if (feature) {
    ctx.features = LAYOUT_FEATURES + ',' + feature;
    requireFeature(await readLayout(ctx), feature);
  }
  const host = flags.host === undefined ? null : hostSlot(flags.host);
  const result = await edit(ctx, layout => {
    const tab = choose(layout, flags._[0], host);
    if (!tab) throw new Failure('no such session');
    if ((tab[field] === true) === value) return null;
    tab[field] = value;
    return layout;
  });
  ctx.out(`${result.changed ? word : 'already ' + word} ${value ? 'on' : 'off'} ${clean(flags._[0])}`);
}

const star = (ctx, flags) => setTabBool(ctx, flags, 'favorite', 'favorite', 'star');
const mute = (ctx, flags) => setTabBool(ctx, flags, 'muted', 'muted', 'mute');
const manual = (ctx, flags) => setTabBool(ctx, flags, 'manual', null, 'manual');

const SETTING_KEYS = ['frequent', 'favorites', 'all', 'frequent_first'];
const SETTING_DEFAULTS = { frequent: true, favorites: true, all: true, frequent_first: true };

async function settings(ctx, flags) {
  const key = flags._[0];
  if (flags._.length !== 2 || !SETTING_KEYS.includes(key)) throw new Failure('settings needs <frequent|favorites|all|frequent_first> on|off');
  const value = onOff('settings', flags._[1]);
  ctx.features = LAYOUT_FEATURES + ',settings';
  requireFeature(await readLayout(ctx), 'settings');
  const result = await edit(ctx, layout => {
    const current = { ...SETTING_DEFAULTS, ...(layout.settings || {}) };
    const stored = layout.settings && layout.settings[key];
    if (stored === value || (!layout.settings && value === SETTING_DEFAULTS[key])) return null;
    layout.settings = { frequent: current.frequent, favorites: current.favorites, all: current.all, frequent_first: current.frequent_first };
    layout.settings[key] = value;
    return layout;
  });
  ctx.out(`${result.changed ? 'set' : 'already'} ${key} ${value ? 'on' : 'off'}`);
}

async function pull(ctx, flags) {
  if (flags._.length) throw new Failure('pull takes no arguments');
  await list(ctx, flags);
}

export async function run(argv, overrides = {}) {
  const env = overrides.env || process.env;
  const out = overrides.out || (line => process.stdout.write(line + '\n'));
  const err = overrides.err || (line => process.stderr.write(line + '\n'));
  const [command, ...rest] = argv;
  if (!command || command === 'help' || command === '--help') { out(USAGE.trimEnd()); return command ? 0 : 2; }
  try {
    const key = env.MULTIPROMPT_KEY;
    if (!key) throw new Failure('set MULTIPROMPT_KEY');
    const home = env.HOME;
    const ctx = {
      key, env, out, err, features: LAYOUT_FEATURES,
      url: (env.MULTIPROMPT_URL || DEFAULT_URL).replace(/\/+$/, ''),
      fetch: overrides.fetch || globalThis.fetch,
      ownerPath: overrides.ownerPath || (home ? join(home, '.local/state/multiprompt/mb-owners.json') : ''),
      tmux: overrides.tmux || (args => spawnSync('tmux', args, { encoding: 'utf8' })),
      runtime: overrides.runtime || ((args, input) => spawnSync('python3', [env.MULTIPROMPT_READER || join(home || '', '.multiprompt-runtime/reader.py'), ...args], { input, encoding: 'utf8', timeout: 30000 })),
      lock: overrides.lock,
      resolveFolder: overrides.resolveFolder
    };
    if (!ctx.ownerPath) throw new Failure('HOME is required');
    if (command === 'workspace' || command === 'group' || command === 'roster') {
      const sub = rest[0];
      const flags = parse(rest.slice(1));
      if (command === 'workspace') await workspaceCommand(ctx, sub, flags);
      else if (command === 'group') await groupCommand(ctx, sub, flags);
      else if (sub === 'apply' && flags._.length === 1) await applyRoster(ctx, flags._[0], flags['dry-run']);
      else throw new Failure('roster needs apply <file>');
      return 0;
    }
    const flags = parse(rest);
    const commands = { list, open, close, rename: renameSession, move: moveSession, style, star, mute, manual, settings, pull };
    if (!commands[command]) throw new Failure(`unknown command ${command}`);
    const code = await commands[command](ctx, flags);
    return code || 0;
  } catch (e) {
    if (!(e instanceof Failure)) throw e;
    err('mb: ' + e.message);
    return 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) process.exitCode = await run(process.argv.slice(2));
