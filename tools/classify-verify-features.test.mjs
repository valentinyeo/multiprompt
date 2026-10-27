import assert from 'node:assert/strict';
import test from 'node:test';
import { featuresForPaths, selection } from './classify-verify-features.mjs';

test('shared files select no desktop journey', () => {
  assert.deepEqual(featuresForPaths([
    'src/main.zig', 'src/sidebar.zig', 'src/chat_render.zig', 'build.zig',
    '.github/workflows/verify.yml', '.claude/skills/verify-multiprompt/control.ps1', 'README.md',
  ]), []);
  assert.equal(selection(['src/main.zig']).appearance, false);
});

test('a changed feature file selects only that journey, once, in path order', () => {
  assert.deepEqual(featuresForPaths(['src/themes.zig']), ['appearance']);
  assert.equal(selection(['src/themes.zig', 'src/startup.zig']).appearance, true);
  assert.deepEqual(featuresForPaths(['src/chat_view.zig', 'src/themes.zig', 'src/themes.zig']), ['chat-view', 'appearance']);
  assert.deepEqual(featuresForPaths(['tools/fixtures/IGSH-812/clip.wav']), ['chat-dictation']);
  assert.deepEqual(featuresForPaths(['src/launch_cache.zig']), ['session-restore']);
  assert.deepEqual(featuresForPaths(['.claude/skills/verify-multiprompt/features/chat-focus.md']), ['chat-focus']);
  assert.deepEqual(featuresForPaths(['.claude/skills/verify-multiprompt/features/README.md']), []);
  assert.deepEqual(featuresForPaths([
    'tools/browser-switch-speed.test.js', 'src/chat_switch.zig', 'tools/verify-chat-delivery/drive.ps1',
    'src/chat_history.zig', 'src/window_frame.zig', 'src/browser_corners.zig',
  ]), []);
  assert.deepEqual(featuresForPaths([]), []);
});
