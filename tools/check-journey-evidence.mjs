import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('..', import.meta.url));
export const workflowsDirectory = path.join(root, '.github/workflows');

const evidencePath = /evidence|screenshots?|\.(?:png|bmp|jpe?g|webp|mp4)(?:$|['"\s,*])/i;
const screenshotName = /\.(?:png|bmp|jpe?g|webp|mp4)$/i;
const screenshotToken = /\.(?:png|bmp|jpe?g|webp|mp4)(?:$|[*?'"\s,])/i;
const removal = /(?:^|[\s;&|]|-)(?:Remove-Item|rm|rmdir|rd|del)\s+([^\r\n;&|]+)/i;
const fileSuffix = /\.(?:json|log|txt|md|ya?ml)$/i;

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

export function evidenceScope(paths) {
  const directories = new Set();
  let screenshots = false;
  for (const value of paths) {
    for (const token of value.split(/[\s'",]+/)) {
      if (!token) continue;
      if (screenshotToken.test(token)) screenshots = true;
      const segments = token.split('/').filter(segment => segment && !/^\$\{\{.*\}\}$/.test(segment));
      const last = segments[segments.length - 1] || '';
      if (/[*?]/.test(last) || screenshotName.test(last) || fileSuffix.test(last)) segments.pop();
      for (const segment of segments) directories.add(segment.toLowerCase());
    }
  }
  return { directories: [...directories], screenshots };
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

function removesEvidence(target, scope) {
  const segments = target.split(/[/\\]/).filter(Boolean).map(segment => segment.toLowerCase());
  if (scope.directories.some(directory => segments.includes(directory))) return true;
  return scope.screenshots && screenshotName.test(target);
}

function stepName(step) {
  const found = /^\s*-?\s*name:\s*(.*)$/m.exec(step.text.join('\n'));
  return found ? found[1].trim() : '';
}

function checkVerifyVideoRecording(file, job, problems) {
  if (file !== '.github/workflows/verify.yml' || job.name !== 'verify') return;
  const ffmpegStep = job.steps.find(step => /uses:\s*\.\/\.github\/actions\/install-ffmpeg\b/.test(step.text.join('\n')));
  if (!ffmpegStep) {
    problems.push(`${file} (job ${job.name}): does not install FFmpeg for journey video recording`);
  } else {
    const condition = stepCondition(ffmpegStep);
    if (condition) {
      problems.push(`${file}:${ffmpegStep.line} (job ${job.name}): installs FFmpeg conditionally (${condition}), so other journeys lose journey.mp4`);
    }
  }
  for (const name of ['Launch Doctor Drive Evidence Cleanup', 'Verify real native browser journey']) {
    const step = job.steps.find(candidate => stepName(candidate) === name);
    if (!step) continue;
    const body = step.text.join('\n');
    if (!/drive\.ps1\b/.test(body)) {
      problems.push(`${file}:${step.line} (job ${job.name}): ${name} does not run drive.ps1, so journeys produce no journey.mp4`);
    }
    if (/control\.ps1\s+-Feature\s+\$env:FEATURE\b/.test(body)) {
      problems.push(`${file}:${step.line} (job ${job.name}): ${name} calls control.ps1 directly for $env:FEATURE, bypassing journey.mp4 recording`);
    }
  }
}

export function checkJourneyEvidence(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    for (const job of parseWorkflow(source)) {
      checkVerifyVideoRecording(file, job, problems);
      const uploads = [];
      for (const [index, step] of job.steps.entries()) {
        const paths = stepPaths(step).filter(value => evidencePath.test(value));
        if (/upload-artifact/.test(step.text.join('\n')) && paths.length) uploads.push({ index, step, paths });
      }
      for (const upload of uploads) {
        const where = `${file}:${upload.step.line} (job ${job.name}, ${upload.paths.join(' ')})`;
        const condition = stepCondition(upload.step);
        if (!/always\s*\(\s*\)/.test(condition)) {
          problems.push(`${where}: uploads journey evidence without if: always(), so a failed or cancelled run loses it`);
        } else if (/(?:success|failure|cancelled)\s*\(\s*\)/.test(condition)) {
          problems.push(`${where}: uploads journey evidence with ${condition}, which skips the upload when the run fails or is cancelled`);
        }
        const scope = evidenceScope(upload.paths);
        for (const step of job.steps.slice(0, upload.index)) {
          const targets = removalTargets(step).filter(target => removesEvidence(target, scope));
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
