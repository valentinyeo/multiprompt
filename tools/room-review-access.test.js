const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

for (const name of ['pr-verifier.yml', 'chat-still.yml', 'verify-skill-eval.yml']) {
  test(`${name} lets the observed worker bot run reviews without allowing arbitrary bots`, () => {
    const source = fs.readFileSync(`.github/workflows/${name}`, 'utf8');
    const actions = source.split(/uses: anthropics\/claude-code-action@/).slice(1);
    assert.ok(actions.length > 0);
    for (const action of actions) {
      const inputs = action.slice(0, action.indexOf('          prompt:'));
      const allowed = inputs.match(/allowed_bots:\s*([^\n]+)/)?.[1];
      assert.ok(allowed, 'the observed worker bot needs explicit review access');
      const bots = allowed.replace(/["']/g, '').split(',').map(bot => bot.trim().replace(/\[bot\]$/, ''));
      assert.ok(bots.includes('software-factory-runners'));
      assert.ok(bots.every(bot => ['software-factory-runners', 'hypertask-runners'].includes(bot)));
      assert.match(inputs, /claude_code_oauth_token:/);
    }
  });
}
