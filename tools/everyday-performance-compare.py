import argparse
import json
import math
from pathlib import Path
import statistics

parser = argparse.ArgumentParser()
parser.add_argument('evidence', type=Path)
args = parser.parse_args()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


base = read(args.evidence / 'base/report.json')
head = read(args.evidence / 'head/report.json')
order = read(args.evidence / 'order.json')
if base['trials'] < 5 or base['trials'] != head['trials']:
    raise ValueError('Expected at least five trials on each side')
if [row['side'] for row in order] != ['base', 'head'] * base['trials']:
    raise ValueError('Trials did not alternate base/head')
if base['errors'] or head['errors']:
    raise ValueError('Failed actions cannot supply a comparison')
for key in ('cores', 'os', 'sampleCounts', 'imageOS', 'imageVersion', 'optimization', 'observer', 'endpoints', 'profile'):
    if base['machine'][key] != head['machine'][key]:
        raise ValueError(f'Mismatching measurement configuration: {key}')
result = {'trialsPerSide': base['trials'], 'errors': 0, 'actions': {}}
print('| Action | Base p50/p95/p99/max ms | Head p50/p95/p99/max ms | Trial p50 ranges ms |')
print('| --- | --- | --- | --- |')
for action, before in base['actions'].items():
    after = head['actions'][action]
    if before['n'] != after['n']:
        raise ValueError(f'Missing {action} samples')
    shifts = [b['p50'] - a['p50'] for a, b in zip(before['trials'], after['trials'])]
    if any(not math.isfinite(shift) for shift in shifts):
        raise ValueError('Invalid trial timing')
    result['actions'][action] = {'base': before, 'head': after,
                                 'pairedP50ChangesMs': shifts,
                                 'medianPairedP50ChangeMs': statistics.median(shifts)}
    columns = [' / '.join(f'{row[key]:.2f}' for key in ('p50', 'p95', 'p99', 'max')) for row in (before, after)]
    ranges = [' to '.join(f'{value:.2f}' for value in row['trialMedianRangeMs']) for row in (before, after)]
    print(f'| {action} | {columns[0]} | {columns[1]} | {ranges[0]} / {ranges[1]} |')
(args.evidence / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n')
