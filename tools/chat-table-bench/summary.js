const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function summarize(samples) {
  const result = {};
  for (const revision of ['before', 'after']) {
    const values = samples[revision];
    assert.equal(values.length, 7, `${revision} sample count`);
    const ms = values.map((sample, index) => {
      assert.equal(sample.sample, index + 1, `${revision} sample sequence`);
      assert.equal(sample.builds, 2000, `${revision} build count`);
      assert.ok(Number.isSafeInteger(sample.ticks) && sample.ticks > 0, 'positive counter ticks');
      assert.ok(Number.isSafeInteger(sample.frequency) && sample.frequency > 0, 'positive counter frequency');
      return sample.ticks / sample.frequency * 1000 / sample.builds;
    });
    result[revision] = { samples: values, msPerBuild: [...ms].sort((a, b) => a - b)[3] };
  }
  result.ratio = result.after.msPerBuild / result.before.msPerBuild;
  assert.ok(result.ratio <= 0.8, `median improvement must be at least 20%: ratio=${result.ratio}`);
  result.improvedPairs = samples.after.filter((sample, index) => {
    const before = samples.before[index];
    return sample.ticks / sample.frequency <= 0.8 * before.ticks / before.frequency;
  }).length;
  assert.ok(result.improvedPairs >= 6, `at least six of seven paired samples must improve by 20%: ${result.improvedPairs}`);
  return result;
}

module.exports = { summarize };
if (require.main === module) {
  const root = process.argv[2];
  const samples = {};
  for (const revision of ['before', 'after']) {
    samples[revision] = Array.from({ length: 7 }, (_, index) => {
      const log = fs.readFileSync(path.join(root, `${revision}-${index + 1}.log`), 'utf8').replace(/^\uFEFF/, '');
      const matches = [...log.matchAll(/CHAT_TABLE_SAMPLE builds=(\d+) ticks=(\d+) frequency=(\d+)/g)];
      assert.equal(matches.length, 1, `${revision} sample ${index + 1} receipt`);
      return { sample: index + 1, builds: Number(matches[0][1]), ticks: Number(matches[0][2]), frequency: Number(matches[0][3]) };
    });
  }
  const result = summarize(samples);
  fs.writeFileSync(path.join(root, 'summary.json'), JSON.stringify(result, null, 2));
  console.log(`TABLE BUILD COST VERIFIED ${JSON.stringify(result)}`);
}
