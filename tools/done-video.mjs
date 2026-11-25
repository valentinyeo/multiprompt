#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const defaults = { repo: 'valentinyeo/multiprompt', workflow: 'pr-verifier.yml' };
const valueOptions = new Set(['--journey', '--repo', '--out']);
const booleanOptions = new Set(['--help']);

export class CliError extends Error {
  constructor(message, code = 1) {
    super(message);
    this.name = 'CliError';
    this.code = code;
  }
}

export function parseArgs(argv) {
  const options = {};
  const words = [];
  for (let i = 0; i < argv.length; i++) {
    const word = argv[i];
    if (!word.startsWith('--')) {
      words.push(word);
      continue;
    }
    const split = word.indexOf('=');
    const name = split < 0 ? word : word.slice(0, split);
    const inline = split < 0 ? undefined : word.slice(split + 1);
    if (booleanOptions.has(name)) {
      if (inline !== undefined) throw new CliError(`${name} takes no value`);
      options[name] = true;
      continue;
    }
    if (!valueOptions.has(name)) throw new CliError(`unknown option ${name}`);
    const value = inline ?? argv[++i];
    if (value === undefined || value.startsWith('--') || value === '') throw new CliError(`${name} needs a value`);
    options[name] = value;
  }
  if (options['--help']) return { help: true, pr: '', journey: '', repo: options['--repo'] || defaults.repo, out: options['--out'] || '' };
  if (!words.length) throw new CliError('pass a pull request number, for example: node tools/done-video.mjs 1234 [journey]');
  if (words.length > 2) throw new CliError(`expected at most <pr-number> [journey], got: ${words.join(' ')}`);
  const pr = String(words[0]).replace(/^#/, '');
  if (!/^\d+$/.test(pr)) throw new CliError(`pull request number must be numeric, got ${words[0]}`);
  const journey = options['--journey'] || words[1] || '';
  if (journey && !/^[a-z][a-z0-9-]*$/.test(journey)) throw new CliError(`invalid journey name: ${journey}`);
  return { help: false, pr, journey, repo: options['--repo'] || defaults.repo, out: options['--out'] || '' };
}

export function selectVerifierRuns(runs, prNumber) {
  const target = Number(prNumber);
  const title = `verify PR ${prNumber}`;
  return (Array.isArray(runs) ? runs : [])
    .filter(run => run && (
      run.display_title === title ||
      (Array.isArray(run.pull_requests) && run.pull_requests.some(pr => Number(pr.number) === target))
    ))
    .sort((left, right) => Number(right.id) - Number(left.id));
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function journeyArtifactPattern(journey) {
  return new RegExp(`^verify-${escapeRegex(journey)}(?:-\\d+-(?:light|dark))?$`);
}

function newestByName(artifacts) {
  const latest = new Map();
  for (const artifact of Array.isArray(artifacts) ? artifacts : []) {
    if (!artifact || artifact.expired || typeof artifact.name !== 'string') continue;
    const previous = latest.get(artifact.name);
    if (!previous || String(artifact.created_at || '') > String(previous.created_at || '') ||
      (String(artifact.created_at || '') === String(previous.created_at || '') && Number(artifact.id) > Number(previous.id))) {
      latest.set(artifact.name, artifact);
    }
  }
  return [...latest.values()].sort((left, right) => left.name.localeCompare(right.name));
}

export function listJourneyArtifacts(artifacts) {
  return newestByName(artifacts).filter(artifact => /^verify-/.test(artifact.name) && !/^verify-app(?:-|$)/.test(artifact.name) && !/-[0-9a-f]{40}(?:-|$)/.test(artifact.name));
}

export function selectEvidenceArtifact(artifacts, journey = '', preferredJourneys = []) {
  const candidates = listJourneyArtifacts(artifacts);
  if (!candidates.length) throw new CliError('no non-expired verify-* evidence artifacts found');
  if (journey) {
    const pattern = journeyArtifactPattern(journey);
    const match = candidates.find(artifact => pattern.test(artifact.name));
    if (!match) {
      throw new CliError(`no evidence artifact for journey "${journey}"; available: ${candidates.map(item => item.name).join(', ')}`);
    }
    return match;
  }
  for (const preferred of Array.isArray(preferredJourneys) ? preferredJourneys : []) {
    const pattern = journeyArtifactPattern(String(preferred));
    const match = candidates.find(artifact => pattern.test(artifact.name));
    if (match) return match;
  }
  return candidates[0];
}

export function selectBeforeArtifact(artifacts, headArtifact) {
  const match = headArtifact.name.match(/^(verify-.+?)(-\d+-(?:light|dark))?$/);
  const pattern = new RegExp(`^${escapeRegex(match[1])}-[0-9a-f]{40}${escapeRegex(match[2] || '')}$`);
  const before = newestByName(artifacts).find(artifact => pattern.test(artifact.name));
  if (!before) throw new CliError(`no matching before video artifact for ${headArtifact.name}`);
  return before;
}

export function findJourneyVideo(directory, filename = 'journey.mp4') {
  const found = [];
  const walk = current => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile() && entry.name.toLowerCase() === filename.toLowerCase() && fs.statSync(full).size > 0) {
        found.push(path.relative(directory, full).split(path.sep).join('/'));
      }
    }
  };
  if (fs.existsSync(directory)) walk(directory);
  found.sort();
  const rootVideo = found.find(file => !file.includes('/'));
  const chosen = rootVideo || found[0];
  if (!chosen) throw new CliError(`no non-empty ${filename} found in ${directory}`);
  return path.resolve(directory, chosen);
}

export function defaultIo() {
  return {
    exec: (command, args) => spawnSync(command, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }),
    downloadZip: (repo, artifactId, archivePath) => {
      const fd = fs.openSync(archivePath, 'w');
      try {
        execFileSync('gh', ['api', `repos/${repo}/actions/artifacts/${artifactId}/zip`], { stdio: ['ignore', fd, 'pipe'] });
      } finally {
        fs.closeSync(fd);
      }
    },
    extractZip: (archivePath, targetDir) => {
      fs.mkdirSync(targetDir, { recursive: true });
      execFileSync('unzip', ['-oq', archivePath, '-d', targetDir], { stdio: ['ignore', 'ignore', 'pipe'] });
    },
    tempDir: () => os.tmpdir(),
    write: text => process.stdout.write(text),
    error: text => process.stderr.write(text),
  };
}

function ghJson(io, args) {
  const result = io.exec('gh', args);
  if (result.error) throw new CliError(`gh could not start: ${result.error.message}`);
  if (result.status !== 0) {
    const detail = String(result.stderr || '').trim().split(/\r?\n/).filter(Boolean).pop() || `exit ${result.status}`;
    throw new CliError(`gh ${args.join(' ')} failed: ${detail}`);
  }
  try {
    return JSON.parse(result.stdout || 'null');
  } catch {
    throw new CliError(`gh ${args.join(' ')} returned unreadable JSON`);
  }
}

function fetchRunArtifacts(io, repo, runId) {
  const artifacts = [];
  for (let page = 1; ; page++) {
    const response = ghJson(io, ['api', `repos/${repo}/actions/runs/${runId}/artifacts?per_page=100&page=${page}`]);
    const batch = Array.isArray(response?.artifacts) ? response.artifacts : [];
    artifacts.push(...batch);
    if (batch.length < 100) return artifacts;
  }
}

function readSelectionFeatures(io, repo, artifacts, scratchDir, expectedHead = '') {
  const selectionArtifact = newestByName(artifacts).find(item => item.name === 'pr-verifier-selection');
  if (!selectionArtifact) {
    if (expectedHead) throw new CliError('cannot confirm the manually dispatched verifier head without its selection artifact');
    return [];
  }
  try {
    const archive = path.join(scratchDir, 'selection.zip');
    const dir = path.join(scratchDir, 'selection');
    io.downloadZip(repo, selectionArtifact.id, archive);
    io.extractZip(archive, dir);
    if (expectedHead) {
      const pr = JSON.parse(fs.readFileSync(path.join(dir, 'pr.json'), 'utf8'));
      if (pr.headRefOid !== expectedHead) throw new CliError('the verifier evidence belongs to an older PR head; wait for the current verifier');
    }
    const file = path.join(dir, 'selection.json');
    if (!fs.existsSync(file)) return [];
    const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
    return Array.isArray(parsed.features) ? parsed.features : [];
  } catch (error) {
    if (expectedHead) throw error instanceof CliError ? error : new CliError('cannot read the manually dispatched verifier head');
    return [];
  }
}

export function run(parsed, io = defaultIo()) {
  const pr = ghJson(io, ['pr', 'view', parsed.pr, '--repo', parsed.repo, '--json', 'headRefOid']);
  const response = ghJson(io, ['api', `repos/${parsed.repo}/actions/workflows/${defaults.workflow}/runs?per_page=100`]);
  const runs = selectVerifierRuns(response?.workflow_runs || [], parsed.pr).filter(run => run.head_sha === pr.headRefOid || run.event === 'workflow_dispatch');
  if (!runs.length) throw new CliError(`no ${defaults.workflow} run found for PR #${parsed.pr} in ${parsed.repo}`);
  let chosenRun = null;
  let runArtifacts = [];
  for (const candidate of runs) {
    const listed = fetchRunArtifacts(io, parsed.repo, candidate.id);
    if (listJourneyArtifacts(listed).length) {
      chosenRun = candidate;
      runArtifacts = listed;
      break;
    }
  }
  if (!chosenRun) throw new CliError(`no ${defaults.workflow} run for PR #${parsed.pr} has non-expired journey evidence artifacts`);
  const baseDir = parsed.out ? path.resolve(parsed.out) : path.join(io.tempDir(), 'multiprompt-done-video', `pr-${parsed.pr}-run-${chosenRun.id}`);
  fs.mkdirSync(baseDir, { recursive: true });
  const scratchDir = fs.mkdtempSync(path.join(baseDir, '.dl-'));
  try {
    const preferred = readSelectionFeatures(io, parsed.repo, runArtifacts, scratchDir,
      chosenRun.event === 'workflow_dispatch' ? pr.headRefOid : '');
    const artifact = selectEvidenceArtifact(runArtifacts, parsed.journey, preferred);
    const before = selectBeforeArtifact(runArtifacts, artifact);
    const videoPaths = [];
    for (const [item, filename] of [[before, 'before.mp4'], [artifact, 'after.mp4']]) {
      const archive = path.join(scratchDir, `${filename}.zip`);
      const target = path.join(baseDir, item.name);
      fs.rmSync(target, { recursive: true, force: true });
      io.downloadZip(parsed.repo, item.id, archive);
      io.extractZip(archive, target);
      videoPaths.push(findJourneyVideo(target, filename));
    }
    return { pr: parsed.pr, runId: Number(chosenRun.id), artifact: artifact.name, videoPaths };
  } finally {
    fs.rmSync(scratchDir, { recursive: true, force: true });
  }
}

const helpText = `Usage: node tools/done-video.mjs <pr-number> [journey] [--repo owner/name] [--out dir]

Downloads the same journey's base and head evidence from the PR verifier.
Prints before.mp4 then after.mp4, one local path per line, for the ticket and PR.
`;

export function main(argv, io = defaultIo()) {
  try {
    const parsed = parseArgs(argv);
    if (parsed.help) {
      io.write(helpText);
      return 0;
    }
    const outcome = run(parsed, io);
    io.write(`${outcome.videoPaths.join('\n')}\n`);
    return 0;
  } catch (error) {
    if (!(error instanceof CliError)) throw error;
    io.error(`done-video: ${error.message}\n`);
    return error.code;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main(process.argv.slice(2));
}
