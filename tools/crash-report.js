#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const { spawnSync } = require('node:child_process');

function parseCrashReport(text) {
  const out = { fields: {}, stackRvas: [], logTail: '' };
  const lines = text.split(/\r?\n/);
  let section = '';
  for (const line of lines) {
    if (section === 'stack') {
      const m = /^\s+0x([0-9A-Fa-f]+)\s*$/.exec(line);
      if (m) {
        out.stackRvas.push(parseInt(m[1], 16));
        continue;
      }
      section = '';
    }
    if (section === 'log') {
      out.logTail += line + '\n';
      continue;
    }
    if (line.startsWith('stack_rvas')) {
      section = 'stack';
      continue;
    }
    if (line.startsWith('debug_log_tail')) {
      section = line.includes('debug log off') ? '' : 'log';
      out.fields.debug_log_tail = line.includes('debug log off') ? 'off' : 'on';
      continue;
    }
    const kv = /^([a-z_]+): (.*)$/.exec(line);
    if (kv) out.fields[kv[1]] = kv[2];
  }
  const off = /^0x([0-9A-Fa-f]+)/.exec(out.fields.exe_offset || '');
  out.exeOffset = off ? parseInt(off[1], 16) : null;
  return out;
}

function symbolizerArgs(exePath, offsets) {
  return [
    '--use-native-pdb-reader',
    '--relative-address',
    '--functions=linkage',
    '--demangle',
    `--obj=${exePath}`,
    ...offsets.map((o) => '0x' + o.toString(16)),
  ];
}

function parseSymbolizerOutput(stdout, count) {
  const blocks = stdout.split(/\r?\n\r?\n/).filter((b) => b.trim().length > 0);
  const result = [];
  for (let i = 0; i < count; i++) {
    const lines = (blocks[i] || '').split(/\r?\n/).filter(Boolean);
    result.push({ fn: lines[0] || '??', where: lines[1] || '' });
  }
  return result;
}

function windowsHelp(offsets) {
  return [
    'To resolve these on Windows without llvm-symbolizer:',
    '  1. Open multiprompt.exe (the build named in "version") in WinDbg with its multiprompt.pdb on the symbol path.',
    '  2. Run:  ln multiprompt+0x' + (offsets[0] || 0).toString(16),
    '  or with the LLVM tools:  llvm-symbolizer --use-native-pdb-reader --relative-address --obj=multiprompt.exe 0x' +
      (offsets[0] || 0).toString(16),
    'The .dmp next to the report opens in WinDbg or Visual Studio and shows the full stack.',
  ].join('\n');
}

function main(argv) {
  const args = argv.slice(2);
  let file = null;
  let exe = null;
  let symbolizer = 'llvm-symbolizer';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--exe') exe = args[++i];
    else if (args[i] === '--pdb') exe = exe || args[++i].replace(/\.pdb$/i, '.exe');
    else if (args[i] === '--symbolizer') symbolizer = args[++i];
    else file = args[i];
  }
  if (!file) {
    console.error('usage: node tools/crash-report.js <crash.txt> [--exe multiprompt.exe] [--symbolizer llvm-symbolizer]');
    return 2;
  }
  const report = parseCrashReport(fs.readFileSync(file, 'utf8'));
  const f = report.fields;
  console.log(`version ${f.version} (${f.build}) at ${f.time}`);
  console.log(`${f.exception_code} at ${f.module}+${f.module_offset}; tabs ${f.tabs}; chat view ${f.chat_view}`);
  const offsets = [];
  if (report.exeOffset !== null) offsets.push(report.exeOffset);
  offsets.push(...report.stackRvas);
  if (offsets.length === 0) {
    console.log('No exe offset in this report (the crash was outside multiprompt.exe).');
    return 0;
  }
  if (!exe) {
    console.log('Offsets: ' + offsets.map((o) => '0x' + o.toString(16)).join(' '));
    console.log(windowsHelp(offsets));
    return 0;
  }
  const run = spawnSync(symbolizer, symbolizerArgs(exe, offsets), { encoding: 'utf8' });
  if (run.error || run.status !== 0) {
    console.log(`Could not run ${symbolizer}: ${run.error ? run.error.message : run.stderr}`);
    console.log(windowsHelp(offsets));
    return 1;
  }
  const names = parseSymbolizerOutput(run.stdout, offsets.length);
  names.forEach((n, i) => {
    const label = i === 0 && report.exeOffset !== null ? 'crash  ' : 'stack  ';
    console.log(`${label} 0x${offsets[i].toString(16)}  ${n.fn}  ${n.where}`);
  });
  return 0;
}

module.exports = { parseCrashReport, symbolizerArgs, parseSymbolizerOutput };

if (require.main === module) process.exitCode = main(process.argv);
