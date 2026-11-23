import { execFileSync } from 'node:child_process';

export const READER_PATH = 'src/chat_history_reader.py';
const DIRECT_HOST_GENERATION = /(?:generation=RUNTIME_GENERATION|dict\(generation=RUNTIME_GENERATION)/;

export function hostGenerationGuard(source) {
  if (typeof source !== 'string') return { ok: false, reason: `${READER_PATH} is missing` };
  if (!source.includes('def host_generation(')) {
    return { ok: false, reason: `${READER_PATH} must define host_generation()` };
  }
  if (DIRECT_HOST_GENERATION.test(source)) {
    return { ok: false, reason: 'host rotate and host version must use host_generation(), not RUNTIME_GENERATION' };
  }
  return { ok: true, reason: 'host generation guard ok' };
}

export function run(_baseArg, headArg) {
  const head = headArg || 'HEAD';
  const source = execFileSync('git', ['show', `${head}:${READER_PATH}`], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  const host = hostGenerationGuard(source);
  if (!host.ok) {
    console.error(`runtime fingerprint guard: ${host.reason}`);
    process.exitCode = 1;
    return host;
  }
  execFileSync(process.env.PYTHON || 'python3', ['tools/runtime-fingerprint.test.py', '-v'], { stdio: 'inherit', timeout: 90000 });
  console.log('RUNTIME_FINGERPRINT_OK');
  return host;
}

if (import.meta.url === `file://${process.argv[1]}`) run(process.argv[2], process.argv[3]);
