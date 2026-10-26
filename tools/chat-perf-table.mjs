import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const METRICS = ['parse', 'delta', 'reconcile'];
const LINE = /CPU707 benchmark bytes=(\d+) messages=(\d+) parse_ms=(\d+) delta_ms=(\d+) reconcile_ms=(\d+)/;

export function parseRun(log, exit) {
  const match = LINE.exec(log);
  if (!match) return { exit, ok: false };
  return { exit, ok: true, bytes: Number(match[1]), messages: Number(match[2]), parse: Number(match[3]), delta: Number(match[4]), reconcile: Number(match[5]) };
}

export function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

export function buildRow(dir, ref) {
  const read = name => fs.existsSync(path.join(dir, name)) ? fs.readFileSync(path.join(dir, name), 'utf8') : null;
  const identity = (read('identity.txt') ?? '').split('\n');
  const runs = [];
  for (let index = 1; read(`run-${index}.log`) !== null; index++) runs.push(parseRun(read(`run-${index}.log`), Number((read(`run-${index}.exit`) ?? '').trim())));
  return { ref, sha: identity[0] || '', subject: identity[1] || '', unsupported: read('unsupported.txt') !== null, runs };
}

export function summarizeRow(row) {
  const ok = row.runs.filter(run => run.ok);
  const cells = {};
  for (const metric of METRICS) {
    const values = ok.map(run => run[metric]);
    cells[metric] = values.length ? { median: median(values), min: Math.min(...values), max: Math.max(...values) } : null;
  }
  return { ref: row.ref, sha: row.sha, subject: row.subject, unsupported: row.unsupported, measured: ok.length, total: row.runs.length, cells };
}

function refOrder(a, b) {
  const tag = /^v(\d+)\.(\d+)\.(\d+)$/;
  const left = tag.exec(a.ref), right = tag.exec(b.ref);
  if (left && right) return Number(left[3]) - Number(right[3]);
  if (left) return -1;
  if (right) return 1;
  return 0;
}

export function markdown(rows) {
  const lines = [
    '# Chat perf bisect',
    '',
    'Native 50 MB history benchmark (zig build test-chat-perf) on a GitHub-hosted Ubuntu 24.04 runner, Debug build. Cells are median [min, max] milliseconds over the measured runs.',
    '',
    '| Ref | Commit | Runs | Parse ms | Append ms | Reconcile ms | Subject |',
    '| --- | --- | ---: | ---: | ---: | ---: | --- |',
  ];
  const format = cell => cell ? `${cell.median} [${cell.min}, ${cell.max}]` : 'n/a';
  for (const summary of rows.map(summarizeRow).sort(refOrder)) {
    const note = summary.unsupported ? ' (no benchmark step)' : '';
    lines.push(`| ${summary.ref} | ${summary.sha.slice(0, 8)} | ${summary.measured}/${summary.total}${note} | ${format(summary.cells.parse)} | ${format(summary.cells.delta)} | ${format(summary.cells.reconcile)} | ${summary.subject.replace(/\|/g, '/')} |`);
  }
  return lines.join('\n') + '\n';
}

function findRows(dir) {
  const rows = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) rows.push(...findRows(full));
    else if (entry.name === 'row.json') rows.push(JSON.parse(fs.readFileSync(full, 'utf8')));
  }
  return rows;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const [mode, dir, ref] = process.argv.slice(2);
  if (mode === 'row') process.stdout.write(JSON.stringify(buildRow(dir, ref), null, 2) + '\n');
  else if (mode === 'table') process.stdout.write(markdown(findRows(dir)));
  else throw new Error('usage: chat-perf-table.mjs row <dir> <ref> | table <dir>');
}
