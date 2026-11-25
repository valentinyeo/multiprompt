const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.argv[2];
const text = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(text(name));

const result = json('result.json');
assert.equal(result.status, 'passed');
assert.equal(result.mode, 'real-pi');
assert.equal(result.cleanup.activeAfterStop, 0);
assert.equal(result.keyRemoved, true);
assert.equal(result.authFilesRemoved, true);
assert.ok(result.marker && /^MUBO523-[0-9A-F]{24}$/.test(result.marker), 'Missing high-entropy marker');
assert.deepEqual(
  result.cases.map(row => [row.name, row.passed]),
  [
    ['auto-switch-off', true],
    ['pi-model-select', true],
    ['pi-marker-reply', true],
    ['pi-valentin-mode', true],
    ['pi-recall-and-history', true],
    ['switch-pi-to-codex', true],
    ['switch-codex-back-to-pi', true],
  ],
);

const authSummary = json('pi-auth-summary.json');
assert.equal(authSummary.ok, true);
assert.equal(authSummary.provider, 'openai-codex');
assert.equal(authSummary.type, 'oauth');
assert.equal(authSummary.account_id_matches_jwt, true);
assert.equal(authSummary.pi_auth_mode, '0o600');

const provenance = json('pi-provenance.json');
assert.equal(provenance.pi_version, '1.5.0');
assert.equal(provenance.vstack_commit, '2af5980314a2b1bfbdb773a3129f5a8772a2b3ad');
assert.match(provenance.valentin_mode_version_line, /^valentin-mode v\d+/);
assert.equal(provenance.pi_models_has_openai_codex_gpt_6_1_sol, true);
assert.ok(provenance.valentin_mode_body_sha256 && provenance.valentin_mode_body_sha256.length === 64);

const finalSnapshot = json('pi-return-server.json');
assert.ok(Array.isArray(finalSnapshot.hosts) && finalSnapshot.hosts.length >= 3);
for (const host of finalSnapshot.hosts) {
  assert.equal(host.has_custom_command, false, `Host ${host.key} used a custom command instead of real binary`);
  assert.equal(host.auto_switch?.on, false, `Host ${host.key} did not retain auto_switch.on=false`);
  assert.deepEqual(host.child_env_leaks, [], `Host ${host.key} leaked secret env vars`);
}

const piHosts = finalSnapshot.hosts.filter(h => h.provider === 'pi');
const codexHosts = finalSnapshot.hosts.filter(h => h.provider === 'codex');
assert.ok(piHosts.length >= 2, 'Expected initial Pi host and returned Pi host');
assert.ok(codexHosts.length >= 1, 'Expected intermediate Codex host');
assert.notEqual(piHosts[0].sid, piHosts[piHosts.length - 1].sid, 'Expected distinct Pi SIDs across roundtrip');

for (const piHost of piHosts) {
  const ack = (piHost.log_events || []).find(
    e => e.event === 'pi_set_model_reply' && e.success === true && e.provider === 'openai-codex' && e.model === 'gpt-6.1-sol',
  );
  assert.ok(ack, `Missing real Pi RPC set_model ack for ${piHost.key}`);
}

const allPiAssistant = finalSnapshot.pi_sessions.flatMap(s => s.messages.filter(m => m.role === 'assistant'));
assert.ok(allPiAssistant.length >= 4, 'Expected at least 4 real Pi assistant replies');
for (const reply of allPiAssistant) {
  assert.equal(reply.provider, 'openai-codex', 'Pi assistant reply did not come from openai-codex');
  assert.equal(reply.model, 'gpt-6.1-sol', 'Pi assistant reply did not come from gpt-6.1-sol');
  assert.equal(reply.stopReason, 'stop', `Pi assistant reply ended with stopReason=${reply.stopReason}`);
}

const skillLoads = finalSnapshot.pi_sessions.flatMap(s => s.skill_loads || []);
assert.ok(
  skillLoads.some(load => load.location.endsWith('/valentin-mode/SKILL.md') && load.body_sha256 === provenance.valentin_mode_body_sha256),
  'Native Pi transcript did not prove real pinned valentin-mode SKILL.md load',
);

assert.ok(result.historyPreservation.storedOrdered === true, 'Stored history order check failed');
assert.ok(result.historyPreservation.visibleOrdered === true, 'Visible copied history order check failed');
assert.equal(typeof result.modelRecall.piTurn3, 'boolean');
assert.equal(typeof result.modelRecall.codexAfterSwitch, 'boolean');
assert.equal(typeof result.modelRecall.piAfterReturn, 'boolean');
assert.ok(Array.isArray(result.unsupportedReturnHops) && result.unsupportedReturnHops.length >= 1);

const copiedFinal = text('pi-return-copied.txt');
assert.ok(copiedFinal.includes(result.marker), 'Final copied history is missing the original marker');
assert.ok(copiedFinal.includes('Switched AI: Pi to Codex'), 'Final copied history is missing Pi-to-Codex divider');
assert.ok(copiedFinal.includes('Switched AI: Codex to Pi'), 'Final copied history is missing Codex-to-Pi divider');

for (const shot of [
  'auto-switch-off.png',
  'pi-model-select.png',
  'pi-turn1.png',
  'pi-valentin-mode.png',
  'pi-recall-bottom.png',
  'pi-recall-top.png',
  'codex-reply.png',
  'roundtrip-top.png',
  'roundtrip-middle.png',
  'roundtrip-bottom.png',
]) {
  assert.ok(fs.statSync(path.join(root, shot)).size > 1000, `Missing or empty screenshot: ${shot}`);
}

const acl = json('key-acl.json');
assert.equal(acl.protected, true);
assert.equal(acl.rules.length, 1);
assert.equal(acl.rules[0].sid, acl.owner);

const locks = JSON.parse(text('server-start.stdout.log').split(/\r?\n/).find(line => line.includes('"blockedWriter"')));
assert.match(locks.kernel, /WSL2/i);
assert.equal(locks.blockedWriter, 'SQLITE_BUSY');
assert.equal(locks.integrity, 'ok');
assert.equal(locks.writes, 2);

assert.match(text('ssh-preflight.txt'), /Linux[\s\S]*tmux[\s\S]*Python/);
assert.match(text('sshd.log'), /Accepted publickey for mpverify/);
assert.equal(json('doctor.json').sha256.toLowerCase(), json('build.json').sha256.toLowerCase());

const probe = spawnSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', path.join(root, 'journey.mp4')], { encoding: 'utf8' });
fs.writeFileSync(path.join(root, 'ffprobe.stdout.log'), probe.stdout ?? '');
fs.writeFileSync(path.join(root, 'ffprobe.stderr.log'), probe.stderr ?? String(probe.error ?? ''));
fs.writeFileSync(path.join(root, 'ffprobe.exit-code.txt'), String(probe.status));
assert.equal(probe.status, 0, `Video probe failed; see ${path.join(root, 'ffprobe.stderr.log')}`);
const video = JSON.parse(probe.stdout);
assert.ok(video.streams.some(stream => stream.codec_type === 'video' && Number(stream.nb_frames) > 0));
assert.ok(Number(video.format.duration) > 1);

const forbiddenFiles = [];
function scanForSecrets(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      scanForSecrets(full);
    } else {
      if (entry.name === 'auth.json') forbiddenFiles.push(full);
      if (/\.(?:json|jsonl|log|txt)$/.test(entry.name)) {
        const body = fs.readFileSync(full, 'utf8');
        if (/"refresh_token"\s*:|"access_token"\s*:|eyJhbGciOiJSUzI1Ni/.test(body)) {
          forbiddenFiles.push(`${full} (token material)`);
        }
      }
    }
  }
}
scanForSecrets(root);
assert.deepEqual(forbiddenFiles, [], `Credential material leaked into evidence: ${forbiddenFiles.join(', ')}`);

console.log('Real Pi openai-codex/gpt-6.1-sol fallback, valentin-mode provenance, roundtrip and cleanup passed');
