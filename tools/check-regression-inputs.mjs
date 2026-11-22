import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export function isInputFile(file) {
  return /^tools\/.*\.(?:[cm]?js|py)$/.test(file) || file.startsWith('tests/') || file === 'build.zig' || /^\.github\/workflows\/[^/]+\.yml$/.test(file);
}

export function addedLines(diff) {
  const lines = new Set();
  let line = 0;
  for (const text of diff.split('\n')) {
    const hunk = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(text);
    if (hunk) line = Number(hunk[1]);
    else if (text.startsWith('+') && !text.startsWith('+++')) lines.add(line++);
    else if (text.startsWith(' ')) line++;
  }
  return lines;
}

function isolatedTempOperation(source, start, end) {
  const names = [...source.matchAll(/\b(?:const|let|var)\s+(\w+)\s*=\s*(?:\w+\.)?mkdtemp(?:Sync)?\s*\(/g)].map(match => match[1]);
  if (!names.length || !/(?:\bgit\s+init\b|['"]init['"])/.test(source)) return false;
  const before = source.lastIndexOf('\n', start) + 1;
  const after = source.indexOf(');', end);
  const call = source.slice(before, after < 0 ? end : Math.min(after + 2, end + 2000));
  for (const name of names) {
    const cwd = new RegExp(`\\bcwd\\s*:\\s*${name}\\b`);
    if (cwd.test(call)) return true;
    const wrappers = [...source.matchAll(/\b(?:const|let)\s+(\w+)\s*=\s*[^;\n]*\bexecFileSync\s*\(\s*['"]git['"][^;]*;/g)];
    if (wrappers.some(wrapper => cwd.test(wrapper[0]) && new RegExp(`\\b${wrapper[1]}\\s*\\(`).test(call))) return true;
  }
  return false;
}

function nonCodeRanges(source) {
  const ranges = [];
  for (let i = 0; i < source.length; i++) {
    const start = i;
    const char = source[i];
    if (source.startsWith('//', i) || char === '#') {
      i = source.indexOf('\n', i);
      if (i < 0) i = source.length;
      ranges.push({ start, end: i, kind: 'comment' });
    } else if (source.startsWith('/*', i)) {
      i = source.indexOf('*/', i + 2);
      i = i < 0 ? source.length : i + 1;
      ranges.push({ start, end: i + 1, kind: 'comment' });
    } else if (['"', "'", '`'].includes(char)) {
      const delimiter = source.startsWith(char.repeat(3), i) ? char.repeat(3) : char;
      i += delimiter.length;
      while (i < source.length && !source.startsWith(delimiter, i)) { if (source[i] === '\\') i++; i++; }
      i += delimiter.length - 1;
      ranges.push({ start, end: i + 1, kind: 'string', content: source.slice(start + delimiter.length, i + 1 - delimiter.length) });
    } else if (char === '/' && /(?:^|[=(:,\[!&|?;{}])\s*$/.test(source.slice(0, i))) {
      let inClass = false;
      while (++i < source.length) {
        if (source[i] === '\\') i++;
        else if (source[i] === '[') inClass = true;
        else if (source[i] === ']') inClass = false;
        else if (source[i] === '/' && !inClass) break;
        else if (source[i] === '\n') break;
      }
      ranges.push({ start, end: i + 1, kind: 'regex' });
    }
  }
  return ranges;
}

export function findHistoryInputs(file, source, added) {
  const operations = [];
  const ranges = nonCodeRanges(source);
  const shell = /\bgit\s+(show|cat-file|archive)\s+([^\n;"'`]+)/g;
  const array = /(['"`])(show|cat-file|archive)\1\s*,\s*(['"`])((?:\\.|(?!\3)[^\n])*)\3/g;
  for (const match of source.matchAll(shell)) operations.push({ start: match.index, end: match.index + match[0].length, command: match[1], argument: match[2].trim(), shell: true });
  for (const match of source.matchAll(array)) {
    let argument = match[4];
    let end = match.index + match[0].length;
    if (argument.startsWith('-')) {
      const next = /^\s*,\s*(['"`])((?:\\.|(?!\1)[^\n])*)\1/.exec(source.slice(end));
      if (next) { argument = next[2]; end += next[0].length; }
    }
    operations.push({ start: match.index, end, command: match[2], argument });
  }
  const errors = [];
  const reported = new Set();
  for (const operation of operations) {
    const range = ranges.find(range => operation.start >= range.start && operation.start < range.end);
    if (range && range.kind !== 'string') continue;
    if (range && !operation.shell && range.start !== operation.start) continue;
    if (range && operation.shell && (!/^\s*git\s/.test(range.content) || !/(?:exec\w*|spawn\w*|run|check_output|system|addSystemCommand)\s*\([^;]*$/i.test(source.slice(Math.max(0, range.start - 200), range.start)) && !file.endsWith('.yml'))) continue;
    if (operation.command === 'show' && !/^[^\s:]+:/.test(operation.argument)) continue;
    const first = source.slice(0, operation.start).split('\n').length;
    const last = first + source.slice(operation.start, operation.end).split('\n').length - 1;
    const line = [...added].find(line => line >= first && line <= last);
    if (line === undefined || reported.has(line) || isolatedTempOperation(source, operation.start, operation.end)) continue;
    reported.add(line);
    errors.push(`${file}:${line} loads ${operation.argument} from git history; snapshot the exact input in tools/fixtures/<ticket>/ and read it with fs.readFileSync`);
  }
  return errors;
}

export function checkRegressionInputs(base, root = '.') {
  if (!base || base.startsWith('-')) throw new Error('Usage: node tools/check-regression-inputs.mjs <base-ref> [--root DIR]');
  const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  const range = `${base}...HEAD`;
  const files = git(['diff', '--no-ext-diff', '--name-only', '-z', '--diff-filter=ACMR', range, '--']).split('\0').filter(isInputFile);
  const errors = [];
  for (const file of files) {
    const diff = git(['diff', '--no-ext-diff', '--no-color', '--unified=0', range, '--', file]);
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    errors.push(...findHistoryInputs(file, source, addedLines(diff)));
  }
  return { errors, files: files.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [base, flag, root] = process.argv.slice(2);
    if (process.argv.length > 6 || flag && (flag !== '--root' || !root)) throw new Error('Usage: node tools/check-regression-inputs.mjs <base-ref> [--root DIR]');
    const result = checkRegressionInputs(base, root || '.');
    if (result.errors.length) { console.error(result.errors.join('\n')); process.exitCode = 1; }
    else console.log(`Regression inputs OK: ${result.files} changed input files`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
