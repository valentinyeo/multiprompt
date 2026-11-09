#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  commentBody,
  connectedMachines,
  readResult,
  recordAttempt,
  releaseVersion,
  shippedTickets,
  shouldAttempt,
  summarize,
} from './lib.mjs';

const repo = 'valentinyeo/multiprompt';
const here = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  if (index < 0) return fallback;
  const value = process.argv[index + 1];
  return value && !value.startsWith('--') ? value : true;
}

function has(name) {
  return process.argv.includes(`--${name}`);
}

function exec(command, args, options = {}) {
  return execFileSync(command, args, { encoding: 'utf8', timeout: 900000, maxBuffer: 64 * 1024 * 1024, ...options }).trim();
}

const host = String(arg('host', 'laptop2'));
const stateDir = String(arg('state-dir', path.join(os.homedir(), '.local/state/multiprompt-laptop-check')));
const agent = String(arg('agent', process.env.LAPTOP_CHECK_AGENT || 'RUNNER 7'));
const maxAttempts = Number(arg('attempts', 2));
const wantTag = String(arg('tag', 'latest'));
const appPath = arg('app-path', '');
const posting = !has('no-post');
const ceoHt = fs.existsSync(path.join(os.homedir(), 'projects/ceo/bin/ceo-ht'))
  ? path.join(os.homedir(), 'projects/ceo/bin/ceo-ht')
  : 'ceo-ht';

function lh(args, options = {}) {
  return exec('lh', ['--machine', host, ...args], options);
}

function releaseTag() {
  if (wantTag !== 'latest') return wantTag;
  return exec('gh', ['release', 'view', '-R', repo, '--json', 'tagName', '--jq', '.tagName']);
}

function previousTag(tag) {
  const list = JSON.parse(exec('gh', ['release', 'list', '-R', repo, '--limit', '40', '--json', 'tagName']));
  const index = list.findIndex(entry => entry.tagName === tag);
  return index >= 0 && index + 1 < list.length ? list[index + 1].tagName : '';
}

function shippedFrom(previous, tag) {
  const range = previous ? `${previous}...${tag}` : tag;
  const subjects = exec('gh', ['api', `repos/${repo}/compare/${range}`, '--jq', '.commits[].commit.message | split("\\n")[0]']);
  return shippedTickets(subjects.split('\n'));
}

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(path.join(stateDir, 'state.json'), 'utf8'));
  } catch {
    return {};
  }
}

function saveState(state) {
  fs.mkdirSync(stateDir, { recursive: true });
  fs.writeFileSync(path.join(stateDir, 'state.json'), `${JSON.stringify(state, null, 2)}\n`);
}

function postComment(ticket, body) {
  exec(ceoHt, ['comment', 'add', ticket, '--text', body], { env: { ...process.env, CEO_AGENT: agent } });
}

function report(line) {
  console.log(line);
}

const tag = releaseTag();
const version = releaseVersion(tag);
const state = loadState();
const entry = state[tag];

if (!shouldAttempt(entry, maxAttempts)) {
  report(`LAPTOP_CHECK_SKIPPED ${tag} ${entry.verdict} after ${entry.attempts} attempt(s)`);
  process.exit(0);
}

let machineList = '';
try {
  machineList = exec('lh', ['machines']);
} catch {
  machineList = '';
}
if (!connectedMachines(machineList).has(host)) {
  report(`LAPTOP_CHECK_WAITING ${tag} ${host} is offline`);
  process.exit(0);
}

const tempFolder = lh(['shell', '$env:TEMP', '--timeout', '60']).replace(/[\r\n]/g, '');
const remoteScript = `${tempFolder}\\multiprompt-laptop-check.ps1`;
lh(['write', remoteScript, '--binary', fs.readFileSync(path.join(here, 'check.ps1')).toString('base64')]);

const appArgument = appPath === true || !appPath ? '' : ` -AppPath '${appPath}'`;
const command = `powershell -NoProfile -ExecutionPolicy Bypass -File '${remoteScript}' -ExpectVersion ${version} -StartIfMissing${appArgument}`;

let stdout = '';
let runError = '';
try {
  stdout = lh(['shell', command, '--timeout', '1500']);
} catch (error) {
  stdout = String(error.stdout ?? '');
  runError = String(error.stderr ?? error.message ?? '').slice(0, 400);
}

let result;
try {
  result = readResult(stdout);
} catch (error) {
  report(`LAPTOP_CHECK_ERROR ${tag} ${error.message} ${runError}`);
  state[tag] = recordAttempt(entry, tag, 'FAIL', new Date().toISOString());
  saveState(state);
  process.exit(1);
}

const summary = summarize(result, version);
result.summary = summary;
fs.mkdirSync(stateDir, { recursive: true });
fs.writeFileSync(path.join(stateDir, `result-${tag}.json`), `${JSON.stringify(result, null, 2)}\n`);

const tickets = shippedFrom(previousTag(tag), tag);
const body = commentBody({
  tag,
  host: result.host || host,
  verdict: summary.verdict,
  failed: summary.failed,
  missing: summary.missing,
  checks: summary.checks,
});

const posted = [];
for (const ticket of tickets) {
  if (!posting) {
    posted.push(`${ticket} (not posted)`);
    continue;
  }
  try {
    postComment(ticket, body);
    posted.push(ticket);
  } catch (error) {
    posted.push(`${ticket} (post failed: ${String(error.message).slice(0, 120)})`);
  }
}

state[tag] = recordAttempt(entry, tag, summary.verdict, result.at || new Date().toISOString());
saveState(state);

report(`LAPTOP_CHECK_${summary.verdict} ${tag} on ${result.host || host}: ${summary.checks.map(check => `${check.name}=${check.ok === true ? 'ok' : 'fail'}`).join(' ')}`);
for (const check of summary.checks) report(`  ${check.ok === true ? 'PASS' : 'FAIL'} ${check.name}: ${check.detail}`);
if (summary.missing.length) report(`  MISSING ${summary.missing.join(', ')}`);
report(`  tickets ${tickets.length ? posted.join(', ') : 'none shipped in this range'}`);
if (runError) report(`  shell note ${runError}`);
process.exit(summary.verdict === 'PASS' ? 0 : 1);
