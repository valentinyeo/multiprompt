const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('Resync retires cached generation without touching draft or delivery, and evidence rejects broken repair', async () => {
  const source = read('src/chat_session.zig');
  const match = source.match(/pub fn chatResync\(\) void \{[^]*?\n\}/);
  assert.ok(match, 'Existing chat menu needs a non-destructive Resync action');
  const body = match[0].replace('pub fn', 'fn').replaceAll('app_state.', '');
  assert.doesNotMatch(body, /chatResetForShell|sendChat|chatOutbox|SetWindowText|DeleteFile/);
  assert.match(source, /entry\.resync and !disk and !history\.more/);
  assert.match(source, /else if \(!has_messages\) entry.history.start else 0/);
  assert.match(source, /showHeaderNoticeAscii\("Chat resynced"/);
  assert.match(read('src/more_menu.zig'), /\.resync => "Resync chat"/);
  assert.match(read('src/main.zig'), /Item\.resync\) => @import\("chat_session.zig"\)\.chatResync\(\)/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-resync-'));
  try {
    fs.writeFileSync(path.join(dir, 'proof.zig'), String.raw`
const std = @import("std");
const Key = struct { shell_id: u32 = 42 };
const Entry = struct { key: Key = .{}, cache_cancelled: std.atomic.Value(bool) = .init(false), disk_loaded: bool = false, resync: bool = false };
var old: Entry = .{};
var replacement: Entry = .{};
var entries = [_]*Entry{&old};
var g_chat_histories = struct { items: []*Entry }{ .items = &entries };
var active_shell: u32 = 0;
var shell_count: u32 = 1;
var owns = true;
var allocate = true;
var requests: usize = 0;
var forgotten: usize = 0;
var notices: usize = 0;
var draft: [5]u8 = "draft".*;
var outbox: [4]u8 = "sent".*;
var g_chat_cache_write_mutex = struct {
    held: bool = false,
    fn tryLock(self: *@This()) bool { std.debug.assert(!self.held); self.held = true; return true; }
    fn unlock(self: *@This()) void { std.debug.assert(self.held); self.held = false; }
}{};
fn Sleep(_: u32) void { unreachable; }
fn chatViewOwnsInput() bool { return owns; }
fn chatFileIdentity() Key { return .{}; }
fn chatHistoryForget(id: u32) void {
    std.debug.assert(g_chat_cache_write_mutex.held and id == 42 and old.cache_cancelled.load(.acquire));
    forgotten += 1;
}
fn chatHistoryEntry(_: Key) ?*Entry { return if (allocate) &replacement else null; }
fn chatFileRequest(_: Key) void {
    std.debug.assert(!g_chat_cache_write_mutex.held and replacement.disk_loaded and replacement.resync);
    requests += 1;
}
fn debugLog(_: []const u8) void { notices += 1; }
` + body + String.raw`
test "fresh source without stale disk, unchanged draft and outbox, guarded invalid states" {
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expectEqual(@as(usize, 1), forgotten);
    try std.testing.expectEqualStrings("draft", &draft);
    try std.testing.expectEqualStrings("sent", &outbox);
    owns = false;
    chatResync();
    owns = true;
    active_shell = 1;
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    active_shell = 0;
    allocate = false;
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expect(!g_chat_cache_write_mutex.held);
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'proof.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  const { verifyObserved } = await import('./chat-resync-proof.mjs');
  const value = {error: null, draftBefore: 'draft stays here', draftAfter: 'draft stays here', waitingBefore: 'queued:stale waiting message', waitingAfter: '', copied: 'After  resync', sendStart: 10, sendEnd: 20};
  const rewrite = {before: 'Before resync', after: 'After  resync', bytes: 13};
  const log = '[chat] resync requested\n[chat] resync completed';
  assert.equal(verifyObserved(value, [], rewrite, log), true);
  assert.throws(() => verifyObserved({...value, draftAfter: ''}, [], rewrite, log), /draft preserved/);
  assert.throws(() => verifyObserved({...value, waitingAfter: value.waitingBefore}, [], rewrite, log), /waiting label repaired/);
  assert.throws(() => verifyObserved(value, [{ms: 15, argv: ['send-keys', 'Enter']}], rewrite, log), /no message transport/);
  assert.throws(() => verifyObserved(value, [], rewrite, ''), /source reload completed/);
});

test('recovery oracle rejects missing claims and duplicate input', async () => {
  const { verifyRecovery } = await import('./chat-resync-proof.mjs');
  const texts = ['RECOVERY_HEAD_'.padEnd(200, 'h') + ' ', 'PENDING_ONE', 'PENDING_TWO', 'ACCEPTED_FOURTH'];
  const keys = ['desktop-101', 'desktop-102', 'desktop-103', 'desktop-104'];
  const rows = keys.map((key, i) => ({key, sid:'sid', text:texts[i], state:i ? 'queued' : 'submitted', scan:100, origin:100, source_inode:7, created:i + 1, recovery_scan:100}));
  const before = {sid:'sid', inode:7, source_bytes:100, schema_version:2, screen:'esc to interrupt unsent terminal draft', rows, claims:[]};
  const event = {inode:7, origin:100, eof:600000,
    legacy_rows:rows.map(r => [r.key,r.sid,r.text,r.state,r.scan,r.origin,r.source_inode,r.created,null]),
    appended_rows:rows.map(r => [r.key,r.sid,r.text,r.state,600000,r.origin,r.source_inode,r.created,null])};
  const after = structuredClone(before);
  after.source_bytes = 600000;
  after.rows[0].state = after.rows[3].state = 'delivered';
  after.claims = ['desktop-101','desktop-104'].map((key, i) => ({key,sid:'sid',inode:7,offset:100+i,digest:'a'.repeat(64)}));
  const observation = {error:null,headUnconfirmedBefore:true,renderedBefore:'',draftBefore:'draft stays here',draftAfter:'draft stays here',draftRepeat:'draft stays here',sendStart:1,sendEnd:10,renderedAfter:'RECOVERY_HEAD_'.padEnd(200, 'h') + ' ACCEPTED_FOURTH',renderedRepeat:'RECOVERY_HEAD_'.padEnd(200, 'h') + ' ACCEPTED_FOURTH',queueBefore:'queued:PENDING_ONE|queued:PENDING_TWO|queued:ACCEPTED_FOURTH',queueAfter:'queued:PENDING_ONE|queued:PENDING_TWO',queueRepeat:'queued:PENDING_ONE|queued:PENDING_TWO'};
  const boots = [{full_sha256:'27e681fab0bbebf4620f0ff47c66d1fcc4442152fb1c7046eac376726a2672d0',inner_sha256:'458a0cb74a3500963f4a50e5ee01d25422f860b76ee4507a56f1aab13e0abaee',generation:3}];
  const logical = ['recovery-head','pending-one','pending-two','accepted-fourth'];
  const mapping = keys.map((server,i) => ({logical:logical[i],server,qid:0x101+i,text:texts[i]}));
  const entries = mapping.map(row => ({t:row.text,s:3,x:1,held:1,w:100,d:600100,qid:row.qid}));
  const box = messages => ({version:2,queues:[{key:'tmux:0:verify-agent',messages}]});
  const clients = {before:box(entries),after:box(entries.slice(1,3)),repeat:box(entries.slice(1,3))};
  assert.equal(verifyRecovery(before,event,after,structuredClone(after),observation,[],boots,mapping,clients), true);
  assert.throws(() => verifyRecovery(before,event,after,after,{...observation,headUnconfirmedBefore:false},[],boots,mapping,clients), /pending desktop head/);
  const broken = structuredClone(after); broken.claims.pop();
  assert.throws(() => verifyRecovery(before,event,broken,broken,observation,[],boots,mapping,clients));
  assert.throws(() => verifyRecovery(before,event,after,after,observation,[{ms:5}],boots,mapping,clients));
  const wrong = structuredClone(event); wrong.appended_rows[3][8] = 100;
  assert.throws(() => verifyRecovery(before,wrong,after,after,observation,[],boots,mapping,clients));
  const missing = structuredClone(clients); missing.before.queues[0].messages.shift();
  assert.throws(() => verifyRecovery(before,event,after,after,observation,[],boots,mapping,missing), /initial identities/);
  const retained = structuredClone(clients); retained.after.queues[0].messages.push(entries[3]);
  assert.throws(() => verifyRecovery(before,event,after,after,observation,[],boots,mapping,retained), /accepted echoes/);
  const lost = structuredClone(clients); lost.repeat.queues[0].messages.pop();
  assert.throws(() => verifyRecovery(before,event,after,after,observation,[],boots,mapping,lost), /pending must survive/);
  const badMap = structuredClone(mapping); badMap[0].qid = 0x102;
  assert.throws(() => verifyRecovery(before,event,after,after,observation,[],boots,badMap,clients), /identity mapping/);
});


test('recovery oracle enforces declared plan selection', async () => {
  const { verifyRecoveryPlan } = await import('./chat-resync-proof.mjs');
  const plan = {recovery_required:true,cases:['resync','resync-recovery'],app:{version:'0.28.1042',sha256:'hash'},harness:{source:'revision'}};
  assert.equal(verifyRecoveryPlan(plan), true);
  assert.equal(verifyRecoveryPlan({...plan,recovery_required:false,cases:['resync'],app:{...plan.app,version:'0.28.1043'}}), false);
  assert.throws(() => verifyRecoveryPlan({...plan,cases:['resync']}), /case mismatch/);
  assert.throws(() => verifyRecoveryPlan({...plan,recovery_required:false}), /case mismatch/);
});
