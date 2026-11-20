import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { discoverFeatures } from './verify-features.cjs';

const cliPath = new URL('./mbv.mjs', import.meta.url);
const cliReady = fs.existsSync(cliPath);
const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/SOFT-2755');
const read = name => fs.readFileSync(path.join(fixtures, name), 'utf8');
const sha = '033ae68e075dd873f6f55da940791b1859248332';
const title = 'verify appearance soft-2755-verify-cli';

function stubIo(exec, temporary = os.tmpdir()) {
  const io = { calls: [], written: [], errors: [], exec: (command, args) => (io.calls.push(`${command} ${args.join(' ')}`), exec(command, args)), sleep: () => {}, temporary: () => temporary, write: text => io.written.push(text), error: text => io.errors.push(text) };
  return io;
}

function offline() {
  return () => assert.fail('the network must not be touched');
}

test('the agent-facing CLI exists so these contracts can run', () => {
  assert.equal(cliReady, true, 'tools/mbv.mjs is missing');
});

if (cliReady) {
  const { CliError, decisiveLine, featureFromTitle, listEvidence, listFeatures, main, parseArgs, parseResultText, requireJourney, runTitle, selectRun } = await import('./mbv.mjs');
    const runs = JSON.parse(read('runs.json'));

  test('parseArgs splits command, positionals and options', () => {
    const parsed = parseArgs(['run', 'appearance', '--ref', 'soft-2755', '--dry-run', '--json']);
    assert.equal(parsed.command, 'run');
    assert.deepEqual(parsed.args, ['appearance']);
    assert.deepEqual(parsed.options, { '--ref': 'soft-2755', '--dry-run': true, '--json': true });
  });

  test('parseArgs accepts inline values and rejects malformed options', () => {
    assert.equal(parseArgs(['proof', '44511646202', '--feature=inbox']).options['--feature'], 'inbox');
    assert.throws(() => parseArgs(['list', '--nope']), error => error instanceof CliError && /unknown option --nope/.test(error.message));
    assert.throws(() => parseArgs(['list', '--dry-run=yes']), error => error instanceof CliError && /takes no value/.test(error.message));
    assert.throws(() => parseArgs(['list', '--ref']), error => error instanceof CliError && /--ref needs a value/.test(error.message));
    assert.throws(() => parseArgs(['list', '--ref', '--json']), error => error instanceof CliError && /--ref needs a value/.test(error.message));
  });

  test('the journey list comes from discoverFeatures, never a copy', () => {
    const discovered = discoverFeatures();
    const journeys = listFeatures();
    assert.deepEqual(journeys.map(journey => journey.feature), discovered.available);
    for (const journey of journeys) assert.equal(journey.file, `.claude/skills/verify-multiprompt/features/${journey.feature}.md`);
    assert.deepEqual(journeys.filter(journey => journey.prTriggered).map(journey => journey.feature), discovered.pr);
  });

  test('requireJourney accepts a discovered journey and refuses the rest', () => {
    const appearance = requireJourney('appearance');
    assert.equal(appearance.feature, 'appearance');
    assert.equal(appearance.prTriggered, true);
    assert.throws(() => requireJourney('appearnce'), error => error instanceof CliError && /unknown journey appearnce/.test(error.message) && /node tools\/mbv\.mjs list/.test(error.hint));
    assert.throws(() => requireJourney('inbox-spa'), error => /did you mean inbox-space/.test(error.hint));
  });

  test('runTitle and featureFromTitle agree with the workflow run-name', () => {
    assert.equal(runTitle('appearance', 'soft-2755'), 'verify appearance soft-2755');
    assert.equal(runTitle('appearance', 'soft-2755', 'v0.28.947'), 'verify appearance v0.28.947');
    assert.equal(featureFromTitle('verify title-bar master'), 'title-bar');
    assert.equal(featureFromTitle('something else'), '');
  });

  test('run lookup matches head SHA and display title, never the latest run', () => {
    assert.equal(selectRun(runs, { headSha: sha, title }).databaseId, 44512077777, 'the newest matching run is the new one');
    assert.equal(selectRun(runs, { headSha: sha, title, exclude: new Set([44512077777]) }).databaseId, 44511833333, 'an excluded run is never the new one');
    assert.equal(selectRun(runs, { headSha: sha, title: 'verify appearance other-branch' }), null);
    assert.equal(selectRun(runs, { headSha: '5574e5748dc5b5f51f5d05c7d0678acba828c9b1', title }).databaseId, 44512099999, 'the same title on another SHA is that SHA\'s run');
    assert.equal(selectRun([], { headSha: sha, title }), null);
  });

  test('a newer queued run wins over an older finished run with the same SHA and title', () => {
    const both = [{ databaseId: 2, headSha: sha, displayTitle: title, status: 'queued' }, { databaseId: 1, headSha: sha, displayTitle: title, status: 'completed' }];
    assert.equal(selectRun(both, { headSha: sha, title }).databaseId, 2);
  });

  test('result.json parsing reads status, error, cleanup and failed checks', () => {
    const failed = parseResultText(read('result-failed.json'));
    assert.equal(failed.status, 'failed');
    assert.deepEqual(failed.errors, ['Waited 20 s for palette contains named command Mute Tab.']);
    assert.equal(failed.cleanup, 'owned process tree stopped; scratch copied to evidence/data then removed');
    assert.equal(failed.scratchRemoved, true);
    assert.equal(failed.version, '0.28.1762');
    assert.deepEqual(failed.failedChecks, []);

    const passed = parseResultText(read('result-passed.json'));
    assert.equal(passed.status, 'passed');
    assert.deepEqual(passed.failedChecks, [{ name: 'steer-chord', detail: 'kept the draft' }]);

    const verdict = parseResultText(read('result-verdict.json'));
    assert.equal(verdict.status, 'passed');
    assert.deepEqual(verdict.errors, ['nothing']);
    assert.deepEqual(verdict.failedChecks, [{ name: 'scrolling', detail: 'pixels moved' }]);
  });

  test('result.json parsing survives the BOM PowerShell writes', () => {
    const text = `\uFEFF${JSON.stringify({ feature: 'inbox', status: 'failed', error: 'x' })}`;
    assert.equal(parseResultText(text).status, 'failed');
  });

  test('result.json parsing reports unknown instead of guessing', () => {
    const unknown = parseResultText('{"feature":"inbox"}');
    assert.equal(unknown.status, 'unknown');
    assert.deepEqual(unknown.errors, []);
    assert.equal(unknown.scratchRemoved, null);
  });

  test('the decisive line is the harness error, not the Retain step text', () => {
    const line = decisiveLine(read('job-log-wrapped.txt'));
    assert.equal(line, 'Waited 20 s for palette contains named command Mute Tab.');
    assert.doesNotMatch(line, /Workflow failed before/);
  });

  test('the decisive line falls back to a thrown message and then to nothing', () => {
    assert.equal(decisiveLine('2026-11-19T04:41:28.4828213Z Bot photo verification failed; see result.json'), 'Bot photo verification failed; see result.json');
    assert.equal(decisiveLine(''), '');
    assert.equal(decisiveLine('today is quiet'), '');
  });

  test('listEvidence reports only files that exist', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mbv-evidence-'));
    fs.mkdirSync(path.join(directory, 'data'), { recursive: true });
    fs.writeFileSync(path.join(directory, 'after.png'), 'x');
    fs.writeFileSync(path.join(directory, 'result.json'), '{}');
    fs.writeFileSync(path.join(directory, 'data', 'journey.mp4'), 'x');
    assert.deepEqual(listEvidence(directory), { mp4: ['data/journey.mp4'], png: ['after.png'], json: ['result.json'], other: [] });
  });

  test('mbv list --json prints only JSON', () => {
    const io = stubIo(offline());
    assert.equal(main(['list', '--json'], io), 0);
    const output = JSON.parse(io.written.join(''));
    assert.equal(output.journeys.length, discoverFeatures().available.length);
    assert.deepEqual(output.journeys.find(journey => journey.feature === 'inbox'), { feature: 'inbox', file: '.claude/skills/verify-multiprompt/features/inbox.md', prTriggered: false });
  });

  test('mbv run --dry-run prints the exact command and dispatches nothing', () => {
    const io = stubIo((command, args) => {
      if (command === 'gh' && args[0] === 'api') return { status: 0, stdout: JSON.stringify({ sha }) };
      if (command === 'gh' && args[0] === 'run') return { status: 0, stdout: JSON.stringify(runs) };
      return { status: 0, stdout: '' };
    });
    assert.equal(main(['run', 'appearance', '--ref', 'soft-2755-verify-cli', '--dry-run'], io), 0);
    const output = io.written.join('');
    assert.match(output, /gh workflow run verify\.yml --repo valentinyeo\/multiprompt --ref soft-2755-verify-cli -f feature=appearance/);
    assert.match(output, /title   verify appearance soft-2755-verify-cli/);
    assert.equal(io.calls.some(call => call.startsWith('gh workflow run')), false);
  });

  test('mbv run with --tag carries the tag into the run title and the dispatch', () => {
    const io = stubIo((command, args) => {
      if (command === 'gh' && args[0] === 'api') return { status: 0, stdout: JSON.stringify({ sha }) };
      return { status: 0, stdout: JSON.stringify(runs) };
    });
    assert.equal(main(['run', 'appearance', '--ref', 'master', '--tag', 'v0.28.947', '--dry-run', '--json'], io), 0);
    const output = JSON.parse(io.written.join(''));
    assert.equal(output.displayTitle, 'verify appearance v0.28.947');
    assert.equal(output.command, 'gh workflow run verify.yml --repo valentinyeo/multiprompt --ref master -f feature=appearance -f tag=v0.28.947');
  });

  test('mbv run refuses an unknown journey before any gh call', () => {
    const io = stubIo(() => assert.fail('no gh call for an unknown journey'));
    assert.equal(main(['run', 'appearnce', '--dry-run'], io), 1);
    assert.match(io.errors.join(''), /unknown journey appearnce/);
    assert.match(io.errors.join(''), /next: .*node tools\/mbv\.mjs list/);
    assert.deepEqual(io.calls, []);
  });

  test('mbv run refuses a malformed tag with the expected shape', () => {
    const io = stubIo(() => assert.fail('no gh call for a malformed tag'));
    assert.equal(main(['run', 'appearance', '--tag', '0.28.947', '--dry-run'], io), 1);
    assert.match(io.errors.join(''), /--tag must look like v0\.28\.947/);
  });

  test('mbv fails loudly when the ref is not on the remote', () => {
    const io = stubIo((command, args) => (args[0] === 'api' ? { status: 1, stdout: '', stderr: 'gh: Not Found (HTTP 404)' } : { status: 0, stdout: '[]' }));
    assert.equal(main(['run', 'appearance', '--ref', 'unpushed', '--dry-run'], io), 1);
    assert.match(io.errors.join(''), /push unpushed first/);
  });

  test('mbv proof reports the artifact, the failure and only the evidence it found', () => {
    const io = stubIo((command, args) => {
      if (args[0] === 'run' && args[1] === 'view') return { status: 0, stdout: JSON.stringify({ databaseId: 44459413179, displayTitle: 'verify inbox master', status: 'completed', conclusion: 'failure', url: 'https://example.test/runs/44459413179' }) };
      if (args[0] === 'api') return { status: 0, stdout: JSON.stringify({ artifacts: [{ name: 'verify-inbox' }, { name: 'verify-inbox-space' }, { name: 'verify-app' }] }) };
      if (args[0] === 'run' && args[1] === 'download') {
        const target = args[args.indexOf('--dir') + 1];
        fs.mkdirSync(target, { recursive: true });
        fs.writeFileSync(path.join(target, 'result.json'), read('result-failed.json'));
        fs.writeFileSync(path.join(target, 'doctor.json'), read('doctor.json'));
        fs.writeFileSync(path.join(target, 'after.png'), 'x');
        return { status: 0, stdout: '' };
      }
      return { status: 0, stdout: '' };
    });
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'mbv-proof-'));
    assert.equal(main(['proof', '44459413179', '--out', out], io), 1);
    const output = io.written.join('');
    assert.match(output, /artifact verify-inbox -> /);
    assert.doesNotMatch(output, /verify-inbox-space/, 'a longer journey name is not this journey');
    assert.match(output, /result\.json {3}failed/);
    assert.match(output, /error {9}Waited 20 s for palette contains named command Mute Tab\./);
    assert.match(output, /evidence {6}1 png, 2 json, 0 mp4/);
    assert.match(output, /missing {7}journey\.mp4 missing/);
  });

  test('mbv proof --json stays machine readable and never invents files', () => {
    const io = stubIo((command, args) => {
      if (args[0] === 'run' && args[1] === 'view') return { status: 0, stdout: JSON.stringify({ databaseId: 7, displayTitle: 'verify appearance master', status: 'completed', conclusion: 'success', url: 'https://example.test/runs/7' }) };
      if (args[0] === 'api') return { status: 0, stdout: JSON.stringify({ artifacts: [{ name: 'verify-appearance' }] }) };
      if (args[0] === 'run' && args[1] === 'download') {
        const target = args[args.indexOf('--dir') + 1];
        fs.mkdirSync(target, { recursive: true });
        fs.writeFileSync(path.join(target, 'result.json'), read('result-passed.json'));
        return { status: 0, stdout: '' };
      }
      return { status: 0, stdout: '' };
    });
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'mbv-proof-json-'));
    assert.equal(main(['proof', '7', '--out', out, '--json'], io), 0);
    const output = JSON.parse(io.written.join(''));
    const artifact = output.artifacts[0];
    assert.equal(artifact.name, 'verify-appearance');
    assert.equal(artifact.result.status, 'passed');
    assert.equal(artifact.doctor, null);
    assert.deepEqual(artifact.evidence.mp4, []);
    assert.deepEqual(artifact.evidence.png, []);
  });

  test('mbv proof never reports a pass without a result.json', () => {
    const io = stubIo((command, args) => {
      if (args[0] === 'run' && args[1] === 'view') return { status: 0, stdout: JSON.stringify({ databaseId: 9, displayTitle: 'verify appearance master', status: 'completed', conclusion: 'success', url: 'https://example.test/runs/9' }) };
      if (args[0] === 'api') return { status: 0, stdout: JSON.stringify({ artifacts: [{ name: 'verify-appearance' }] }) };
      const target = args[args.indexOf('--dir') + 1];
      fs.mkdirSync(target, { recursive: true });
      fs.writeFileSync(path.join(target, 'after.png'), 'x');
      return { status: 0, stdout: '' };
    });
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'mbv-proof-empty-'));
    assert.equal(main(['proof', '9', '--out', out], io), 1);
    assert.match(io.written.join(''), /result\.json {3}missing/);
  });

  test('mbv proof names the missing artifact instead of failing silently', () => {
    const io = stubIo((command, args) => {
      if (args[0] === 'run' && args[1] === 'view') return { status: 0, stdout: JSON.stringify({ databaseId: 8, displayTitle: 'verify appearance master', status: 'completed', conclusion: 'success', url: 'https://example.test/runs/8' }) };
      return { status: 0, stdout: JSON.stringify({ artifacts: [{ name: 'verify-app' }] }) };
    });
    assert.equal(main(['proof', '8', '--out', os.tmpdir()], io), 1);
    assert.match(io.errors.join(''), /has no verify-appearance artifact/);
  });

  test('mbv failures lists failed verify jobs with their id and decisive line', () => {
    const io = stubIo((command, args) => {
      if (args[0] === 'run' && args[1] === 'view' && args.includes('--json')) return { status: 0, stdout: JSON.stringify({ databaseId: 44459413179, displayTitle: 'verify appearance master', status: 'completed', conclusion: 'failure', url: 'https://example.test/runs/44459413179', jobs: [{ name: 'journeys', conclusion: 'success', databaseId: 1 }, { name: 'verify (inbox)', conclusion: 'failure', databaseId: 2 }, { name: 'verify (chat-still)', conclusion: 'failure', databaseId: 3 }] }) };
      if (args[0] === 'run' && args[1] === 'view') return { status: 0, stdout: read('job-log-wrapped.txt') };
      return { status: 1, stdout: '' };
    });
    assert.equal(main(['failures', '44459413179'], io), 1);
    const output = io.written.join('');
    assert.match(output, /verify \(inbox\) +2 {2}Waited 20 s for palette contains named command Mute Tab\./);
    assert.match(output, /verify \(chat-still\) +3 {2}Waited 20 s for palette contains named command Mute Tab\./);
    assert.doesNotMatch(output, /journeys/);
  });

  test('mbv failures refuses a run that has not finished', () => {
    const io = stubIo(() => ({ status: 0, stdout: JSON.stringify({ databaseId: 9, displayTitle: 'verify appearance master', status: 'in_progress', url: 'https://example.test/runs/9', jobs: [] }) }));
    assert.equal(main(['failures', '9'], io), 1);
    assert.match(io.errors.join(''), /is still in_progress/);
    assert.match(io.errors.join(''), /next: wait for it with node tools\/mbv\.mjs watch 9/);
  });

  test('mbv rejects a missing argument with the command help pointer', () => {
    const io = stubIo(() => assert.fail('no gh call without a run id'));
    assert.equal(main(['watch'], io), 1);
    assert.match(io.errors.join(''), /watch needs one argument/);
    assert.match(io.errors.join(''), /next: run node tools\/mbv\.mjs watch --help/);
  });

  test('mbv rejects a non-numeric run id', () => {
    const io = stubIo(() => assert.fail('no gh call for a bad run id'));
    assert.equal(main(['watch', 'latest'], io), 1);
    assert.match(io.errors.join(''), /watch needs a run id, got latest/);
  });

  test('mbv rejects an unknown command and prints help', () => {
    const io = stubIo(offline());
    assert.equal(main(['lisy'], io), 1);
    assert.match(io.errors.join(''), /unknown command lisy/);
    assert.equal(main(['--help'], stubIo(offline())), 0);
    assert.equal(main(['run', '--help'], stubIo(offline())), 0);
  });
}
