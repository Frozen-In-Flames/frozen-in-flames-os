from __future__ import annotations
import argparse, json, os, pathlib, sqlite3, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = pathlib.Path(os.environ.get("FIF_ROOT", "/opt/frozen-in-flames"))
REGISTRY = pathlib.Path(os.environ.get("FIF_REGISTRY", str(ROOT / "registry/platforms.json")))
STATE = pathlib.Path(os.environ.get("FIF_STATE", "/var/lib/frozen-in-flames"))
SERVICE_PORTS = {"catalog":8101,"provenance":8102,"dependency":8103,"evidence":8104,"policy":8105,"profiles":8106,"build":8107,"ai":8108,"workspace":8109}

def load_registry():
    with REGISTRY.open(encoding="utf-8") as f: return json.load(f)

def db():
    # Production uses PostgreSQL through psql migrations and the service can
    # use SQLite only for isolated developer smoke tests when explicitly set.
    path = os.environ.get("FIF_SQLITE_PATH")
    if not path: return None
    con = sqlite3.connect(path); con.row_factory = sqlite3.Row
    return con

class Handler(BaseHTTPRequestHandler):
    service = "workspace"
    def log_message(self, fmt, *args):
        print(json.dumps({"ts":time.time(),"service":self.service,"client":self.client_address[0],"message":fmt%args}), flush=True)
    def send_json(self, obj, status=200):
        raw=json.dumps(obj,ensure_ascii=False,indent=2).encode()
        self.send_response(status); self.send_header("Content-Type","application/json; charset=utf-8"); self.send_header("Content-Length",str(len(raw))); self.send_header("Cache-Control","no-store"); self.end_headers(); self.wfile.write(raw)
    def do_GET(self):
        path=urlparse(self.path).path.rstrip("/") or "/"
        if path in ("/health","/ready"):
            return self.send_json({"status":"ok","service":self.service,"timestamp":time.time()})
        if self.service=="catalog" and path in ("/","/platforms"):
            data=load_registry(); return self.send_json({"count":len(data["platforms"]),"platforms":data["platforms"],"policy":data["policy"]})
        if self.service=="workspace" and path in ("/","/summary"):
            data=load_registry(); return self.send_json({"name":"FROZEN IN FLAMES","platform_count":len(data["platforms"]),"services":list(SERVICE_PORTS),"state":"operational-shell; backend health is reported per service"})
        if self.service=="dependency" and path=="/capabilities":
            return self.send_json({"relations":["Depends","Pre-Depends","Recommends","Suggests","Conflicts","Breaks","Provides"],"features":["Debian control parsing","dependency AST","version comparison","architecture qualifiers","Multi-Arch metadata","snapshot identity"]})
        if self.service=="provenance" and path=="/identity-model":
            return self.send_json({"chain":["Project","Source Version","Package Instance","Artifact SHA-256"],"hash":"sha256"})
        if self.service=="policy" and path=="/layers":
            return self.send_json({"layers":["evidence","derivation","policy","profile"],"freedom_axes":["software_freedom_F","hardware_freedom_H"]})
        return self.send_json({"service":self.service,"path":path,"message":"Endpoint not found"},404)
    def do_POST(self):
        length=int(self.headers.get("Content-Length","0")); raw=self.rfile.read(min(length,2_000_000))
        try: payload=json.loads(raw or b"{}")
        except Exception: return self.send_json({"error":"invalid JSON"},400)
        if self.service=="evidence" and self.path.rstrip("/")=="/records":
            if not isinstance(payload.get("claim"),str) or not payload["claim"].strip(): return self.send_json({"error":"claim is required"},400)
            return self.send_json({"accepted":True,"record":payload,"status":"queued-for-persistence"},202)
        if self.service=="build" and self.path.rstrip("/")=="/validate":
            return self.send_json({"accepted":True,"requested_target":payload.get("target","qcow2"),"note":"Build execution is performed by the host Nix builder, not by this API."},202)
        if self.service=="ai" and self.path.rstrip("/")=="/models":
            return self.send_json({"accepted":True,"model":payload,"status":"registered-metadata-only"},202)
        if self.service=="profiles" and self.path.rstrip("/")=="/profiles":
            return self.send_json({"accepted":True,"profile":payload,"status":"validated-metadata-only"},202)
        if self.service=="dependency" and self.path.rstrip("/")=="/parse":
            return self.send_json(parse_relation(payload.get("relation","")),200)
        return self.send_json({"error":"endpoint not found"},404)

def parse_relation(text):
    """Small deterministic Debian relation tokenizer; not a full apt resolver."""
    import re
    groups=[]
    for alt_group in text.split(","):
        alternatives=[]
        for item in alt_group.split("|"):
            m=re.match(r"\s*([A-Za-z0-9+.-]+)(?::([A-Za-z0-9-]+))?\s*(?:\((<<|<=|=|>=|>>)\s*([^)]*\S[^)]*)\))?\s*(?:\[([^]]+)\])?\s*(?:<([^>]+)>)?\s*$",item)
            if not m: return {"valid":False,"input":text,"error":f"cannot parse relation atom: {item.strip()}"}
            alternatives.append({"package":m.group(1),"architecture_qualifier":m.group(2),"operator":m.group(3),"version":m.group(4).strip() if m.group(4) else None,"architectures":m.group(5).split() if m.group(5) else [],"profiles":m.group(6).split() if m.group(6) else []})
        groups.append(alternatives)
    return {"valid":True,"ast":{"kind":"relation-list","groups":groups}}

def main():
    p=argparse.ArgumentParser(); p.add_argument("--service",choices=SERVICE_PORTS,required=True); p.add_argument("--port",type=int); a=p.parse_args()
    cls=type("BoundHandler",(Handler,),{"service":a.service})
    server=ThreadingHTTPServer(("127.0.0.1",a.port or SERVICE_PORTS[a.service]),cls)
    print(json.dumps({"event":"service-start","service":a.service,"port":a.port or SERVICE_PORTS[a.service]}),flush=True)
    server.serve_forever()
if __name__=="__main__": main()
