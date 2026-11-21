"""Starts each service on an ephemeral loopback port and exercises its HTTP behavior."""
import http.client
import json
import os
import pathlib
import sys
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

ROOT = pathlib.Path(__file__).resolve().parents[1]
os.environ["FIF_REGISTRY"] = str(ROOT / "registry" / "platforms.json")
sys.path.insert(0, str(ROOT / "app"))
import frozen_service.__main__ as svc  # noqa: E402
# test_core imports the module first, so the environment variable above may come too late.
# Point the module at this checkout explicitly.
svc.REGISTRY = ROOT / "registry" / "platforms.json"
# Persistence tests run against a throwaway state directory.
import tempfile  # noqa: E402
svc.STATE = pathlib.Path(tempfile.mkdtemp(prefix="fif-state-test-"))


class _Quiet:
    def log_message(self, *args):
        pass


def start(service):
    cls = type("Quiet" + service, (_Quiet, svc.Handler), {"service": service})
    server = ThreadingHTTPServer(("127.0.0.1", 0), cls)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_address[1]}"


def call(base, path, method="GET", raw=None):
    req = urllib.request.Request(base + path, data=raw, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


class ServiceTests(unittest.TestCase):
    servers = {}

    @classmethod
    def setUpClass(cls):
        for name in svc.SERVICE_PORTS:
            cls.servers[name] = start(name)

    @classmethod
    def tearDownClass(cls):
        for server, _ in cls.servers.values():
            server.shutdown()
            server.server_close()

    def base(self, name):
        return self.servers[name][1]

    def test_all_nine_services_report_health(self):
        self.assertEqual(len(svc.SERVICE_PORTS), 9)
        for name in svc.SERVICE_PORTS:
            status, body = call(self.base(name), "/health")
            self.assertEqual(status, 200, name)
            self.assertEqual(body["status"], "ok")

    def test_catalog_lists_39_platforms_and_forbids_unfree(self):
        status, body = call(self.base("catalog"), "/platforms")
        self.assertEqual(status, 200)
        self.assertEqual(body["count"], 39)
        self.assertFalse(body["policy"]["unfree_allowed"])

    def test_workspace_summary(self):
        status, body = call(self.base("workspace"), "/summary")
        self.assertEqual(status, 200)
        self.assertEqual(body["platform_count"], 39)
        self.assertEqual(len(body["services"]), 9)

    def test_unknown_path_is_404(self):
        self.assertEqual(call(self.base("catalog"), "/nope")[0], 404)

    def test_evidence_persists_claim_and_reports_storage(self):
        # Contract change, 2026-11-21: this test previously asserted
        # status "accepted-not-persisted", which was the specified
        # behavior before the audit's persistence item was implemented.
        # The service now appends accepted records to its state
        # directory and reports "persisted"; the test asserts the new
        # contract, including read-back through the GET endpoint.
        status, body = call(self.base("evidence"), "/records", "POST", b'{"claim": "GPL-2.0-only"}')
        self.assertEqual(status, 202)
        self.assertEqual(body["status"], "persisted")
        self.assertGreaterEqual(body["stored_records"], 1)
        status, body = call(self.base("evidence"), "/records")
        self.assertEqual(status, 200)
        claims = [entry["record"].get("claim") for entry in body["records"]]
        self.assertIn("GPL-2.0-only", claims)

    def test_query_string_does_not_break_routing(self):
        status, _ = call(self.base("evidence"), "/records?source=test", "POST", b'{"claim": "x"}')
        self.assertEqual(status, 202)

    def test_evidence_rejects_missing_claim(self):
        self.assertEqual(call(self.base("evidence"), "/records", "POST", b"{}")[0], 400)

    def test_evidence_rejects_invalid_json(self):
        self.assertEqual(call(self.base("evidence"), "/records", "POST", b"not-json")[0], 400)

    def test_evidence_rejects_json_array_without_crashing(self):
        # Regression: a JSON array body used to raise AttributeError and drop the connection.
        status, body = call(self.base("evidence"), "/records", "POST", b"[1, 2]")
        self.assertEqual(status, 400)
        self.assertIn("object", body["error"])

    def test_invalid_content_length_is_400(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.servers["evidence"][0].server_address[1], timeout=5)
        conn.request("POST", "/records", body=b"{}", headers={"Content-Length": "abc"})
        self.assertEqual(conn.getresponse().status, 400)
        conn.close()

    def test_dependency_parses_valid_relation(self):
        status, body = call(self.base("dependency"), "/parse", "POST",
                            b'{"relation": "libc6 (>= 2.35), foo:any | bar (<< 3.0)"}')
        self.assertEqual(status, 200)
        self.assertTrue(body["valid"])
        self.assertEqual(len(body["ast"]["groups"]), 2)

    def test_dependency_invalid_relation_is_422(self):
        status, body = call(self.base("dependency"), "/parse", "POST", b'{"relation": "foo (>= )"}')
        self.assertEqual(status, 422)
        self.assertFalse(body["valid"])

    def test_dependency_rejects_non_string_relation(self):
        self.assertEqual(call(self.base("dependency"), "/parse", "POST", b'{"relation": 5}')[0], 400)

    def test_build_ai_profiles_post_contracts(self):
        # Build validation still stores nothing: it is a receipt, and
        # its response carries no storage claim. AI and profiles now
        # persist like evidence (contract change, 2026-11-21).
        self.assertEqual(call(self.base("build"), "/validate", "POST", b'{"target": "iso"}')[0], 202)
        status, body = call(self.base("ai"), "/models", "POST", b'{"name": "m"}')
        self.assertEqual(status, 202)
        self.assertEqual(body["status"], "persisted")
        status, body = call(self.base("profiles"), "/profiles", "POST", b'{"name": "p"}')
        self.assertEqual(status, 202)
        self.assertEqual(body["status"], "persisted-not-validated")

    def test_registry_missing_returns_503(self):
        original = svc.REGISTRY
        svc.REGISTRY = pathlib.Path("/nonexistent/platforms.json")
        try:
            self.assertEqual(call(self.base("catalog"), "/platforms")[0], 503)
        finally:
            svc.REGISTRY = original

    def test_identity_chain_and_layers(self):
        self.assertEqual(call(self.base("provenance"), "/identity-model")[1]["chain"][0], "Project")
        self.assertEqual(call(self.base("policy"), "/layers")[1]["layers"][-1], "profile")


if __name__ == "__main__":
    unittest.main()
