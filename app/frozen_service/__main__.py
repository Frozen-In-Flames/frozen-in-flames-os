"""FROZEN IN FLAMES service process.

Nine processes share this module; --service selects one. Each binds to loopback only.
Persistence: the three record-accepting POST endpoints (evidence /records,
ai /models, profiles /profiles) append each accepted record as one JSON line
to FIF_STATE/<service>.jsonl and report status "persisted" only after the
append succeeds; the matching GET endpoints read the records back. If the
state directory is not writable the POST fails with 503 and nothing is
claimed. The remaining services are read-only projections of the platform
registry or pure functions of their input (dependency parsing, build
validation), and hold no state by design; the per-service account is in
docs/RECONCILIATION.md. The relational store (PostgreSQL, database
"frozen") carries the migration-managed schema applied by the
frozen-migrate unit, and WordPress uses PostgreSQL through PG4WP.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = pathlib.Path(os.environ.get("FIF_ROOT", "/opt/frozen-in-flames"))
REGISTRY = pathlib.Path(os.environ.get("FIF_REGISTRY", str(ROOT / "registry/platforms.json")))
STATE = pathlib.Path(os.environ.get("FIF_STATE", "/var/lib/frozen-in-flames"))


def persist_record(service, record):
    """Append one record to the service's JSONL store under STATE.

    Returns the number of records stored after the append. Raises
    OSError when the state directory cannot be written; callers turn
    that into a 503 and never claim the record was saved.
    """
    STATE.mkdir(parents=True, exist_ok=True)
    path = STATE / f"{service}.jsonl"
    line = json.dumps({"ts": time.time(), "record": record}, ensure_ascii=False)
    with path.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    return sum(1 for _ in path.open(encoding="utf-8"))


def read_records(service):
    """Return every persisted record for a service, oldest first."""
    path = STATE / f"{service}.jsonl"
    if not path.exists():
        return []
    records = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records
SERVICE_PORTS = {
    "catalog": 8101, "provenance": 8102, "dependency": 8103, "evidence": 8104,
    "policy": 8105, "profiles": 8106, "build": 8107, "ai": 8108, "workspace": 8109,
}
MAX_BODY_BYTES = 2_000_000

# One Debian relation atom: name[:arch] [(op version)] [[arch ...]] [<profile ...>]
RELATION_ATOM = re.compile(
    r"\s*([A-Za-z0-9+.-]+)(?::([A-Za-z0-9-]+))?\s*"
    r"(?:\((<<|<=|=|>=|>>)\s*([^)]*\S[^)]*)\))?\s*"
    r"(?:\[([^]]+)\])?\s*"
    r"(?:<([^>]+)>)?\s*$"
)


def load_registry():
    with REGISTRY.open(encoding="utf-8") as f:
        return json.load(f)


class Handler(BaseHTTPRequestHandler):
    service = "workspace"

    def log_message(self, fmt, *args):
        print(json.dumps({"ts": time.time(), "service": self.service,
                          "client": self.client_address[0], "message": fmt % args}), flush=True)

    def send_json(self, obj, status=200):
        raw = json.dumps(obj, ensure_ascii=False, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def route(self):
        # Query strings are ignored for routing.
        return urlparse(self.path).path.rstrip("/") or "/"

    def registry(self):
        try:
            return load_registry()
        except (OSError, ValueError):
            self.send_json({"error": "platform registry unavailable"}, 503)
            return None

    def read_json_object(self):
        """Return (payload, error). The body must be a JSON object."""
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None, "invalid Content-Length"
        if length < 0 or length > MAX_BODY_BYTES:
            return None, "request body must be between 0 and 2000000 bytes"
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw or b"{}")
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None, "invalid JSON"
        if not isinstance(payload, dict):
            return None, "JSON body must be an object"
        return payload, None

    def do_GET(self):
        path = self.route()
        if path in ("/health", "/ready"):
            return self.send_json({"status": "ok", "service": self.service, "timestamp": time.time()})
        if self.service == "catalog" and path in ("/", "/platforms"):
            data = self.registry()
            if data is None:
                return
            return self.send_json({"count": len(data["platforms"]), "platforms": data["platforms"],
                                   "policy": data["policy"]})
        if self.service == "workspace" and path in ("/", "/summary"):
            data = self.registry()
            if data is None:
                return
            return self.send_json({"name": "FROZEN IN FLAMES", "platform_count": len(data["platforms"]),
                                   "services": list(SERVICE_PORTS),
                                   "state": "operational-shell; backend health is reported per service"})
        if self.service == "dependency" and path == "/capabilities":
            return self.send_json({
                "relations": ["Depends", "Pre-Depends", "Recommends", "Suggests",
                              "Conflicts", "Breaks", "Provides"],
                "features": ["Debian control parsing", "relation atom parsing", "architecture qualifiers",
                             "build profile restrictions"],
                "not_implemented": ["version ordering", "alternatives resolution", "Multi-Arch semantics",
                                    "cycle detection", "snapshot solving"],
            })
        if self.service == "provenance" and path == "/identity-model":
            return self.send_json({"chain": ["Project", "Source Version", "Package Instance", "Artifact SHA-256"],
                                   "hash": "sha256"})
        if (self.service, path) in (("evidence", "/records"), ("ai", "/models"),
                                    ("profiles", "/profiles")):
            records = read_records(self.service)
            return self.send_json({"service": self.service, "count": len(records),
                                   "records": records})
        if self.service == "policy" and path == "/layers":
            return self.send_json({"layers": ["evidence", "derivation", "policy", "profile"],
                                   "freedom_axes": ["software_freedom_F", "hardware_freedom_H"]})
        return self.send_json({"service": self.service, "path": path, "message": "Endpoint not found"}, 404)

    def do_POST(self):
        path = self.route()
        payload, error = self.read_json_object()
        if error:
            return self.send_json({"error": error}, 400)
        if self.service == "evidence" and path == "/records":
            claim = payload.get("claim")
            if not isinstance(claim, str) or not claim.strip():
                return self.send_json({"error": "claim is required"}, 400)
            try:
                count = persist_record(self.service, payload)
            except OSError:
                return self.send_json({"error": "state directory is not writable; record not stored"}, 503)
            return self.send_json({"accepted": True, "record": payload,
                                   "status": "persisted", "stored_records": count}, 202)
        if self.service == "build" and path == "/validate":
            return self.send_json({"accepted": True, "requested_target": payload.get("target", "qcow2"),
                                   "note": "Build execution is performed by the host Nix builder, not by this API."},
                                  202)
        if self.service == "ai" and path == "/models":
            try:
                count = persist_record(self.service, payload)
            except OSError:
                return self.send_json({"error": "state directory is not writable; record not stored"}, 503)
            return self.send_json({"accepted": True, "model": payload,
                                   "status": "persisted", "stored_records": count}, 202)
        if self.service == "profiles" and path == "/profiles":
            try:
                count = persist_record(self.service, payload)
            except OSError:
                return self.send_json({"error": "state directory is not writable; record not stored"}, 503)
            return self.send_json({"accepted": True, "profile": payload,
                                   "status": "persisted-not-validated", "stored_records": count}, 202)
        if self.service == "dependency" and path == "/parse":
            relation = payload.get("relation", "")
            if not isinstance(relation, str):
                return self.send_json({"error": "relation must be a string"}, 400)
            result = parse_relation(relation)
            return self.send_json(result, 200 if result["valid"] else 422)
        return self.send_json({"error": "endpoint not found"}, 404)


def parse_relation(text):
    """Small deterministic Debian relation tokenizer. It is not a resolver."""
    groups = []
    for alt_group in text.split(","):
        alternatives = []
        for item in alt_group.split("|"):
            m = RELATION_ATOM.match(item)
            if not m:
                return {"valid": False, "input": text,
                        "error": f"cannot parse relation atom: {item.strip()}"}
            alternatives.append({
                "package": m.group(1),
                "architecture_qualifier": m.group(2),
                "operator": m.group(3),
                "version": m.group(4).strip() if m.group(4) else None,
                "architectures": m.group(5).split() if m.group(5) else [],
                "profiles": m.group(6).split() if m.group(6) else [],
            })
        groups.append(alternatives)
    return {"valid": True, "ast": {"kind": "relation-list", "groups": groups}}


def main():
    parser = argparse.ArgumentParser(description="Run one FROZEN IN FLAMES service on loopback.")
    parser.add_argument("--service", choices=sorted(SERVICE_PORTS), required=True)
    parser.add_argument("--port", type=int)
    args = parser.parse_args()
    port = args.port if args.port is not None else SERVICE_PORTS[args.service]
    handler = type("BoundHandler", (Handler,), {"service": args.service})
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(json.dumps({"event": "service-start", "service": args.service, "port": port}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
