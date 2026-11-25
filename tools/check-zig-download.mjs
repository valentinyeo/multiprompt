import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('..', import.meta.url));
export const workflowsDirectory = path.join(root, '.github/workflows');
export const actionUse = './.github/actions/setup-zig';

export function inlineDownloads(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    for (const [index, line] of source.split(/\r?\n/).entries()) {
      if (!line.includes('ziglang.org')) continue;
      problems.push(`${file}:${index + 1}: downloads Zig inline instead of ${actionUse}, so one stuck transfer holds the job until its time cap`);
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

export function checkZigDownload(files) {
  return inlineDownloads(files);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const problems = checkZigDownload(readWorkflows(process.argv[2]));
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exitCode = 1;
  } else {
    console.log(`Every workflow installs Zig through ${actionUse}`);
  }
}
