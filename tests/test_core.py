import json, pathlib, unittest, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'app'))
from frozen_service.__main__ import parse_relation
class CoreTests(unittest.TestCase):
 def test_catalog_count_and_valkey(self):
  d=json.loads((ROOT/'registry/platforms.json').read_text()); self.assertEqual(len(d['platforms']),39); self.assertIn('valkey',[x['id'] for x in d['platforms']]); self.assertNotIn('redis',[x['id'] for x in d['platforms']])
 def test_dependency_ast(self):
  d=parse_relation('libc6 (>= 2.35), foo:any | bar (<< 3.0)'); self.assertTrue(d['valid']); self.assertEqual(len(d['ast']['groups']),2); self.assertEqual(d['ast']['groups'][1][0]['architecture_qualifier'],'any')
 def test_invalid_relation(self): self.assertFalse(parse_relation('foo (>= )')['valid'])
if __name__=='__main__': unittest.main()
