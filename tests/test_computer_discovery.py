import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load_discovery():
    path = Path(__file__).resolve().parents[1] / 'src/computer/discover.py'
    if not path.is_file():
        return None
    spec = importlib.util.spec_from_file_location('computer_discovery', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


discovery = load_discovery()


def proxy(viewer=12345, target=23456, host='127.0.0.1'):
    return ("from websockify.websocketproxy import WebSocketProxy\n"
            "WebSocketProxy(listen_host=" + repr(host) + ", listen_port=" + str(viewer) +
            ", target_host='127.0.0.1', target_port=" + str(target) + ").start_server()\n")


class MappingTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(discovery, 'the Computer discovery script ships with the app')

    def test_mapping_uses_the_active_literal_ports_not_a_host_default(self):
        self.assertEqual(discovery.proxy_mapping(proxy()), (12345, 23456))
        self.assertEqual(discovery.proxy_mapping(proxy(34567, 45678)), (34567, 45678))

    def test_known_redirect_handler_preserves_the_literal_desktop_mapping(self):
        source = '''from urllib.parse import urlsplit
from websockify.websocketproxy import ProxyRequestHandler, WebSocketProxy
class DesktopHandler(ProxyRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == '/':
            self.send_response(302)
            self.send_header('Location', '/vnc.html?autoconnect=1&resize=scale')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        super().do_GET()
WebSocketProxy(listen_host='127.0.0.1', listen_port=12345, target_host='127.0.0.1', target_port=23456, web='/usr/share/novnc', RequestHandlerClass=DesktopHandler, file_only=True).start_server()
'''
        self.assertEqual(discovery.proxy_mapping(source), (12345, 23456))
        with self.assertRaises(discovery.Unavailable):
            discovery.proxy_mapping(source.replace('self.send_response(302)', 'self.send_response(200)'))

    def test_dormant_call_cannot_masquerade_as_running_mapping(self):
        for source in [
            'def unused():\n    ' + proxy().split('\n')[1] + '\n',
            'if False:\n    ' + proxy().split('\n')[1] + '\n',
            'mapping = ' + proxy().split('\n')[1] + '\n',
            proxy() + proxy(34567, 45678),
            "class WebSocketProxy:\n    pass\n" + proxy(),
            proxy().replace('from websockify.websocketproxy', 'from unrelated'),
            proxy().replace('listen_port=12345', 'listen_port=int("12345")'),
            proxy().replace('.start_server()', ''),
        ]:
            with self.subTest(source=source), self.assertRaises(discovery.Unavailable):
                discovery.proxy_mapping(source)

    def test_public_listeners_and_invalid_port_types_fail_closed(self):
        for source in [proxy(host='0.0.0.0'), proxy(host='::'), proxy(0), proxy(65536), proxy(-1),
                       proxy().replace('listen_port=12345', 'listen_port=True'),
                       proxy().replace("target_host='127.0.0.1'", "target_host='192.0.2.1'"),
                       proxy().replace('target_port=23456', 'target_port=23456, auth_plugin="anything"')]:
            with self.subTest(source=source), self.assertRaises(discovery.Unavailable):
                discovery.proxy_mapping(source)

    def test_duplicate_service_options_are_not_last_value_wins(self):
        with self.assertRaises(discovery.Unavailable):
            discovery.option(['-display', ':7', '-display', ':8'], '-display')

    def test_live_listener_must_belong_to_that_same_process_and_uid(self):
        def read(path, **kwargs):
            if path.endswith('/tcp'):
                return io.StringIO('header\n0: 0100007F:3039 00000000:0000 0A 0 0 0 1001 0 55\n')
            return io.StringIO('header\n')
        with patch.object(discovery.os, 'listdir', return_value=['4']), patch.object(discovery.os, 'readlink', return_value='socket:[55]'), patch('builtins.open', side_effect=read):
            discovery.listeners(99, {12345}, 1001)
            with self.assertRaises(discovery.Unavailable):
                discovery.listeners(99, {12345}, 1002)
        with patch.object(discovery.os, 'listdir', return_value=['4']), patch.object(discovery.os, 'readlink', return_value='socket:[66]'), patch('builtins.open', side_effect=read):
            with self.assertRaises(discovery.Unavailable):
                discovery.listeners(99, {12345}, 1001)

    def test_one_loopback_listener_cannot_hide_an_additional_public_listener(self):
        def read(path, **kwargs):
            rows = 'header\n'
            if path.endswith('/tcp'):
                rows += '0: 0100007F:3039 00000000:0000 0A 0 0 0 1001 0 55\n'
                rows += '1: 00000000:3039 00000000:0000 0A 0 0 0 1001 0 56\n'
            return io.StringIO(rows)
        with patch.object(discovery.os, 'listdir', return_value=['4']), patch.object(discovery.os, 'readlink', return_value='socket:[55]'), patch('builtins.open', side_effect=read):
            with self.assertRaises(discovery.Unavailable):
                discovery.listeners(99, {12345}, 1001)

    @unittest.skipUnless(os.name == 'posix', 'Linux descriptor and ownership contract')
    def test_auth_file_is_own_private_regular_file_not_symlink_or_other_user(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'auth'
            path.write_bytes(b'12345678')
            path.chmod(0o600)
            self.assertEqual(discovery.private_file(str(path), os.getuid(), 16)[0], b'12345678')
            with self.assertRaises(discovery.Unavailable):
                discovery.private_file(str(path), os.getuid() + 1, 16)
            path.chmod(0o644)
            with self.assertRaises(discovery.Unavailable):
                discovery.private_file(str(path), os.getuid(), 16)
            path.chmod(0o600)
            link = Path(directory) / 'link'
            link.symlink_to(path)
            with self.assertRaises(OSError):
                discovery.private_file(str(link), os.getuid(), 16)
            with self.assertRaises(discovery.Unavailable):
                discovery.private_file(str(path), os.getuid(), 4)


if __name__ == '__main__':
    unittest.main()
