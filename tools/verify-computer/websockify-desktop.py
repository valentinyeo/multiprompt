from urllib.parse import urlsplit
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


WebSocketProxy(listen_host='127.0.0.1', listen_port=6080, target_host='127.0.0.1', target_port=5900, web='/usr/local/lib/verify-computer/web', RequestHandlerClass=DesktopHandler, file_only=False).start_server()
