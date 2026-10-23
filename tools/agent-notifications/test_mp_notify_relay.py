import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("relay", Path(__file__).with_name("mp_notify_relay.py"))
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)


class Relay(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.servers = []
        self.threads = []
        self.probes = {}
        relay.route_cache.clear()

    def laptop(self, name, reply=b"", probe_reply=None, probe_barrier=None, stall=None, requests=1):
        path = self.directory / (name + ".sock")
        server = socket.socket(socket.AF_UNIX)
        server.bind(str(path))
        server.listen(5)
        server.settimeout(2)
        self.servers.append(server)
        self.addCleanup(server.close)
        received = []
        self.probes[name] = []

        def accept():
            try:
                for _ in range(requests + 1):
                    conn, _ = server.accept()
                    with conn:
                        conn.settimeout(1)
                        message = conn.recv(65536)
                        if message.startswith(b"ZSBWHO:"):
                            self.probes[name].append(message)
                            if probe_barrier:
                                probe_barrier.wait(1)
                            if stall:
                                stall.wait(0.7)
                            if probe_reply is not None:
                                payload = (json.dumps(probe_reply).encode() + b"\n"
                                           if isinstance(probe_reply, dict) else probe_reply)
                                conn.sendall(payload[:5])
                                conn.sendall(payload[5:])
                            continue
                        received.append(message)
                        if reply:
                            conn.sendall(reply)
                        if len(received) == requests:
                            break
            except (OSError, threading.BrokenBarrierError):
                pass

        thread = threading.Thread(target=accept)
        thread.start()
        self.threads.append(thread)
        self.addCleanup(thread.join, 2)
        return received

    def send(self, data, response=False):
        left, right = socket.socketpair()
        thread = threading.Thread(target=relay.handle, args=(right, self.directory))
        thread.start()
        left.sendall(data)
        if response:
            left.settimeout(2)
            result = left.recv(65536)
        else:
            left.shutdown(socket.SHUT_WR)
            result = None
        thread.join(2)
        self.assertFalse(thread.is_alive())
        left.close()
        return result

    def test_fanout_to_two_laptops(self):
        first = self.laptop("one")
        second = self.laptop("two")
        self.send(b"ETA:tab:300:working")
        for thread in self.threads:
            thread.join(2)
        self.assertEqual(first, [b"ETA:tab:300:working"])
        self.assertEqual(second, first)

    def test_dead_socket_is_removed_and_others_receive(self):
        stale = self.directory / "dead.sock"
        dead = socket.socket(socket.AF_UNIX)
        dead.bind(str(stale))
        dead.close()
        live = self.laptop("live")
        self.send(b"DONE:tab")
        self.threads[0].join(2)
        self.assertFalse(stale.exists())
        self.assertEqual(live, [b"DONE:tab"])

    def test_idle_sweep_removes_only_refused_sockets(self):
        stale = self.directory / "dead.sock"
        dead = socket.socket(socket.AF_UNIX)
        dead.bind(str(stale))
        dead.close()
        live = self.directory / "live.sock"
        server = socket.socket(socket.AF_UNIX)
        self.addCleanup(server.close)
        server.bind(str(live))
        server.listen()
        ordinary = self.directory / "ordinary.sock"
        ordinary.write_text("not a socket")
        relay.sweep(self.directory)
        self.assertFalse(stale.exists())
        self.assertTrue(live.exists())
        self.assertTrue(ordinary.exists())

    def test_refused_connect_keeps_a_socket_that_is_still_listening(self):
        live = self.directory / "live.sock"
        server = socket.socket(socket.AF_UNIX)
        self.addCleanup(server.close)
        server.bind(str(live))
        server.listen()

        class Refusing(socket.socket):
            def connect(self, address):
                raise ConnectionRefusedError(111, "Connection refused")

        real = relay.socket.socket
        relay.socket.socket = Refusing
        try:
            relay.sweep(self.directory)
        finally:
            relay.socket.socket = real
        self.assertTrue(live.exists())

    def test_periodic_sweep_removes_socket_without_notifications(self):
        stop = threading.Event()
        swept_twice = threading.Event()
        stale = self.directory / "idle.sock"
        calls = []
        original = relay.sweep

        def observed(directory):
            calls.append(1)
            if len(calls) == 1:
                dead = socket.socket(socket.AF_UNIX)
                dead.bind(str(stale))
                dead.close()
            else:
                original(directory)
                swept_twice.set()

        with patch.object(relay, "SWEEP_INTERVAL", 0.05), patch.object(relay, "sweep", side_effect=observed):
            thread = threading.Thread(target=relay.serve, kwargs={"directory": self.directory, "port": 0, "stop": stop})
            thread.start()
            try:
                self.assertTrue(swept_twice.wait(2))
                self.assertFalse(stale.exists())
            finally:
                stop.set()
                thread.join(2)
                self.assertFalse(thread.is_alive())

    def test_directory_owner_is_required_even_when_mode_is_700(self):
        self.directory.chmod(0o700)
        with patch.object(relay.os, "getuid", return_value=os.getuid() + 1), contextlib.redirect_stderr(io.StringIO()) as log:
            self.assertEqual(relay.serve(self.directory, port=0), relay.UNSAFE_DIRECTORY)
        self.assertIn("not owned", log.getvalue())
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)

    def test_owned_directory_mode_is_repaired(self):
        self.directory.chmod(0o755)
        self.assertTrue(relay.prepare_directory(self.directory))
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)

    def test_unfixable_directory_mode_exits_without_serving(self):
        self.directory.chmod(0o755)
        with patch.object(Path, "chmod", side_effect=PermissionError("denied")), contextlib.redirect_stderr(io.StringIO()) as log:
            self.assertEqual(relay.serve(self.directory, port=0), relay.UNSAFE_DIRECTORY)
        self.assertIn("denied", log.getvalue())

    def test_old_apps_fall_back_to_newest_only(self):
        old = self.laptop("old", b"old reply")
        new = self.laptop("new", b"new reply")
        path = self.directory / "new.sock"
        newer = path.stat().st_mtime_ns + 1_000_000_000
        os.utime(path, ns=(newer, newer))
        self.assertEqual(self.send(b"ZSB:tab:payload\n", response=True), b"new reply")
        self.threads[1].join(2)
        self.assertEqual(new, [b"ZSB:tab:payload\n"])
        self.assertEqual(old, [])

    def test_ranking_prefers_ownership_then_idle_then_legacy_mtime(self):
        paths = ["legacy-new", "no-tab", "idle-owner", "active-owner", "legacy-old"]
        replies = [None, {"has_tab": False, "idle_ms": 0},
                   {"has_tab": True, "idle_ms": 500},
                   {"has_tab": True, "idle_ms": 10}, None]
        self.assertEqual(relay.rank_sockets(paths, replies),
                         ["active-owner", "idle-owner", "legacy-new", "legacy-old", "no-tab"])

    def test_no_owner_prefers_lowest_idle_and_ties_keep_mtime_order(self):
        paths = ["new", "old", "legacy"]
        self.assertEqual(relay.rank_sockets(paths, [
            {"has_tab": False, "idle_ms": 100},
            {"has_tab": False, "idle_ms": 1}, None]), ["legacy", "old", "new"])
        self.assertEqual(relay.rank_sockets(paths, [
            {"has_tab": True, "idle_ms": 1},
            {"has_tab": True, "idle_ms": 1}, None]), paths)
        self.assertEqual(relay.zsb_sockets([], b"tab"), [])

    def test_fake_sockets_probe_in_parallel_and_choose_active_owner_not_newest(self):
        barrier = threading.Barrier(3)
        active = self.laptop("P1", b"P1 reply", {"has_tab": True, "idle_ms": 5, "host": "P1"}, barrier)
        idle = self.laptop("X13s", b"X13s reply", {"has_tab": True, "idle_ms": 10000, "host": "X13s"}, barrier)
        unrelated = self.laptop("other", b"wrong reply", {"has_tab": False, "idle_ms": 0, "host": "other"}, barrier)
        path = self.directory / "X13s.sock"
        newer = path.stat().st_mtime_ns + 1_000_000_000
        os.utime(path, ns=(newer, newer))
        self.assertEqual(self.send(b"ZSB:tab:payload\n", response=True), b"P1 reply")
        self.assertEqual(active, [b"ZSB:tab:payload\n"])
        self.assertEqual(idle, [])
        self.assertEqual(unrelated, [])
        self.assertTrue(all(messages == [b"ZSBWHO:746162\n"] for messages in self.probes.values()))

    def test_fake_sockets_without_owner_choose_lowest_idle(self):
        self.laptop("active", b"active reply", {"has_tab": False, "idle_ms": 0, "host": "P1"})
        self.laptop("idle", b"wrong reply", {"has_tab": False, "idle_ms": 500, "host": "X13s"})
        self.assertEqual(self.send(b"ZSB:tab:payload\n", response=True), b"active reply")

    def test_silent_probes_share_one_deadline_and_owners_beat_unknown(self):
        stalled = threading.Event()
        self.addCleanup(stalled.set)
        for index in range(6):
            self.laptop(str(index), stall=stalled)
        self.laptop("live", b"live reply", {"has_tab": True, "idle_ms": 10000, "host": "P1"})
        started = time.monotonic()
        try:
            self.assertEqual(self.send(b"ZSB:tab:payload\n", response=True), b"live reply")
            self.assertLess(time.monotonic() - started, 0.65)
        finally:
            stalled.set()

    def test_unknown_old_app_beats_explicit_nonowner(self):
        old = self.laptop("legacy", b"legacy reply")
        nonowner = self.laptop("new", b"wrong reply", {"has_tab": False, "idle_ms": 0, "host": "new"})
        self.assertEqual(self.send(b"ZSB:agent-1:payload\n", response=True), b"legacy reply")
        self.assertEqual(old, [b"ZSB:agent-1:payload\n"])
        self.assertEqual(nonowner, [])
        self.assertEqual(self.probes["legacy"], [b"ZSBWHO:6167656e742d31\n"])

    def test_single_socket_never_probes(self):
        received = self.laptop("only", b"reply")
        with patch.object(relay, "probe", wraps=relay.probe) as probe:
            self.assertEqual(self.send(b"ZSB:tab:payload\n", response=True), b"reply")
            probe.assert_not_called()
        self.assertEqual(received, [b"ZSB:tab:payload\n"])
        self.assertEqual(self.probes["only"], [])

    def test_consecutive_requests_reuse_choice_without_wire_probes(self):
        chosen = self.laptop("owner", b"reply", {"has_tab": True, "idle_ms": 0, "host": "owner"}, requests=2)
        other = self.laptop("other", b"wrong reply", {"has_tab": False, "idle_ms": 0, "host": "other"})
        for _ in range(2):
            self.assertEqual(self.send(b"ZSB:agent-1:payload\n", response=True), b"reply")
        self.assertEqual(chosen, [b"ZSB:agent-1:payload\n"] * 2)
        self.assertEqual(other, [])
        self.assertTrue(all(messages == [b"ZSBWHO:6167656e742d31\n"] for messages in self.probes.values()))

    def test_routes_cached_per_session_for_five_seconds_then_reprobed(self):
        paths = [self.directory / "new.sock", self.directory / "old.sock"]
        now = [100.0]
        owner = paths[1]

        def reply(path, session, deadline):
            return {"has_tab": path == owner, "idle_ms": 0, "host": str(path)}

        with patch.object(relay.time, "monotonic", side_effect=lambda: now[0]), patch.object(relay, "probe", side_effect=reply) as probe:
            self.assertEqual(relay.zsb_sockets(paths, b"one"), paths[::-1])
            self.assertEqual(probe.call_count, 2)
            owner = paths[0]
            now[0] = 104.9
            self.assertEqual(relay.zsb_sockets(paths, b"one"), paths[::-1])
            self.assertEqual(probe.call_count, 2)
            self.assertEqual(relay.zsb_sockets(paths, b"two"), paths)
            self.assertEqual(probe.call_count, 4)
            now[0] = 105.0
            self.assertEqual(relay.zsb_sockets(paths, b"one"), paths)
            self.assertEqual(probe.call_count, 6)

    def test_socket_inventory_change_invalidates_cache_and_cache_is_bounded(self):
        paths = [self.directory / "new.sock", self.directory / "old.sock"]
        with patch.object(relay, "probe", return_value=None) as probe:
            self.assertEqual(relay.zsb_sockets(paths, b"tab"), paths)
            self.assertEqual(relay.zsb_sockets(paths + [self.directory / "added.sock"], b"tab"), paths + [self.directory / "added.sock"])
            self.assertEqual(probe.call_count, 5)
            self.assertEqual(relay.zsb_sockets(paths[:1], b"tab"), paths[:1])
            self.assertEqual(probe.call_count, 5)
            with patch.object(relay, "MAX_CACHED_ROUTES", 2):
                for session in (b"one", b"two", b"three"):
                    relay.zsb_sockets(paths, session)
                self.assertLessEqual(len(relay.route_cache), 2)

    def test_malformed_probe_replies_are_legacy(self):
        invalid = [b"not json\n", b"[]\n", b'{}\n',
                   b'{"has_tab":1,"idle_ms":0,"host":"x"}\n',
                   b'{"has_tab":true,"idle_ms":-1,"host":"x"}\n',
                   b'{"has_tab":true,"idle_ms":true,"host":"x"}\n',
                   b'{"has_tab":true,"idle_ms":0}\n',
                   b"x" * relay.MAX_PROBE_REPLY]
        for index, payload in enumerate(invalid):
            name = f"invalid-{index}"
            self.laptop(name, probe_reply=payload)
            self.assertIsNone(relay.probe(self.directory / (name + ".sock"), b"tab", time.monotonic() + 0.4))

    def test_slow_hook_finishes_within_one_second(self):
        for index in range(8):
            self.laptop(str(index))
        started = time.monotonic()
        self.send(b"ACTIVE:tab")
        self.assertLess(time.monotonic() - started, 1)

    def test_tcp_hook_that_closes_right_after_writing_is_forwarded(self):
        received = self.laptop("one", requests=5)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        stop = threading.Event()
        server = threading.Thread(target=relay.serve, args=(self.directory, port, stop))
        server.start()
        self.addCleanup(server.join, 2)
        self.addCleanup(stop.set)
        deadline = time.monotonic() + 2
        while True:
            try:
                with socket.create_connection(("127.0.0.1", port), 0.2) as hook:
                    hook.sendall(b"DONE:tab\n")
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.05)
        deadline = time.monotonic() + 2
        while b"DONE:tab\n" not in received and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertIn(b"DONE:tab\n", received)


if __name__ == "__main__":
    unittest.main()
