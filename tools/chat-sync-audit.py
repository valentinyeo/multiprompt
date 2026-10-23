import argparse
import html
import importlib.util
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
SETTLE_SECONDS = 5


def load_reader():
    spec = importlib.util.spec_from_file_location('chat_reader_audit', ROOT / 'src/chat_history_reader.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(argv, **kwargs):
    return subprocess.run(argv, capture_output=True, text=True, timeout=60, check=True, **kwargs).stdout


def chat_agent(argv):
    if argv and Path(argv[0]).name in ('node', 'bun'):
        argv = argv[1:]
    return not (argv and Path(argv[0]).name in ('codex', 'codex.js') and argv[1:2] == ['cloud'])


def normalize(text):
    text = text.translate(str.maketrans('‘’“”', '\'\'""'))
    text = re.sub(r'</?pasted_content\b[^>]*>', ' ', text, flags=re.I)
    return ' '.join(text.split())


def pane_candidates(capture):
    candidates = []
    lines = capture.splitlines()
    for line_no, line in enumerate(lines[:-8], 1):
        line = ANSI.sub('', line).strip()
        if line.startswith('● ') and not re.match(r'^● [A-Za-z_]+\(', line):
            if ANSI.sub('', lines[line_no]).lstrip().startswith('⎿'):
                continue
            text = line[2:].strip()
            if text.endswith('·') and re.fullmatch(r'(?:\d+[hms]\s*)+…?', ANSI.sub('', lines[line_no]).strip()):
                continue
        elif re.match(r'^[❯›>] ', line):
            text = line[2:].strip()
        else:
            continue
        if re.match(r'^/rename(?:\s|$)|^Advising using .+ \d+(?:\.\d+)+$', text):
            continue
        if text.startswith('Message from @') or re.search(r' · (?:\d+[hms]\s*)+…?$', text):
            continue
        if re.match(r'^(?:Running \d+ shell commands?\b|Compacted while idle\b|Background command "|Monitor event:)', text):
            continue
        if line.startswith('● ') and re.fullmatch(r'Task ".*" still running in background', text):
            continue
        if line.startswith('● ') and re.match(r'^Build in progress \(~?\d+(?:\.\d+)? min\); ', text):
            continue
        if re.fullmatch(r'[A-Z][a-z]+ing \d+ [^,…]+(?:(?:, [a-z]+ing \d+ [^,…]+)+…?|…)', text):
            continue
        text = normalize(text)
        if len(text) >= 20:
            candidates.append(dict(text=text[:80], probe=text[:60], pane_line=line_no))
    return candidates


def transcript_evidence(reader, path, wire, finding):
    fields = wire.splitlines()[0].split('\t')
    base, end = int(fields[5]), int(fields[6])
    evidence = []
    rows = [json.loads(line) for line in wire.splitlines()[1:-1]]
    row = finding.get('row', 0)
    target = rows[row - 1] if 0 < row <= len(rows) else None
    offset = 0
    with path.open('rb') as source:
        for line_number, line in enumerate(source, 1):
            if not line.endswith(b'\n'):
                break
            at = offset
            offset += len(line)
            if finding['kind'] != 'pane_missing' and not base <= at < end:
                continue
            event = json.loads(line)
            messages = [row for row in reader.conversation_rows(event, fields[9], at) if row['role'] in ('user', 'assistant')]
            record = 'conversation'
            if not messages:
                fact = reader.settlement_event(event, fields[9])
                messages = [fact] if fact else []
                if fact and fact['settlement']['content'].lstrip().startswith('<task-notification>'):
                    record = 'task_notification'
            matches = False
            for message in messages:
                content = message.get('settlement', {}).get('content', message['text'])
                matches = target is not None and content == target.get('settlement', {}).get('content', target['text'])
                if target is None and finding.get('text'):
                    plain = normalize(content.replace('**', '').replace('`', ''))
                    matches = normalize(finding['text'])[:60] in plain
                if matches:
                    break
            if not messages:
                if finding['kind'] == 'pane_missing' and event.get('type') == 'system' and isinstance(event.get('content'), str):
                    matches = normalize(finding['text'])[:60] in normalize(event['content'].replace('**', '').replace('`', ''))
                    record = 'system_notice'
                content = (event.get('message') or {}).get('content', [])
                if finding['kind'] == 'pane_missing' and isinstance(content, list):
                    for part in content:
                        if not isinstance(part, dict):
                            continue
                        if part.get('type') == 'thinking':
                            value, record = part.get('thinking', ''), 'thinking'
                        elif part.get('type') == 'tool_use':
                            value, record = (part.get('input') or {}).get('description', ''), 'tool_activity'
                        else:
                            continue
                        if isinstance(value, str) and normalize(finding['text'])[:60] in normalize(value.replace('**', '').replace('`', '')):
                            matches = True
                            break
            if matches:
                evidence.append(dict(line=line_number, timestamp=event.get('timestamp', ''), record=record,
                                     location='before_cold_tail' if at < base else 'after_snapshot' if at >= end else 'in_window'))
    return evidence[-8:]


def not_drift(item, wire):
    if item['kind'] != 'pane_missing' or not item['transcript_lines']:
        return False
    user = False
    for line in wire.splitlines()[1:-1]:
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict) and row.get('role') == 'user':
            user = True
            break
    return all(row['record'] != 'conversation' or row['location'] == 'after_snapshot' or
               row['location'] == 'before_cold_tail' and user for row in item['transcript_lines'])


def settle_pending(reader, path, wire, findings, sleep=time.sleep):
    if not any(item['kind'] == 'pane_missing' and not item['transcript_lines'] for item in findings):
        return findings
    sleep(SETTLE_SECONDS)
    settled = []
    for item in findings:
        if item['kind'] == 'pane_missing' and not item['transcript_lines']:
            item['transcript_lines'] = transcript_evidence(reader, path, wire, item)
            if not_drift(item, wire):
                continue
        settled.append(item)
    return settled


def audit_pane(reader, pane, session, agent, agent_pid, binary, sleep=time.sleep):
    resolved = reader.resolve_tmux_agent(agent, session, agent_pid)
    if not resolved:
        return [dict(kind='transcript_missing', session=session, pane=pane, text='Live agent transcript could not be resolved')]
    sid, path = resolved
    truth_sid, _ = reader.claude_session_metadata(agent_pid) if agent == 'claude' else (None, None)
    context = dict(session=session, pane=pane, transcript=str(path))
    if truth_sid and truth_sid != sid:
        return [dict(context, kind='transcript_mismatch', text='Resolved transcript differs from live agent metadata')]
    query = dict(id=1, codex=agent == 'codex', sid=sid, tmux=session,
                 cwd=reader.read_process_cwd(agent_pid) or '', settlement=True, cached_sid='',
                 inode=0, offset=0, start=0, before=0, mtime=0, probe='')
    capture = run(['tmux', 'capture-pane', '-p', '-J', '-t', pane, '-S', '-120'])
    wire = reader.response(query, reader.READER_SOURCE)
    if '\thistory\tok\t' not in wire.splitlines()[0]:
        return [dict(context, kind='transcript_missing', text=wire.splitlines()[0][-80:])]
    candidates = pane_candidates(capture)
    argv = [str(binary)]
    for candidate in candidates:
        argv.extend(['--contains', candidate['probe']])
    output = run(argv, input=wire)
    findings = []
    for line in output.splitlines():
        item = json.loads(line)
        if 'probe' in item:
            if item['present']:
                continue
            candidate = candidates[item['probe']]
            item = dict(kind='pane_missing', text=candidate['text'], pane_line=candidate['pane_line'])
        item['text'] = item.get('text', '')[:80]
        item.update(context)
        item['transcript_lines'] = transcript_evidence(reader, path, wire, item)
        if not_drift(item, wire):
            continue
        findings.append(item)
    return settle_pending(reader, path, wire, findings, sleep)


def ticket_is_open(ticket):
    value = json.loads(run(['project', '--json', 'task', 'get', str(ticket)]))
    task = value['tasks'][0] if value.get('tasks') else value.get('task', value.get('data', value))
    section = task.get('section', task.get('sectionName', task.get('section_name')))
    if isinstance(section, dict):
        section = section.get('name', section.get('title'))
    if not isinstance(section, str):
        raise ValueError('Ticket response has no section name; refusing duplicate filing')
    return section.lower() != 'done'


def file_tickets(findings, state_path):
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    for kind in sorted({item['kind'] for item in findings}):
        if kind in state and ticket_is_open(state[kind]):
            continue
        details = []
        for item in findings:
            if item['kind'] != kind:
                continue
            details.append('<li>Session: ' + html.escape(item.get('session', '')) +
                           '<br>Transcript: ' + html.escape(item.get('transcript', 'unresolved')) +
                           '<br>Lines/timestamps: ' + html.escape(json.dumps(item.get('transcript_lines', []))) +
                           '<br>Evidence: ' + html.escape(item.get('text', '')[:80]) + '</li>')
        description = '<ul>' + ''.join(details) + '</ul><p>Filed by the chat sync audit.</p>'
        output = run(['project', 'task', 'create', '--project', '2060', '--section', 'Todo',
                      '--title', 'Chat sync audit: ' + kind + ' drift', '--labels', 'Desktop App,Bug',
                      '--description', description])
        match = re.search(r'"ticketNumber":\s*"([A-Z][A-Z0-9]*-\d+)"', output)
        if not match:
            raise ValueError('Ticket creation returned no ticket number; check board before retrying')
        state[kind] = match.group(1)
        state_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = state_path.with_suffix('.tmp')
        temporary.write_text(json.dumps(state, indent=2) + '\n')
        temporary.replace(state_path)


def main():
    parser = argparse.ArgumentParser(description='Compare live agent panes with the desktop Chat View reader and renderer.')
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--file-tickets', action='store_true')
    parser.add_argument('--state', type=Path, default=Path.home() / '.local/state/mp-chat-audit/state.json')
    args = parser.parse_args()
    findings = []
    checked = 0
    try:
        reader = load_reader()
        table = reader.process_table()
        panes = run(['tmux', 'list-panes', '-a', '-F', '#{pane_id}\t#{session_name}\t#{pane_pid}'])
        for line in panes.splitlines():
            pane, session, pid = line.split('\t')
            for agent in ('claude', 'codex'):
                agent_pid = reader.agent_pid_for_panes([int(pid)], table, agent)
                if agent_pid is None:
                    continue
                if not chat_agent(table.get(agent_pid, (0, []))[1]):
                    continue
                checked += 1
                try:
                    findings.extend(audit_pane(reader, pane, session, agent, agent_pid, ROOT / 'zig-out/bin/chat-audit'))
                except (OSError, ValueError, subprocess.SubprocessError) as error:
                    findings.append(dict(kind='audit_error', session=session, pane=pane, text=type(error).__name__))
        if args.file_tickets:
            file_tickets(findings, args.state)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        findings.append(dict(kind='audit_error', text=type(error).__name__))
    for finding in findings:
        finding['text'] = finding.get('text', '')[:80]
        if args.json:
            print(json.dumps(finding))
        else:
            print(finding['kind'] + ' ' + json.dumps({key: value for key, value in finding.items() if key != 'kind'}))
    if args.json:
        print(json.dumps(dict(summary=f'{len(findings)} drift findings', findings=len(findings), panes=checked)))
    else:
        print(f'Checked {checked} live agent panes')
        print(f'{len(findings)} drift findings')


if __name__ == '__main__':
    main()
