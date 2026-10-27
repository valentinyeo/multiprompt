import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function assess(data) {
  if (data.sessionCount !== 10 || !Number.isSafeInteger(data.transcriptBytes) || data.transcriptBytes < 250 * 1024 * 1024) throw new Error('Missing ten-session 250 MiB workload');
  if (!Array.isArray(data.switches) || data.switches.length !== 50) throw new Error('Expected exactly 50 switches');
  const targets = new Map();
  for (const sample of data.switches) {
    if (!Number.isInteger(sample.shell) || !Number.isFinite(sample.us) || sample.us < 0 || !Number.isSafeInteger(sample.blocks) || sample.blocks < 1) throw new Error('Invalid switch or missing painted content');
    targets.set(sample.shell, (targets.get(sample.shell) || 0) + 1);
  }
  if (targets.size !== 10 || [...targets.values()].some(count => count !== 5)) throw new Error('Every session must be visited five times');
  if (!Number.isInteger(data.idleShell) || !targets.has(data.idleShell)) throw new Error('Missing visited idle conversation');
  if (!Array.isArray(data.idleUs) || data.idleUs.length < 10 || data.idleUs.some(us => !Number.isFinite(us) || us < 0)) throw new Error('Missing idle poll samples');
  const sorted = data.switches.map(sample => sample.us / 1000).sort((a, b) => a - b);
  const p95Ms = sorted[Math.ceil(sorted.length * 0.95) - 1];
  const idleMaxMs = Math.max(...data.idleUs) / 1000;
  return { p95Ms, maxMs: sorted.at(-1), idleMaxMs, idleShell: data.idleShell, switches: sorted.length, idlePolls: data.idleUs.length, pass: p95Ms <= 100 && idleMaxMs <= 5 };
}

export function instrument(root) {
  const file = path.join(root, 'src/main.zig');
  let source = fs.readFileSync(file, 'utf8');
  if (source.includes('chat-idle-poll: us=')) return;
  const needle = '                    chatFileOnReady();';
  if (!source.includes(needle)) throw new Error('Unknown idle-poll timing boundary');
  source = source.replace(needle, `                    const poll_revision = app_state.g_chat_last_hash;
                    var poll_started: i64 = 0;
                    if (app_state.g_chat_active and !app_state.g_chat_screen_working and !app_state.g_voice_mode_active and @import("diagnostics.zig").verboseLoggingEnabled()) _ = @import("win32.zig").QueryPerformanceCounter(&poll_started);
                    defer {
                        if (poll_started != 0 and poll_revision == app_state.g_chat_last_hash) {
                            var now: i64 = 0;
                            var frequency: i64 = 1;
                            _ = @import("win32.zig").QueryPerformanceCounter(&now);
                            _ = @import("win32.zig").QueryPerformanceFrequency(&frequency);
                            var buf: [80]u8 = undefined;
                            debugLog(std.fmt.bufPrint(&buf, "chat-idle-poll: us={d}", .{@divTrunc((now -| poll_started) * 1_000_000, @max(1, frequency))}) catch "chat-idle-poll: timing error");
                        }
                    }
` + needle);
  fs.writeFileSync(file, source);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [command, ...files] = process.argv.slice(2);
  if (command === 'instrument' && files.length === 1) instrument(files[0]);
  else if (command === 'report' && files.length === 2) {
    const rows = files.map(file => ({ revision: JSON.parse(fs.readFileSync(file)).revision, ...assess(JSON.parse(fs.readFileSync(file))) }));
    const report = ['## Session speed', '', '| Build | Switch p95 | Slowest switch | Idle poll max | Samples |', '| --- | ---: | ---: | ---: | ---: |', ...rows.map(row => `| ${row.revision} | ${row.p95Ms.toFixed(3)} ms | ${row.maxMs.toFixed(3)} ms | ${row.idleMaxMs.toFixed(3)} ms | ${row.switches} switches / ${row.idlePolls} idle polls (session ${row.idleShell}) |`), '', 'Limits: switch p95 ≤100 ms; every observed idle poll ≤5 ms. Ten sessions, one 250 MiB transcript. Idle polls use an already loaded conversation after the switching cycle, not an ongoing history backfill. Diagnostic dispatch timing, with matching painted content; not input-to-pixel latency. Baseline receives identical idle-only diagnostic instrumentation. One run per build; no speedup claim.'].join('\n');
    console.log(report);
    if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + '\n');
    fs.writeFileSync(path.join(path.dirname(files[1]), 'verdict.json'), JSON.stringify(rows, null, 2));
    if (!rows[1].pass) process.exitCode = 1;
  } else throw new Error('usage: switch-performance.mjs instrument ROOT | report BASE.json HEAD.json');
}
