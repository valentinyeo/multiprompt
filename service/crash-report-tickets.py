import argparse
from collections import defaultdict
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def command(args):
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=120)
    return result.stdout


def board(*args):
    value = json.loads(command([os.environ.get('CRASH_BOARD_COMMAND', 'ceo-ht'), *args, '--json']))
    if value.get('success') is not True:
        raise RuntimeError('Board operation failed')
    return value


def activity(ticket, text):
    command([os.environ.get('CRASH_BOARD_COMMAND', 'ceo-ht'), 'activity', 'add', ticket, text])


def signature(row):
    key = [row['app_version'], row['thread'], row['summary'], row['stack_trace'].replace('\r\n', '\n').strip()]
    return hashlib.sha256(json.dumps(key, ensure_ascii=True).encode()).hexdigest()


def receipt(row):
    return hashlib.sha256(json.dumps([row['device_id'], row['report_id']]).encode()).hexdigest()


def reports():
    spec = importlib.util.spec_from_file_location('reader', Path(__file__).with_name('crash-reports.py'))
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    token = os.environ.get('CLOUDFLARE_API_TOKEN') or command(['yeo-key', 'Multiprompt Account Deploy', 'CLOUDFLARE_API_TOKEN']).strip()
    account = os.environ['CLOUDFLARE_ACCOUNT_ID']
    headers = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
    prefix = '/accounts/' + account + '/d1/database'
    base = os.environ.get('CLOUDFLARE_API_BASE_URL', 'https://api.cloudflare.com/client/v4').rstrip('/')
    databases = reader.api(base, prefix + '?name=multiprompt-account', headers)
    database = next(d['uuid'] for d in databases if d['name'] == 'multiprompt-account')
    result = reader.api(base, prefix + '/' + database + '/query', headers, {
        'sql': "SELECT device_id,report_id,captured_at,received_at,app_version,thread,summary,stack_trace FROM crash_reports WHERE android_version='Windows' AND summary IN ('Windows freeze','Windows crash') ORDER BY received_at,device_id,report_id",
        'params': [],
    })
    if len(result) != 1 or result[0].get('success') is not True or not isinstance(result[0].get('results'), list):
        raise RuntimeError('Report query failed')
    return result[0]['results']


def save(path, state):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state), encoding='utf-8')
    temporary.replace(path)


def find_ticket(title):
    result = board('task', 'list', '--project', '2060', '--search', title, '--limit', '500')
    if result.get('has_more') or result.get('nextCursor'):
        raise RuntimeError('Ticket search incomplete')
    matches = [t for t in result['tasks'] if t['title'] == title]
    if len(matches) > 1:
        raise RuntimeError('Duplicate report tickets need reconciliation')
    return matches[0] if matches else None


def triage(rows, path):
    state = json.loads(path.read_text()) if path.exists() else {}
    groups = defaultdict(list)
    for row in rows:
        groups[signature(row)].append(row)
    for sig, group in groups.items():
        title = 'Multiprompt stopped working: report ' + str(int(sig[:12], 16))
        entry = state.get(sig)
        task = None
        if entry is None:
            task = find_ticket(title)
            if task is None:
                created = board('task', 'create', '--project', '2060', '--section', 'Todo', '--labels', 'Multiprompt', '--priority', 'high', '--title', title, '--description', '<h2>Problem</h2><ul><li>Multiprompt stopped responding.</li><li>The saved report arrived automatically.</li></ul><h2>Fix</h2><p>Find and fix this recorded freeze.</p><h2>Done when</h2><p>The recorded freeze cannot happen again.</p><h2>Risk</h2><p>A wrong fix leaves the freeze unchanged.</p><h2>Decision</h2><p>None.</p>')
                task = (created.get('tasks') or [created.get('task')])[0]
            ticket = task['ticketNumber']
            entry = {'ticket': ticket, 'receipts': []}
            state[sig] = entry
            save(path, state)
        ticket = entry['ticket']
        pending = {receipt(row): row for row in group if receipt(row) not in entry['receipts']}
        if not pending:
            continue
        log = board('task', 'agent-log', ticket, '--limit', '100')['activities']
        logged = '\n'.join(a['text'] for a in log)
        for ident, row in pending.items():
            marker = 'freeze-receipt:' + ident
            if marker not in logged:
                current = board('task', 'get', ticket)['tasks'][0]
                if current['section'] == 'Done':
                    board('task', 'move', ticket, '--section', 'Todo')
                activity(ticket, f"Automatic desktop report. signature:{sig}\nCount: {len(entry['receipts']) + 1}; version: {row['app_version']}; captured: {row['captured_at']}; kind: {row['summary']}\n{row['stack_trace']}\n{marker}")
            entry['receipts'].append(ident)
            save(path, state)
        print(f'TRIAGED {ticket} count={len(entry["receipts"])} signature={sig}')


def ci_proof(run_id, ticket, state_dir):
    marker = 'freeze-ci-run:' + run_id
    log = board('task', 'agent-log', ticket, '--limit', '100')['activities']
    if any(marker in a['text'] for a in log):
        return
    run = json.loads(command([os.environ.get('CRASH_GH_COMMAND', 'gh'), 'run', 'view', run_id, '--repo', 'valentinyeo/multiprompt', '--json', 'conclusion,workflowName,url,headSha']))
    if run['conclusion'] is None or run['conclusion'] == '':
        return
    if run['conclusion'] != 'success' or run['workflowName'] != 'Freeze recorder':
        raise RuntimeError('Forced freeze workflow did not pass')
    with tempfile.TemporaryDirectory(dir=state_dir) as directory:
        command([os.environ.get('CRASH_GH_COMMAND', 'gh'), 'run', 'download', run_id, '--repo', 'valentinyeo/multiprompt', '--name', 'freeze-evidence', '--dir', directory])
        proof = json.loads((Path(directory) / 'result.json').read_text())
        text = (Path(directory) / 'first-freeze.txt').read_text()
        if proof['healthyReports'] != 0 or proof['firstStallReports'] != 1 or proof['secondStallReports'] != 2:
            raise RuntimeError('Forced freeze evidence counts invalid')
        if not re.search(r'^thread_context: captured$', text, re.M) or not re.search(r'^  0x[0-9A-F]+$', text, re.M):
            raise RuntimeError('Forced freeze thread context missing')
        activity(ticket, f"Automatic CI freeze receipt. {marker}\nRun: {run['url']}\nCommit: {run['headSha']}\nHealthy: 0 reports; first forced stall: 1; second: 2.\n{text}")
        print('CI_FREEZE_RECEIPT_OK ' + run['url'])


def main():
    parser = argparse.ArgumentParser(description='Turn uploaded Windows freeze/crash signatures into Software Factory tickets.')
    parser.add_argument('--state-dir', type=Path, default=Path.home() / '.local/state/multiprompt-crash-tickets')
    parser.add_argument('--ci-run', default=os.environ.get('CRASH_CI_RUN'), help='Optional forced-freeze GitHub run to acknowledge automatically')
    parser.add_argument('--proof-ticket', default='IGSH-1170')
    args = parser.parse_args()
    import fcntl
    args.state_dir.mkdir(parents=True, exist_ok=True)
    with (args.state_dir / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        triage(reports(), args.state_dir / 'receipts.json')
        if args.ci_run:
            ci_proof(args.ci_run, args.proof_ticket, args.state_dir)


if __name__ == '__main__':
    main()
