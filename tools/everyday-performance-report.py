import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import re
import statistics

parser = argparse.ArgumentParser()
parser.add_argument('baseline', type=Path)
parser.add_argument('--profile', type=Path)
args = parser.parse_args()
ACTIONS = ('typing', 'switching', 'opening', 'scrolling', 'streaming')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def stats(values):
    ordered = sorted(values)
    return dict(n=len(ordered), p50=statistics.median(ordered),
                p95=ordered[math.ceil(len(ordered) * .95) - 1],
                p99=ordered[math.ceil(len(ordered) * .99) - 1], max=ordered[-1])


machine = read(args.baseline / 'machine.json')
if machine['profile']:
    raise ValueError('Instrumented runs cannot supply baseline percentiles')
trials = sorted(args.baseline.glob('trial-*/samples.json'))
if len(trials) != machine['trials']:
    raise ValueError('Missing trials')
samples = defaultdict(list)
trial_stats = defaultdict(list)
controls = []
for file in trials:
    trial = read(file)
    if trial['failure'] or trial['errors']:
        raise ValueError(f'Failed trial: {file}: {trial["failure"]}')
    if 'Some app changes could not be saved' in file.with_name('debug.log').read_text(encoding='utf-8-sig'):
        raise ValueError(f'App save failure invalidates trial: {file}')
    if read(file.with_name('cleanup.json'))['ActiveProcesses'] != 0:
        raise ValueError('Owned processes leaked')
    if not read(file.with_name('stream-receipt.json'))['exactLatestFound']:
        raise ValueError('Latest streamed output not confirmed')
    for action in ACTIONS:
        batch = [s for s in trial['samples'] if s['action'] == action]
        if len(batch) != machine.get('sampleCounts', {}).get(action, machine['sampleCount']) or any(not s['success'] or not math.isfinite(s['ms']) or s['ms'] < 0 or not s['proof'] for s in batch):
            raise ValueError(f'Invalid {action} samples: {file}')
        values = [s['ms'] for s in batch]
        samples[action].extend(values)
        trial_stats[action].append(stats(values))
    control = file.with_name('control.json')
    if control.exists():
        controls.extend(read(control)['compositorControlMs'])
report = dict(machine=machine, errors=0, trials=len(trials), actions={})
for action in ACTIONS:
    row = stats(samples[action])
    row['trials'] = trial_stats[action]
    row['trialMedianRangeMs'] = [min(s['p50'] for s in trial_stats[action]), max(s['p50'] for s in trial_stats[action])]
    report['actions'][action] = row
if controls:
    report['compositorControlMs'] = stats(controls)
if args.profile:
    profile_machine = read(args.profile / 'machine.json')
    if not profile_machine['profile']:
        raise ValueError('Expected separate profiling replay')
    baseline_build = read(args.baseline / 'build.json')
    profile_build = read(args.profile / 'build.json')
    if any(baseline_build[k] != profile_build[k] for k in ('sourceTree', 'build')):
        raise ValueError('Profile and baseline use different product sources')
    spans_by_name = defaultdict(list)
    by_action = defaultdict(lambda: defaultdict(list))
    slow_windows = []
    components = defaultdict(lambda: defaultdict(list))
    blocked_inputs = []
    for file in sorted(args.profile.glob('trial-*/samples.json')):
        trial = read(file)
        if trial['failure'] or trial['errors'] or not read(file.with_name('stream-receipt.json'))['exactLatestFound']:
            raise ValueError(f'Profile replay failed: {file}')
        spans = []
        for match in re.finditer(r'PERFSPAN name=(\S+) start=(\d+) end=(\d+) us=(\d+) tid=(\d+)', file.with_name('debug.log').read_text(encoding='utf-8-sig')):
            name, start, end, us, tid = match.groups()
            span = dict(name=name, start=int(start), end=int(end), ms=int(us) / 1000, tid=int(tid))
            spans.append(span)
            spans_by_name[name].append(span['ms'])
        for sample in trial['samples']:
            for field in ('inputReturnMs', 'acknowledgedMs', 'compositorWaitMs'):
                if field in sample:
                    components[sample['action']][field].append(sample[field])
            if 'acknowledgedMs' in sample and abs(sample['acknowledgedMs'] + sample['compositorWaitMs'] - sample['ms']) > .5:
                raise ValueError('Timing components do not sum to elapsed time')
            selected = [s for s in spans if s['end'] >= sample['startQpc'] and s['start'] <= sample['endQpc']]
            if sample['action'] == 'switching' and sample.get('inputReturnMs', 0) > 100:
                input_end = sample['startQpc'] + sample['inputReturnMs'] * profile_machine['qpcFrequency'] / 1000
                layouts = [s for s in selected if s['name'] == 'chat_render.zig:chatRelayout' and s['start'] < input_end]
                overlap_ms = sum(max(0, min(s['end'], input_end) - max(s['start'], sample['startQpc'])) * 1000 / profile_machine['qpcFrequency'] for s in layouts)
                blocked_inputs.append(dict(index=sample['index'], inputMs=sample['inputReturnMs'], layoutOverlapMs=overlap_ms, layouts=layouts))
            for span in selected:
                by_action[sample['action']][span['name']].append(span['ms'])
            slow_windows.append(dict(action=sample['action'], index=sample['index'], ms=sample['ms'], startQpc=sample['startQpc'], spans=sorted(selected, key=lambda s: s['ms'], reverse=True)[:8]))
    report['profile'] = dict(
        warning='Separate instrumented replay; inclusive spans >=1ms, nested times must not be added; not baseline latency. Overlap is association, not proof of critical path.',
        blockedInputs=blocked_inputs,
        components={action: {name: stats(v) for name, v in fields.items()} for action, fields in components.items()},
        stages={name: stats(v) | {'sumMs': sum(v)} for name, v in spans_by_name.items()},
        actions={action: {name: stats(v) | {'sumMs': sum(v)} for name, v in groups.items()} for action, groups in by_action.items()},
        slowWindows=sorted(slow_windows, key=lambda s: s['ms'], reverse=True)[:30])
output = args.baseline / 'report.json'
output.write_text(json.dumps(report, indent=2) + '\n')
print('| Action | n | p50 ms | p95 ms | p99 ms | max ms | trial p50 range ms |')
print('| --- | ---: | ---: | ---: | ---: | ---: | --- |')
for action, row in report['actions'].items():
    print(f'| {action} | {row["n"]} | {row["p50"]:.2f} | {row["p95"]:.2f} | {row["p99"]:.2f} | {row["max"]:.2f} | {row["trialMedianRangeMs"][0]:.2f}–{row["trialMedianRangeMs"][1]:.2f} |')
print(f'Errors: 0; trials: {len(trials)}; report: {output}')
