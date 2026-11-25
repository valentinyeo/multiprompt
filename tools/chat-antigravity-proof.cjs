const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const pngMagic = '89504e470d0a1a0a';

function verifyCopiedHistory(copiedBack, backTexts) {
  copiedBack = copiedBack.replace(/\r\n/g, '\n');
  let copiedOffset = 0;
  for (const text of backTexts.filter(Boolean)) {
    const displayed = text.replace(/\r\n/g, '\n')
      .replace(/^---\n(Switched AI: (?:Claude to Antigravity|Antigravity to Claude))\n---$/, '--- $1 ---');
    const position = copiedBack.indexOf(displayed, copiedOffset);
    assert.ok(position >= 0, `the rendered switch back lost or reordered ${text}`);
    copiedOffset = position + displayed.length;
  }
}

function verify(root) {
  const dir = path.join(root, 'antigravity-chats');
  const read = name => fs.readFileSync(path.join(dir, name), 'utf8');
  const json = name => JSON.parse(read(name));
  const rootJson = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));
  const lines = name => read(name).trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const png = name => fs.readFileSync(path.join(root, `${name}.png`)).subarray(0, 8).toString('hex');
  const shot = name => assert.equal(png(name), pngMagic, `missing screenshot ${name}`);
  assert.equal(json('observation.json').error, null);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  for (const name of ['antigravity-chat-before', 'antigravity-switch-palette', 'antigravity-switched-chat',
    'antigravity-new-session-palette', 'antigravity-new-session', 'antigravity-tab-menu-switch',
    'antigravity-switch-while-replying', 'antigravity-switch-back-claude',
    'antigravity-fresh-before-reload', 'antigravity-fresh-after-reload', 'antigravity-fresh-reload-twice',
    'antigravity-fresh-tab-away', 'antigravity-fresh-tab-returned']) shot(name);
  const config = json('antigravity-config.json');
  assert.equal(config.provider, 'antigravity');
  assert.equal(config.enabled, true);
  assert.equal(config.tmux, 'verify-agent');
  assert.equal(config.switched_from.provider, 'claude');
  const history = lines('antigravity-history.jsonl');
  const texts = history.map(row => (row.row ? row.row.text : '') || '');
  assert.ok(texts.some(text => text.includes('earlier claude question')), 'earlier message missing after the switch');
  assert.ok(texts.some(text => text.includes('Switched AI: Claude to Antigravity')), 'switch divider missing');
  const seed = json('seed-session.json');
  const afterSwitch = json('session-after-switch.json');
  assert.equal(afterSwitch.tabs.length, seed.tabs.length, 'the switch changed the chat rows');
  assert.equal(afterSwitch.tabs[0].name, seed.tabs[0].name, 'the switch renamed the chat');
  const received = lines('stand-in/antigravity-deliver.jsonl');
  assert.ok(received.some(row => String(row.text).includes('after the switch')), 'the Antigravity host never received the new message');
  assert.ok(read('claude-history.jsonl').includes('Claude stand-in answer'), 'the earlier message was not answered before the switch');
  const agent = lines('stand-in/agy-agent.jsonl');
  assert.ok(agent.some(row => row.argv.some(part => part.includes('stream-json'))), 'the fixture was not started through the Antigravity argv');
  assert.ok(read('stand-in/invocations.jsonl').includes('antigravity'), 'the new session did not route an Antigravity launch');
  const after = json('session-new-session.json');
  assert.equal(after.tabs.length, seed.tabs.length + 1, 'the new Antigravity session did not add one row');
  const fresh = after.tabs.find(tab => tab.name === 'Antigravity');
  assert.ok(fresh, 'the new row is not named Antigravity');
  assert.equal(fresh.cv, true, 'the new Antigravity row did not open in Chat View');
  assert.match(fresh.tmux_session, /^live-/);
  const freshReload = json('fresh-reload.json');
  assert.equal(freshReload.reload, 'Chat View Resync chat');
  assert.equal(freshReload.reloads, 2, 'the journey must reload the whole history more than once');
  assert.equal(freshReload.messages, 3, 'the journey must send three distinct synthetic messages');
  assert.equal(new Set(freshReload.texts).size, 3);
  assert.equal(new Set(freshReload.replies).size, 3);
  assert.equal(freshReload.tabAwayBack, true);
  assert.equal(freshReload.sidAfter, fresh.csid, 'the full reloads changed the fresh Antigravity chat identity');
  assert.equal(freshReload.displayHistoryAfter, true, 'the full reloads dropped the claimed Antigravity history flag');
  const claim = json('fresh-history-claim.json');
  assert.equal(claim.display_history, true, 'the fresh Antigravity host start never claimed its canonical history');
  assert.equal(claim.historyExists, true, 'the fresh Antigravity history file does not exist after the host claimed it');
  assert.match(claim.claimBoundary, /production host loop start/);
  assert.ok(Number.isSafeInteger(freshReload.blocksBefore) && freshReload.blocksBefore >= 6, 'the fresh Antigravity history painted too few blocks before the reload');
  assert.equal(freshReload.blocksAfter, freshReload.blocksBefore, 'the full reload changed the painted Antigravity row count');
  const stages = [['before', 'before the reload'], ['after', 'after the reload'], ['reload-twice', 'after the repeated reload'], ['tab-away-back', 'after a tab away and back']];
  const transcripts = stages.map(([stage]) => read(`fresh-copied-${stage}.txt`));
  const expected = freshReload.texts.flatMap((text, index) => [text, freshReload.replies[index]]);
  for (const [index, transcript] of transcripts.entries()) {
    let cursor = 0;
    for (const kept of expected) {
      assert.equal(transcript.split(kept).length, 2, `the ${stages[index][1]} Antigravity copy did not hold exactly one ${kept}`);
      const found = transcript.indexOf(kept, cursor);
      assert.ok(found >= 0, `the ${stages[index][1]} Antigravity copy is out of order at ${kept}`);
      cursor = found + kept.length;
    }
    assert.equal(transcript.trim(), transcripts[0].trim(), `the ${stages[index][1]} view changed the visible Antigravity transcript`);
  }
  assert.equal(freshReload.sameTranscript, true);
  const doctor = json('doctor.json');
  assert.ok(Number.isSafeInteger(doctor.pid) && doctor.pid > 0, 'doctor identity missing');
  assert.equal(doctor.hwnd > 0, true);
  const agyPane = json('agy-pane-agent.json');
  assert.equal(agyPane.pane, 'agy-pane');
  assert.equal(agyPane.paneCommand, 'agy');
  assert.equal(agyPane.agent, 8, 'the app did not report the agy tmux pane as Antigravity');
  assert.equal(agyPane.label, 'Antigravity');

  const menu = json('tab-menu.json');
  assert.equal(menu.source, 'chat tab right-click menu');
  assert.equal(menu.selected, 7176, 'the tab right-click menu did not select Switch AI to Claude');
  assert.match(menu.rows, /\b7176\b/, 'the tab right-click menu never listed Switch AI to Claude');
  const refused = json('switch-while-replying.json');
  const held = lines('stand-in/antigravity-hold.jsonl');
  const holding = held.find(row => row.stage === 'replying' && row.text === 'after the switch');
  assert.ok(holding, 'the stand-in never held the reply to the new message');
  assert.equal(typeof holding.reply, 'string', 'the hold never named the reply it keeps open');
  assert.equal(refused.heldReply, holding.reply, 'the journey recorded a different held reply');
  assert.ok(Number.isSafeInteger(holding.ms), 'the hold carried no time');
  assert.ok(!held.some(row => row.stage === 'timeout'), 'the stand-in timed out waiting for the journey to release the reply');
  const released = held.find(row => row.stage === 'released' && row.text === 'after the switch');
  assert.ok(released, 'the held reply was never released');
  assert.equal(released.released, true, 'the journey never sent its release signal');
  assert.equal(released.reply, holding.reply, 'the release named a different reply');
  assert.ok(released.ms >= holding.ms, 'the release came before the hold');
  assert.ok(texts.some(text => text.includes(holding.reply)), 'the released reply never reached the switched chat');
  const switches = lines('stand-in/antigravity-switch.jsonl');
  const busy = switches.find(row => row.status === 'busy');
  assert.ok(busy, 'the host never refused a switch while the chat was replying');
  assert.ok(Number.isSafeInteger(busy.ms) && busy.ms >= holding.ms && busy.ms <= released.ms, 'the switch was not refused while the reply was held');
  assert.equal(busy.target, 'claude');
  assert.equal(busy.reason, 'chat_busy');
  assert.equal(refused.request.target, 'claude');
  assert.equal(refused.reply.status, 'busy');
  assert.equal(refused.providerAfter, 'antigravity', 'the refused switch moved the chat off Antigravity');
  assert.equal(refused.sidAfter, config.sid, 'the refused switch changed the chat session');
  assert.ok(switches.some(row => row.status === 'switched' && row.target === 'claude'), 'the later switch to Claude never happened');
  const backConfig = json('claude-back-config.json');
  assert.equal(backConfig.provider, 'claude');
  assert.equal(backConfig.enabled, true);
  assert.equal(backConfig.switched_from.provider, 'antigravity');
  const backRows = lines('claude-back-history.jsonl');
  const backTexts = backRows.map(row => (row.row ? row.row.text : '') || '');
  for (const text of ['earlier claude question', 'after the switch', 'Antigravity stand-in reply',
    'Switched AI: Claude to Antigravity', 'Switched AI: Antigravity to Claude']) {
    assert.ok(backTexts.some(row => row.includes(text)), `the switch back to Claude lost ${text}`);
  }
  verifyCopiedHistory(read('switch-back-copied.txt'), backTexts);
  const back = json('switch-back.json');
  assert.equal(back.provider, 'claude');
  assert.equal(back.switchedFrom, 'antigravity');
  assert.ok(backTexts.some(text => text.includes(holding.reply)), 'the switch back to Claude lost the released reply');
  const backSession = json('session-after-switch-back.json');
  assert.equal(backSession.tabs.length, seed.tabs.length, 'the switch back changed the chat rows');
  assert.equal(backSession.tabs[0].name, seed.tabs[0].name, 'the switch back renamed the chat');
  assert.equal(backSession.tabs[0].ai_agent, 1, 'the app did not adopt Claude for the chat');
  assert.equal(back.rows, backRows.length);

  const totals = rootJson('cleanup.json');
  return {
    feature: 'antigravity-chats',
    status: 'passed',
    boundary: 'Antigravity is a repository stand-in that speaks the production stream-json protocol; SSH and the remote shell are stand-ins, the app, keyboard input and the production reader host are real. The Claude side of a switch is served by the same fixture host store, with no live Claude process.',
    cleanup: `The owned Windows job stopped the app and its children (${totals.remaining_owned_processes} left running); each case's isolated profile, its agent-host home and the socket temp folder were removed (scratchRemoved=${totals.scratch_removed}); the evidence copy was kept (evidencePreserved=${totals.evidence_preserved}).`,
    cases: [
      {
        name: 'antigravity-chats',
        passed: true,
        detail: { switched: config.switched_from.provider + ' to ' + config.provider, historyRows: history.length, newSession: fresh.tmux_session, agentPane: agyPane.pane + ' ' + agyPane.paneCommand + ' -> agent ' + agyPane.agent + ' ' + agyPane.label },
      },
      {
        name: 'switch-back-to-claude',
        passed: true,
        detail: { switched: 'antigravity to claude', historyRows: backRows.length, kept: 'same row, same name, earlier messages and both Switch AI dividers', adoptedAgent: backSession.tabs[0].ai_agent, screenshot: 'antigravity-switch-back-claude.png' },
      },
      {
        name: 'tab-menu-switch-ai',
        passed: true,
        detail: { entry: 'Switch AI to Claude', target: menu.selected, source: menu.source, rows: menu.rows, screenshot: menu.screenshot },
      },
      {
        name: 'switch-while-replying',
        passed: true,
        detail: { refused: 'busy', reason: busy.reason, notice: refused.notice, providerAfter: refused.providerAfter, screenshot: refused.screenshot },
      },
      {
        name: 'fresh-antigravity-reload',
        passed: true,
        detail: { messages: freshReload.messages, reloads: freshReload.reloads, blocksBefore: freshReload.blocksBefore, blocksAfter: freshReload.blocksAfter, claim: 'fresh-history-claim.json', before: 'fresh-copied-before.txt', after: 'fresh-copied-after.txt', twice: 'fresh-copied-reload-twice.txt', tabAway: 'fresh-copied-tab-away-back.txt', screenshot: 'antigravity-fresh-tab-returned.png' },
      },
    ],
  };
}

module.exports = { verify, verifyCopiedHistory };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const result = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('ANTIGRAVITY_OK');
  } catch (error) {
    console.error(error.stack);
    process.exitCode = 1;
  }
}
