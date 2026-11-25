import contextlib
import io
import json
import os
from pathlib import Path
import socket
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tools/fixtures/MUBO-566"
WRAPPERS = ("src/mp_zsb.sh", "tools/vps-multiprompt-browser.sh")


class ZsbPortHolderTest(unittest.TestCase):
    def request(self, wrapper, holder, reply=b"", unavailable=False):
        source = (ROOT / wrapper).read_text().split("<<'PY_REQUEST'\n", 1)[1].split("\nPY_REQUEST", 1)[0]
        read_text, read_bytes, iterdir = Path.read_text, Path.read_bytes, Path.iterdir
        proc = Path("/proc") / str(holder["pid"])

        def text(path, *args, **kwargs):
            if str(path) == "/proc/net/tcp":
                return "header\n0: 0100007F:4C5C 00000000:0000 0A 0 0 0 0 0 12345\n"
            if str(path) == "/proc/net/tcp6":
                return "header\n"
            return read_text(path, *args, **kwargs)

        def binary(path, *args, **kwargs):
            if path == proc / "cmdline":
                return holder["command"].replace(" ", "\x00").encode() + b"\x00"
            return read_bytes(path, *args, **kwargs)

        def entries(path):
            if str(path) == "/proc":
                return iter([proc])
            if path == proc / "fd":
                return iter([path / "3"])
            return iterdir(path)

        conn = MagicMock()
        conn.__enter__.return_value = conn
        conn.recv.side_effect = [reply, b""] if reply else [b""]
        output, errors = io.StringIO(), io.StringIO()
        with tempfile.TemporaryDirectory() as home, \
                patch.dict(os.environ, {"HOME": home, "XDG_CONFIG_HOME": home,
                                        "MULTIPROMP_NOTIFY_RELAY_TOKEN": "fixture-token"}, clear=True), \
                patch.object(sys, "argv", [wrapper, "fixture-chat", "19548", "status"]), \
                patch.object(Path, "read_text", text), patch.object(Path, "read_bytes", binary), \
                patch.object(Path, "iterdir", entries), patch("os.readlink", return_value="socket:[12345]"), \
                patch.object(socket, "create_connection", side_effect=OSError("fixture refused") if unavailable else None,
                             return_value=conn), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            code = 0
            try:
                exec(compile(source, wrapper, "exec"), {"__name__": "__main__"})
            except SystemExit as error:
                code = error.code
        return code, json.loads(output.getvalue()), conn

    def test_MUBO_566_notification_relay_is_a_bridge_not_a_port_conflict(self):
        holders = json.loads((FIXTURES / "port-holders.json").read_text())
        for wrapper in WRAPPERS:
            for holder in holders["bridges"]:
                for unavailable, expected in ((False, "empty_reply"), (True, "tunnel_down")):
                    with self.subTest(wrapper=wrapper, holder=holder, unavailable=unavailable):
                        code, reply, _ = self.request(wrapper, holder, unavailable=unavailable)
                        self.assertEqual(code, 1)
                        self.assertEqual(reply["error"], expected)
                        self.assertNotIn("kill ", reply.get("hint", ""))

    def test_MUBO_566_other_port_holders_are_still_refused_and_named(self):
        holders = json.loads((FIXTURES / "port-holders.json").read_text())
        for wrapper in WRAPPERS:
            for holder in holders["conflicts"]:
                for unavailable in (False, True):
                    with self.subTest(wrapper=wrapper, holder=holder, unavailable=unavailable):
                        code, reply, _ = self.request(wrapper, holder, unavailable=unavailable)
                        self.assertEqual(code, 1)
                        self.assertEqual(reply["error"], "port_conflict")
                        self.assertEqual(reply["holder"], holder)

    def test_MUBO_566_bridge_replies_reach_the_browser_unchanged(self):
        holder = json.loads((FIXTURES / "port-holders.json").read_text())["bridges"][0]
        expected = {"ok": True, "result": {"url": "https://example.com/fixture"}}
        for wrapper in WRAPPERS:
            with self.subTest(wrapper=wrapper):
                code, reply, conn = self.request(wrapper, holder, json.dumps(expected).encode())
                self.assertEqual(code, 0)
                self.assertEqual(reply, expected)
                self.assertTrue(conn.sendall.call_args.args[0].startswith(b"AUTH:fixture-token:ZSB:fixture-chat:"))


if __name__ == "__main__":
    unittest.main()
