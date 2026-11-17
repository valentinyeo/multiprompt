const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');

test('nine user-facing features link to executable journey recipes', () => {
  const directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features');
  const index = fs.readFileSync(path.join(directory, 'README.md'), 'utf8');
  const available = new Set(discoverFeatures(directory).available);
  for (const feature of ['sidebar-sessions', 'chat-and-composer', 'palette', 'browser-pane', 'workspaces-rooms', 'shortcuts', 'settings-appearance', 'notifications-inbox', 'relaunch-update']) {
    assert.ok(index.includes(`](${feature}.md)`), `${feature} is indexed`);
    const text = fs.readFileSync(path.join(directory, `${feature}.md`), 'utf8');
    assert.deepEqual([...text.matchAll(/^## (.+)$/gm)].map(match => match[1]), ['Sub-features', 'How to get to it (user POV)', 'Driving it with drive.ps1', 'Gotchas']);
    assert.ok(text.includes('Preconditions:'));
    const journeys = text.match(/^Journeys: (.+)$/m);
    assert.ok(journeys, `${feature} names its journeys`);
    for (const journey of journeys[1].split(', ')) assert.ok(available.has(journey), `${feature}/${journey} has an executable recipe`);
  }
});
