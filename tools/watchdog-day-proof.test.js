const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('a working-day proof requires fresh positive coverage from one real device session', () => {
  const file = path.join(__dirname, 'watchdog-day-proof.py');
  assert.ok(fs.existsSync(file), 'positive watchdog coverage verifier exists');
  const source = String.raw`
import importlib.util
spec = importlib.util.spec_from_file_location('proof', ${JSON.stringify(file)})
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
started = 100000
now = started + 8 * 3600 + 60
def row(responsive=m.DAY_MS, observed=m.DAY_MS, gap=0, freezes=0, process=2, sequence=8):
    return dict(device_id='desktop', report_id=f'watchdog-{started}-{process}-300-{sequence}', captured_at=now, app_version='0.28.1', android_version='Windows', thread='watchdog', summary=m.HEALTH, stack_trace=f'observed_ms: {observed}\nresponsive_ms: {responsive}\nunobserved_ms: {gap}\nfreezes: {freezes}\n')
def status(rows, at=now):
    return m.inspect(rows, at)['status']
assert status([]) == 'observing'
assert status([dict(summary='Windows freeze')]) == 'observing'
assert status([row()]) == 'passed'
for changed in [row(responsive=m.DAY_MS-500), row(gap=5000), row(freezes=1), row(responsive=m.DAY_MS+1), row(observed=m.DAY_MS*2)]:
    assert status([changed]) == 'observing', changed
assert status([row()], now + 5401) == 'observing'
assert status([dict(row(), captured_at=now+1)]) == 'observing'
assert status([row(responsive=m.DAY_MS//2, observed=m.DAY_MS//2), row(responsive=m.DAY_MS//2, observed=m.DAY_MS//2, process=3)]) == 'observing'
assert status([row(), row(responsive=60000, observed=60000, sequence=9)]) == 'observing'
assert status([row(freezes=1), row(sequence=9)]) == 'observing'
incident = dict(device_id='desktop', captured_at=now, android_version='Windows', summary='Windows freeze')
assert status([row(), incident]) == 'observing'
assert status([row(), dict(incident, captured_at=now+1)], now+1) == 'observing'
assert status([row(), dict(incident, summary='Windows crash')]) == 'observing'
assert status([row(), dict(incident, device_id='other')]) == 'passed'
assert m.inspect([row()], now, device='other')['status'] == 'observing'
assert status([dict(row(), stack_trace=row()['stack_trace'] + 'private text')]) == 'observing'
assert status([dict(row(), report_id='untyped')]) == 'observing'
print('POSITIVE_WATCHDOG_COVERAGE_OK')
`;
  const result = spawnSync('python3', ['-c', source], { encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /POSITIVE_WATCHDOG_COVERAGE_OK/);
});
