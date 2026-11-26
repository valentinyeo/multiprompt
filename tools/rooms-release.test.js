const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('a release build compiles Rooms in and a non-release build can leave them out', () => {
  const build = read('build.zig');
  assert.doesNotMatch(build, /Rooms preview cannot be included in a release/);
  assert.match(
    build,
    /const rooms_preview_flag = b\.option\(bool, "rooms-preview", "Compile the desktop Rooms integration"\);\s*const release = b\.option\(bool, "release", "Build a publishable release with a configured signing public key"\) orelse false;\s*const rooms_preview = rooms_preview_flag orelse release;/
  );
  assert.match(read('src/main.zig'), /pub const ROOMS_PREVIEW = if \(@hasDecl\(build_config, "rooms_preview"\)\) build_config\.rooms_preview else false;/);
  const release = read('.github/workflows/release.yml');
  assert.match(release, /-Drelease=\$\{\{ github\.event_name != 'pull_request' \}\}/);
  assert.doesNotMatch(release, /-Drooms-preview=false/);
  const tests = read('.github/workflows/test.yml');
  assert.match(tests, /zig build -Dtarget=x86_64-windows-gnu -Drelease=true --summary all/);
  assert.match(tests, /zig build -Dtarget=aarch64-windows-gnu --summary all/);
  assert.match(read('.github/workflows/verify.yml'), /zig build -Drelease=false [^\n]*-Dcpu=x86_64_v3 -Dtarget=x86_64-windows-gnu/);
});

test('Rooms keep a shortcut, a Ctrl+K row, and a shortcut-list row', () => {
  const shortcuts = read('src/shortcuts.zig');
  assert.match(shortcuts, /\.a = "Ctrl\+Shift\+N", \.b = "Create a Room"/);
  assert.match(shortcuts, /\.a = "Ctrl\+K -> New room", \.b = "Create a Room"/);
  assert.match(shortcuts, /if \(shift and kb\.vkCode == 0x4E\) \{\s*if \(@import\("room_frontend\.zig"\)\.enabled\)/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /if \(room\.enabled\)/);
  assert.match(palette, /room\.new_room_target/);
  const doc = read('openwiki/operations/keyboard-shortcuts.md');
  assert.match(doc, /Ctrl\+Shift\+N/);
  assert.match(doc, /Create a Room/);
  assert.match(doc, /Ctrl\+K -&gt; New room/);
});

test('compiled-in Rooms do not arm a timer with no account', () => {
  const front = read('src/room_frontend.zig');
  const startup = front.slice(front.indexOf('pub fn startupSettled()'), front.indexOf('pub fn accountReady()'));
  assert.doesNotMatch(startup, /SetTimer/);
  const ready = front.slice(front.indexOf('fn accountReadyInternal()'), front.indexOf('pub fn applyAccountLayout('));
  const timer = ready.indexOf('SetTimer');
  const account = ready.indexOf('account_len != 0');
  assert.ok(account >= 0 && timer > account, 'the only startup timer follows a real account');
  assert.match(ready, /if \(!ui_ready\) return;/);
  const registry = JSON.parse(read('tools/idle-registry.json')).timers;
  for (const name of ['TIMER_ROOM', 'TIMER_ROOM_UI', 'TIMER_ROOM_EVIDENCE', 'TIMER_ROOM_DISCOVERY', 'TIMER_ROOM_REPLIES']) {
    assert.equal(registry[name].kind, 'event', name);
    assert.equal(registry[name].idle_max_per_min, 0, name);
  }
});

test('desktop and Android rooms speak protocol 1', () => {
  const contract = JSON.parse(read('tools/fixtures/IGSH-2315/android-room-handshake.json'));
  assert.deepEqual(contract, {
    room_protocol: 1,
    room_messages: 1,
    room_reply_protocol: 1,
    room_message_protocol: 1,
  });
  assert.match(read('src/room_service.py'), /'room_protocol': 1/);
  assert.match(read('src/room_bridge.py'), /'room_protocol': 1/);
  assert.match(read('src/room_bridge.py'), /result\['room_reply_protocol'\] = 1 if live else None/);
  assert.match(read('src/room_bridge.py'), /request\['room_messages'\] != 1/);
  assert.match(read('src/rooms.zig'), /\.room_messages = 1/);
  assert.match(read('src/chat_history_reader.py'), /ROOM_MESSAGE_PROTOCOL = 1/);
  assert.match(read('src/room_frontend.zig'), /version\.integer != 1/);
  assert.match(read('src/room_frontend.zig'), /reply\.integer == 1/);
  const android = process.env.MULTIPROMPT_ANDROID_ROOT;
  if (!android) return;
  const androidRead = (file) => fs.readFileSync(path.join(android, file), 'utf8');
  const client = androidRead('app/src/main/java/dev/multiprompt/companion/room/RoomClient.kt');
  assert.match(client, /put\("room_messages", 1\)/);
  assert.match(client, /optInt\("room_reply_protocol", 0\) == 1/);
  const bridge = androidRead('app/src/main/assets/rooms/room_bridge.py');
  assert.match(bridge, /'room_protocol': 1/);
  assert.match(bridge, /result\['room_reply_protocol'\] = 1 if live else None/);
  assert.match(bridge, /request\['room_messages'\] != 1/);
  assert.match(androidRead('app/src/main/assets/rooms/room_service.py'), /'room_protocol': 1/);
  assert.match(androidRead('app/src/main/assets/chat_history_reader.py'), /ROOM_MESSAGE_PROTOCOL = 1/);
});
