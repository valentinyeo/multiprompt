import ast
import base64
try:
    import grp
    import pwd
except ImportError:
    grp = pwd = None
import hashlib
import json
import os
import re
import stat
import subprocess
import sys


class Unavailable(Exception):
    pass


def require(ok):
    if not ok:
        raise Unavailable()


def command(argv, limit=65536):
    result = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, timeout=4, check=True)
    require(len(result.stdout) <= limit)
    return result.stdout


def service_pid(unit):
    fields = dict(line.split('=', 1) for line in command([
        '/usr/bin/systemctl', 'show', unit, '--no-pager',
        '--property=MainPID,ActiveState,SubState']).decode('ascii').splitlines())
    require(fields.get('ActiveState') == 'active' and fields.get('SubState') == 'running')
    pid = fields.get('MainPID', '')
    require(pid.isdecimal() and int(pid) > 1)
    return int(pid)


def process(pid, uid):
    root = '/proc/' + str(pid)
    require(os.stat(root).st_uid == uid)
    status = open(root + '/status', encoding='ascii').read(65536)
    ids = re.search(r'^Uid:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$', status, re.M)
    require(ids is not None and all(int(v) == uid for v in ids.groups()))
    raw = open(root + '/cmdline', 'rb').read(65537)
    require(len(raw) <= 65536 and raw.endswith(b'\0'))
    argv = [v.decode('utf-8', 'strict') for v in raw[:-1].split(b'\0')]
    require(argv and os.path.isabs(argv[0]))
    return argv


def option(argv, name):
    require(argv.count(name) == 1)
    index = argv.index(name)
    require(index + 1 < len(argv))
    return argv[index + 1]


def port(value):
    require(isinstance(value, int) and not isinstance(value, bool) and 0 < value < 65536)
    return value


def proxy_mapping(source):
    tree = ast.parse(source)
    calls = []
    for node in tree.body:
        if isinstance(node, ast.ImportFrom):
            names = [name.name for name in node.names]
            require(all(name.asname is None for name in node.names))
            require((node.module, names) in [('urllib.parse', ['urlsplit']),
                    ('websockify.websocketproxy', ['ProxyRequestHandler', 'WebSocketProxy']),
                    ('websockify.websocketproxy', ['WebSocketProxy'])])
            continue
        if isinstance(node, ast.ClassDef):
            require(node.name == 'DesktopHandler' and len(node.bases) == 1 and
                    isinstance(node.bases[0], ast.Name) and node.bases[0].id == 'ProxyRequestHandler' and
                    not node.decorator_list and not node.keywords)
            expected = ast.parse('''class DesktopHandler(ProxyRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == '/':
            self.send_response(302)
            self.send_header('Location', '/vnc.html?autoconnect=1&resize=scale')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        super().do_GET()
''').body[0]
            require(ast.dump(node) == ast.dump(expected))
            continue
        require(isinstance(node, ast.Expr) and isinstance(node.value, ast.Call))
        start = node.value
        require(isinstance(start.func, ast.Attribute) and start.func.attr == 'start_server')
        require(not start.args and not start.keywords and isinstance(start.func.value, ast.Call))
        call = start.func.value
        require(isinstance(call.func, ast.Name) and call.func.id == 'WebSocketProxy' and not call.args)
        calls.append(call)
    require(len(calls) == 1)
    values = {}
    allowed = {'listen_host', 'listen_port', 'target_host', 'target_port', 'web', 'RequestHandlerClass', 'file_only'}
    for kw in calls[0].keywords:
        require(kw.arg in allowed and kw.arg not in values)
        if kw.arg == 'RequestHandlerClass':
            require(isinstance(kw.value, ast.Name) and kw.value.id == 'DesktopHandler')
            values[kw.arg] = kw.value.id
        else:
            require(isinstance(kw.value, ast.Constant))
            values[kw.arg] = kw.value.value
    require(values.get('listen_host') == '127.0.0.1' and values.get('target_host') == '127.0.0.1')
    return port(values.get('listen_port')), port(values.get('target_port'))


def listeners(pid, expected, uid):
    inodes = set()
    for name in os.listdir('/proc/' + str(pid) + '/fd'):
        try:
            link = os.readlink('/proc/' + str(pid) + '/fd/' + name)
        except OSError:
            continue
        match = re.fullmatch(r'socket:\[(\d+)\]', link)
        if match:
            inodes.add(match[1])
    found = set()
    for table, loopback in [('tcp', '0100007F'), ('tcp6', '00000000000000000000000001000000')]:
        entries = open('/proc/net/' + table, encoding='ascii').read(1048577)
        require(len(entries) <= 1048576)
        for line in entries.splitlines()[1:]:
            fields = line.split()
            if len(fields) < 10 or fields[3] != '0A':
                continue
            address, number = fields[1].split(':')
            number = int(number, 16)
            if number not in expected:
                continue
            owned = int(fields[7]) == uid and fields[9] in inodes
            if table == 'tcp6' and address == loopback and not owned:
                continue
            require(address == loopback and owned)
            if table == 'tcp':
                found.add(number)
    require(found == set(expected))


def writable_only_by(info, uid):
    if info.st_mode & 0o002:
        return False
    if not info.st_mode & 0o020:
        return True
    user = pwd.getpwuid(uid).pw_name
    return (set(grp.getgrgid(info.st_gid).gr_mem) <= {user} and
            all(entry.pw_uid == uid for entry in pwd.getpwall() if entry.pw_gid == info.st_gid))


def started_at(pid):
    fields = open('/proc/' + str(pid) + '/stat', encoding='ascii').read(65536).rsplit(')', 1)[1].split()
    boot = re.search(r'^btime (\d+)$', open('/proc/stat', encoding='ascii').read(1048576), re.M)
    require(boot is not None and len(fields) > 19)
    return int(boot.group(1)) + int(fields[19]) / os.sysconf('SC_CLK_TCK')


def private_file(path, uid, maximum):
    require(os.path.isabs(path))
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_uid == uid and info.st_mode & 0o077 == 0)
        require(0 < info.st_size <= maximum)
        data = os.read(fd, maximum + 1)
        require(len(data) == info.st_size)
        return data, info
    finally:
        os.close(fd)


def discover(include_password=True, expected_user=None):
    import resource
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    uid = os.getuid()
    require(uid != 0 and os.geteuid() == uid)
    user = pwd.getpwuid(uid).pw_name
    require(expected_user is not None and user == expected_user)
    vnc_pid = service_pid('x11vnc.service')
    proxy_pid = service_pid('novnc-desktop.service')
    vnc = process(vnc_pid, uid)
    proxy = process(proxy_pid, uid)
    require(os.path.basename(vnc[0]) == 'x11vnc' and '-localhost' in vnc)
    require(not any(v in vnc for v in ['-nopw', '-passwd', '-viewpasswd', '-passwdfile', '-unixpw', '-ssl', '-inetd', '-connect', '-rawfb']))
    display = option(vnc, '-display')
    require(re.fullmatch(r':[0-9]+(?:\.0)?', display) is not None)
    vnc_port = port(int(option(vnc, '-rfbport')))
    auth = option(vnc, '-rfbauth')
    auth_bytes, auth_info = private_file(auth, uid, 16)
    require(len(auth_bytes) == 8)
    require(len(proxy) == 2 and os.path.basename(proxy[0]) in {'python3', 'python3.12', 'python3.13', 'python3.14'})
    script = proxy[1]
    require(os.path.isabs(script) and os.path.basename(script) == 'websockify-desktop.py')
    fd = os.open(script, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_uid in {0, uid} and writable_only_by(info, uid) and info.st_size <= 16384)
        require(info.st_mtime <= started_at(proxy_pid))
        source = os.read(fd, 16385).decode('utf-8', 'strict')
    finally:
        os.close(fd)
    viewer_port, target_port = proxy_mapping(source)
    require(target_port == vnc_port and viewer_port != vnc_port)
    listeners(vnc_pid, {vnc_port}, uid)
    listeners(proxy_pid, {viewer_port}, uid)
    x_socket = os.stat('/tmp/.X11-unix/X' + display[1:].split('.')[0])
    require(stat.S_ISSOCK(x_socket.st_mode) and x_socket.st_uid == uid)
    require(process(vnc_pid, uid) == vnc and process(proxy_pid, uid) == proxy)
    decoded = b''
    if include_password:
        executable = os.stat(vnc[0])
        require(executable.st_uid in {0, uid} and executable.st_mode & 0o022 == 0)
        fd = os.open(auth, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            info = os.fstat(fd)
            require((info.st_dev, info.st_ino, info.st_uid, info.st_mode) ==
                    (auth_info.st_dev, auth_info.st_ino, auth_info.st_uid, auth_info.st_mode))
            name = '/proc/self/fd/' + str(fd)
            result = subprocess.run([vnc[0], '-norc', '-showrfbauth', name],
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                timeout=4, check=True, pass_fds=(fd,))
            prefix = ('rfbDecryptPasswdFromFile file: ' + name + '\nrfbDecryptPasswdFromFile pass: ').encode()
            require(len(result.stdout) <= 256 and result.stdout.startswith(prefix) and result.stdout.endswith(b'\n'))
            decoded = result.stdout[len(prefix):-1]
            require(0 < len(decoded) <= 8 and all(32 <= c < 127 for c in decoded))
        finally:
            os.close(fd)
    check, current = private_file(auth, uid, 16)
    require(check == auth_bytes and (current.st_ino, current.st_dev) == (auth_info.st_ino, auth_info.st_dev))
    identity = hashlib.sha256(json.dumps([os.uname().nodename, uid, user, display, vnc_port, viewer_port,
        os.readlink('/proc/' + str(vnc_pid) + '/exe'), auth_info.st_dev, auth_info.st_ino,
        x_socket.st_dev, x_socket.st_ino, open('/proc/sys/kernel/random/boot_id', encoding='ascii').read(64).strip()], separators=(',', ':')).encode()).hexdigest()
    return {'version': 1, 'host': os.uname().nodename, 'uid': uid, 'user': user, 'display': display, 'desktop': identity,
            'viewer_port': viewer_port, 'password': base64.b64encode(decoded).decode('ascii')}


def main(include_password, expected_user):
    try:
        result = discover(include_password, expected_user)
    except Unavailable as error:
        trace = error.__traceback__
        while trace.tb_next is not None and trace.tb_next.tb_frame.f_code.co_name != 'require':
            trace = trace.tb_next
        print(json.dumps({'unavailable': trace.tb_frame.f_code.co_name + ':' + str(trace.tb_lineno)}), flush=True)
        return
    except Exception as error:
        print(json.dumps({'unavailable': type(error).__name__}), flush=True)
        return
    print(json.dumps(result, separators=(',', ':')), flush=True)
    result.clear()
    if include_password:
        sys.stdin.buffer.read(1)
