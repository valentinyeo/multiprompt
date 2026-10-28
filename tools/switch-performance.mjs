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
  if (!Array.isArray(data.idleUs) || data.idleUs.length < 50 || data.idleUs.some(us => !Number.isFinite(us) || us < 0)) throw new Error('Missing idle poll samples');
  const sorted = data.switches.map(sample => sample.us / 1000).sort((a, b) => a - b);
  const p95Ms = sorted[Math.ceil(sorted.length * 0.95) - 1];
  const idle = data.idleUs.map(us => us / 1000).sort((a, b) => a - b);
  const middle = Math.floor(idle.length / 2);
  const idleMedianMs = idle.length % 2 ? idle[middle] : (idle[middle - 1] + idle[middle]) / 2;
  const idleMaxMs = idle.at(-1);
  return { p95Ms, maxMs: sorted.at(-1), idleMedianMs, idleMaxMs, idleShell: data.idleShell, switches: sorted.length, idlePolls: data.idleUs.length, pass: p95Ms <= 100 && idleMedianMs <= 5 };
}

export function assessRepeated(pairs) {
  if (!Array.isArray(pairs) || pairs.length !== 5) throw new Error('Expected five alternating pairs');
  const hashes = { base: pairs[0]?.base?.sha256, head: pairs[0]?.head?.sha256 };
  if (Object.values(hashes).some(sha => typeof sha !== 'string' || !/^[a-f0-9]{64}$/i.test(sha))) throw new Error('Missing executable hash');
  return pairs.map(({ base, head }) => {
    for (const [sample, side] of [[base, 'base'], [head, 'head']]) {
      if (sample.sha256 !== hashes[side] || sample.observerPollMs !== 750 || !Number.isFinite(sample.observerIdleCpuMs) || sample.observerIdleCpuMs < 0 || !Number.isFinite(sample.appIdleCpuMs) || sample.appIdleCpuMs < 0 || !Number.isFinite(sample.idleWallMs) || sample.idleWallMs <= 0) throw new Error('Invalid alternating-build accounting');
    }
    if (!Number.isInteger(head.idleStatusReads) || head.idleStatusReads < 49) throw new Error("Missing live status acquisition during idle polls");
    const baseline = assess(base);
    const candidate = assess(head);
    if (!candidate.pass) throw new Error('A candidate run exceeded unchanged session speed limits');
    return { baseline, candidate, observerCpuMs: { baseline: base.observerIdleCpuMs, candidate: head.observerIdleCpuMs }, appCpuMs: { baseline: base.appIdleCpuMs, candidate: head.appIdleCpuMs } };
  });
}

export function instrument(root, profile = false) {
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
  if (profile) {
    const calls = ['chatFileOnReady();', 'refreshChatTranscript(false);', 'if (app_state.g_chat_active) chatWorkingIndicatorSync();', '@import("chat_composer.zig").chatStopSlotSync();', 'voiceCheckScreenFallback();'];
    const start = source.indexOf('if (wp == TIMER_CHAT_REFRESH)');
    const end = source.indexOf('if (wp == TIMER_CHAT_FOREGROUND_RETRY)', start);
    let poll = source.slice(start, end);
    poll = poll.replace('var poll_started: i64 = 0;', 'var poll_started: i64 = 0;\n                    var poll_stages: [5]i64 = @splat(0);');
    for (const [index, call] of calls.entries()) poll = poll.replace(call, call + `\n                    if (poll_started != 0) _ = @import("win32.zig").QueryPerformanceCounter(&poll_stages[${index}]);`);
    poll = poll.replace('var buf: [80]u8 = undefined;', 'var buf: [256]u8 = undefined;');
    poll = poll.replace('chat-idle-poll: us={d}', 'chat-idle-poll: us={d} ready_us={d} transcript_us={d} working_us={d} composer_us={d} voice_us={d}');
    const times = calls.map((_, index) => `@divTrunc((poll_stages[${index}] -| ${index ? `poll_stages[${index - 1}]` : 'poll_started'}) * 1_000_000, @max(1, frequency))`);
    poll = poll.replace('.{@divTrunc((now -| poll_started) * 1_000_000, @max(1, frequency))}', `.{@divTrunc((now -| poll_started) * 1_000_000, @max(1, frequency)), ${times.join(', ')}}`);
    source = source.slice(0, start) + poll + source.slice(end);
    const stages = [
      ['chat_render.zig', 'chatPaintTranscriptContent', 'paint'],
      ['chat_render.zig', 'chatRelayout', 'layout'],
      ['dwrite_text.zig', 'draw', 'text'],
      ['diagnostics.zig', 'debugLog', 'logging'],
      ['session.zig', 'saveSession', 'save'],
    ];
    for (const [name, fn, stage] of stages) {
      const file = path.join(root, 'src', name);
      let body = fs.readFileSync(file, 'utf8');
      const signature = new RegExp(`(fn ${fn}\\([^\\n]+\\{)`);
      if (!signature.test(body)) throw new Error(`Unknown CPU profile boundary: ${name}:${fn}`);
      body = body.replace(signature, `$1\n    const cpu_profile_start = @import("switch_cpu_profile.zig").start();\n    defer @import("switch_cpu_profile.zig").end(.${stage}, cpu_profile_start);`);
      fs.writeFileSync(file, body);
    }
    fs.writeFileSync(path.join(root, 'src/switch_cpu_profile.zig'), `
const std = @import("std");
const win = @import("win32.zig");
extern "kernel32" fn QueryThreadCycleTime(win.HANDLE, *u64) callconv(win.WINAPI) win.BOOL;
const Stage = enum { paint, layout, text, logging, save };
threadlocal var cycles: [5]u64 = @splat(0);
pub fn start() u64 {
    var value: u64 = 0;
    _ = QueryThreadCycleTime(@ptrFromInt(std.math.maxInt(usize) - 1), &value);
    return value;
}
pub fn end(stage: Stage, before: u64) void { cycles[@intFromEnum(stage)] += start() -| before; }
pub fn report() void {
    const measured = cycles;
    cycles = @splat(0);
    var message: [256]u8 = undefined;
    @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&message, "UI-CYCLES paint={d} layout={d} text={d} logging={d} save={d}", .{ measured[0], measured[1], measured[2], measured[3], measured[4] }) catch return);
}
`);
    source = source.replace('chat-idle-poll: us={d} ready_us=', 'chat-idle-poll: us={d} ready_us=');
    source = source.replace('                    const poll_revision =', '                    defer @import("switch_cpu_profile.zig").report();\n                    const poll_revision =');
    const captureFile = path.join(root, 'src/chat_capture.zig');
    let capture = fs.readFileSync(captureFile, 'utf8');
    const boundary = '    _ = FreeConsole();';
    const from = capture.indexOf('pub fn captureChatTranscript(');
    let body = capture.slice(from);
    body = body.replace(boundary, `    var profile_start: i64 = 0;
    var profile_attach: i64 = 0;
    var profile_read: i64 = 0;
    _ = @import("win32.zig").QueryPerformanceCounter(&profile_start);
    defer {
        var end: i64 = 0;
        var frequency: i64 = 1;
        _ = @import("win32.zig").QueryPerformanceCounter(&end);
        _ = @import("win32.zig").QueryPerformanceFrequency(&frequency);
        var message: [200]u8 = undefined;
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&message, "idle-capture: attach_us={d} read_us={d} parse_us={d}", .{
            @divTrunc((profile_attach -| profile_start) * 1_000_000, @max(1, frequency)),
            @divTrunc((profile_read -| profile_attach) * 1_000_000, @max(1, frequency)),
            @divTrunc((end -| profile_read) * 1_000_000, @max(1, frequency)),
        }) catch "idle-capture: error");
    }
` + boundary);
    body = body.replace('    defer _ = FreeConsole();', '    defer _ = FreeConsole();\n    _ = @import("win32.zig").QueryPerformanceCounter(&profile_attach);');
    body = body.replace('    chatCaptureStatus(shell_index, width, chars_read, rows);', '    _ = @import("win32.zig").QueryPerformanceCounter(&profile_read);\n    chatCaptureStatus(shell_index, width, chars_read, rows);');
    fs.writeFileSync(captureFile, capture.slice(0, from) + body);
  }
  fs.writeFileSync(file, source);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [command, ...files] = process.argv.slice(2);
  if (command === 'instrument' && (files.length === 1 || (files.length === 2 && files[1] === '--profile'))) instrument(files[0], files[1] === '--profile');
  else if (command === 'repeated' && files.length === 1) {
    const pairs = Array.from({ length: 5 }, (_, index) => Object.fromEntries(['base', 'head'].map(side => [side, JSON.parse(fs.readFileSync(path.join(files[0], `run-${index + 1}`, side, 'samples.json'), 'utf8').replace(/^\uFEFF/, ''))])));
    const rows = assessRepeated(pairs);
    fs.writeFileSync(path.join(files[0], 'repeated-verdict.json'), JSON.stringify(rows, null, 2));
    console.log('REPEATED_IDLE_VERIFIED', JSON.stringify(rows));
  } else if (command === 'report' && files.length === 2) {
    const rows = files.map(file => ({ revision: JSON.parse(fs.readFileSync(file)).revision, ...assess(JSON.parse(fs.readFileSync(file))) }));
    const report = ['## Session speed', '', '| Build | Switch p95 | Slowest switch | Idle poll median | Idle poll max | Samples |', '| --- | ---: | ---: | ---: | ---: | ---: |', ...rows.map(row => `| ${row.revision} | ${row.p95Ms.toFixed(3)} ms | ${row.maxMs.toFixed(3)} ms | ${row.idleMedianMs.toFixed(3)} ms | ${row.idleMaxMs.toFixed(3)} ms | ${row.switches} switches / ${row.idlePolls} idle polls (session ${row.idleShell}) |`), '', 'Limits: switch p95 ≤100 ms; settled idle poll median ≤5 ms. Ten sessions, one 250 MiB transcript. Ten warmup idle polls are discarded before sampling an already loaded conversation after the switching cycle, not an ongoing history backfill. Diagnostic dispatch timing, with matching painted content; not input-to-pixel latency. Baseline receives identical idle-only diagnostic instrumentation. One run per build; no speedup claim.'].join('\n');
    console.log(report);
    if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + '\n');
    fs.writeFileSync(path.join(path.dirname(files[1]), 'verdict.json'), JSON.stringify(rows, null, 2));
    if (!rows[1].pass) process.exitCode = 1;
  } else throw new Error('usage: switch-performance.mjs instrument ROOT | report BASE.json HEAD.json');
}
