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
      assert.match(inputs, /allowed_bots: "software-factory-runners\[bot\]"/);
      assert.doesNotMatch(inputs, /allowed_bots:\s*["']?\*/);
      assert.match(inputs, /claude_code_oauth_token:/);
    }
  });
}
