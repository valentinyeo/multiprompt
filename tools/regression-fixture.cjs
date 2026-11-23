const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { parseTicketId, ticketIds } = require('./ticket-id.js');

const FIXTURE_ROOT = 'tools/fixtures';
const REPRO_FILE = 'repro.json';

function ticketFolderNames(ticket) {
  const parsed = parseTicketId(ticket);
  if (!parsed) return [];
  const names = new Set([parsed.id, `${parsed.prefix}-${parsed.number}`]);
  if (parsed.prefix === 'IGSH') names.add(`SOFT-${parsed.number}`);
  return [...names];
}

function isRepair(pr) {
  const title = pr?.title || '';
  const body = pr?.body || '';
  return /\bbug(?:[ -]?fix)?\b|^fix(?:\([^)]*\))?[!:]|\bfix(?:es|ed)?\b|\bRevert\b/i.test(title) ||
    /\bbug\s*fix\b/i.test(body) ||
    (pr?.labels || []).some(label => /^(?:bug|bug[ -]?fix|defect|regression)$/i.test(typeof label === 'string' ? label : label.name));
}

function ticketTitleMarksBug(root, ticket) {
  for (const name of ticketFolderNames(ticket)) {
    const file = path.join(root, 'tools/ticket-titles', `${name}.txt`);
    if (!fs.existsSync(file)) continue;
    const title = fs.readFileSync(file, 'utf8').trim();
    if (/\b(?:regression|bug)\b/i.test(title)) return true;
  }
  return false;
}

function primaryTicket(pr) {
  const ordered = [...ticketIds(`${pr?.title || ''}\n${pr?.body || ''}`)];
  return ordered[0] || null;
}

function isBugPullRequest(pr, root = '.') {
  if (!pr) return false;
  if (isRepair(pr)) return true;
  const ticket = primaryTicket(pr);
  return !!(ticket && ticketTitleMarksBug(root, ticket));
}

function gitNames(base, range, root = '.') {
  const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  return git(['diff', '--no-ext-diff', '--name-only', '-z', '--diff-filter=ACMR', range, '--']).split('\0').filter(Boolean);
}

function fixturePathsForTicket(ticket, files) {
  const prefixes = ticketFolderNames(ticket).map(name => `${FIXTURE_ROOT}/${name}/`);
  return files.filter(file => prefixes.some(prefix => file.startsWith(prefix)));
}

function readReproManifest(root, ticket) {
  for (const name of ticketFolderNames(ticket)) {
    const file = path.join(root, FIXTURE_ROOT, name, REPRO_FILE);
    if (!fs.existsSync(file)) continue;
    try {
      const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (!Array.isArray(manifest.command) || !manifest.command.length) throw new Error('command is required');
      if (manifest.command.some(part => typeof part !== 'string')) throw new Error('command entries must be strings');
      const files = Array.isArray(manifest.files) ? manifest.files.map(String) : [];
      if (files.some(file => file.includes('..') || file.startsWith('/'))) throw new Error('files must stay inside the repository');
      return { ticket: parseTicketId(ticket).id, folder: name, command: manifest.command, files, logPattern: String(manifest.logPattern || '^# (pass|fail) ') };
    } catch (error) {
      throw new Error(`${file}: ${error.message}`);
    }
  }
  return null;
}

function fixtureInputPaths(files, ticket) {
  return fixturePathsForTicket(ticket, files).filter(file => !file.endsWith(`/${REPRO_FILE}`));
}

function fixtureReadInDiff(files, ticket, root = '.') {
  const needles = ticketFolderNames(ticket).map(name => `${FIXTURE_ROOT}/${name}/`);
  const tests = files.filter(file => /(?:\.test\.[cm]?js|(?:\.test|-test)\.py)$/.test(file));
  return tests.some(file => {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    return needles.some(needle => source.includes(needle));
  });
}

function checkBugFixtureErrors({ base, root = '.', pr, files }) {
  if (!isBugPullRequest(pr, root)) return [];
  const ticket = primaryTicket(pr);
  const errors = [];
  if (!ticket) {
    errors.push('Bug-fix pull requests must name a ticket in the title (for example SOFT-3144: …).');
    return errors;
  }
  const listed = files || gitNames(base, `${base}...HEAD`, root);
  const inputs = fixtureInputPaths(listed, ticket);
  if (!inputs.length) {
    errors.push(`Add captured input under tools/fixtures/${parseTicketId(ticket).id}/ (not only ${REPRO_FILE}).`);
  }
  try {
    if (!readReproManifest(root, ticket)) errors.push(`Add tools/fixtures/${parseTicketId(ticket).id}/${REPRO_FILE} with the failing-first test command.`);
  } catch (error) {
    errors.push(error.message);
  }
  if (!fixtureReadInDiff(listed, ticket, root)) {
    errors.push(`Add or change a test that reads tools/fixtures/${parseTicketId(ticket).id}/ and proves the bug.`);
  }
  return errors;
}

function substantiveBaseFailure(log) {
  const text = String(log || '');
  if (!text || /MODULE_NOT_FOUND|Cannot find module/.test(text)) return false;
  return /AssertionError|checkBugFixtureErrors|tools\/fixtures\/|bug-fix fixture gate missing/i.test(text);
}

function provenFixtureRepro(item) {
  return item &&
    Number.isInteger(item.base_exit_code) &&
    item.base_exit_code !== 0 &&
    item.head_exit_code === 0 &&
    substantiveBaseFailure(item.base_log);
}

function fixtureReproFromSummary(summary) {
  const rows = summary?.fixtureRepro;
  if (!Array.isArray(rows) || !rows.length) return null;
  return rows.every(provenFixtureRepro) ? rows : null;
}

function missingFixtureReproNote(ticket) {
  return `Bug-fix pull request ${ticket || ''} needs a failing-first repro (base failed, head passed) in verifier evidence.`.replace('  ', ' ');
}

module.exports = {
  FIXTURE_ROOT,
  REPRO_FILE,
  ticketFolderNames,
  isRepair,
  isBugPullRequest,
  primaryTicket,
  checkBugFixtureErrors,
  readReproManifest,
  provenFixtureRepro,
  fixtureReproFromSummary,
  missingFixtureReproNote,
  gitNames,
};