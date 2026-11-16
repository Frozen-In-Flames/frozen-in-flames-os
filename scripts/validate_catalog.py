#!/usr/bin/env python3
import json,sys
p=json.load(open(sys.argv[1],encoding='utf-8'))
items=p['platforms']; ids=[x['id'] for x in items]
assert len(items)==39, f'expected 39 platform targets, found {len(items)}'
assert len(ids)==len(set(ids)), 'duplicate platform id'
assert p['policy']['unfree_allowed'] is False, 'unfree packages must remain disabled'
assert 'valkey' in ids and 'redis' not in ids, 'Valkey must replace Redis'
for x in items:
    for k in ('id','name','category','role','mode','license'): assert x.get(k), f'missing {k}: {x}'
print(f'catalog OK: {len(items)} unique platform targets; unfree disabled; Valkey present')
