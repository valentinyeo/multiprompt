import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

POLICY = 'aggregate statistics only; all fixture text generated'
FRAME_SCOPE = 'first observed after completed target-paint log; not compositor-first-present'
TIMING_SCOPE = 'first nonempty cached target paint; latest-message receipt verified after timing'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value, name):
    require(type(value) in (int, float) and math.isfinite(value) and value >= 0, name + ' must be a finite nonnegative measurement')
    return value


def cpu(sample):
    elapsed = number(sample['elapsed_ms'], 'elapsed_ms')
    require(elapsed > 0 and sample['forced_paints'] is False and sample['image_probe'] is False, 'ordinary CPU window must not paint or capture')
    total = number(sample['cpu_ms'], 'cpu_ms')
    require(abs(number(sample['cpu_one_core_percent'], 'cpu_one_core_percent') - 100 * total / elapsed) < 0.001, 'CPU must use one-core process time')
    number(sample['observer_cpu_ms'], 'observer_cpu_ms')
    require(0 <= number(sample['machine_busy_percent'], 'machine_busy_percent') <= 100, 'machine busy percentage')
    points = sample['cpu_points']
    require(len(points) >= 2 and points[0] == dict(elapsed_ms=0, cpu_ms=0), 'CPU window needs an initial counter')
    previous_time, previous_cpu, peak = 0, 0, 0
    for point in points[1:]:
        time = number(point['elapsed_ms'], 'CPU point time')
        used = number(point['cpu_ms'], 'CPU point counter')
        require(time > previous_time and used >= previous_cpu, 'CPU counters must be ordered and cumulative')
        peak = max(peak, 100 * (used - previous_cpu) / (time - previous_time))
        previous_time, previous_cpu = time, used
    require(abs(previous_time - elapsed) < 0.001 and abs(previous_cpu - total) < 0.001, 'CPU points must cover the entire window')
    if 'owned_job' in sample:
        job = sample['owned_job']
        window = number(job['elapsed_ms'], 'owned job interval')
        used = number(job['cpu_ms'], 'owned job CPU')
        require(window >= elapsed and abs(number(job['cpu_one_core_percent'], 'owned job CPU percentage') - 100 * used / window) < 0.001, 'owned job CPU accounting differs from its interval')
    return peak


def artifact(root, name):
    path = (root / name).resolve()
    require(path.is_relative_to(root.resolve()), 'artifact escapes evidence directory')
    return path.read_bytes()


def image(root, prefix):
    raw = artifact(root, prefix + '.bmp')
    require(len(raw) >= 54 and raw[:2] == b'BM', 'actual BMP capture missing')
    size, offset = struct.unpack_from('<IxxxxI', raw, 2)
    header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', raw, 14)
    require(header >= 40 and width > 0 and height != 0 and planes == 1 and bits in (24, 32) and compression == 0, 'unsupported BMP capture')
    stride = ((width * bits + 31) // 32) * 4
    require(offset >= 14 + header and size == len(raw) == offset + stride * abs(height), 'BMP pixels are incomplete')
    png = artifact(root, prefix + '.png')
    require(len(png) >= 33 and png[:8] == b'\x89PNG\r\n\x1a\n' and png[12:16] == b'IHDR', 'actual PNG screenshot missing')
    require(struct.unpack_from('>II', png, 16) == (width, abs(height)), 'PNG and BMP capture dimensions differ')
    return hashlib.sha256(raw).hexdigest()


def evaluate(value, root, require_cleanup=False):
    require(value['schema'] == 1 and value['source'] == 'GitHub Windows native desktop', 'native journey evidence required')
    require(value['setup_passed'] is True and not value['errors'], 'setup errors are not switch regressions')
    shells = value['session_shells']
    require(len(shells) == 5 and len(set(shells)) == 5 and all(type(s) is int and s > 0 for s in shells), 'five distinct published sessions required')
    shape_raw = artifact(root, 'chat-shapes.json')
    shapes = json.loads(shape_raw)
    fixture = value['fixture']
    require(shapes['content_policy'] == fixture['policy'] == POLICY, 'private source messages are forbidden')
    require(fixture['shape_sha256'] == hashlib.sha256(shape_raw).hexdigest(), 'fixture must match the recorded public numeric shapes')
    require(len(shapes['sessions']) == len(fixture['sessions']) == 5, 'five measured shape profiles required')
    for profile, generated in zip(shapes['sessions'], fixture['sessions']):
        require(generated['name'] == profile['name'] and generated['source_completeness'] == profile['source_completeness'], 'profile identity/completeness changed')
        require(generated['source_conversation_messages'] == profile['conversation_messages'] and generated['marker_messages'] == 2, 'conversation counts changed')
        require(generated['generated_conversation_messages'] == profile['conversation_messages'] + 2, 'generated conversation count changed')
        require(generated['runner_messages'] == sum(count for size, count in profile['runner_lengths_utf16']), 'runner length coverage changed')
        require(generated['tool_records'] == sum(count for size, count in profile['tool_record_bytes']), 'tool record coverage changed')
        if profile['source_completeness'] == 'complete-host-log':
            require(generated['generated_bytes'] == profile['source_bytes'] and generated['generated_records'] == profile['source_records'] + 2, 'complete source byte/record budget changed')
        else:
            require(profile['source_completeness'] == 'partial-desktop-cache-sample' and generated['ignored_source_padding_bytes'] == 0, 'partial source was inflated or mislabelled')
    require(set(value['modes']) == {'browser_closed', 'browser_open'}, 'both browser modes required')
    failures, peak = [], 0
    for mode, samples in value['modes'].items():
        require(len(samples) == 20, 'twenty actual switches per browser mode required')
        targets = []
        previous_target = None
        for index, sample in enumerate(samples):
            require(sample['index'] == index and sample['source_shell'] in shells and sample['target_shell'] in shells and sample['source_shell'] != sample['target_shell'], 'invalid measured switch route')
            if previous_target is not None:
                require(sample['source_shell'] == previous_target, 'switch route sequence is disconnected')
            previous_target = sample['target_shell']
            targets.append(sample['target_shell'])
            require(sample['input'] in ('ctrl-digit', 'sidebar-click') and sample['timing_scope'] == TIMING_SCOPE, 'unrecorded input or paint timing scope')
            peak = max(peak, cpu(sample))
            require(number(sample['layout_width'], 'layout_width') > 0 and number(sample['client_width'], 'client_width') > 0, 'paint geometry must be nonempty')
            require(type(sample['post_paint_moves']) is bool, 'post-paint movement must be observed')
            shown = number(sample['shown_ms'], 'shown_ms')
            hang = number(sample['hang_ms'], 'hang_ms')
            require(shown <= sample['elapsed_ms'], 'paint outside measurement window')
            require(0 <= number(sample['cpu_at_shown_ms'], 'cpu_at_shown_ms') <= sample['cpu_ms'], 'paint CPU counter outside measured interval')
            expected = sample['expected_latest']
            receipt = artifact(root, sample['latest_receipt']).decode('utf-8-sig')
            require(expected and sample['last_marker'] in receipt, 'actual copied session endpoint receipt missing')
            latest = expected in receipt
            require(sample['latest_message_verified'] is latest, 'latest-message verdict differs from the copied receipt')
            probe = sample['frame_probe']
            require(probe['source_shell'] == sample['source_shell'] and probe['target_shell'] == sample['target_shell'] and probe['image_probe'] is True and probe['forced_paints'] is False, 'image replay must follow the same route separately')
            require(probe['frame_scope'] == FRAME_SCOPE, 'first-observation scope must remain explicit')
            require(number(probe['shown_ms'], 'image paint time') <= number(probe['capture_started_ms'], 'capture start') <= number(probe['capture_completed_ms'], 'capture end') <= number(probe['elapsed_ms'], 'image interval'), 'image capture timing missing')
            first = image(root, probe['image_prefix'] + '-first-observed')
            settled = image(root, probe['image_prefix'] + '-settled')
            if not latest or shown >= 150 or hang >= 100 or first != settled or sample['layout_width'] != sample['client_width'] or sample['post_paint_moves']:
                failures.append(dict(mode=mode, index=index, shown_ms=shown, hang_ms=hang, latest_message_verified=latest, first_observed_matches_settled=first == settled))
        require(all(targets.count(shell) == 4 for shell in shells), 'each of five sessions needs four measured visits per mode')
    require(set(value['idle']) == {'before', 'after'}, 'matching idle observations required')
    for sample in value['idle'].values():
        require(sample['input'] == 'idle', 'idle baseline must not switch')
        cpu(sample)
    if require_cleanup:
        tree = json.loads(artifact(root, 'process-tree.json').decode('utf-8-sig'))
        result = json.loads(artifact(root, 'result.json').decode('utf-8-sig'))
        require(tree['activeAfterStop'] == 0 and result['scratchRemoved'] is True, 'owned process/scratch cleanup incomplete')
    limitations = [FRAME_SCOPE, TIMING_SCOPE, 'one profile is a partial cache sample; message order and layout semantics are generated']
    if any(sample['input'] != 'sidebar-click' for samples in value['modes'].values() for sample in samples):
        limitations.insert(0, 'Ctrl+digit path, not sidebar-click proof')
    return dict(status='failed' if failures else 'passed', category='switch-budget' if failures else 'within-observed-budgets', product_acceptance_proven=False,
                failures=failures, switches=40, peak_observed_one_core_percent=peak, limitations=limitations)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence')
    parser.add_argument('--require-cleanup', action='store_true')
    parser.add_argument('--expect-regression', action='store_true')
    args = parser.parse_args()
    path = Path(args.evidence)
    try:
        result = evaluate(json.loads(path.read_text(encoding='utf-8-sig')), path.parent, args.require_cleanup)
    except (ValueError, KeyError, TypeError, OSError, IndexError, struct.error) as error:
        result = dict(status='failed', category='invalid-evidence', error=str(error))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.with_name('shape-switch-verdict.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
    if args.expect_regression:
        recorded = result['category'] == 'switch-budget' and any(sample['latest_message_verified'] is False for sample in result['failures'])
        if recorded:
            print('BASELINE_STALE_REPLY_RECORDED')
        raise SystemExit(0 if recorded else 1)
    raise SystemExit(0 if result['status'] == 'passed' else 1)
