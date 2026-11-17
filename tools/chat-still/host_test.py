import importlib.util
import json
import pathlib
import tempfile
import threading
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("chat_still_host", pathlib.Path(__file__).with_name("host.py"))
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class HostStreamTest(unittest.TestCase):
    def test_stream_uses_production_events_and_finishes_in_provider_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            sid = "a1b2c3d4-0927-4000-8000-000000000901"
            (root / "state.json").write_text(json.dumps({"sessions": ["first", "target"], "sids": {"target": sid}, "home": str(root)}))
            transcript = root / ".claude/projects/C--verify-work1" / (sid + ".jsonl")
            transcript.parent.mkdir(parents=True)
            transcript.write_text('{"existing":true}\n')
            (root / "still-stream-start").touch()
            events, records, requests, sends = [], [], [], []
            completed = threading.Event()

            def record(file, **row):
                records.append(row)
                if row["stage"] in ("completed", "error"):
                    completed.set()

            def event(provider, identity, tmux, session, kind, payload=None, item=None):
                self.assertEqual((provider, identity, tmux), ("claude", sid, "target"))
                events.append({"event": {"kind": kind, "payload": payload, "item": item, "sid": identity}})

            namespace = {"serve_request": lambda *args: requests.append(args),
                         "serve_print": lambda response: sends.append(response), "host_event": event}
            host.install(namespace, root, record)
            request = namespace["serve_request"]
            request(json.dumps({"op": "events_subscribe", "sid": "other"}), None, {}, None)
            self.assertFalse((root / "still-host-claimed").exists())
            with mock.patch.object(host.time, "sleep", lambda duration: None):
                request(json.dumps({"op": "events_subscribe", "sid": sid}), None, {}, None)
                self.assertTrue(completed.wait(2), records)
            self.assertEqual(records[-1]["stage"], "completed", records)
            deltas = [row["event"] for row in events if row["event"]["kind"] == "text.delta"]
            self.assertEqual(len(deltas), 30)
            self.assertEqual(len({row["item"] for row in deltas}), 1)
            self.assertTrue(all(len(a["payload"]["text"]) < len(b["payload"]["text"]) for a, b in zip(deltas, deltas[1:])))
            receipt = json.loads((root / "still-stream-receipt.json").read_text())
            self.assertEqual(len(receipt["chunks"]), 30)
            final = json.loads(transcript.read_text().splitlines()[-1])
            self.assertEqual(final["message"]["content"][0]["text"], deltas[-1]["payload"]["text"])
            self.assertEqual(deltas[0]["item"], final["message"]["id"] + ":text:0")
            request(json.dumps({"op": "events_subscribe", "sid": sid}), None, {}, None)
            self.assertEqual(len(events), 33)
            namespace["serve_print"]({"result": {"events": events}})
            self.assertEqual(len(sends), 1)
            self.assertEqual(records[-1]["stage"], "pushed")
            self.assertEqual(len(requests), 3)


if __name__ == "__main__":
    unittest.main()
