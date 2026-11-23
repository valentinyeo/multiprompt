import { execFileSync } from 'node:child_process';

export const READER_PATH = 'src/chat_history_reader.py';
const GENERATION = /^RUNTIME_GENERATION = (\d+)$/m;

export function generationOf(source) {
  if (typeof source !== 'string') return null;
  const found = GENERATION.exec(source);
  return found ? Number(found[1]) : null;
}

export function verdict(baseSource, headSource) {
  if (typeof headSource !== 'string') return { ok: false, reason: `${READER_PATH} is missing from the head revision` };
  const head = generationOf(headSource);
  if (head === null) return { ok: false, reason: `${READER_PATH} has no RUNTIME_GENERATION line` };
  if (typeof baseSource !== 'string') return { ok: true, reason: `${READER_PATH} is new` };
  if (baseSource === headSource) return { ok: true, reason: `${READER_PATH} is unchanged` };
  const base = generationOf(baseSource);
  if (base === null) return { ok: true, reason: `${READER_PATH} first gained RUNTIME_GENERATION` };
  if (head > base) return { ok: true, reason: `RUNTIME_GENERATION ${base} -> ${head}` };
  return { ok: false, reason: `the reader changed but RUNTIME_GENERATION stayed ${base}` };
}

function git(...args) {
  return execFileSync('git', args, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).trim();
}

function exists(revision) {
  try {
    git('cat-file', '-e', `${revision}:${READER_PATH}`);
    return true;
  } catch {
    return false;
  }
}

function resolveBase(requested) {
  const candidates = [requested, 'origin/master', 'HEAD^'].filter((value) => value && /^[0-9a-f]{7,40}$|^[\w./-]+$/.test(value));
  for (const candidate of candidates) {
    if (/^0+$/.test(candidate)) continue;
    try {
      return git('rev-parse', '--verify', `${candidate}^{commit}`);
    } catch {
      continue;
    }
  }
  return null;
}

export function run(baseArg, headArg) {
  const head = git('rev-parse', '--verify', `${headArg || 'HEAD'}^{commit}`);
  const base = resolveBase(baseArg);
  const headSource = exists(head) ? git('show', `${head}:${READER_PATH}`) : null;
  const baseSource = base && exists(base) ? git('show', `${base}:${READER_PATH}`) : null;
  const result = verdict(baseSource, headSource);
  if (!result.ok) {
    console.error(`runtime generation guard: ${result.reason}`);
    console.error('Every edit of src/chat_history_reader.py must raise RUNTIME_GENERATION by at least one.');
    process.exitCode = 1;
    return result;
  }
  console.log(`runtime generation guard: ${result.reason}`);
  console.log(`RUNTIME_GENERATION_OK ${base ? base.slice(0, 8) : '-'}..${head.slice(0, 8)}`);
  return result;
}

if (import.meta.url === `file://${process.argv[1]}`) run(process.argv[2], process.argv[3]);
