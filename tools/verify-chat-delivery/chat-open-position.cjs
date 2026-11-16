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

function steadyPosition(trace, start, end) {
  if (end - start < 3500) throw new Error('Steady chat needs a multi-second observation');
  const samples = [...trace.matchAll(/\[chat\] position ms=(\d+) shell=(\d+) first=(\d+) message=(\d+) offset=(\d+) y=(-?\d+) scroll=(-?\d+) height=(\d+) pad=(\d+) opening=(\d+) paints=(\d+) layouts=(\d+) tick=(\d+)/g)]
    .map(match => ({ shell: Number(match[2]), first: Number(match[3]), message: match[4], offset: match[5], y: Number(match[6]), scroll: Number(match[7]), height: Number(match[8]), paints: Number(match[11]), layouts: Number(match[12]), tick: Number(match[13]) }))
    .filter(sample => sample.tick >= start && sample.tick <= end);
  if (samples.length < 2 || samples.at(-1).tick - samples[0].tick < 2000) throw new Error('Steady chat is missing multi-second position and paint samples');
  const first = samples[0];
  const last = samples.at(-1);
  const moved = samples.filter(sample => sample.shell !== first.shell || sample.message !== first.message || sample.offset !== first.offset || sample.y !== first.y);
  return { status: moved.length ? 'failed' : 'passed', window_ms: end - start, sampled_ms: last.tick - first.tick, paints: last.paints - first.paints, layouts: last.layouts - first.layouts, samples, moved };
}

module.exports = { openingPosition, steadyPosition };

if (require.main === module) {
  const args = process.argv.slice(2);
  const steady = args[0] === '--steady';
  if (steady) args.shift();
  const [input, shell, observedMs, output] = args;
  const trace = fs.readFileSync(input, 'utf8');
  const result = steady ? steadyPosition(trace, Number(shell), Number(observedMs)) : openingPosition(trace, shell, Number(observedMs));
  fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
  if (result.status !== 'passed') {
    console.error(steady ? 'Chat messages moved during the steady observation' : 'Chat messages moved during the first second after opening');
    process.exitCode = 1;
  }
}
