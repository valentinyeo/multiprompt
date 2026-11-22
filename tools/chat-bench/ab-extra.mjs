import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const FIELDS = [
  ['idleAverageCpu', 'Idle CPU %'],
  ['averageCpu', 'Average CPU %'],
  ['fiveSecondPeakCpu', '5 s peak CPU %'],
  ['thirtySecondPeakCpu', '30 s peak CPU %'],
  ['peakRssMiB', 'Peak RSS MiB'],
  ['switchPaintP95Ms', 'Switch paint p95 ms'],
  ['coldPaintP95Ms', 'Cold paint p95 ms'],
  ['warmPaintP95Ms', 'Warm paint p95 ms'],
  ['warmContentP95Ms', 'Warm content p95 ms'],
];

function median(values) {
  const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (!sorted.length) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function round(value) {
  return value === null ? 'n/a' : String(Math.round(value * 10) / 10);
}

export function summarize(runs) {
  if (!Array.isArray(runs) || !runs.length) throw new Error('No benchmark runs');
  const tags = [...new Set(runs.map(run => run.tag))];
  return tags.map(tag => {
    const rows = runs.filter(run => run.tag === tag);
    const cells = Object.fromEntries(FIELDS.map(([key]) => {
      const values = rows.map(run => run.result?.metrics?.[key]).filter(Number.isFinite);
      return [key, { median: median(values), min: values.length ? Math.min(...values) : null, max: values.length ? Math.max(...values) : null, n: values.length }];
    }));
    return { tag, runs: rows.length, failedChecks: median(rows.map(run => run.result?.failures?.length)), cells };
  });
}

export function markdown(groups) {
  const lines = ['# Chat bench metrics per release', '', 'Linux/Wine on a GitHub-hosted Ubuntu 24.04 runner; not native Windows acceptance. Cells are median [min, max] over the runs.', '', `| Tag | Runs | ${FIELDS.map(field => field[1]).join(' | ')} | Failed checks |`, `| --- | ---: | ${FIELDS.map(() => '---:').join(' | ')} | ---: |`];
  for (const group of groups) {
    const cells = FIELDS.map(([key]) => {
      const cell = group.cells[key];
      return cell.n ? `${round(cell.median)} [${round(cell.min)}, ${round(cell.max)}]` : 'n/a';
    });
    lines.push(`| ${group.tag} | ${group.runs} | ${cells.join(' | ')} | ${group.failedChecks ?? 'n/a'} |`);
  }
  lines.push('');
  return lines.join('\n');
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const [manifestFile, out] = process.argv.slice(2);
  if (!manifestFile || !out || process.argv.length !== 4) throw new Error('Usage: ab-extra.mjs <manifest.json> <output-directory>');
  const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
  const runs = manifest.map(run => ({ ...run, result: JSON.parse(fs.readFileSync(path.resolve(path.dirname(manifestFile), run.path), 'utf8')) }));
  const groups = summarize(runs);
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'metrics.json'), JSON.stringify({ groups, runs: runs.map(run => ({ label: run.label, tag: run.tag, index: run.index, status: run.result?.status, failures: run.result?.failures, metrics: run.result?.metrics })) }, null, 2) + '\n');
  const text = markdown(groups);
  fs.writeFileSync(path.join(out, 'metrics.md'), text);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  console.log(text);
  console.log(`::notice title=chat-bench-metrics::${text.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A')}`);
}
