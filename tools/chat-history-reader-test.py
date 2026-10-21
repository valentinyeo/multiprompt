import base64
import importlib.util
import json
import os
import selectors
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class HistoryReaderTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.addCleanup(patch.stopall)
        patch.object(reader, 'HOME', self.home).start()
        self.path = self.home / '.claude/projects/-work-demo/sid.jsonl'
        self.path.parent.mkdir(parents=True)
        self.query = dict(id=7, codex=False, sid='sid', tmux='term-1', cwd='/work/demo',
                          cached_sid='', inode=0, offset=0)

    def event(self, text='hello', **extra):
        return dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text=text)]), **extra)

    def write(self, *events):
        self.path.write_text(''.join(json.dumps(e) + '\n' for e in events))

    def read(self):
        wire = reader.response(self.query)
        lines = wire.splitlines()
        self.assertEqual(lines[-1], reader.END)
        fields = lines[0].split('\t')
        self.assertEqual(fields[:4], ['@mp', '7', 'history', 'ok'])
        if fields[13] != 'older':
            self.query.update(cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]), mtime=int(fields[11]), probe=fields[12])
        self.query['start'] = int(fields[14])
        self.query.pop('before', None)
        return fields, [json.loads(line) for line in lines[1:-1]]

    def test_claude_status_header(self):
        todos = [dict(content=f"Task {i}\tline\nnext", status="completed" if i < 3 else "in_progress" if i == 3 else "pending") for i in range(7)]
        old = self.tool_call("TodoWrite", dict(todos=[dict(content="old", status="pending")]))
        latest = self.tool_call("TodoWrite", dict(todos=todos))
        latest["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=2000, cache_read_input_tokens=70000, cache_creation_input_tokens=4000))
        self.write(old, latest)
        _, rows = self.read()
        status = [row for row in rows if row["role"] == "status"]
        self.assertEqual(len(status), 1)
        self.assertEqual(status[0]["model"], "Opus 5.5")
        self.assertEqual(status[0]["percent_left"], 62)
        self.assertEqual(len(status[0]["todos"]), 7)
        self.assertEqual(sum(t["status"] == "completed" for t in status[0]["todos"]), 3)
        self.assertEqual(status[0]["todos"][0]["text"], todos[0]["content"])
        _, rows = self.read()
        self.assertEqual([row for row in rows if row["role"] == "status"], status)

    def test_codex_status_header(self):
        self.query["codex"] = True
        self.path = self.home / ".codex/sessions/2026/10/20/rollout-2026-sid.jsonl"
        self.path.parent.mkdir(parents=True)
        plan = [dict(step=f"Step {i}", status="completed" if i < 3 else "pending") for i in range(7)]
        self.write(dict(type="turn_context", payload=dict(model="gpt-5.6")),
                   dict(type="response_item", payload=dict(type="function_call", name="update_plan", arguments=json.dumps(dict(plan=plan)))),
                   dict(type="event_msg", payload=dict(type="token_count", info=dict(last_token_usage=dict(input_tokens=76000), model_context_window=200000))))
        _, rows = self.read()
        status = next(row for row in rows if row["role"] == "status")
        self.assertEqual(status["model"], "gpt-5.6")
        self.assertEqual(status["percent_left"], 62)
        self.assertEqual(len(status["todos"]), 7)
        self.assertEqual(sum(t["status"] == "completed" for t in status["todos"]), 3)

    def test_status_todo_beyond_tail(self):
        todo = self.tool_call("TodoWrite", dict(todos=[dict(content="still relevant", status="in_progress")]))
        self.write(todo)
        with self.path.open("a") as target:
            for _ in range(7000):
                target.write(json.dumps(dict(type="progress", padding="x" * 100)) + "\n")
            target.write(json.dumps(self.event()) + "\n")
        self.assertGreater(self.path.stat().st_size, reader.TAIL_BYTES)
        _, rows = self.read()
        self.assertEqual(next(row for row in rows if row["role"] == "status")["todos"], [dict(text="still relevant", status="in_progress")])

    def test_status_cache_reads_only_new_bytes(self):
        event = self.event("status " + "x" * 1000)
        event["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        line = (json.dumps(event) + "\n").encode()
        self.path.write_bytes(line * (2 * 1024 * 1024 // len(line) + 1))
        _, rows = self.read()
        self.assertEqual(next(row for row in rows if row["role"] == "status")["percent_left"], 62)
        event = self.event("new usage")
        event["message"]["usage"] = dict(input_tokens=100000)
        delta = (json.dumps(event) + "\n").encode()
        with self.path.open("ab") as target:
            target.write(delta)
        original_open = Path.open
        read_bytes = 0

        class Counted:
            def __init__(self, source):
                self.source = source

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return self.source.__exit__(*args)

            def __getattr__(self, name):
                return getattr(self.source, name)

            def read(self, *args):
                nonlocal read_bytes
                data = self.source.read(*args)
                read_bytes += len(data)
                return data

        def counted_open(path, *args, **kwargs):
            source = original_open(path, *args, **kwargs)
            return Counted(source) if path == self.path and args == ("rb",) else source

        with patch.object(Path, "open", counted_open):
            fields, rows = self.read()
        self.assertEqual(fields[13], "delta")
        self.assertLess(read_bytes, len(delta) + 256 * 1024)
        status = next(row for row in rows if row["role"] == "status")
        self.assertEqual(status["model"], "Opus 5.5")
        self.assertEqual(status["percent_left"], 50)
        self.assertNotIn("todos", status)

    def test_status_cache_resets_on_new_inode(self):
        old = self.tool_call("TodoWrite", dict(todos=[dict(content="old", status="pending")]))
        old["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        self.write(old)
        self.assertIn("todos", next(row for row in self.read()[1] if row["role"] == "status"))
        inode = self.path.stat().st_ino
        new = self.event("new file " + "x" * 1000)
        new["message"].update(model="claude-sonnet-5-5", usage=dict(input_tokens=100000))
        replacement = self.path.with_suffix(".new")
        replacement.write_text(json.dumps(new) + "\n")
        replacement.replace(self.path)
        self.assertNotEqual(inode, self.path.stat().st_ino)
        status = next(row for row in self.read()[1] if row["role"] == "status")
        self.assertEqual(status["model"], "Sonnet 5.5")
        self.assertEqual(status["percent_left"], 50)
        self.assertNotIn("todos", status)

    def test_status_cache_new_todowrite_updates_count(self):
        old = self.tool_call("TodoWrite", dict(todos=[dict(content="one", status="pending")]))
        self.write(old)
        status = next(row for row in self.read()[1] if row["role"] == "status")
        self.assertEqual((sum(t["status"] == "completed" for t in status["todos"]), len(status["todos"])), (0, 1))
        todos = [dict(content="one", status="completed"), dict(content="two", status="pending")]
        with self.path.open("a") as target:
            target.write(json.dumps(self.tool_call("TodoWrite", dict(todos=todos))) + "\n")
        status = next(row for row in self.read()[1] if row["role"] == "status")
        self.assertEqual((sum(t["status"] == "completed" for t in status["todos"]), len(status["todos"])), (1, 2))

    def test_status_cache_absent_todos_become_present_then_empty(self):
        event = self.event()
        event["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        self.write(event)
        self.assertNotIn("todos", next(row for row in self.read()[1] if row["role"] == "status"))
        for todos in ([dict(content="new task", status="completed")], []):
            with self.path.open("a") as target:
                target.write(json.dumps(self.tool_call("TodoWrite", dict(todos=todos))) + "\n")
            status = next(row for row in self.read()[1] if row["role"] == "status")
            self.assertEqual(status["todos"], [dict(text=t["content"], status=t["status"]) for t in todos])
            self.assertEqual((status["model"], status["percent_left"]), ("Opus 5.5", 62))

    def test_status_cache_codex_updates_plan_and_usage(self):
        self.query["codex"] = True
        self.path = self.home / ".codex/sessions/rollout-2026-sid.jsonl"
        self.path.parent.mkdir(parents=True)
        self.write(dict(type="turn_context", payload=dict(model="gpt-5.6")),
                   dict(type="event_msg", payload=dict(type="token_count", info=dict(last_token_usage=dict(input_tokens=76000), model_context_window=200000))))
        self.assertNotIn("todos", next(row for row in self.read()[1] if row["role"] == "status"))
        plan = [dict(step="new step", status="completed")]
        with self.path.open("a") as target:
            target.write(json.dumps(dict(type="response_item", payload=dict(type="function_call", name="update_plan", arguments=json.dumps(dict(plan=plan))))) + "\n")
            target.write(json.dumps(dict(type="event_msg", payload=dict(type="token_count", info=dict(last_token_usage=dict(input_tokens=100000), model_context_window=400000)))) + "\n")
        status = next(row for row in self.read()[1] if row["role"] == "status")
        self.assertEqual((status["model"], status["percent_left"]), ("gpt-5.6", 75))
        self.assertEqual(status["todos"], [dict(text="new step", status="completed")])

    def test_status_cache_finishes_partial_line_and_resets_on_shrink(self):
        event = self.event()
        event["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        self.write(event)
        self.read()
        update = self.event("x" * (reader.TAIL_BYTES + 100))
        update["message"].update(model="claude-sonnet-5-5", usage=dict(input_tokens=100000))
        line = json.dumps(update).encode()
        with self.path.open("ab") as target:
            target.write(line)
        self.assertEqual(next(row for row in self.read()[1] if row["role"] == "status")["model"], "Opus 5.5")
        with self.path.open("ab") as target:
            target.write(b"\n")
        status = next(row for row in self.read()[1] if row["role"] == "status")
        self.assertEqual((status["model"], status["percent_left"]), ("Sonnet 5.5", 50))
        self.write(dict(type="progress"))
        self.assertFalse(any(row["role"] == "status" for row in self.read()[1]))

    def test_status_cache_skips_decoding_older_usage_and_bounds_entries(self):
        event = self.event()
        event["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        self.write(*(event for _ in range(1000)))
        original_loads = json.loads
        with self.path.open("rb") as source, patch.object(reader.json, "loads", wraps=original_loads) as loads:
            reader.status_header(source, self.path.stat().st_size, "claude")
        self.assertEqual(loads.call_count, 1)
        self.assertLessEqual(len(reader.STATUS_CACHE), 256)
        for i in range(257):
            path = self.home / f"status-{i}.jsonl"
            path.write_text(json.dumps(event) + "\n")
            with path.open("rb") as source:
                reader.status_header(source, path.stat().st_size, "claude")
        self.assertEqual(len(reader.STATUS_CACHE), 256)
        self.assertNotIn((str(self.path.resolve()), self.path.stat().st_ino), reader.STATUS_CACHE)

    def test_status_bounds_models_and_context(self):
        for model, display in (("claude-sonnet-5-5", "Sonnet 5.5"), ("claude-fable-5-1", "Fable 5.1"), ("claude-haiku-4-5-20251001", "Haiku 4.5"), ("claude-future", "future")):
            self.query.update(cached_sid="", offset=0)
            event = self.tool_call("TodoWrite", dict(todos=[dict(content="😀" * 250, status="completed")] * 60))
            event["message"].update(model=model, usage=dict(input_tokens=380000))
            event["context"] = "[1m]"
            self.write(event)
            _, rows = self.read()
            status = next(row for row in rows if row["role"] == "status")
            self.assertEqual(status["model"], display)
            self.assertEqual(status["percent_left"], 62)
            self.assertEqual(len(status["todos"]), 50)
            self.assertEqual(len(status["todos"][0]["text"]), 200)
        self.query.update(cached_sid="", offset=0)
        self.write(dict(type="assistant", message=dict(content=[], usage=dict(input_tokens=300000))))
        self.assertEqual(next(row for row in self.read()[1] if row["role"] == "status")["percent_left"], 0)

    def test_status_ignores_partial_record_larger_than_chunk(self):
        self.write(dict(type="assistant", message=dict(content=[], model="claude-opus-5-5", usage=dict(input_tokens=76000))))
        with self.path.open("ab") as target:
            target.write(b'{"type":"assistant","message":{"model":"wrong","padding":"' + b'x' * (reader.TAIL_BYTES + 100))
        with self.path.open("rb") as source:
            status = reader.status_header(source, self.path.stat().st_size, "claude")
        self.assertEqual(status["model"], "Opus 5.5")
        self.assertEqual(status["percent_left"], 62)

    def search(self, text):
        wire = reader.response(dict(self.query, search=text, offset='ignored', before=-1, probe=None))
        lines = wire.splitlines()
        self.assertEqual(lines[-1], reader.END)
        fields = lines[0].split('\t')
        self.assertEqual(fields[:5], ['@mp', '7', 'search', 'ok', 'sid'])
        rows = [json.loads(line) for line in lines[1:-1]]
        self.assertEqual(int(fields[7]), len(rows))
        self.assertEqual(fields[9:], ['claude', 'term-1'])
        return fields, rows

    def test_igsh268_first_middle_offsets_and_casefold(self):
        first = dict(type='user', message=dict(role='user', content='First Straße phrase'))
        middle = self.event('Middle literal .* phrase')
        self.write(first, self.event('x' * (reader.TAIL_BYTES + 100)), middle, self.event('last'))
        raw = self.path.read_bytes().splitlines(keepends=True)
        _, rows = self.search('STRASSE')
        self.assertEqual([(r['offset'], r['end'], r['role']) for r in rows], [(0, len(raw[0]), 'user')])
        self.assertIn('Straße', rows[0]['snippet'])
        _, rows = self.search('LITERAL .*')
        self.assertEqual(rows[0]['offset'], len(raw[0]) + len(raw[1]))
        self.assertEqual(rows[0]['end'], sum(map(len, raw[:3])))
        self.assertEqual(rows[0]['role'], 'assistant')

    def test_igsh268_absent_sidechain_and_compaction(self):
        self.write(self.event('visible'), self.event('hidden', isSidechain=True), self.event('hidden', isCompactSummary=True))
        self.assertEqual(self.search('absent')[1], [])
        self.assertEqual(self.search('hidden')[1], [])
        self.assertEqual(len(self.search('visible')[1]), 1)

    def test_igsh268_cap_and_snippet(self):
        self.write(*(self.event('x' * 300 + 'needle' + 'y' * 300) for _ in range(510)))
        fields, rows = self.search('needle')
        self.assertEqual(len(rows), 500)
        self.assertEqual(fields[8], '1')
        self.assertEqual([r['offset'] for r in rows], sorted(r['offset'] for r in rows))
        self.assertTrue(all(len(r['snippet']) <= 160 and 'needle' in r['snippet'] for r in rows))

    def test_igsh268_tool_text_and_detail(self):
        self.write(self.tool_call(value=dict(command='unique tool command')), self.tool_result('distinct result text'))
        _, rows = self.search('unique tool')
        self.assertEqual(rows[0]['role'], 'tool')
        self.assertEqual(rows[0]['offset'], 0)
        _, rows = self.search('distinct result')
        self.assertEqual(rows[0]['role'], 'tool')
        self.assertEqual(rows[0]['offset'], len(self.path.read_bytes().splitlines(keepends=True)[0]))

    def test_igsh268_only_current_visible_tool_details_match(self):
        self.write(self.tool_call(value=dict(command='x' * 2000 + 'hidden input')),
                   self.tool_result('obsolete output'), self.tool_result('current output'))
        self.assertEqual(self.search('hidden input')[1], [])
        self.assertEqual(self.search('obsolete output')[1], [])
        self.assertEqual(len(self.search('current output')[1]), 1)
        self.write(self.tool_result('orphan output'))
        self.assertEqual(self.search('orphan output')[1], [])

    def test_igsh268_search_prefilter_preserves_tool_bookkeeping(self):
        for agent, kinds in [('claude', ['tool_use']), ('codex', ['function_call', 'custom_tool_call', 'local_shell_call', 'tool_use'])]:
            for kind in kinds:
                with self.subTest(agent=agent, kind=kind):
                    if agent == 'claude':
                        call = self.tool_call(value=dict(command='unrelated input'))
                        result = self.tool_result('distinctive needle output')
                        replacement = self.tool_result('replacement without matching text')
                    else:
                        call = dict(type='response_item', payload=dict(type=kind, call_id='call-prefilter', name='exec_command', arguments='{"cmd":"unrelated input"}'))
                        result_kind = 'tool_result' if kind == 'tool_use' else kind + '_output'
                        result = dict(type='response_item', payload=dict(type=result_kind, call_id='call-prefilter', output='distinctive needle output'))
                        replacement = dict(type='response_item', payload=dict(type=result_kind, call_id='call-prefilter', output='replacement without matching text'))
                    self.write(call, result)
                    fields = reader.search_response(dict(self.query, search='distinctive needle'), self.path, agent, 'sid').splitlines()
                    rows = [json.loads(line) for line in fields[1:-1]]
                    self.assertEqual(fields[0].split('\t')[8], '0')
                    self.assertEqual(len(rows), 1)
                    self.assertEqual(rows[0]['offset'], len(self.path.read_bytes().splitlines(keepends=True)[0]))
                    self.assertEqual(rows[0]['role'], 'tool')
                    self.write(call, result, replacement)
                    self.assertEqual(len(reader.search_response(dict(self.query, search='distinctive needle'), self.path, agent, 'sid').splitlines()), 2)
        self.write(self.tool_call(value=dict(command='x' * 2000 + 'distinctive needle')), self.tool_result('unrelated result'))
        self.assertEqual(self.search('distinctive needle')[1], [])
        self.write(self.tool_call(name='Read', value=dict(file_path='project/example.txt')))
        self.assertEqual(len(self.search('Read example')[1]), 1)
        self.write(self.tool_call(value=dict(description='normalized   summary', command='true')))
        self.assertEqual(len(self.search('normalized summary')[1]), 1)

    def test_igsh268_search_prefilter_covers_170_mb_and_chunk_boundaries(self):
        padding = (json.dumps(self.event('cmd ' + 'x' * 15996)) + '\n').encode()
        hit = (json.dumps(self.event('distinctive middle needle', timestamp='middle')) + '\n').encode()
        last = (json.dumps(self.event('distinctive final needle', timestamp='last')) + '\n').encode()
        count = 170_000_000 // len(padding) // 2 + 1
        with self.path.open('wb') as output:
            for _ in range(count):
                output.write(padding)
            middle = output.tell()
            output.write(hit)
            for _ in range(count):
                output.write(padding)
            final = output.tell()
            output.write(last)
            output.write(json.dumps(self.event('distinctive incomplete needle')).encode())
        self.assertGreaterEqual(self.path.stat().st_size, 170_000_000)
        with patch.object(reader.json, 'loads', wraps=json.loads) as loads, patch.object(reader.time, 'monotonic', return_value=0.0):
            fields, rows = self.search('distinctive')
        self.assertEqual(fields[8], '0')
        self.assertEqual([(row['offset'], row['end'], row['timestamp']) for row in rows],
                         [(middle, middle + len(hit), 'middle'), (final, final + len(last), 'last')])
        self.assertLess(loads.call_count, 20)
        with patch.object(reader.json, 'loads', wraps=json.loads) as loads, patch.object(reader.time, 'monotonic', return_value=0.0):
            fields, rows = self.search('md instructions for')
        self.assertEqual(fields[8], '0')
        self.assertEqual(rows, [])
        self.assertEqual(loads.call_count, 0)
        data = (json.dumps(self.event('x' * (1024 * 1024 - 20) + 'boundary needle')) + '\n').encode()
        self.path.write_bytes(b'{}\n' + data + (json.dumps(self.event('boundary needle')) + '\n').encode())
        fields, rows = self.search('boundary needle')
        self.assertEqual(fields[8], '0')
        self.assertEqual(len(rows), 2)
        self.assertEqual([row['offset'] for row in rows], [3, 3 + len(data)])

    def test_igsh268_search_prefilter_keeps_escaped_unicode_and_markup_matches(self):
        for text, needle in [('Straße', 'strasse'), ('é', 'é'), ('quote " and \\ path', 'quote " and \\ path'),
                             ('prefix <local-command-stdout>hidden</local-command-stdout>suffix', 'prefix suffix'),
                             ('pre<local-command-stdout>hidden</local-command-stdout>fix', 'prefix'),
                             ('<command-name>deploy</command-name><command-args>production now</command-args>', 'deploy production'),
                             ('some<pasted_content>joined words</pasted_content> here', 'some joined words'),
                             ('Kelvin ſtraße ﬃle', 'kelvin strasse ffile'), ('İ', 'i'), ('ŉame', 'name'),
                             ('ßfoo', 'sfoo'), ('barﬀ', 'barf'), ('ﬃ', 'f'), ('ﬀ', 'f')]:
            for ascii_json in (True, False):
                with self.subTest(needle=needle, ascii_json=ascii_json):
                    event = dict(type='user', message=dict(role='user', content=text))
                    self.path.write_text(json.dumps(event, ensure_ascii=ascii_json) + '\n')
                    self.assertEqual(len(self.search(needle)[1]), 1)
        self.path.write_bytes(json.dumps(self.event('needle')).replace('needle', '\\u006eeedle').encode() + b'\n')
        self.assertEqual(len(self.search('needle')[1]), 1)
        self.path.write_bytes((json.dumps(self.event('needle')) + '\n').encode('utf-16-be'))
        self.assertEqual(len(self.search('needle')[1]), 1)
        for identity in ['escaped/id', 'escaped\\id', 'escaped"id', 'é', 'plain']:
            self.write(self.tool_call(identity=identity), self.tool_result('distinctive needle', identity=identity))
            self.assertEqual(len(self.search('distinctive needle')[1]), 1)

    def test_igsh268_search_prefilter_unicode_fold_table_is_exhaustive(self):
        expected = {chr(code) for code in range(128, sys.maxunicode + 1)
                    if any('a' <= char <= 'z' for char in chr(code).casefold())}
        self.assertEqual(set(reader.SEARCH_ASCII_FOLDS), expected)

    def test_igsh268_pure_function_codex_and_service_dispatch(self):
        self.write(dict(type='response_item', timestamp='now', payload=dict(type='message', role='user', content=[dict(type='input_text', text='Codex needle')])) )
        pure = reader.search_response(dict(self.query, search='NEEDLE'), self.path, 'codex', 'sid')
        self.assertIn('"role":"user"', pure)
        self.assertIn('\tsearch\tok\tsid\t', pure)
        self.write(self.event('service needle'))
        request = dict(self.query, search='NEEDLE')
        result = subprocess.run([sys.executable, str(ROOT / 'tools/chat-bench/reader-service.py'), str(ROOT / 'src/chat_history_reader.py')],
                                input=json.dumps(dict(job=12, protocol='history', request=json.dumps(request))) + '\n', text=True,
                                capture_output=True, check=True, env=dict(os.environ, HOME=str(self.home)))
        envelope = json.loads(result.stdout)
        self.assertEqual(envelope['job'], 12)
        self.assertIn('\tsearch\tok\tsid\t', envelope['wire'])
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(request) + '\n', text=True, capture_output=True, check=True,
                                env=dict(os.environ, HOME=str(self.home)))
        self.assertIn('\tsearch\tok\tsid\t', json.loads(result.stdout)['wire'])

    def test_igsh268_invalid_and_time_cap(self):
        self.write(self.event('needle'))
        for value in ('', 'x' * 201, None, 4, []):
            with self.assertRaises(ValueError):
                reader.response(dict(self.query, search=value))
        with patch.object(reader.time, 'monotonic', side_effect=[0, 2]):
            fields, rows = self.search('needle')
        self.assertEqual(fields[8], '1')
        self.assertEqual(rows, [])

    def test_status_and_whole_conversation_search_share_source_offsets(self):
        todo = self.tool_call("TodoWrite", dict(todos=[dict(content="status-only needle", status="pending")]))
        todo["message"].update(model="claude-opus-5-5", usage=dict(input_tokens=76000))
        self.write(self.event("conversation needle"), todo)
        self.query["source_offsets"] = True
        _, rows = self.read()
        status = next(row for row in rows if row["role"] == "status")
        self.assertEqual((status["model"], status["percent_left"]), ("Opus 5.5", 62))
        self.assertNotIn("offset", status)
        message = next(row for row in rows if row.get("text") == "conversation needle")
        cache = dict(reader.STATUS_CACHE)
        _, hits = self.search("conversation needle")
        self.assertEqual((hits[0]["offset"], hits[0]["end"]), (message["offset"], message["end"]))
        self.assertEqual(reader.STATUS_CACHE, cache)
        self.assertEqual(self.search("Opus 5.5")[1], [])
        self.assertEqual(next(row for row in self.read()[1] if row["role"] == "status"), status)

    def tool_call(self, name='Bash', value=None, identity='call-263'):
        return dict(type='assistant', timestamp='2026-10-18T11:00:00Z', message=dict(role='assistant', content=[
            dict(type='tool_use', id=identity, name=name, input=value or dict(command='zig build test'))]))

    def tool_result(self, output='passed', error=False, identity='call-263'):
        return dict(type='user', timestamp='2026-10-18T11:00:01Z', message=dict(role='user', content=[
            dict(type='tool_result', tool_use_id=identity, content=output, is_error=error)]))

    def diff_row(self, name, value, result=None):
        events = [self.tool_call(name, value)]
        if result is not None:
            events.append(dict(self.tool_result(), toolUseResult=result))
        self.write(*events)
        self.query.update(cached_sid='', offset=0)
        return self.read()[1][0]

    def test_igsh270_edit_structured_patch(self):
        row = self.diff_row('Edit', dict(file_path='foo.zig', old_string='wrong', new_string='fallback'),
                            dict(structuredPatch=[dict(lines=[' context', '-before', '+after', '+extra'])]))
        self.assertEqual(row['diff'], ' context\n-before\n+after\n+extra')
        self.assertEqual(row['text'], 'Edited foo.zig +2 -1')

    def test_igsh270_edit_fallback_uses_uncapped_input(self):
        old = 'same\n' * 1000 + 'before'
        new = 'same\n' * 1000 + 'after'
        row = self.diff_row('Edit', dict(file_path='foo.zig', old_string=old, new_string=new))
        self.assertEqual(row['diff'], ' same\n-before\n+after')
        self.assertEqual(row['text'], 'Edited foo.zig +1 -1')

    def test_igsh270_multiedit(self):
        row = self.diff_row('MultiEdit', dict(file_path='foo.zig', edits=[dict(old_string='a', new_string='b'),
                                                                       dict(old_string='c', new_string='d\ne')]))
        self.assertEqual(row['diff'], '-a\n+b\n-c\n+d\n+e')
        self.assertEqual(row['text'], 'Edited foo.zig +3 -2')

    def test_igsh270_write_create_all_green(self):
        for result in [None, dict(type='create', structuredPatch=[], content='first\nsecond\n')]:
            row = self.diff_row('Write', dict(file_path='new.zig', content='first\nsecond\n'), result)
            self.assertEqual(row['diff'], '+first\n+second')
            self.assertEqual(row['text'], 'Wrote new.zig +2 -0')

    def test_igsh270_codex_apply_patch(self):
        value = '*** Begin Patch\n*** Update File: foo.zig\n@@\n context\n-before\n+after\n*** Add File: new.zig\n+new\n*** End Patch'
        for kind, field, payload in [('custom_tool_call', 'input', value),
                                     ('function_call', 'arguments', json.dumps(dict(input=value)))]:
            event = dict(type='response_item', payload=dict(type=kind, name='apply_patch', call_id='patch', **{field: payload}))
            row = reader.tool_events(event, 'codex')[0]
            self.assertEqual(row['diff'], ' context\n-before\n+after\n+new')
            self.assertEqual(row['text'], 'Edited foo.zig +2 -1')

    def test_igsh270_diff_cap_counts_all_lines(self):
        row = self.diff_row('Edit', dict(file_path='foo.zig', old_string='old', new_string='new'),
                            dict(structuredPatch=[dict(lines=['-old'] * 25 + ['+new'] * 30)]))
        self.assertEqual(len(row['diff'].splitlines()), 41)
        self.assertEqual(row['diff'].splitlines()[-1], ' … 15 more lines')
        self.assertEqual(row['text'], 'Edited foo.zig +30 -25')

    def test_igsh270_result_delta_and_flag(self):
        result = dict(self.tool_result(), toolUseResult=dict(structuredPatch=[dict(lines=['-a', '+b'])]))
        self.write(self.tool_call('Edit', dict(file_path='foo', old_string='a', new_string='c')))
        self.read()
        with self.path.open('a') as output:
            output.write(json.dumps(result) + '\n')
        row = self.read()[1][0]
        self.assertEqual(row['diff'], '-a\n+b')
        self.assertEqual((row['added'], row['removed']), (1, 1))
        with patch.object(reader, 'ISSUE_270_DIFF_CARDS', False):
            self.assertNotIn('diff', reader.tool_events(result, 'claude')[0])

    def test_igsh402_ordered_segments_keep_ids_offsets_and_adjacent_text(self):
        event = self.tool_call()
        event['message']['id'] = 'reply-402'
        tool = event['message']['content'][0]
        event['message']['content'] = [dict(type='text', text='Before'), dict(type='text', text='still before'),
                                      tool, dict(type='thinking', thinking='hidden'), dict(type='text', text='After'),
                                      dict(tool, id='second-call'), dict(type='text', text='Last')]
        self.query['source_offsets'] = True
        self.write(event)
        fields, rows = self.read()
        self.assertEqual([row['role'] for row in rows], ['assistant', 'tool', 'assistant', 'tool', 'assistant'])
        self.assertEqual([row['text'] for row in rows if row['role'] == 'assistant'], ['Before\nstill before', 'After', 'Last'])
        self.assertEqual(rows[0]['id'], 'reply-402')
        self.assertEqual(len({row['id'] for row in rows}), len(rows))
        self.assertTrue(all((row['offset'], row['end']) == (0, self.path.stat().st_size) for row in rows))
        self.assertEqual(reader.response(dict(self.query, cached_sid='', offset=0)).splitlines()[1:-1],
                         [reader.wire_row(row) for row in rows])
        self.assertEqual(self.read()[1], [])
        self.assertEqual(fields[13], 'tail')

    def test_igsh402_live_delta_partial_write_and_result_pairing(self):
        self.write(self.event('initial'))
        self.read()
        event = self.tool_call()
        event['message'].update(id='reply-402', content=[dict(type='text', text='Before'),
            *event['message']['content'], dict(type='text', text='After')])
        offset = self.query['offset']
        raw = (json.dumps(event) + '\n').encode()
        with self.path.open('ab') as output:
            output.write(raw[:-1])
        self.assertEqual(self.read()[1], [])
        self.assertEqual(self.query['offset'], offset)
        with self.path.open('ab') as output:
            output.write(raw[-1:])
        with patch.object(reader, 'PAGE_BYTES', 1):
            fields, rows = self.read()
        self.assertEqual(fields[13], 'delta')
        self.assertEqual([row['role'] for row in rows], ['assistant', 'tool', 'assistant'])
        self.assertEqual(rows[1]['status'], 'running')
        with self.path.open('a') as output:
            output.write(json.dumps(self.tool_result()) + '\n')
        result = self.read()[1]
        self.assertEqual([row['role'] for row in result], ['tool_result'])
        paired = reader.pair_tool_rows(rows + result)
        self.assertEqual([row['role'] for row in paired], ['assistant', 'tool', 'assistant'])
        self.assertEqual(paired[1]['status'], 'ok')
        self.assertEqual(len({row['id'] for row in paired}), len(paired))

    def test_igsh402_missing_message_ids_and_repeated_message_ids_are_stable(self):
        for identity in ('', 'shared-message'):
            with self.subTest(identity=identity):
                event = self.tool_call()
                event['message'].update(id=identity, content=[dict(type='text', text='Before'),
                    *event['message']['content'], dict(type='text', text='After')])
                later = dict(event, message=dict(event['message'], content=[dict(event['message']['content'][1], id='later-call'),
                                                                          dict(type='text', text='Later')]))
                self.write(event, later)
                self.query.update(cached_sid='', offset=0)
                _, rows = self.read()
                self.assertTrue(all(row['id'] for row in rows))
                self.assertEqual(len({row['id'] for row in rows}), len(rows))
                replay = reader.response(dict(self.query, cached_sid='', offset=0)).splitlines()[1:-1]
                self.assertEqual([reader.wire_row(row) for row in rows], replay)

    def test_igsh402_search_matches_visible_segments_in_source_order(self):
        event = self.tool_call(value=dict(command='needle command'))
        event['message']['content'] = [dict(type='text', text='needle before'),
                                      *event['message']['content'], dict(type='text', text='needle after')]
        self.write(event, self.tool_result('finished'))
        for query in ('needle', 'needle ', 'before\nneedle'):
            with self.subTest(query=query):
                _, hits = self.search(query)
                if query.startswith('before'):
                    self.assertEqual(hits, [])
                else:
                    self.assertEqual([hit['role'] for hit in hits], ['assistant', 'tool', 'assistant'])
                    self.assertEqual(hits[0]['snippet'], 'needle before')
                    self.assertEqual(hits[-1]['snippet'], 'needle after')
                    self.assertTrue(all(hit['offset'] == 0 for hit in hits))

    def test_igsh402_hidden_events_and_disabled_tools_keep_previous_contract(self):
        event = self.tool_call()
        event['message'].update(id='reply-402', content=[dict(type='text', text='Before'),
            *event['message']['content'], dict(type='text', text='After')])
        for flag in ('isMeta', 'isSidechain', 'isCompactSummary', 'isVisibleInTranscriptOnly'):
            self.assertEqual(reader.conversation_rows(dict(event, **{flag: True}), 'claude'), [])
        with patch.object(reader, 'ISSUE_263_TOOL_STEPS', False):
            self.assertEqual(reader.conversation_rows(event, 'claude'),
                             [reader.conversation_event(event, 'claude')])
        plain = self.event('plain')
        self.assertEqual(reader.conversation_rows(plain, 'claude'), [reader.conversation_event(plain, 'claude')])

    def test_igsh263_claude_paired_ok_error_running_and_later_delta(self):
        for error in (False, True):
            self.query.update(cached_sid='', offset=0)
            self.write(self.tool_call(), self.tool_result(error=error))
            _, rows = self.read()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]['role'], 'tool')
            self.assertEqual(rows[0]['status'], 'error' if error else 'ok')
            self.assertEqual(rows[0]['text'], 'Ran zig build test')
            self.assertIn('\n\npassed', rows[0]['detail'])
        self.query.update(cached_sid='', offset=0)
        self.write(self.tool_call())
        _, rows = self.read()
        self.assertEqual(rows[0]['status'], 'running')
        with self.path.open('a') as source:
            source.write(json.dumps(self.tool_result()) + '\n')
        _, rows = self.read()
        self.assertEqual(rows, [dict(role='tool_result', id='call-263', timestamp='2026-10-18T11:00:01Z',
                                     text='', status='ok', detail='passed')])

    def test_igsh263_latest_result_replaces_output_without_losing_input(self):
        self.write(self.tool_call(), self.tool_result('failed', error=True), self.tool_result('passed'))
        _, rows = self.read()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['status'], 'ok')
        self.assertEqual(rows[0]['detail'], '{"command":"zig build test"}\n\npassed')

    def test_igsh263_result_only_is_not_a_question_or_user_row(self):
        event = self.tool_result()
        self.assertFalse(reader.asks_question(json.dumps(event), 'claude'))
        self.write(event)
        _, rows = self.read()
        self.assertEqual([r['role'] for r in rows], ['tool_result'])
        with patch.object(reader, 'ISSUE_263_TOOL_STEPS', False):
            self.query.update(cached_sid='', offset=0)
            _, rows = self.read()
            self.assertEqual(rows, [])

    def test_igsh263_codex_real_shapes_and_errors(self):
        self.path = self.home / '.codex/sessions/2026/10/18/rollout-test-sid.jsonl'
        self.path.parent.mkdir(parents=True)
        self.query.update(codex=True)
        for call_kind, result_kind in [('function_call', 'function_call_output'), ('custom_tool_call', 'custom_tool_call_output'),
                                       ('local_shell_call', 'local_shell_call_output')]:
            for output, status in [('Exit code: 0\npassed', 'ok'), ('Process exited with code 2', 'error'),
                                   ('Exit code: 17', 'error'), ({'metadata': {'exit_code': 1}, 'output': 'failed'}, 'error'),
                                   ({'success': False}, 'error'), ({'status': 'failed'}, 'error'),
                                   ({'error': 'command rejected'}, 'error'), ('Error: command rejected', 'error'),
                                   ('apply_patch verification failed: missing file', 'error'),
                                   ('{"metadata":{"exit_code":3}}', 'error'),
                                   ([{'type': 'input_text', 'text': 'Process exited with code 1'}], 'error')]:
                self.query.update(cached_sid='', offset=0)
                args = dict(cmd='zig build test')
                payload = dict(type=call_kind, call_id='call-codex', name='exec_command', arguments=json.dumps(args))
                if call_kind == 'custom_tool_call':
                    payload['input'] = payload.pop('arguments')
                if call_kind == 'local_shell_call':
                    payload.pop('name')
                    payload.pop('arguments')
                    payload['action'] = dict(command=['zig', 'build', 'test'])
                self.write(dict(type='response_item', payload=payload),
                           dict(type='response_item', payload=dict(type=result_kind, call_id='call-codex', output=output)))
                _, rows = self.read()
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0]['status'], status)
                self.assertEqual(rows[0]['text'], 'Ran zig build test')
                self.assertEqual(rows[0]['id'], 'call-codex')
        self.query.update(cached_sid='', offset=0)
        self.write(dict(type='response_item', payload=payload))
        _, rows = self.read()
        self.assertEqual(rows[0]['status'], 'running')
        with self.path.open('a') as source:
            source.write(json.dumps(dict(type='response_item', payload=dict(type=result_kind, call_id='call-codex', output='Exit code: 0'))) + '\n')
        _, rows = self.read()
        self.assertEqual(rows[0]['role'], 'tool_result')
        self.assertEqual(rows[0]['status'], 'ok')

    def test_tool_codex_result_metadata_overrides_output_examples(self):
        outputs = ['Error: documented example', 'Exit code: 17', 'Process exited with code 2']
        for metadata in [{'exit_code': 0}, {'is_error': False}, {'success': True}, {'status': 'completed'}]:
            for output in outputs:
                for value in [dict(metadata, output=output), dict(metadata=metadata, output=output),
                              json.dumps(dict(metadata=metadata, output=output))]:
                    with self.subTest(value=value):
                        event = dict(type='response_item', payload=dict(type='function_call_output',
                                     call_id='command', output=value))
                        self.assertEqual(reader.tool_events(event, 'codex')[0]['status'], 'ok')
        for metadata in [{'exit_code': 1}, {'is_error': True}, {'success': False}, {'status': 'failed'}]:
            event = dict(type='response_item', payload=dict(type='function_call_output',
                         call_id='command', output=dict(metadata=metadata, output='all fine')))
            self.assertEqual(reader.tool_events(event, 'codex')[0]['status'], 'error')
        for output in outputs:
            event = dict(type='response_item', payload=dict(type='function_call_output',
                         call_id='command', output=output))
            self.assertEqual(reader.tool_events(event, 'codex')[0]['status'], 'error')

    def test_igsh263_summary_per_tool_and_detail_cap_without_images(self):
        cases = [('Edit', {'file_path': '/tmp/main.zig'}, 'Edited main.zig'),
                 ('Write', {'file_path': 'C:\\src\\main.zig'}, 'Wrote main.zig'),
                 ('MultiEdit', {'file_path': '/tmp/main.zig'}, 'Edited main.zig'),
                 ('apply_patch', '*** Begin Patch\n*** Update File: src/main.zig\n', 'Edited main.zig'),
                 ('apply_patch', '*** Add File: src/new.zig\n', 'Wrote new.zig'),
                 ('Read', {'file_path': '/tmp/main.zig'}, 'Read main.zig'),
                 ('Bash', {'description': 'tests', 'command': 'zig build test'}, 'Ran tests'),
                 ('shell', {'command': 'zig build'}, 'Ran zig build'),
                 ('exec_command', {'cmd': 'zig build'}, 'Ran zig build'),
                 ('Grep', {'pattern': 'needle'}, 'Searched needle'),
                 ('Glob', {'pattern': '*.zig'}, 'Searched *.zig'),
                 ('WebFetch', {'url': 'https://example.com/a'}, 'Fetched example.com'),
                 ('WebSearch', {'query': 'zig tests'}, 'Searched web zig tests'),
                 ('Task', {'description': 'review'}, 'Agent: review'),
                 ('Agent', {'description': 'review'}, 'Agent: review'),
                 ('other', {}, 'other')]
        for name, value, expected in cases:
            self.assertEqual(reader.tool_summary(name, value), expected)
        self.write(self.tool_call(value=dict(command='echo ' + 'word ' * 2000)),
                   self.tool_result([dict(type='text', text='output ' * 1000),
                                     dict(type='image', source=dict(type='base64', data='A' * 2000))]))
        _, rows = self.read()
        self.assertLessEqual(len(rows[0]['text']), 120)
        self.assertEqual(len(rows[0]['detail']), 4000)
        self.assertTrue(rows[0]['detail'].endswith('…'))
        self.assertIn('\n\noutput ', rows[0]['detail'])
        self.assertNotIn('A' * 256, rows[0]['detail'])
        self.assertNotIn('A' * 256, reader.tool_text('data:image/png;base64,' + 'A' * 2000))

    def test_igsh263_nested_input_is_compact_and_image_payloads_are_removed(self):
        value = dict(action=dict(command=['zig', 'build']), source='ordinary source code', image=dict(type='image', source=dict(type='base64', data='short_base64')))
        text = reader.tool_text(value)
        self.assertEqual(json.loads(text)['action'], dict(command=['zig', 'build']))
        self.assertEqual(json.loads(text)['source'], 'ordinary source code')
        self.assertNotIn('short_base64', text)
        self.assertNotIn('\n', text)

    def test_igsh263_tail_search_passes_tool_result_events_to_find_question(self):
        question = dict(type='user', message=dict(role='user', content='QUESTION-263 do the work'))
        hidden = dict(type='progress', text='hidden ' * (reader.TAIL_BYTES // 7 + 100))
        self.write(self.event('earlier'), question, hidden, self.tool_call(), self.tool_result(), self.event('answer'))
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'QUESTION-263 do the work')
        self.assertEqual([row['role'] for row in rows], ['user', 'tool', 'assistant'])

    def test_igsh263_page_boundary_keeps_running_then_result_and_budgets_tools(self):
        self.write(self.event('initial'))
        self.read()
        with self.path.open('a') as source:
            source.write(json.dumps(self.tool_call()) + '\n' + json.dumps(self.tool_result('result ' * 40)) + '\n')
        with patch.object(reader, 'PAGE_BYTES', 300):
            fields, rows = self.read()
            self.assertEqual(fields[8], '1')
            self.assertEqual(rows[0]['status'], 'running')
            _, rows = self.read()
            self.assertEqual(rows[0]['role'], 'tool_result')
        self.query.update(cached_sid='', offset=0)
        self.write(*(self.tool_call(value=dict(command='word ' * 900), identity=str(i)) for i in range(250)))
        _, rows = self.read()
        self.assertLessEqual(sum(len(reader.wire_row(row)) + 1 for row in rows), reader.TAIL_BYTES)

    def test_igsh361_compaction_summary_never_shows_as_the_newest_message(self):
        fixture = json.loads((ROOT / 'tools/fixtures/igsh361/upwork-compact.json').read_text())
        self.write(*fixture['records'])
        _, rows = self.read()
        self.assertFalse(any('This session is being continued' in row.get('text', '') for row in rows))
        self.assertEqual(rows[-1]['role'], 'assistant')
        self.assertTrue(rows[-1]['text'].startswith("**Yes, I've sent 3 more proposals"))

    def test_igsh349_pasted_tags_keep_neutral_inner_text(self):
        self.write(dict(type='user', timestamp='2026-10-17T15:06:44.490Z',
                        message=dict(role='user', content='<pasted_content id="5ebf">\nplease check the build\n</pasted_content id="5ebf">')))
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'please check the build')
        self.assertEqual(reader.clean_command_markup('<PASTED_CONTENT id="x" other="y">\nplease check the build\n</PASTED_CONTENT id="x">'), 'please check the build')
        self.assertEqual(reader.clean_command_markup('one<pasted_content id="x">two</pasted_content id="x">three'), 'one two three')
        self.assertEqual(reader.clean_command_markup('before\n<pasted_content id="x">\nplease check the build\n</pasted_content id="x">\nafter'), 'before\nplease check the build\nafter')

    def test_igsh349_queued_command_uses_latest_exact_queue_stamp(self):
        text = 'please check the build'
        self.query['settlement'] = True
        self.write(
            dict(type='queue-operation', operation='enqueue', timestamp='2026-10-17T15:06:45.089Z', content=text),
            self.event('neutral reply', timestamp='2026-10-17T15:06:46.479Z'),
            self.event('another neutral reply', timestamp='2026-10-17T15:06:47.140Z'),
            dict(type='user', timestamp='2026-10-17T15:06:48.337Z', message=dict(role='user', content=[dict(type='tool_result', content='neutral result')])),
            dict(type='queue-operation', operation='remove', timestamp='2026-10-17T15:06:48.689Z', content=text),
            dict(type='attachment', timestamp='2026-10-17T15:06:44.490Z', attachment=dict(type='queued_command', prompt=text)))
        _, rows = self.read()
        self.assertEqual(rows[-1]['timestamp'], '2026-10-17T15:06:48.689Z')
        self.assertGreaterEqual(rows[-1]['timestamp'], rows[0]['timestamp'])
        self.query.update(offset=0, cached_sid='', settlement=False)
        _, rows = self.read()
        self.assertEqual(rows[-1]['timestamp'], '2026-10-17T15:06:48.689Z')
        self.query.update(offset=0, cached_sid='')
        with patch.object(reader, 'ISSUE_349_QUEUED_STAMP_FROM_QUEUE', False):
            _, legacy = self.read()
        self.assertEqual(legacy[-1]['timestamp'], '2026-10-17T15:06:44.490Z')

    def owner(self, name='secondary', uid=1001, home='/home/secondary'):
        return types.SimpleNamespace(pw_name=name, pw_uid=uid, pw_dir=home)

    def test_owner_is_only_a_nonroot_account_matching_an_unambiguous_home(self):
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner()):
            self.assertEqual(reader.conversation_owner('/home/secondary/projects/demo'), ('secondary', Path('/home/secondary')))
            for cwd in ['/work/demo', '/home/secondary/../root/demo', '/home/-root/demo', '/home/secondary']:
                self.assertIsNone(reader.conversation_owner(cwd))
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner(uid=0)):
            self.assertIsNone(reader.conversation_owner('/home/secondary/demo'))
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner(home='/root')):
            self.assertIsNone(reader.conversation_owner('/home/secondary/demo'))
        with patch.object(reader.pwd, 'getpwnam', side_effect=KeyError):
            self.assertIsNone(reader.conversation_owner('/home/unknown/demo'))

    def test_configured_and_xdg_claude_roots_and_safe_symlink_containment(self):
        for directory in [self.home / 'custom-config', self.home / '.config/claude']:
            path = directory / 'projects/-work-demo/configured.jsonl'
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(self.event('configured')) + '\n')
            with patch.dict('os.environ', {'CLAUDE_CONFIG_DIR': str(directory)}):
                self.assertEqual(reader.conversation_path('claude', 'configured', '/work/demo'), path)
            path.unlink()
        with patch.dict('os.environ', {'CLAUDE_CONFIG_DIR': ''}):
            path.write_text(json.dumps(self.event('xdg')) + '\n')
            self.assertEqual(reader.conversation_path('claude', 'configured', '/work/demo'), path)
        outside = self.home / 'outside.jsonl'
        outside.write_text('{}\n')
        self.path.symlink_to(outside)
        self.assertIsNone(reader.conversation_path('claude', 'sid', '/work/demo'))

    def test_owner_home_is_read_directly_before_sudo(self):
        owner_home = self.home / 'owner'
        path = owner_home / '.claude/projects/-work-demo/sid.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(self.event('owner readable')) + '\n')
        with patch.object(reader, 'conversation_owner', return_value=('secondary', owner_home)), \
                patch.object(reader.subprocess, 'run', side_effect=AssertionError('no sudo for readable files')):
            wire = reader.response(self.query, source='reader source')
        self.assertIn('owner readable', wire)
        self.write(self.event('own readable'))
        with patch.object(reader, 'conversation_owner', return_value=('secondary', owner_home)):
            self.assertIn('own readable', reader.response(self.query))

    def test_path_probe_distinguishes_denied_from_missing_and_tries_other_roots(self):
        self.write(self.event('denied'))
        original_open = Path.open
        def denied_open(path, *args, **kwargs):
            if path == self.path:
                raise PermissionError('not readable')
            return original_open(path, *args, **kwargs)
        with patch.object(Path, 'open', denied_open):
            with self.assertRaises(PermissionError):
                reader.conversation_path('claude', 'sid', '/work/demo')
        alternate = self.home / '.config/claude/projects/-work-demo/sid.jsonl'
        alternate.parent.mkdir(parents=True)
        alternate.write_text(json.dumps(self.event('alternative readable')) + '\n')
        with patch.object(Path, 'open', denied_open):
            self.assertEqual(reader.conversation_path('claude', 'sid', '/work/demo'), alternate)

    def test_permission_denied_reexecutes_same_source_and_query_without_shell_or_prompt(self):
        expected = '@mp\t7\thistory\tok\tsid\t0\n{"text":"owner rows"}\n@@MP_END@@\n'
        with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader.subprocess, 'run', side_effect=[subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0, expected, '')]) as run:
            self.assertEqual(reader.response(self.query, source=reader.READER_SOURCE), expected)
        self.assertEqual(run.call_args_list[0].args[0], ['sudo', '-n', '-u', 'secondary', '--', 'true'])
        command = run.call_args_list[1].args[0]
        self.assertEqual(command[:8], ['sudo', '-n', '-H', '-u', 'secondary', '--', 'python3', '-'])
        self.assertEqual(json.loads(base64.b64decode(command[8])), self.query)
        self.assertEqual(command[9], '--owner')
        self.assertEqual(run.call_args_list[1].kwargs['input'], reader.READER_SOURCE)
        self.assertNotIn('shell', run.call_args_list[1].kwargs)

    def test_sudo_unavailable_timeout_and_owner_reexec_never_prompt_or_loop(self):
        for failure in [subprocess.CompletedProcess([], 1), FileNotFoundError(), subprocess.TimeoutExpired('sudo', 3)]:
            effect = failure if isinstance(failure, Exception) else [failure]
            with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                    patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                    patch.object(reader.subprocess, 'run', side_effect=effect) as run:
                wire = reader.response(self.query, source=reader.READER_SOURCE)
            self.assertIn('\thistory\tmissing\t', wire)
            self.assertIn('permission denied', wire)
            self.assertEqual(run.call_count, 1)
        with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader.subprocess, 'run', side_effect=AssertionError('must not loop')):
            self.assertIn('permission denied', reader.response(self.query, reader.READER_SOURCE, as_owner=True))

    def test_missing_reason_and_stdin_source_can_reexecute_without_a_local_reader_file(self):
        self.query['tmux'] = ''
        self.assertIn('session transcript not found', reader.response(self.query))
        self.write(self.event('reexecuted stdin'))
        with patch.dict('os.environ', {'HOME': str(self.home)}):
            encoded = base64.b64encode(json.dumps(self.query).encode()).decode()
            result = subprocess.run([sys.executable, '-', encoded, '--owner'], input=reader.READER_SOURCE,
                                    capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('reexecuted stdin', result.stdout)

    def test_complete_history_pages_then_only_new_bytes(self):
        self.write(*(self.event(f'message {i} ' + 'x' * 4000) for i in range(500)))
        fields, rows = self.read()
        self.assertGreater(int(fields[5]), 0)
        self.assertTrue(rows[-1]['text'].startswith('message 499 '))
        latest_offset = self.query['offset']
        pages = 1
        while self.query['start']:
            self.query['before'] = self.query['start']
            fields, page = self.read()
            rows = page + rows
            pages += 1
            self.assertEqual(self.query['offset'], latest_offset)
        self.assertGreater(pages, 1)
        self.assertEqual(len(rows), 500)
        self.assertTrue(rows[0]['text'].startswith('message 0 '))
        self.assertTrue(rows[-1]['text'].startswith('message 499 '))
        offset = self.query['offset']
        fields, page = self.read()
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual(page, [])
        with self.path.open('a') as f:
            f.write(json.dumps(self.event('new delta')) + '\n')
        fields, page = self.read()
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual([r['text'] for r in page], ['new delta'])

    def test_long_message_is_sent_whole_not_trimmed_to_180kb(self):
        text = 'start ' + 'ę' * 400000 + ' end'
        self.write(self.event(text))
        fields, rows = self.read()
        self.assertEqual(rows, [])
        self.query['before'] = int(fields[14])
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], text)

    def test_partial_utf8_record_does_not_advance_cursor(self):
        self.write(self.event('first'))
        _, rows = self.read()
        offset = self.query['offset']
        raw = (json.dumps(self.event('ę second'), ensure_ascii=False) + '\n').encode()
        with self.path.open('ab') as f:
            f.write(raw[:-2])
        fields, rows = self.read()
        self.assertEqual(self.query['offset'], offset)
        self.assertEqual(rows, [])
        with self.path.open('ab') as f:
            f.write(raw[-2:])
        fields, rows = self.read()
        self.assertEqual([r['text'] for r in rows], ['ę second'])

    def test_tool_only_pages_advance_without_dropping_next_message(self):
        self.write(self.event('first'))
        self.read()
        tool = json.dumps(dict(type='progress', text='large tool data' * 10)) + '\n'
        with self.path.open('a') as source:
            source.write(tool + json.dumps(self.event('reply')) + '\n')
        with patch.object(reader, 'SCAN_BYTES', len(tool)):
            fields, rows = self.read()
        self.assertEqual(rows, [])
        self.assertEqual(fields[8], '1')
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'reply')

    def test_replaced_file_and_wrong_cached_sid_restart_at_zero(self):
        self.write(self.event('old'))
        self.read()
        fresh = self.path.with_suffix('.tmp')
        fresh.write_text(json.dumps(self.event('new inode')) + '\n')
        fresh.replace(self.path)
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual(rows[0]['text'], 'new inode')
        self.query['cached_sid'] = 'another'
        self.assertEqual(self.read()[0][5], '0')

    def test_issue358_first_page_starts_at_the_question_behind_a_big_hidden_record(self):
        hidden = dict(type='user', isMeta=True, message=dict(role='user', content=[dict(type='text', text='s' * (reader.TAIL_BYTES + 100000))]))
        question = dict(type='user', message=dict(role='user', content='QUESTION-358 research the best b2b repos'))
        self.write(self.event('EARLIER-358'), self.event('p' * (reader.TAIL_BYTES + 1000)), question, hidden, self.event('ANSWER-358'))
        old = subprocess.CompletedProcess([], 0, (ROOT / 'tools/fixtures/reader-before-e85be39.py').read_text(), '')
        control = types.ModuleType('reader358control')
        exec(compile(old.stdout, 'reader358control.py', 'exec'), control.__dict__)
        control.HOME = self.home
        control_rows = control.response(dict(self.query)).splitlines()[1:-1]
        self.assertEqual([json.loads(row)['role'] for row in control_rows], ['assistant'])
        fields, rows = self.read()
        self.assertEqual(fields[13], 'tail')
        self.assertEqual([row['text'] for row in rows], ['QUESTION-358 research the best b2b repos', 'ANSWER-358'])
        self.assertEqual(fields[14], fields[5])
        self.query['before'] = int(fields[5])
        fields, rows = self.read()
        self.assertEqual(fields[13], 'older')
        self.assertIn('EARLIER-358', [row['text'] for row in rows])

    def test_issue358_look_back_gives_up_before_the_reply_gets_too_big(self):
        hidden = dict(type='user', isMeta=True, message=dict(role='user', content=[dict(type='text', text='s' * (reader.TAIL_BYTES + 100000))]))
        question = dict(type='user', message=dict(role='user', content='QUESTION-358 far back'))
        talk = [self.event('t' * 4000) for _ in range(reader.TAIL_BYTES // 4000 + 10)]
        self.write(question, *talk, hidden, self.event('ANSWER-358'))
        size = self.path.stat().st_size
        wire = reader.response(dict(self.query))
        fields = wire.splitlines()[0].split('\t')
        self.assertGreaterEqual(int(fields[5]), size - reader.TAIL_BYTES)
        self.assertNotIn('QUESTION-358', wire)
        self.assertIn('ANSWER-358', wire)
        with patch.object(reader, 'ISSUE_358_TAIL_STARTS_AT_QUESTION', False):
            self.write(question, hidden, self.event('ANSWER-358'))
            self.assertNotIn('QUESTION-358', reader.response(dict(self.query)))

    def test_shrunken_source_during_scroll_resets_to_tail_instead_of_retrying_stale_page_forever(self):
        self.write(self.event('x' * (reader.TAIL_BYTES + 100)), self.event('old latest'))
        self.read()
        self.assertGreater(self.query['start'], reader.TAIL_BYTES)
        self.query['before'] = self.query['start']
        self.write(self.event('new smaller source'))
        fields, rows = self.read()
        self.assertEqual(fields[13], 'tail')
        self.assertEqual([row['text'] for row in rows], ['new smaller source'])

    def test_same_inode_rewrites_and_changed_append_boundary_restart_at_zero(self):
        self.write(self.event('old reply'))
        self.read()
        self.write(self.event('new reply'))
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual(rows[0]['text'], 'new reply')
        self.write(self.event('newer reply'), self.event('appended'))
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual([r['text'] for r in rows], ['newer reply', 'appended'])

    def test_missing_sid_uses_exact_tmux_process_metadata(self):
        self.write(self.event('mapped history'))
        self.query['sid'] = 'stale'
        with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)) as resolve:
            fields, rows = self.read()
        resolve.assert_called_once_with('claude', 'term-1')
        self.assertEqual(fields[4], 'sid')
        self.assertEqual(rows[0]['text'], 'mapped history')
        with patch.object(reader, 'resolve_tmux_agent', side_effect=AssertionError('exact sid does not scan proc')):
            self.query['sid'] = 'sid'
            self.read()

    def test_claude_pid_map_resolves_its_exact_jsonl(self):
        self.write(self.event())
        metadata = self.home / '.claude/sessions/99.json'
        metadata.parent.mkdir(parents=True)
        metadata.write_text(json.dumps(dict(sessionId='sid', cwd='/work/demo')))
        with patch.object(reader.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '10\n', '')), \
                patch.object(reader, 'process_table', return_value={10: (1, ['bash']), 99: (10, ['claude'])}), \
                patch.object(reader, 'read_process_cwd', return_value='/wrong'):
            self.assertEqual(reader.resolve_tmux_agent('claude', 'term-1'), ('sid', self.path))

    def test_new_session_without_transcript_never_shows_a_neighbours_chat(self):
        self.write(self.event())
        metadata = self.home / '.claude/sessions/99.json'
        metadata.parent.mkdir(parents=True)
        metadata.write_text(json.dumps(dict(sessionId='fresh', cwd='/work/demo')))
        with patch.object(reader.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '10\n', '')), \
                patch.object(reader, 'process_table', return_value={10: (1, ['bash']), 99: (10, ['claude'])}), \
                patch.object(reader, 'read_process_cwd', return_value='/work/demo'):
            self.assertIsNone(reader.resolve_tmux_agent('claude', 'term-1'))

    def test_descends_sudo_su_and_runtime_without_mistaking_arguments_for_agents(self):
        table = {10: (1, ['bash']), 11: (10, ['sudo', '-u', 'secondary', 'claude']),
                 12: (11, ['su', 'secondary', '-c', 'claude']),
                 13: (12, ['node', '/opt/bin/claude.js']),
                 20: (1, ['claude'])}
        self.assertEqual(reader.agent_pid_for_panes([10], table, 'claude'), 13)
        self.assertIsNone(reader.agent_pid_for_panes([99], table, 'claude'))
        self.assertIsNone(reader.agent_pid_for_panes([10], {10: (1, ['python3', '-c', 'claude'])}, 'claude'))
        old = subprocess.CompletedProcess([], 0, (ROOT / 'tools/fixtures/reader-before-7a02ac9.py').read_text(), '')
        control = types.ModuleType('reader708')
        exec(compile(old.stdout, 'reader708.py', 'exec'), control.__dict__)
        self.assertNotEqual(control.agent_pid_for_panes([10], table, 'claude'), 13)

    def test_local_ssh_socket_join_separates_same_user_same_cwd_sessions(self):
        table = {10: (1, ['bash']), 11: (10, ['ssh', '-t', 'secondary@localhost']),
                 20: (1, ['ssh', '-t', 'secondary@localhost']),
                 30: (2, ['sshd: secondary [priv]']), 31: (30, ['sshd: secondary@pts/1']),
                 32: (31, ['bash']), 33: (32, ['claude']),
                 40: (2, ['sshd: secondary [priv]']), 41: (40, ['bash']), 42: (41, ['claude'])}
        client = ('0100007F:ABCD', '0100007F:0016')
        other = ('0100007F:ABCE', '0100007F:0016')
        connections = {11: [client], 20: [other], 30: [client[::-1]], 31: [client[::-1]], 40: [other[::-1]]}
        self.assertIsNone(reader.agent_pid_for_panes([10], table, 'claude'))
        linked = reader.link_local_ssh(table.copy(), connections)
        self.assertEqual(reader.agent_pid_for_panes([10], linked, 'claude'), 33)
        self.assertEqual(reader.agent_pid_for_panes([20], linked, 'claude'), 42)
        self.assertIsNone(reader.agent_pid_for_panes([10], reader.link_local_ssh(table.copy(), {11: [client], 30: [other[::-1]]}), 'claude'))
        ipv6 = ('00000000000000000000000001000000:ABCD', '00000000000000000000000001000000:0016')
        self.assertEqual(reader.agent_pid_for_panes([10], reader.link_local_ssh(table.copy(), {11: [ipv6], 30: [ipv6[::-1]]}), 'claude'), 33)

    def test_proc_snapshot_reads_tcp_socket_inodes_and_tolerates_inaccessible_fds(self):
        root = self.home / 'proc'
        (root / 'net').mkdir(parents=True)
        (root / 'net/tcp').write_text('header\n0: 0100007F:ABCD 0100007F:0016 01 0 0 0 0 0 100\n0: 0100007F:0016 0100007F:ABCD 01 0 0 0 0 0 101\n')
        (root / 'net/tcp6').write_text('header\n')
        for pid, inode in [(10, 100), (30, 101)]:
            (root / str(pid) / 'fd').mkdir(parents=True)
            (root / str(pid) / 'fd/3').symlink_to(f'socket:[{inode}]')
        table = {10: (1, ['ssh']), 30: (2, ['sshd: secondary [priv]']), 31: (30, ['claude']), 40: (2, ['sshd: unrelated'])}
        with patch.object(reader, 'process_table', return_value=table):
            linked = reader.local_ssh_process_table(root)
        self.assertEqual(reader.agent_pid_for_panes([10], linked, 'claude'), 31)

    def test_open_transcript_is_exact_newest_and_excludes_subagents_and_outside_paths(self):
        self.write(self.event('open transcript'))
        newer = self.path.with_name('newer.jsonl')
        newer.write_text(json.dumps(self.event('newest')) + '\n')
        import os
        os.utime(self.path, (1, 1))
        os.utime(newer, (2, 2))
        subagent = self.path.parent / 'sid/subagents/agent-other.jsonl'
        subagent.parent.mkdir(parents=True)
        subagent.write_text('{}\n')
        outside = self.home / 'outside.jsonl'
        outside.write_text('{}\n')
        fd = self.home / 'fd'
        fd.mkdir()
        for index, target in enumerate([self.path, newer, subagent, outside]):
            (fd / str(index)).symlink_to(target)
        original_iterdir = Path.iterdir
        def proc_fds(path):
            return fd.iterdir() if str(path) == '/proc/99/fd' else original_iterdir(path)
        with patch.object(Path, 'iterdir', proc_fds), patch.object(reader, 'read_process_cwd', return_value='/wrong'), \
                patch.object(reader, 'claude_session_metadata', side_effect=AssertionError('open transcript wins')):
            self.assertEqual(reader.resolve_tmux_agent('claude', 'term-1', 99), ('newer', newer))

    def test_empty_identity_discovers_owner_then_reads_same_source_as_owner_once(self):
        self.query.update(sid='', cwd='')
        expected = '@mp\t7\thistory\tok\tsid\t0\n{"text":"cross-user"}\n@@MP_END@@\n'
        with patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader, 'tmux_owner_process', return_value=(99, ('secondary', Path('/home/secondary')))), \
                patch.object(reader, 'owner_response', return_value=expected) as read_owner:
            self.assertEqual(reader.response(self.query, reader.READER_SOURCE), expected)
        owner_query = dict(self.query, discovery_pid=99)
        read_owner.assert_called_once_with(owner_query, ('secondary', Path('/home/secondary')), reader.READER_SOURCE)
        self.write(self.event('owner process map'))
        with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)) as resolve, \
                patch.object(reader, 'tmux_owner_process', side_effect=AssertionError('no recursive sudo')):
            self.assertIn('owner process map', reader.response(owner_query, reader.READER_SOURCE, as_owner=True))
        resolve.assert_called_once_with('claude', 'term-1', 99)

    def test_stale_saved_sid_returns_to_the_callers_tmux_server_for_owner_discovery(self):
        missing = reader.missing_response(self.query, 'session transcript not found')
        expected = '@mp\t7\thistory\tok\tlive-sid\t0\n{"text":"live rows"}\n@@MP_END@@\n'
        owner = ('secondary', Path('/home/secondary'))
        with patch.object(reader, 'conversation_owner', return_value=owner), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader, 'owner_response', side_effect=[missing, expected]) as read_owner, \
                patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader, 'tmux_owner_process', return_value=(99, owner)):
            self.assertEqual(reader.response(self.query, reader.READER_SOURCE), expected)
        self.assertEqual(read_owner.call_count, 2)
        self.assertEqual(read_owner.call_args.args[0], dict(self.query, sid='', discovery_pid=99))

    def test_privileged_discovery_is_noninteractive_stdin_only_and_cannot_select_root(self):
        outputs = [subprocess.CompletedProcess([], 0, '10\n', ''),
                   subprocess.CompletedProcess([], 0, '{"pid":99,"user":"secondary"}', '')]
        with patch.object(reader.subprocess, 'run', side_effect=outputs) as run, \
                patch.object(reader.pwd, 'getpwnam', return_value=self.owner()):
            self.assertEqual(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE), (99, ('secondary', Path('/home/secondary'))))
        self.assertEqual(run.call_args_list[0].args[0][3], '=remote-3')
        command = run.call_args_list[1].args[0]
        self.assertEqual(command[:5], ['sudo', '-n', '--', 'python3', '-'])
        self.assertEqual(json.loads(base64.b64decode(command[5])), dict(agent='claude', panes=[10]))
        self.assertEqual(command[6], '--discover')
        self.assertEqual(run.call_args_list[1].kwargs['input'], reader.READER_SOURCE)
        self.assertNotIn('shell', run.call_args_list[1].kwargs)
        for failure in [subprocess.CompletedProcess([], 1, '', 'denied'), subprocess.TimeoutExpired('sudo', 8),
                        subprocess.CompletedProcess([], 0, 'not json', '')]:
            with patch.object(reader.subprocess, 'run', side_effect=[outputs[0], failure]):
                self.assertIsNone(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE))
        with patch.object(reader.subprocess, 'run', side_effect=outputs), \
                patch.object(reader.pwd, 'getpwnam', return_value=self.owner(uid=0)):
            self.assertIsNone(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE))

    def test_filtering_keeps_queued_prompt_and_plain_text_only(self):
        self.write(dict(type='attachment', attachment=dict(type='queued_command', prompt='queued')),
                   dict(type='user', message=dict(role='user', content='<command-name>/test</command-name><command-args>foo</command-args>')),
                   self.event('sidechain', isSidechain=True),
                   dict(type='assistant', message=dict(role='assistant', content=[dict(type='tool_use', input='private')])),
                   self.event('answer', timestamp='2026-10-03T12:34:00Z'))
        _, rows = self.read()
        self.assertEqual([r['text'] for r in rows], ['queued', '/test foo', 'answer'])

    def test_refused_slash_command_facts_are_opt_in_and_additive(self):
        prompt = '/hormozi-skills:audit-offer can you use this also to review my own offer'
        enqueue = dict(type='queue-operation', operation='enqueue', timestamp='2026-10-13T11:06:22.591Z', content=prompt)
        refused = dict(type='system', subtype='informational', level='warning',
                       timestamp='2026-10-13T11:06:59.442Z', content='Unknown command: /hormozi-skills:audit-offer')
        args = dict(refused, content='Args from unknown skill: can you use this also to review my own offer')
        self.write(enqueue, refused, args, self.event('normal reply'))
        _, legacy = self.read()
        self.assertEqual([r['text'] for r in legacy], ['normal reply'])
        self.query.update(settlement=True, offset=0, cached_sid='')
        _, rows = self.read()
        self.assertEqual(rows[-1], legacy[0])
        self.assertEqual([r['settlement']['operation'] for r in rows[:-1]], ['enqueue', 'rejected', 'rejected'])
        self.assertEqual(rows[0]['settlement']['content'], prompt)
        self.assertEqual(rows[1]['timestamp'], refused['timestamp'])
        self.assertEqual(rows[1]['settlement']['content'], refused['content'])
        self.assertIsNone(reader.settlement_event(dict(refused, isSidechain=True), 'claude'))
        self.assertIsNone(reader.settlement_event(dict(refused, content='Compacted while idle'), 'claude'))
        self.assertIsNone(reader.settlement_event(refused, 'codex'))

    def test_queue_removal_and_contentless_dequeue_popall_survive_delta_paging(self):
        self.query['settlement'] = True
        enqueue = dict(type='queue-operation', operation='enqueue', content='please review my offer', timestamp='2026-10-13T11:06:22.591Z')
        self.write(enqueue)
        _, rows = self.read()
        self.assertEqual(rows[0]['settlement']['operation'], 'enqueue')
        with self.path.open('a') as output:
            for event in [dict(enqueue, operation='remove'),
                          dict(type='queue-operation', operation='dequeue', timestamp='2026-10-13T11:06:59Z'),
                          dict(type='queue-operation', operation='popAll', timestamp='2026-10-13T11:07:00Z')]:
                output.write(json.dumps(event) + '\n')
        _, rows = self.read()
        self.assertEqual([r['settlement']['operation'] for r in rows], ['remove', 'dequeue', 'popAll'])
        self.assertEqual(rows[0]['settlement']['content'], enqueue['content'])
        self.assertEqual(rows[1]['settlement']['content'], '')

    def test_enqueued_command_delivered_midturn_and_normal_user_remain_user_rows(self):
        self.query['settlement'] = True
        prompt = 'please review my offer'
        self.write(dict(type='queue-operation', operation='enqueue', content=prompt, timestamp='2026-10-13T11:06:22.591Z'),
                   dict(type='queue-operation', operation='remove', content=prompt, timestamp='2026-10-13T11:06:59.442Z'),
                   dict(type='attachment', timestamp='2026-10-13T11:06:59.443Z',
                        attachment=dict(type='queued_command', prompt=prompt)),
                   dict(type='user', timestamp='2026-10-13T11:07:00Z', message=dict(role='user', content='normal user message')))
        _, rows = self.read()
        self.assertEqual([r['text'] for r in rows[2:]], [prompt, 'normal user message'])
        self.assertEqual([r['role'] for r in rows[2:]], ['user', 'user'])
        self.assertEqual(rows[2]['timestamp'], '2026-10-13T11:06:59.443Z')

    def test_codex_rollout_and_input_output_text(self):
        path = self.home / '.codex/sessions/2026/rollout-day-sid.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(dict(type='response_item', payload=dict(type='message', role='user', content=[dict(type='input_text', text='codex prompt')]))) + '\n')
        self.query['codex'] = True
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'codex prompt')

    def test_untrusted_identity_and_corrupt_records_fail_not_partial_success(self):
        self.query['sid'] = '../escape'
        with self.assertRaises(ValueError):
            reader.response(self.query)
        self.query['sid'] = 'sid'
        self.path.write_text('{invalid}\n')
        with self.assertRaises(ValueError):
            reader.response(self.query)

    def test_50mb_cold_start_reads_only_tail_and_rejects_706_positive_control(self):
        self.path.write_text(json.dumps(dict(type='progress', text='x' * (40 * 1024 * 1024))) + '\n')
        row = json.dumps(self.event('latest ' + 'y' * 2000)) + '\n'
        with self.path.open('a') as source:
            while source.tell() < 50 * 1024 * 1024:
                source.write(row)
            source.write(json.dumps(self.event('LATEST-50MB')) + '\n')
        size = self.path.stat().st_size
        original_open = Path.open

        def measure(module):
            read_bytes = 0

            class Counted:
                def __init__(self, source):
                    self.source = source

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return self.source.__exit__(*args)

                def __getattr__(self, name):
                    return getattr(self.source, name)

                def read(self, *args):
                    nonlocal read_bytes
                    data = self.source.read(*args)
                    read_bytes += len(data)
                    return data

                def readline(self, *args):
                    nonlocal read_bytes
                    data = self.source.readline(*args)
                    read_bytes += len(data)
                    return data

            def counted_open(path, *args, **kwargs):
                source = original_open(path, *args, **kwargs)
                return Counted(source) if path == self.path and args == ('rb',) else source

            start = time.monotonic()
            with patch.object(Path, 'open', counted_open):
                wire = module.response(self.query)
            fields = wire.splitlines()[0].split('\t')
            elapsed = time.monotonic() - start
            return read_bytes, elapsed, fields, wire

        def bounded(result):
            count, elapsed, fields, wire = result
            self.assertLessEqual(count, reader.QUESTION_SCAN_BYTES + 64)
            self.assertGreaterEqual(int(fields[5]), size - reader.TAIL_BYTES)
            self.assertEqual(int(fields[6]), size)
            self.assertIn('LATEST-50MB', wire)
            self.assertLess(elapsed, 2.0)

        result = measure(reader)
        bounded(result)
        print(f'CPU707 first-load source_bytes={size} read_bytes={result[0]} ms={result[1] * 1000:.1f}')
        old = subprocess.CompletedProcess([], 0, (ROOT / 'tools/fixtures/reader-before-5880899.py').read_text(), '')
        control = types.ModuleType('reader706')
        exec(compile(old.stdout, 'reader706.py', 'exec'), control.__dict__)
        control.HOME = self.home
        with self.assertRaises(AssertionError):
            bounded(measure(control))

    def test_stale_cursor_on_145mb_log_jumps_to_newest_in_one_reply(self):
        row_size = 4096
        overhead = len((json.dumps(self.event('')) + '\n').encode())
        row = (json.dumps(self.event('y' * (row_size - overhead))) + '\n').encode()
        self.assertEqual(len(row), row_size)
        with self.path.open('wb') as output:
            output.write(b'{"type":"progress","text":"')
            chunk = b'x' * (1024 * 1024)
            for _ in range(120):
                output.write(chunk)
            output.write(b'"}\n')
            while output.tell() < 132 * 1024 * 1024:
                output.write(row * min(256, (132 * 1024 * 1024 - output.tell() + row_size - 1) // row_size))
        self.read()
        stale = dict(self.query)
        self.assertEqual(stale['offset'], self.path.stat().st_size)
        with self.path.open('ab') as output:
            for _ in range(13):
                output.write(row * 256)
            output.write((json.dumps(self.event('NEWEST-145MB')) + '\n').encode())
        size = self.path.stat().st_size
        self.assertGreaterEqual(size, 145 * 1024 * 1024)
        behind = size - stale['offset']
        self.assertGreater(behind, 2 * reader.SCAN_BYTES)
        original_open = Path.open
        read_bytes = 0

        class Counted:
            def __init__(self, source):
                self.source = source

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return self.source.__exit__(*args)

            def __getattr__(self, name):
                return getattr(self.source, name)

            def read(self, *args):
                nonlocal read_bytes
                data = self.source.read(*args)
                read_bytes += len(data)
                return data

        def counted_open(path, *args, **kwargs):
            source = original_open(path, *args, **kwargs)
            return Counted(source) if path == self.path and args == ('rb',) else source

        with patch.object(Path, 'open', counted_open):
            start = time.monotonic()
            wire = reader.response(stale)
            elapsed = time.monotonic() - start
        fields = wire.splitlines()[0].split('\t')
        self.assertEqual(fields[13], 'tail')
        self.assertIn('NEWEST-145MB', wire)
        self.assertEqual(fields[8], '0')
        self.assertEqual(int(fields[6]), size)
        self.assertEqual(fields[14], fields[5])
        self.assertGreaterEqual(int(fields[5]), size - reader.TAIL_BYTES)
        self.assertLessEqual(read_bytes, reader.QUESTION_SCAN_BYTES + 128)
        self.assertLess(elapsed, 0.3)
        print(f'stale-cursor source_bytes={size} behind_bytes={behind} ms={elapsed * 1000:.1f} read_bytes={read_bytes}')

    def test_stale_cursor_switch_off_preserves_delta(self):
        self.write(self.event('cached'))
        self.read()
        offset = self.query['offset']
        row = json.dumps(self.event('new row')) + '\n'
        with self.path.open('a') as output:
            output.write(row * 8)
        with patch.object(reader, 'SCAN_BYTES', len(row) * 2), \
                patch.object(reader, 'ISSUE_345_STALE_JUMPS_TO_TAIL', False):
            fields, rows = self.read()
        self.assertEqual(fields[13], 'delta')
        self.assertEqual(fields[8], '1')
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual(int(fields[6]), offset + len(row) * 2)
        self.assertEqual([row['text'] for row in rows], ['new row', 'new row'])

    def test_recent_cursor_appends_exact_new_rows_as_delta(self):
        for behind in (1, 2):
            with self.subTest(scan_multiple=behind):
                self.write(self.event('cached'))
                self.read()
                offset = self.query['offset']
                events = [self.event('new one'), self.event('new two')]
                data = ''.join(json.dumps(event) + '\n' for event in events)
                with self.path.open('a') as output:
                    output.write(data)
                with patch.object(reader, 'SCAN_BYTES', len(data) // behind):
                    fields, rows = self.read()
                    self.assertEqual(fields[13], 'delta')
                    if fields[8] == '1':
                        fields, page = self.read()
                        self.assertEqual(fields[13], 'delta')
                        rows += page
                self.assertEqual([row['text'] for row in rows], ['new one', 'new two'])
                self.assertEqual(fields[8], '0')
                self.assertEqual(self.query['offset'], offset + len(data))

    def test_stale_cursor_with_empty_tail_keeps_existing_delta_logic(self):
        self.write(self.event('cached'))
        self.read()
        offset = self.query['offset']
        row = json.dumps(self.event('new row')) + '\n'
        with self.path.open('a') as output:
            output.write(row)
            output.write(json.dumps(dict(type='progress', text='x' * (reader.TAIL_BYTES + 100))) + '\n')
        with patch.object(reader, 'SCAN_BYTES', len(row)):
            fields, rows = self.read()
        self.assertEqual(fields[13], 'delta')
        self.assertEqual(fields[8], '1')
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual(int(fields[6]), offset + len(row))
        self.assertEqual([row['text'] for row in rows], ['new row'])

    def test_stale_cursor_whose_tail_has_no_messages_keeps_delta(self):
        self.write(self.event('cached'))
        self.read()
        offset = self.query['offset']
        row = json.dumps(self.event('new row')) + '\n'
        tool = json.dumps(dict(type='progress', text='t' * 200)) + '\n'
        with self.path.open('a') as output:
            output.write(row + tool * (reader.TAIL_BYTES // len(tool) + 10))
        with patch.object(reader, 'SCAN_BYTES', len(row) + len(tool)):
            fields, rows = self.read()
        self.assertEqual(fields[13], 'delta')
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual([row['text'] for row in rows], ['new row'])

    def start_server(self):
        bootstrap = "import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))"
        server = subprocess.Popen([sys.executable, '-u', '-c', bootstrap, '--serve'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  env=dict(os.environ, HOME=str(self.home)))
        def cleanup():
            server.stdin.close()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
            server.stdout.close()
            server.stderr.close()
        self.addCleanup(cleanup)
        server.stdin.write(base64.b64encode((ROOT / 'src/chat_history_reader.py').read_bytes()) + b'\n')
        server.stdin.flush()
        return server

    def server_request(self, server, query):
        line = query if isinstance(query, bytes) else json.dumps(query).encode()
        server.stdin.write(line + b'\n')
        server.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(server.stdout, selectors.EVENT_READ)
            self.assertTrue(selector.select(timeout=5), 'reader reply timed out')
        reply = json.loads(server.stdout.readline())
        self.assertTrue(reply['wire'].endswith(reader.END + '\n'))
        return reply

    def test_serve_multiple_requests_observe_appends_and_eof_in_one_process(self):
        self.write(self.event('first reply'))
        server = self.start_server()
        first = self.server_request(server, self.query)
        self.assertEqual(first['id'], 7)
        self.assertIn('first reply', first['wire'])
        fields = first['wire'].splitlines()[0].split('\t')
        self.query.update(id=8, cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]))
        with self.path.open('a') as output:
            output.write(json.dumps(self.event('second reply')) + '\n')
        second = self.server_request(server, self.query)
        self.assertEqual(second['id'], 8)
        self.assertIn('second reply', second['wire'])
        self.assertNotIn('first reply', second['wire'])
        self.assertIsNone(server.poll())
        server.stdin.close()
        self.assertEqual(server.wait(timeout=5), 0)
        self.assertEqual(server.stderr.read(), b'')

    def test_serve_malformed_requests_do_not_poison_next_request(self):
        self.write(self.event('after malformed'))
        server = self.start_server()
        for malformed in [b'not json', b'null', b'[]', b'{}', b'{"id":9}',
                          b'{"id":true}', b'{"id":-1}', b'{"id":"bad"}']:
            reply = self.server_request(server, malformed)
            self.assertIn('\thistory\terror\t', reply['wire'])
            self.assertEqual(reply['id'], 9 if malformed == b'{"id":9}' else 0)
        self.assertIn('after malformed', self.server_request(server, self.query)['wire'])
        self.assertIsNone(server.poll())

    def test_serve_large_transcript_and_oversized_older_reply_remain_framed(self):
        giant = 'large \" \\ \n 雪 ' * 120000
        self.write(self.event(giant), *(self.event('new ' + str(i) + 'x' * 4000) for i in range(300)))
        server = self.start_server()
        reply = self.server_request(server, self.query)
        fields = reply['wire'].splitlines()[0].split('\t')
        self.assertIn('new 299', reply['wire'])
        self.query.update(id=8, cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]),
                          before=int(fields[14]))
        saw_giant = False
        for rid in range(8, 16):
            self.query['id'] = rid
            reply = self.server_request(server, self.query)
            self.assertEqual(reply['id'], rid)
            rows = reply['wire'].splitlines()
            messages = [json.loads(row) for row in rows[1:-1]]
            saw_giant = any(message['text'] == giant for message in messages)
            self.query['before'] = int(rows[0].split('\t')[14])
            if saw_giant:
                self.assertGreater(len(reply['wire']), 1024 * 1024)
                break
        self.assertTrue(saw_giant)
        self.query.update(id=99, before=0)
        self.assertEqual(self.server_request(server, self.query)['id'], 99)

    def test_embedded_stdin_transaction_without_remote_helper_install(self):
        with patch.dict('os.environ', {'HOME': str(self.home)}):
            self.write(self.event('stdin history'))
            encoded = base64.b64encode(json.dumps(self.query).encode()).decode()
            p = subprocess.run([sys.executable, '-', encoded], input=(ROOT / 'src/chat_history_reader.py').read_text(), text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('stdin history', p.stdout)
        self.assertTrue(p.stdout.endswith('@@MP_END@@\n'))


if __name__ == '__main__':
    unittest.main()
