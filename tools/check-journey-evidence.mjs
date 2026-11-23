import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('..', import.meta.url));
export const workflowsDirectory = path.join(root, '.github/workflows');

const evidencePath = /evidence|screenshots?|\.(?:png|bmp|jpe?g|webp)(?:$|['"\s,*])/i;
const evidenceRoot = /^(?:[a-z0-9_.-]*evidence|screenshots?)$/i;
const removal = /(?:^|[\s;&|]|-)(?:Remove-Item|rm|rmdir|rd|del)\s+((?:-\w+\s+)*[^\r\n;&|]+)/i;
const conditionalAlways = /always\s*\(\s*\)/;

export function parseWorkflow(source) {
  const jobs = [];
  let job = null;
  let step = null;
  for (const [index, line] of source.split(/\r?\n/).entries()) {
    const jobName = /^ {2}([A-Za-z0-9_-]+):\s*$/.exec(line);
    if (jobName) {
      job = { name: jobName[1], steps: [] };
      jobs.push(job);
      step = null;
      continue;
    }
    if (job && /^ {6}- /.test(line)) {
      step = { line: index + 1, text: [line] };
      job.steps.push(step);
      continue;
    }
    if (step) step.text.push(line);
  }
  return jobs;
}

function stepCondition(step) {
  const found = /^\s*-?\s*if:\s*(.*)$/m.exec(step.text.join('\n'));
  return found ? found[1].trim() : '';
}

function stepPaths(step) {
  const lines = step.text;
  const values = [];
  for (let index = 0; index < lines.length; index++) {
    const scalar = /^\s*-?\s*path:\s*(.*)$/.exec(lines[index]);
    if (!scalar) continue;
    if (!/^[|>]/.test(scalar[1].trim())) {
      values.push(scalar[1].trim());
      continue;
    }
    const indent = (/^(\s*)/.exec(lines[index + 1]) || [, ''])[1].length;
    for (let next = index + 1; next < lines.length; next++) {
      if (!lines[next].trim()) continue;
      if ((/^(\s*)/.exec(lines[next])[1]).length < indent) break;
      values.push(lines[next].trim());
    }
  }
  return values;
}

export function evidenceRoots(paths) {
  const roots = new Set();
  for (const value of paths) {
    for (const token of value.split(/[\s'",]+/)) {
      for (const segment of token.split('/')) {
        const clean = segment.replace(/^\$\{\{[^}]*\}\}/, '').replace(/^['"]|['"]$/g, '');
        if (clean && evidenceRoot.test(clean)) roots.add(clean);
      }
    }
  }
  return [...roots];
}

function removalTargets(step) {
  const targets = [];
  for (const line of step.text) {
    const found = removal.exec(line);
    if (!found) continue;
    for (const token of found[1].split(/[\s;&|'"]+/)) {
      if (token && !token.startsWith('-')) targets.push(token.replace(/,+$/, ''));
    }
  }
  return targets;
}

function mentions(target, roots) {
  return target.split(/[/\\]/).some(segment => roots.includes(segment));
}

export function checkJourneyEvidence(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    for (const job of parseWorkflow(source)) {
      const uploads = [];
      for (const [index, step] of job.steps.entries()) {
        const paths = stepPaths(step).filter(value => evidencePath.test(value));
        if (/upload-artifact/.test(step.text.join('\n')) && paths.length) uploads.push({ index, step, paths });
      }
      for (const upload of uploads) {
        const condition = stepCondition(upload.step);
        const where = `${file}:${upload.step.line} (job ${job.name}, ${upload.paths.join(' ')})`;
        if (!conditionalAlways.test(condition)) {
          problems.push(`${where}: uploads journey evidence without if: always(), so a failed or cancelled run loses it`);
        }
        const roots = evidenceRoots(upload.paths);
        for (const step of job.steps.slice(0, upload.index)) {
          const targets = removalTargets(step).filter(target => mentions(target, roots));
          if (targets.length) {
            problems.push(`${where}: ${file}:${step.line} removes ${targets.join(' ')} before the upload`);
          }
        }
      }
    }
  }
  return problems;
}

export function readWorkflows(directory = workflowsDirectory) {
  const files = {};
  for (const name of fs.readdirSync(directory).sort()) {
    if (!/\.ya?ml$/.test(name)) continue;
    files[`.github/workflows/${name}`] = fs.readFileSync(path.join(directory, name), 'utf8');
  }
  return files;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const problems = checkJourneyEvidence(readWorkflows(process.argv[2]));
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('Journey evidence uploads survive failure and cancellation');
  }
}
