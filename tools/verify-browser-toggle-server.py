import http.server
import json
from pathlib import Path
import sys
import time


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/slow":
            self.send_error(404)
            return
        start = b"<html><body><h1>Still loading</h1>"
        end = b"<p>Finished</p></body></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(start) + len(end)))
        self.end_headers()
        self.wfile.write(start)
        self.wfile.flush()
        print("SLOW_LOADING", flush=True)
        time.sleep(30)
        try:
            self.wfile.write(end)
            print("SLOW_FINISHED", flush=True)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            print("SLOW_CANCELLED", flush=True)

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
Path(sys.argv[1]).write_text(json.dumps({"port": server.server_port}))
server.serve_forever()
