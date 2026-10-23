import argparse
from datetime import datetime, timezone
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def api(base, path, headers, data=None):
    request = urllib.request.Request(
        base + path,
        headers=headers,
        data=None if data is None else json.dumps(data).encode('utf-8'),
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.loads(response.read().decode('utf-8'))
    if not result['success']:
        raise RuntimeError('Cloudflare operation failed')
    return result['result']


def utc(seconds):
    try:
        return datetime.fromtimestamp(seconds, timezone.utc).isoformat()
    except (ValueError, OverflowError, OSError):
        return str(seconds) + ' (outside UTC range)'


def format_report(report):
    text = '\n'.join([
        'Device: ' + (report['device_name'] or report['device_id']),
        'Report: ' + report['report_id'],
        'Received: ' + utc(report['received_at']),
        'Captured: ' + utc(report['captured_at']),
        'App version: ' + report['app_version'],
        'Android version: ' + report['android_version'],
        'Thread: ' + report['thread'],
        'Summary: ' + report['summary'],
        'Stack trace:',
        report['stack_trace'],
    ])
    return ''.join(f'\\u{ord(c):04x}' if ord(c) < 32 and c not in '\n\t' or 127 <= ord(c) <= 159 else c for c in text)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description='Read Android crash reports from Cloudflare D1.',
        epilog='Uses CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN; never reads credential files.',
    )
    parser.add_argument('--limit', type=int, default=20, help='maximum reports to show (positive integer, default: 20)')
    parser.add_argument('--database', default='multiprompt-account', help='D1 database name (default: multiprompt-account)')
    parser.add_argument('--device', help='show reports only for this device ID')
    parser.add_argument('--json', action='store_true', help='print raw result rows as JSON')
    args = parser.parse_args(argv)
    if args.limit < 1:
        parser.error('--limit must be positive')
    for name in ('CLOUDFLARE_ACCOUNT_ID', 'CLOUDFLARE_API_TOKEN'):
        if not os.environ.get(name, '').strip():
            parser.error('Missing required environment variable: ' + name)
    headers = {'Authorization': 'Bearer ' + os.environ['CLOUDFLARE_API_TOKEN'], 'Content-Type': 'application/json'}
    base = os.environ.get('CLOUDFLARE_API_BASE_URL', 'https://api.cloudflare.com/client/v4').rstrip('/')
    prefix = '/accounts/' + urllib.parse.quote(os.environ['CLOUDFLARE_ACCOUNT_ID'], safe='') + '/d1/database'
    databases = api(base, prefix + '?' + urllib.parse.urlencode({'name': args.database}), headers)
    database = next((d for d in databases if d['name'] == args.database), None)
    if database is None:
        parser.error('D1 database not found; check --database')
    sql = (
        'SELECT c.device_id,c.report_id,d.name AS device_name,c.received_at,c.captured_at,'
        'c.app_version,c.android_version,c.thread,c.summary,c.stack_trace '
        'FROM crash_reports c LEFT JOIN devices d ON d.id=c.device_id'
    )
    params = []
    if args.device is not None:
        sql += ' WHERE c.device_id=?'
        params.append(args.device)
    sql += ' ORDER BY c.received_at DESC,c.rowid DESC LIMIT ?'
    params.append(args.limit)
    result = api(base, prefix + '/' + urllib.parse.quote(database['uuid'], safe='') + '/query', headers, {'sql': sql, 'params': params})
    if not result[0]['success']:
        raise RuntimeError('D1 query failed')
    rows = result[0]['results']
    print(json.dumps(rows, ensure_ascii=True) if args.json else '\n\n'.join(format_report(row) for row in rows))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    try:
        main()
    except (KeyError, ValueError, RuntimeError, IndexError, urllib.error.URLError):
        sys.exit('Crash report read failed; check Cloudflare credential, account and D1 schema.')
