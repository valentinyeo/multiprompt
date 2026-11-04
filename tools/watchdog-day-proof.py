import argparse
import json
from pathlib import Path
import re
import time


HEALTH = 'Windows watchdog health'
TRACE = re.compile(r'observed_ms: (\d+)\nresponsive_ms: (\d+)\nunobserved_ms: (\d+)\nfreezes: (\d+)\n')
IDENTITY = re.compile(r'watchdog-(\d+)-(\d+)-(\d+)-(\d+)')
DAY_MS = 8 * 60 * 60 * 1000


def inspect(rows, now=None, device=None):
    now = int(time.time()) if now is None else now
    if device is not None:
        rows = [row for row in rows if row.get('device_id') == device]
    sessions = {}
    for row in rows:
        if row.get('summary') != HEALTH or row.get('android_version') != 'Windows' or row.get('thread') != 'watchdog':
            continue
        identity = IDENTITY.fullmatch(row.get('report_id', row.get('id', '')))
        trace = TRACE.fullmatch(row.get('stack_trace', ''))
        if not identity or not trace:
            continue
        started, process, clock, sequence = map(int, identity.groups())
        observed, responsive, unobserved, freezes = map(int, trace.groups())
        captured = row.get('captured_at')
        device = row.get('device_id')
        version = row.get('app_version')
        if not isinstance(captured, int) or not isinstance(device, str) or not device or not isinstance(version, str):
            continue
        if responsive > observed or captured < started or captured > now or now - captured > 5400 or observed + unobserved > (captured - started + 2) * 1000:
            continue
        key = (device, version, started, process, clock)
        value = dict(sequence=sequence, started=started, captured=captured, observed_ms=observed, responsive_ms=responsive, unobserved_ms=unobserved, freezes=freezes)
        sessions.setdefault(key, []).append(value)
    best = 0
    qualified = 0
    for (device, version, _, _, _), history in sessions.items():
        history.sort(key=lambda value: value['sequence'])
        counters = ('captured', 'observed_ms', 'responsive_ms', 'unobserved_ms', 'freezes')
        if any(new[field] < old[field] for old, new in zip(history, history[1:]) for field in counters):
            continue
        value = history[-1]
        incident = any(row.get('device_id') == device and row.get('android_version') == 'Windows' and row.get('summary') in ('Windows freeze', 'Windows crash') and isinstance(row.get('captured_at'), int) and value['started'] <= row['captured_at'] <= now for row in rows)
        if value['freezes'] or value['unobserved_ms'] or incident:
            continue
        best = max(best, value['responsive_ms'])
        if value['responsive_ms'] >= DAY_MS:
            qualified += 1
    return dict(status='passed' if qualified else 'observing', qualified_sessions=qualified, responsive_ms=best, required_ms=DAY_MS, sessions_seen=len(sessions))


def main():
    parser = argparse.ArgumentParser(description='Verify eight hours of real awake watchdog coverage, not absence of incident reports.')
    parser.add_argument('reports', type=Path, help='JSON rows from the authenticated crash report reader; keep private')
    parser.add_argument('--device', required=True, help='actual desktop device ID, never a hosted fixture')
    args = parser.parse_args()
    result = inspect(json.loads(args.reports.read_text(encoding='utf-8')), device=args.device)
    print(json.dumps(result))
    return 0 if result['status'] == 'passed' else 2


if __name__ == '__main__':
    raise SystemExit(main())
