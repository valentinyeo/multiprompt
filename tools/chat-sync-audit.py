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
TOOL_CALL = re.compile(r'^● [A-Za-z_]+(?: [A-Z][A-Za-z_]*)*\(')
SETTLE_SECONDS = 5
SETTLE_LIMIT_SECONDS = 45


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
    prompt, pending = 0, False
    for line_no, line in enumerate(lines, 1):
        line = ANSI.sub('', line).rstrip()
        if re.fullmatch(r'● Advising using .+ \d+(?:\.\d+)+', line):
            pending = True
        elif re.match(r'^[❯›>] ', line):
            prompt, pending = line_no, False
        elif TOOL_CALL.match(line) and line_no < len(lines) and ANSI.sub('', lines[line_no]).lstrip().startswith('⎿'):
            pending = False
        if line_no > len(lines) - 8:
            continue
        if line.startswith('● ') and not TOOL_CALL.match(line):
            if ANSI.sub('', lines[line_no]).lstrip().startswith('⎿'):
                continue
            text = line[2:].strip()
            continuation = []
            for following in lines[line_no:]:
                following = ANSI.sub('', following)
                if not following.strip() or not following[0].isspace() or following.lstrip().startswith('⎿'):
                    break
                continuation.append(following.strip())
            wrapped = ' '.join([text] + continuation)
            if re.search(r' · (?:\d+[hms]\s*)+…?$', wrapped) or (
                    text.endswith('·') and re.fullmatch(r'(?:\d+[hms]\s*)+…?', ' '.join(continuation))):
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
        if line.startswith('● ') and (
            re.fullmatch(r'Task ".*" still running(?: in background)?', wrapped)
            or (wrapped.startswith('Task "') and wrapped.count('"') % 2 == 1)
        ):
            continue
        if line.startswith('● ') and re.fullmatch(r'(?:All|\d+) background agents (?:stopped|running)', text):
            continue
        if line.startswith('● ') and re.match(r'^Build in progress \(~?\d+(?:\.\d+)? min\); ', text):
            continue
        if re.fullmatch(r'[A-Z][a-z]+ing (?:\d+ |[~/])[^,…]+(?:(?:, [a-z]+ing (?:\d+ |[~/])[^,…]+)+…?|…)',
                        wrapped if line.startswith('● ') else text):
            continue
        text = normalize(text)
        if len(text) >= 20:
            candidates.append(dict(text=text[:80], probe=text[:60], pane_line=line_no, prompt=bool(re.match(r'^[❯›>] ', line))))
    if pending:
        for candidate in candidates:
            if candidate['pane_line'] >= prompt:
                candidate['advising'] = True
    return candidates


def tool_path(text, inputs, cwd):
    match = re.match(r'^[A-Z][a-z]+ing (\S.*)$', normalize(text)[:60])
    if not match:
        return False
    for key in ('file_path', 'path', 'notebook_path'):
        value = inputs.get(key)
        if not isinstance(value, str) or not value:
            continue
        file = Path(value)
        paths = [str(file)]
        if file.is_relative_to(Path.home()):
            paths.append('~' + str(file)[len(str(Path.home())):])
        if cwd and file.is_relative_to(cwd):
            paths.append(str(file.relative_to(cwd)))
        if any(normalize(path).startswith(match[1]) or match[1] == normalize(path) + '…' for path in paths):
            return True
    return False


def track_queue(queue, event, line_number):
    if event.get('type') != 'queue-operation':
        return
    operation, content = event.get('operation'), event.get('content')
    content = content if isinstance(content, str) else ''
    if operation == 'enqueue':
        queue.append(dict(content=content, line=line_number, timestamp=event.get('timestamp', '')))
    elif operation == 'dequeue' and queue:
        queue.pop(0)
    elif operation == 'popAll':
        queue.clear()
    elif operation == 'remove' and content:
        for index, entry in enumerate(queue):
            if entry['content'] == content:
                del queue[index]
                break


def transcript_evidence(reader, path, wire, finding):
    fields = wire.splitlines()[0].split('\t')
    base, end = int(fields[5]), int(fields[6])
    evidence, queue = [], []
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
            track_queue(queue, event, line_number)
            messages = [row for row in reader.conversation_rows(event, fields[9], at) if row['role'] in ('user', 'assistant')]
            record = 'conversation'
            if not messages:
                fact = reader.settlement_event(event, fields[9])
                messages = [fact] if fact else []
                record = 'queued_prompt'
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
                            if tool_path(finding['text'], part.get('input') or {}, event.get('cwd')):
                                matches = True
                                break
                        else:
                            continue
                        if isinstance(value, str) and normalize(finding['text'])[:60] in normalize(value.replace('**', '').replace('`', '')):
                            matches = True
                            break
            if matches:
                evidence.append(dict(line=line_number, timestamp=event.get('timestamp', ''), record=record,
                                     location='before_cold_tail' if at < base else 'after_snapshot' if at >= end else 'in_window'))
    unnamed = [entry for entry in queue if not entry['content']]
    if finding['kind'] == 'pane_missing' and finding.get('prompt') and unnamed and not evidence:
        evidence.append(dict(line=unnamed[-1]['line'], timestamp=unnamed[-1]['timestamp'], record='queued_prompt', location='in_window'))
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
    for _ in range(0, SETTLE_LIMIT_SECONDS, SETTLE_SECONDS):
        if not any(item['kind'] == 'pane_missing' and not item['transcript_lines'] for item in findings):
            return findings
        sleep(SETTLE_SECONDS)
        settled = []
        for item in findings:
            if item['kind'] == 'pane_missing' and not item['transcript_lines']:
                item['transcript_lines'] = transcript_evidence(reader, path, wire, item)
                if not_drift(item, wire) or item.get('advising') and not item['transcript_lines']:
                    continue
            settled.append(item)
        findings = settled
    return findings


def resolved_with_settle(reader, agent, session, agent_pid, sleep):
    resolved = reader.resolve_tmux_agent(agent, session, agent_pid)
    for _ in range(0, SETTLE_LIMIT_SECONDS, SETTLE_SECONDS):
        if resolved:
            return resolved
        sleep(SETTLE_SECONDS)
        resolved = reader.resolve_tmux_agent(agent, session, agent_pid)
    return resolved


def audit_pane(reader, pane, session, agent, agent_pid, binary, sleep=time.sleep):
    resolved = resolved_with_settle(reader, agent, session, agent_pid, sleep)
    if not resolved:
        capture = run(['tmux', 'capture-pane', '-p', '-J', '-t', pane, '-S', '-120'])
        candidates = pane_candidates(capture)
        if not candidates and agent == 'claude':
            sid, cwd = reader.claude_session_metadata(agent_pid)
            if sid and reader.conversation_path('claude', sid, cwd or reader.read_process_cwd(agent_pid)) is None:
                return []
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
            item = dict(candidate, kind='pane_missing')
            del item['probe']
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
