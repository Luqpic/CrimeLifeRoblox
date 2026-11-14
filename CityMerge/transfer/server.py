# Tiny localhost-only store for moving serialized Roblox instances between two Studio windows.
import sys, os, re
from http.server import BaseHTTPRequestHandler, HTTPServer
ROOT = sys.argv[1]
class H(BaseHTTPRequestHandler):
    def _path(self):
        name = self.path.strip("/").split("?")[0]
        return os.path.join(ROOT, name) if re.fullmatch(r"[A-Za-z0-9_.-]{1,80}", name) else None
    def do_POST(self):
        p = self._path()
        if not p: self.send_response(400); self.end_headers(); return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        open(p, "wb").write(body)
        self.send_response(200); self.end_headers(); self.wfile.write(str(len(body)).encode())
    def do_GET(self):
        p = self._path()
        if not p or not os.path.exists(p): self.send_response(404); self.end_headers(); return
        data = open(p, "rb").read()
        self.send_response(200); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8765), H).serve_forever()
