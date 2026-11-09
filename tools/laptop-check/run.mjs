#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = 'valentinyeo/multiprompt';
const here = path.dirname(fileURLToPath(import.meta.url));
const requiredChecks = ['install', 'start', 'chats', 'computer-view', 'sync', 'memory', 'crashes'];
const usage = `usage: run.mjs [--host laptop2] [--tag latest|vX.Y.Z] [--no-post] [--state-dir DIR] [--agent NAME] [--attempts N] [--app-path PATH] [--self-test] [--help]

Drives the test laptop through lh: reads the newest release, waits for the app's own
updater to install it, runs check.ps1 there, and posts one comment per shipped ticket.`;

function releaseVersion(tag) {
  const match = /^v(\d+\.\d+\.\d+)$/.exec(String(tag ?? '').trim());
  if (!match) throw new Error(`invalid release tag: ${tag}`);
  return match[1];
}

function shippedTickets(subjects) {
  const tickets = new Set();
  for (const subject of subjects) {
    const line = String(subject ?? '').split('\n')[0];
    for (const match of line.matchAll(/(?:^|[^A-Za-z0-9-])(IGSH-\d+)/g)) tickets.add(match[1]);
  }
  return [...tickets].sort((left, right) => Number(left.slice(5)) - Number(right.slice(5)));
}

function connectedMachines(output) {
  const machines = new Set();
  for (const line of String(output ?? '').split(/\r?\n/)) {
    const match = /^[\u2713\u2714]\s+(\S+)/.exec(line.trim());
    if (match) machines.add(match[1]);
  }
  return machines;
}

function readResult(stdout) {
  const match = /LAPTOP_CHECK_JSON_BEGIN\s*([\s\S]*?)\s*LAPTOP_CHECK_JSON_END/.exec(String(stdout ?? ''));
  if (!match) throw new Error('check output has no result block');
  const result = JSON.parse(match[1]);
  if (!Array.isArray(result?.checks) || result.checks.length === 0) throw new Error('check output has no checks');
  return result;
}

function summarize(result, expectedVersion) {
  const checks = Array.isArray(result?.checks) ? result.checks : [];
  const present = new Set(checks.map(check => check.name));
  const missing = requiredChecks.filter(name => !present.has(name));
  const failed = checks.filter(check => check.ok !== true).map(check => check.name);
  if (expectedVersion && result?.version !== expectedVersion) failed.unshift('version');
  const verdict = missing.length === 0 && failed.length === 0 ? 'PASS' : 'FAIL';
  return { verdict, failed, missing, checks };
}

function escapeHtml(text) {
  return String(text ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function commentBody({ tag, host, verdict, failed, missing, checks }) {
  const lines = [`<p><b>Test laptop check: ${verdict}</b> ${tag} on ${host}</p>`, '<ul>'];
  for (const check of checks) lines.push(`<li>${check.ok === true ? 'PASS' : 'FAIL'} ${escapeHtml(check.name)}: ${escapeHtml(check.detail)}</li>`);
  for (const name of missing) lines.push(`<li>MISSING ${escapeHtml(name)}</li>`);
  lines.push('</ul>');
  if (failed.length > 0) lines.push(`<p>Failed: ${escapeHtml(failed.join(', '))}</p>`);
  return lines.join('\n');
}

function shouldAttempt(entry, maxAttempts = 2) {
  if (!entry) return true;
  if (entry.verdict === 'PASS') return false;
  return Number(entry.attempts ?? 0) < maxAttempts;
}

function recordAttempt(entry, tag, verdict, at) {
  const attempts = entry?.tag === tag ? Number(entry.attempts ?? 0) : 0;
  return { tag, verdict, attempts: attempts + 1, at };
}

function selfTest() {
  const cases = [];
  const check = (name, ok) => {
    if (!ok) throw new Error(`self-test failed: ${name}`);
    cases.push(name);
  };
  const throws = fn => {
    try {
      fn();
      return false;
    } catch {
      return true;
    }
  };
  const clean = version => ({ version, checks: requiredChecks.map(name => ({ name, ok: true, detail: '' })) });
  check('release tag', releaseVersion(' v0.28.900 ') === '0.28.900');
  check('rejects loose tags', ['0.28.900', 'latest', 'v0.28', 'v0.28.900-rc1', ''].every(tag => throws(() => releaseVersion(tag))));
  check('shipped tickets', JSON.stringify(shippedTickets(['IGSH-1901: x', 'Merge IGSH-1894', 'no ticket', 'IGSH-1901: again'])) === JSON.stringify(['IGSH-1894', 'IGSH-1901']));
  check('subject only', JSON.stringify(shippedTickets(['IGSH-7: body\nIGSH-8: also here'])) === JSON.stringify(['IGSH-7']));
  check('machine list', connectedMachines('\u2713 laptop1\n\u2717 laptop2\n').has('laptop1') && !connectedMachines('\u2713 laptop1\n\u2717 laptop2\n').has('laptop2'));
  check('result block', readResult('noise\nLAPTOP_CHECK_JSON_BEGIN\n{"checks":[{"name":"start","ok":true}]}\nLAPTOP_CHECK_JSON_END\n').checks[0].name === 'start');
  check('verdict pass', summarize(clean('0.28.900'), '0.28.900').verdict === 'PASS');
  check('verdict version', summarize(clean('0.28.899'), '0.28.900').failed.includes('version'));
  check('verdict missing', summarize({ version: '0.28.900', checks: [{ name: 'install', ok: true }] }, '0.28.900').verdict === 'FAIL');
  check('escape html', commentBody({ tag: 'v0.28.900', host: 'h', verdict: 'PASS', failed: [], missing: [], checks: [{ name: 'chats', ok: true, detail: '<b>' }] }).includes('&lt;b&gt;'));
  check('one attempt after pass', shouldAttempt(recordAttempt(undefined, 'v0.28.900', 'PASS', 't'), 2) === false);
  check('two attempts after failure', shouldAttempt(recordAttempt(recordAttempt(undefined, 'v0.28.900', 'FAIL', 't'), 'v0.28.900', 'FAIL', 't'), 2) === false);
  return cases.length;
}

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

if (has('help')) {
  console.log(usage);
  process.exit(0);
}

if (has('self-test')) {
  console.log(JSON.stringify({ selfTest: 'pass', cases: selfTest() }));
  process.exit(0);
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
