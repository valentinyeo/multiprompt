import contextlib
import io
import os
import types
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'computer', 'discover.py')
HEADER = '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n'
IPV4_LOOPBACK = '0100007F'
IPV4_ANY = '00000000'
IPV6_LOOPBACK = '00000000000000000000000001000000'


def load():
    namespace = {'__name__': 'computer'}
    with open(SCRIPT, encoding='utf-8') as source:
        exec(compile(source.read(), SCRIPT, 'exec'), namespace)
    return namespace


def row(address, port, uid, inode):
    return '   0: %s:%04X 00000000:0000 0A 00000000:00000000 00:00000000 00000000 %5d        0 %d 1\n' % (address, port, uid, inode)


def fake_system(namespace, owned_inodes, tcp, tcp6):
    tables = {'/proc/net/tcp': HEADER + ''.join(tcp), '/proc/net/tcp6': HEADER + ''.join(tcp6)}
    namespace['os'] = types.SimpleNamespace(
        listdir=lambda path: [str(i) for i in range(len(owned_inodes))],
        readlink=lambda path: 'socket:[%d]' % owned_inodes[int(path.rsplit('/', 1)[1])])
    namespace['open'] = lambda path, encoding=None: io.StringIO(tables[path])


def listener_accepted(namespace, pid, port, uid):
    try:
        namespace['listeners'](pid, {port}, uid)
        return True
    except namespace['Unavailable']:
        return False


def user_database(namespace, members, primary):
    namespace['pwd'] = types.SimpleNamespace(
        getpwuid=lambda uid: types.SimpleNamespace(pw_name='desk', pw_uid=uid, pw_gid=1000),
        getpwall=lambda: [types.SimpleNamespace(pw_name=name, pw_uid=uid, pw_gid=gid) for name, uid, gid in primary])
    namespace['grp'] = types.SimpleNamespace(getgrgid=lambda gid: types.SimpleNamespace(gr_name='desk', gr_mem=members))


def file_info(mode, gid=1000):
    return types.SimpleNamespace(st_mode=0o100000 | mode, st_gid=gid)


class ListenerOwnership(unittest.TestCase):
    def test_another_same_user_server_on_ipv6_loopback_does_not_hide_the_desktop(self):
        namespace = load()
        fake_system(namespace, [11], [row(IPV4_LOOPBACK, 5900, 1000, 11)], [row(IPV6_LOOPBACK, 5900, 1000, 22)])
        self.assertTrue(listener_accepted(namespace, 7, 5900, 1000),
                        'a second VNC server holding [::1]:5900 must not make Computer lose a desktop reachable on 127.0.0.1')

    def test_desktop_listener_owned_by_another_process_is_rejected(self):
        namespace = load()
        fake_system(namespace, [11], [row(IPV4_LOOPBACK, 5900, 1000, 22)], [])
        self.assertFalse(listener_accepted(namespace, 7, 5900, 1000))

    def test_listener_reachable_beyond_loopback_is_rejected(self):
        namespace = load()
        fake_system(namespace, [11, 12], [row(IPV4_LOOPBACK, 5900, 1000, 11), row(IPV4_ANY, 5900, 1000, 12)], [])
        self.assertFalse(listener_accepted(namespace, 7, 5900, 1000))

    def test_ipv6_only_listener_is_not_enough(self):
        namespace = load()
        fake_system(namespace, [11], [], [row(IPV6_LOOPBACK, 5900, 1000, 11)])
        self.assertFalse(listener_accepted(namespace, 7, 5900, 1000))


class ProxyScriptWriters(unittest.TestCase):
    def judge(self, mode, members=(), primary=(('desk', 1000, 1000),)):
        namespace = load()
        check = namespace.get('writable_only_by')
        self.assertIsNotNone(check, 'discovery must judge who can write the viewer service script')
        user_database(namespace, list(members), list(primary))
        return check(file_info(mode), 1000)

    def test_group_writable_script_in_the_users_private_group_is_trusted(self):
        self.assertTrue(self.judge(0o664), 'a default umask 002 install must not make Computer show Lost')

    def test_owner_only_script_is_trusted(self):
        self.assertTrue(self.judge(0o644))

    def test_world_writable_script_is_rejected(self):
        self.assertFalse(self.judge(0o666))

    def test_group_with_another_member_is_rejected(self):
        self.assertFalse(self.judge(0o664, members=('other',)))

    def test_group_that_is_another_users_primary_group_is_rejected(self):
        self.assertFalse(self.judge(0o664, primary=(('desk', 1000, 1000), ('other', 1001, 1000))))


class FailureReport(unittest.TestCase):
    def test_a_failed_check_names_the_function_and_line(self):
        namespace = load()
        self.assertIn('main', namespace, 'discovery must report which check failed')
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            namespace['main'](False, None)
        self.assertRegex(out.getvalue(), r'^\{"unavailable": "discover:\d+"\}\n$')


if __name__ == '__main__':
    unittest.main()
