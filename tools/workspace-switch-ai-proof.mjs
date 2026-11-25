import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const caseName = 'workspace-switch';
const codexDivider = 'Switched AI: Claude to Codex';
const claudeDivider = 'Switched AI: Codex to Claude';

function verify(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const json = name => JSON.parse(read(name).replace(/^\uFEFF/, ''));
  const exists = name => fs.existsSync(path.join(root, name));
  const journal = read(`${caseName}/stand-in/workspace-switch.jsonl`)
    .split('\n')
    .filter(line => line.trim())
    .map(line => JSON.parse(line));
  const stage = name => journal.filter(row => row.stage === name);
  const observation = json(`${caseName}/observation.json`);
  const evidence = json(`${caseName}/workspace-switch.json`);
  const mb = JSON.parse(read(`${caseName}/workspace-switch-mb.txt`));

  assert.ok(!observation.error, `workspace switch case failed: ${observation.error}`);
  assert.equal(stage('seeded').length, 1, 'the fixture did not seed the workspace chats');
  assert.equal(stage('seeded')[0].chats.length, 2, 'the workspace must hold two live chats');
  assert.deepEqual(stage('seeded')[0].chats.map(row => row.tmux), ['ws-chat-one', 'ws-chat-two'], 'the seeded chats are not the two saved tabs');

  const antigravity = stage('switch-reply').filter(row => row.to === 'antigravity');
  assert.equal(antigravity.length, 2, 'the Antigravity attempt did not reach both chats');
  assert.ok(antigravity.every(row => row.status === 'refused' && row.reason === 'unsupported_provider'), 'Antigravity must be refused with unsupported_provider');
  assert.equal(evidence.antigravity.refused, 2, 'the refusal summary is wrong');
  assert.ok(evidence.antigravity.noticeInk >= 10, 'the refusal notice was not painted');

  const codex = stage('switch-reply').filter(row => row.to === 'codex' && row.status === 'switched');
  const claude = stage('switch-reply').filter(row => row.to === 'claude' && row.status === 'switched');
  assert.equal(codex.length, 2, 'the palette did not switch both chats to Codex');
  assert.equal(claude.length, 2, 'the palette did not switch both chats back to Claude');
  assert.ok(stage('provider-start').filter(row => row.provider === 'codex').length >= 2, 'both chats did not start on Codex');
  assert.ok(stage('provider-start').filter(row => row.provider === 'claude').length >= 2, 'both chats did not start on Claude again');

  const chats = evidence.chats;
  assert.equal(chats.length, 2, 'the saved evidence does not describe both chats');
  for (const chat of chats) {
    assert.notEqual(chat.codex, chat.seeded, `${chat.tmux} kept its Claude identity after the switch`);
    assert.notEqual(chat.claude, chat.codex, `${chat.tmux} kept its Codex identity after switching back`);
    assert.ok(codex.some(row => row.switched_sid === chat.codex), `${chat.tmux} is not the chat Codex switched`);
    assert.ok(claude.some(row => row.switched_sid === chat.claude), `${chat.tmux} is not the chat Claude switched back`);
  }
  assert.notEqual(chats[0].claude, chats[1].claude, 'both chats share one Claude identity');

  const copies = {
    before: ['ws-before-one', 'ws-before-two'],
    codex: ['ws-codex-one', 'ws-codex-two'],
    claude: ['ws-claude-one', 'ws-claude-two'],
    mb: ['ws-mb-one', 'ws-mb-two']
  };
  for (const [round, names] of Object.entries(copies)) {
    names.forEach((name, index) => {
      const copy = read(`${caseName}/${name}-copied.txt`);
      const chat = chats[index];
      assert.ok(copy.includes(chat.question), `${name} lost the earlier question`);
      assert.ok(copy.includes(chat.reply), `${name} lost the earlier reply`);
      if (round === 'codex' || round === 'mb') assert.ok(copy.includes(codexDivider), `${name} does not show the Codex divider`);
      if (round === 'claude') assert.ok(copy.includes(claudeDivider), `${name} does not show the Claude divider`);
    });
  }

  assert.equal(mb.ok, true, 'the mb verb refused the workspace switch');
  assert.equal(mb.status, 'complete', 'the mb verb did not complete the workspace switch');
  assert.equal(mb.verb, 'workspace switch-ai', 'the mb verb did not report its own name');
  assert.equal(mb.switched, 2, 'the mb verb did not switch both chats');
  assert.equal(mb.already, 0, 'the mb verb found a chat already switched');
  assert.equal(evidence.mb.exit, 0, 'the mb command line did not exit zero');
  assert.equal(evidence.mb.status, 'complete', 'the recorded mb reply is not the completed one');
  assert.equal(evidence.mb.sids.length, 2, 'the mb verb reported one identity for two chats');
  for (const chat of chats) assert.ok(evidence.mb.sids.includes(chat.mb), `${chat.tmux} does not carry the mb switch identity`);
  assert.notEqual(evidence.mb.sids[0], evidence.mb.sids[1], 'the mb verb reported one identity twice');

  for (const name of ['workspace-switch-before', 'workspace-switch-antigravity-refused', 'workspace-switch-codex', 'workspace-switch-claude', 'workspace-switch-mb']) {
    assert.ok(exists(`${name}.png`), `no screenshot for ${name}`);
  }

  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0, 'the run left owned processes behind');
  assert.equal(cleanup.scratch_removed, true, 'the run left its scratch profile behind');
  return {
    feature: 'workspace-switch-ai',
    status: 'passed',
    boundary: 'Hosted stand-in remote shell, fake tmux and a replaced provider CLI start; production workspace switch, reader handover, message store and native desktop.',
    cleanup: `owned process tree stopped (${cleanup.remaining_owned_processes} left); scratch removed=${cleanup.scratch_removed}; evidence preserved=${cleanup.evidence_preserved}`,
    checks: [
      { name: 'palette switched both chats to Codex', chats: chats.map(row => row.codex) },
      { name: 'palette switched both chats back to Claude', chats: chats.map(row => row.claude) },
      { name: 'Antigravity refused for both chats', reason: 'unsupported_provider', ink: evidence.antigravity.noticeInk },
      { name: 'mb workspace switch-ai verb switched both chats', sids: evidence.mb.sids }
    ]
  };
}

const evidence = process.argv[2];
if (!evidence) throw new Error('Usage: node workspace-switch-ai-proof.mjs <evidence>');
try {
  fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify(verify(evidence), null, 2) + '\n');
  console.log('WORKSPACE_SWITCH_AI_PASS');
} catch (error) {
  console.error(error.stack);
  process.exitCode = 1;
}
