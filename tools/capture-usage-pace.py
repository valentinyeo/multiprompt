import argparse
import json
import math
import pathlib
import time


def number(value):
    if value is None or type(value) in (int, float) and math.isfinite(value):
        return value
    raise ValueError('Invalid numeric usage field')


def sanitize(snapshot, now):
    ts = number(snapshot.get('ts'))
    if ts is None or now - ts > 1800 or ts > now + 60:
        raise ValueError('Stale usage snapshot')
    mode, override = snapshot.get('mode'), snapshot.get('override', 'auto')
    if mode not in ('claude', 'codex') or override not in ('auto', 'claude', 'codex'):
        raise ValueError('Invalid usage mode')
    accounts = snapshot.get('accounts')
    if not isinstance(accounts, list) or not accounts:
        raise ValueError('Missing usage accounts')
    counts, safe = {}, []
    for account in accounts:
        provider = account.get('provider')
        if provider not in ('claude', 'codex'):
            raise ValueError('Unsupported usage provider')
        counts[provider] = counts.get(provider, 0) + 1
        ordinal = counts[provider]
        item = {'id': f'{provider}-{ordinal}', 'label': f'{provider.title()} {ordinal}',
                'provider': provider, 'stale': account.get('stale') is True}
        for name in ('week', 'five_hour'):
            window = account.get(name) or {}
            pace = window.get('pace')
            fields = ('per_hour', 'per_day', 'ratio', 'empty_hours')
            if not isinstance(pace, dict) or not all(field in pace for field in (*fields, 'verdict')):
                raise ValueError('Missing pace block')
            if pace['verdict'] not in ('above', 'on', 'below', 'unknown'):
                raise ValueError('Invalid pace verdict')
            item[name] = {field: number(window.get(field)) for field in ('used', 'time_gone', 'resets_at', 'hours_left')}
            item[name]['pace'] = {field: number(pace[field]) for field in fields}
            item[name]['pace']['verdict'] = pace['verdict']
        safe.append(item)
    return {'ts': ts, 'mode': mode, 'override': override, 'accounts': safe}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=pathlib.Path)
    args = parser.parse_args()
    value = sanitize(json.loads(args.source.read_text()), time.time())
    print(json.dumps(value, indent=2, allow_nan=False))
