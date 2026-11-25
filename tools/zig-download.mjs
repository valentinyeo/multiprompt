import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

export const OFFICIAL_BASE = 'https://ziglang.org/download';
export const MIRRORS_URL = 'https://ziglang.org/download/community-mirrors.txt';
export const FALLBACK_MIRRORS = ['https://zig.linus.dev/zig', 'https://pkg.machengine.org/zig', 'https://zig.squirl.dev'];

export function archiveName(version, target) {
  return `zig-${target}-${version}.${target.includes('windows') ? 'zip' : 'tar.xz'}`;
}

export function parseMirrors(text) {
  return String(text)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => /^https?:\/\//.test(line));
}

export function sourceList({ mirrorsText = '', extra = [] } = {}) {
  const bases = [OFFICIAL_BASE, ...parseMirrors(mirrorsText), ...FALLBACK_MIRRORS, ...extra];
  const seen = new Set();
  const list = [];
  for (const base of bases) {
    const trimmed = base.trim().replace(/\/+$/, '');
    if (!/^https?:\/\//.test(trimmed) || seen.has(trimmed)) continue;
    seen.add(trimmed);
    list.push(trimmed);
  }
  return list;
}

export async function readMirrors({ mirrorsUrl = MIRRORS_URL, limitMs = 15000 } = {}) {
  try {
    const response = await fetch(mirrorsUrl, { signal: AbortSignal.timeout(limitMs), redirect: 'follow' });
    if (!response.ok) return [];
    return parseMirrors(await response.text());
  } catch {
    return [];
  }
}

export function digest(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

async function transfer(url, destination, { timeMs, stallMs }) {
  const controller = new AbortController();
  const stall = () => setTimeout(() => controller.abort(new Error(`no data for ${stallMs}ms`)), stallMs);
  let stallTimer = stall();
  const capTimer = setTimeout(() => controller.abort(new Error(`gave up after ${timeMs}ms`)), timeMs);
  let handle;
  try {
    const response = await fetch(url, { signal: controller.signal, redirect: 'follow' });
    if (!response.ok || !response.body) throw new Error(`HTTP ${response.status}`);
    handle = fs.openSync(destination, 'w');
    let bytes = 0;
    for await (const chunk of response.body) {
      clearTimeout(stallTimer);
      stallTimer = stall();
      fs.writeSync(handle, chunk);
      bytes += chunk.length;
    }
    return bytes;
  } finally {
    clearTimeout(stallTimer);
    clearTimeout(capTimer);
    if (handle !== undefined) fs.closeSync(handle);
  }
}

export async function download({
  version,
  target,
  sha256,
  dest,
  sources,
  budgetMs = 240000,
  perSourceMs = 90000,
  stallMs = 20000,
  log = (line) => process.stderr.write(`${line}\n`),
}) {
  const file = archiveName(version, target);
  if (fs.existsSync(dest) && digest(dest) === sha256) return { source: 'existing', file, bytes: fs.statSync(dest).size };
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  const partial = `${dest}.part`;
  const deadline = Date.now() + budgetMs;
  const tried = [];
  for (const source of sources) {
    const timeMs = Math.min(perSourceMs, deadline - Date.now());
    if (timeMs <= 0) {
      tried.push(`${source}: no time left in the ${budgetMs}ms budget`);
      break;
    }
    const url = `${source}/${version}/${file}`;
    try {
      const bytes = await transfer(url, partial, { timeMs, stallMs });
      const got = digest(partial);
      if (got !== sha256) throw new Error(`checksum ${got} does not match ${sha256}`);
      fs.renameSync(partial, dest);
      log(`Downloaded ${file} (${bytes} bytes) from ${source}`);
      return { source, file, bytes };
    } catch (error) {
      fs.rmSync(partial, { force: true });
      log(`Source ${source} did not deliver ${file}: ${error.message}`);
      tried.push(`${source}: ${error.message}`);
    }
  }
  throw new Error(`No source delivered ${file}: ${tried.join('; ')}`);
}

function usage() {
  return 'usage: node tools/zig-download.mjs --version 0.16.0 --target x86_64-linux --sha256 <hex> --dest <file> [--source <base>]... [--budget-seconds 240] [--per-source-seconds 90] [--mirrors-url <url>] [--no-mirrors]';
}

async function main() {
  const { values } = parseArgs({
    options: {
      version: { type: 'string' },
      target: { type: 'string' },
      sha256: { type: 'string' },
      dest: { type: 'string' },
      source: { type: 'string', multiple: true },
      'budget-seconds': { type: 'string' },
      'per-source-seconds': { type: 'string' },
      'mirrors-url': { type: 'string' },
      'no-mirrors': { type: 'boolean' },
    },
  });
  for (const required of ['version', 'target', 'sha256', 'dest']) {
    if (!values[required]) {
      process.stderr.write(`${usage()}\n`);
      process.exitCode = 2;
      return;
    }
  }
  const published = values['no-mirrors'] ? [] : await readMirrors({ mirrorsUrl: values['mirrors-url'] || MIRRORS_URL });
  const configured = sourceList({ mirrorsText: published.join('\n'), extra: values.source || [] });
  const budgetMs = Number(values['budget-seconds'] || 240) * 1000;
  const perSourceMs = Number(values['per-source-seconds'] || 90) * 1000;
  try {
    const result = await download({ version: values.version, target: values.target, sha256: values.sha256, dest: values.dest, sources: configured, budgetMs, perSourceMs });
    process.stdout.write(`${result.source}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
