const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const script = path.resolve(__dirname, '../service/crash-report-tickets.py');

test('uploaded reports become durable signature tickets; retries and restarts preserve receipts', () => {
  assert.ok(fs.existsSync(script), 'Automatic uploaded-report triage must exist');
  const code = `
import importlib.util, json, tempfile
from pathlib import Path
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('triage', ${JSON.stringify(script)})
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
row = dict(device_id='desktop', report_id='freeze-one', captured_at=100, received_at=101, app_version='0.28.1', thread='main', summary='Windows freeze', stack_trace='exception_code: 0x0\\nstack_rvas:\\n  0x1234\\n')
with patch.object(m, 'board', side_effect=[dict(success=True, tasks=[], nextCursor='next'), dict(success=True, tasks=[dict(title='matching', ticketNumber='IGSH-9')])]) as pages:
    assert m.find_ticket('matching')['ticketNumber'] == 'IGSH-9'
    assert pages.call_args.args[-2:] == ('--cursor', 'next')
with patch.object(m, 'board', return_value=dict(success=True, tasks=[], nextCursor='loop')):
    try:
        m.find_ticket('missing')
        raise AssertionError('Repeated cursor accepted')
    except RuntimeError:
        pass
tasks, logs, events = [], {}, []
def board(*args):
    if args[:2] == ('task', 'list'):
        return dict(success=True, tasks=tasks.copy())
    if args[:2] == ('task', 'create'):
        task = dict(ticketNumber='IGSH-' + str(len(tasks) + 1), title=args[args.index('--title') + 1], section='Todo')
        tasks.append(task)
        return dict(success=True, task=task)
    ticket = args[2]
    if args[:2] == ('task', 'agent-log'):
        return dict(success=True, activities=[dict(text=t) for t in logs.get(ticket, [])])
    if args[:2] == ('task', 'get'):
        return dict(success=True, tasks=[next(t for t in tasks if t['ticketNumber'] == ticket)])
    if args[:2] == ('task', 'move'):
        events.append(args)
        next(t for t in tasks if t['ticketNumber'] == ticket)['section'] = args[-1]
        return dict(success=True)
    raise AssertionError(args)
def activity(ticket, text):
    logs.setdefault(ticket, []).append(text)
with tempfile.TemporaryDirectory() as directory, patch.object(m, 'board', board), patch.object(m, 'activity', activity):
    state = Path(directory) / 'state.json'
    m.triage([row, row], state)
    assert len(tasks) == 1 and len(logs['IGSH-1']) == 1
    m.triage([row], state)
    assert len(logs['IGSH-1']) == 1
    state.unlink()
    m.triage([row], state)
    assert len(tasks) == 1 and len(logs['IGSH-1']) == 1
    tasks[0]['section'] = 'Done'
    next_row = dict(row, report_id='freeze-two', device_id='other-desktop')
    m.triage([row, next_row], state)
    assert len(tasks) == 1 and len(logs['IGSH-1']) == 2
    assert 'Count: 2;' in logs['IGSH-1'][-1]
    assert events[-1] == ('task', 'move', 'IGSH-1', '--section', 'Todo')
    m.triage([dict(row, app_version='0.28.2')], state)
    assert len(tasks) == 2
    m.triage([dict(row, stack_trace='another stack')], state)
    assert len(tasks) == 3
    failed_row = dict(row, report_id='freeze-three')
    with patch.object(m, 'activity', side_effect=RuntimeError('board unavailable')):
        try:
            m.triage([failed_row], state)
            raise AssertionError('Failed board write was swallowed')
        except RuntimeError:
            pass
    assert m.receipt(failed_row) not in json.loads(state.read_text())[m.signature(row)]['receipts']
    m.triage([failed_row], state)
    assert len(logs['IGSH-1']) == 3
    crash_row = dict(row, summary='Windows crash')
    m.triage([crash_row], state)
    assert len(tasks) == 4
print('TRIAGE_BEHAVIOR_OK')
`;
  const result = spawnSync('python3', ['-c', code], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /TRIAGE_BEHAVIOR_OK/);
});

test('completed forced-freeze workflow produces one automatic ticket receipt', () => {
  assert.ok(fs.existsSync(script), 'Forced CI freeze must reach automatic triage');
  const code = `
import importlib.util, json, tempfile
from pathlib import Path
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('triage', ${JSON.stringify(script)})
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
logs = []
run = dict(conclusion='success', workflowName='Freeze recorder', url='https://github.com/example/run', headSha='abc')
def command(args):
    if args[:3] == ['gh', 'run', 'view']:
        return json.dumps(run)
    directory = Path(args[-1])
    (directory / 'result.json').write_text(json.dumps(dict(healthyReports=0, firstStallReports=1, secondStallReports=2)))
    (directory / 'first-freeze.txt').write_text('thread_context: captured\\nstack_rvas:\\n  0x1234\\n')
    return ''
def board(*args):
    return dict(success=True, activities=[dict(text=t) for t in logs])
with tempfile.TemporaryDirectory() as directory, patch.object(m, 'board', board), patch.object(m, 'command', command), patch.object(m, 'activity', lambda ticket, text: logs.append(text)):
    run['conclusion'] = ''
    m.ci_proof('123', 'IGSH-1170', directory)
    assert not logs
    run['conclusion'] = 'failure'
    try:
        m.ci_proof('123', 'IGSH-1170', directory)
        raise AssertionError('Failed run accepted')
    except RuntimeError:
        pass
    run['conclusion'] = 'success'
    m.ci_proof('123', 'IGSH-1170', directory)
    m.ci_proof('123', 'IGSH-1170', directory)
    assert len(logs) == 1 and 'freeze-ci-run:123' in logs[0] and '0x1234' in logs[0]
print('CI_RECEIPT_BEHAVIOR_OK')
`;
  const result = spawnSync('python3', ['-c', code], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /CI_RECEIPT_BEHAVIOR_OK/);
});
