const fs = require('node:fs');

function openingPosition(trace, shell, observedMs) {
  if (!(observedMs >= 1000)) throw new Error('Chat opening was not observed for a full second after first paint');
  const shown = new RegExp(`\\[switch\\] chat content shown shell=${shell} blocks=\\d+ ms=(\\d+)`).exec(trace);
  if (!shown) throw new Error('Chat opening never painted its target content');
  const start = Number(shown[1]);
  const samples = [...trace.matchAll(/\[chat\] position ms=(\d+) shell=(\d+) first=(\d+) message=(\d+) offset=(\d+) y=(-?\d+) scroll=(-?\d+) height=(\d+) pad=(\d+)/g)]
    .map(match => ({ ms: Number(match[1]), shell: Number(match[2]), first: Number(match[3]), message: match[4], offset: match[5], y: Number(match[6]), scroll: Number(match[7]), height: Number(match[8]), pad: Number(match[9]) }))
    .filter(sample => sample.shell === Number(shell) && sample.ms >= start && sample.ms <= start + 1000);
  if (!samples.length) throw new Error('Chat opening has no visible-row paint samples');
  const first = samples[0];
  if (first.ms > start + 50) throw new Error('Chat opening is missing its first painted row');
  const moved = samples.filter(sample => sample.message !== first.message || sample.offset !== first.offset || sample.y !== first.y);
  return { status: moved.length ? 'failed' : 'passed', window_ms: 1000, first_paint_ms: start, samples, moved };
}

module.exports = { openingPosition };

if (require.main === module) {
  const [, , input, shell, observedMs, output] = process.argv;
  const result = openingPosition(fs.readFileSync(input, 'utf8'), shell, Number(observedMs));
  fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
  if (result.status !== 'passed') {
    console.error('Chat messages moved during the first second after opening');
    process.exitCode = 1;
  }
}
