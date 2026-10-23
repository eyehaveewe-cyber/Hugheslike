#!/usr/bin/env python3
"""Expand/check Hughes Atlas data without Godot. Standard library only.
Does not execute simulation behavior or substitute for engine UI testing.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any
ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / 'addons/hughes_atlas/seed_catalog.json'
ID = re.compile(r'^[a-z][a-z0-9_.-]*$')
SEMANTICS = {'structural', 'fact', 'temporal', 'subjective', 'normative', 'possibility', 'design'}
REFS = ('holder', 'context', 'object', 'feeling', 'relationship_type', 'claim')

def load_seed(path: Path = SEED) -> dict[str, Any]:
    seed = json.loads(path.read_text(encoding='utf-8'))
    for key, filename in seed.get('seed_files', {}).items():
        seed[key] = json.loads((path.parent / filename).read_text(encoding='utf-8'))[key]
    return seed

def expand_seed(seed: dict[str, Any]) -> dict[str, Any]:
    doc = {k: seed[k] for k in ('schema_version', 'title', 'kinds', 'relations', 'views')}
    doc.update(nodes=[], edges=[], layout={})
    by_id = {}
    rels = {r['id']: r for r in doc['relations']}
    for group in seed['groups']:
        for suffix, label, description in group['rows']:
            node = dict(id=f"{group['kind']}.{suffix}", label=label, kind=group['kind'],
                        domain=group['domain'], scope=group.get('scope', 'definition'),
                        description=description, tags=[])
            doc['nodes'].append(node)
            by_id[node['id']] = node
    for row in seed['links']:
        for source in row[0].split():
            for target in row[2].split():
                qualifiers = dict(row[3]) if len(row) > 3 else {}
                relation = row[1]
                if rels[relation]['semantics'] == 'subjective':
                    qualifiers.setdefault('holder', source)
                scope = 'example' if 'example' in (by_id[source]['scope'], by_id[target]['scope']) else 'definition'
                key = '|'.join((source, relation, target, str(qualifiers.get('id_suffix', ''))))
                doc['edges'].append(dict(id='e_' + hashlib.sha256(key.encode()).hexdigest()[:16],
                                        **{'from': source, 'relation': relation, 'to': target},
                                        scope=scope, qualifiers=qualifiers))
    return doc

def accepts(relation: dict, source: dict, target: dict) -> bool:
    return (('*' in relation['source_kinds'] or source['kind'] in relation['source_kinds'])
            and ('*' in relation['target_kinds'] or target['kind'] in relation['target_kinds'])
            and (relation['id'] != 'subtype_of' or source['kind'] == target['kind']))

def validate(doc: Any) -> list[str]:
    errors = []
    if not isinstance(doc, dict):
        return ['Document must be an object.']
    if doc.get('schema_version') != 1:
        errors.append('Unsupported schema_version.')
    collections = ('kinds', 'relations', 'nodes', 'edges', 'views')
    for name in collections:
        if not isinstance(doc.get(name), list):
            errors.append(f'{name} must be an array.')
    if errors:
        return errors
    for name in collections:
        seen = set()
        for row in doc[name]:
            if not isinstance(row, dict) or not isinstance(row.get('id'), str) or not ID.fullmatch(row['id']):
                errors.append(f'{name}: invalid stable ID.')
                continue
            if row['id'] in seen:
                errors.append(f"{name}: duplicate id {row['id']}")
            seen.add(row['id'])
    if errors:
        return errors
    kinds = {k['id'] for k in doc['kinds']}
    nodes = {n['id']: n for n in doc['nodes']}
    rels = {r['id']: r for r in doc['relations']}
    for r in doc['relations']:
        for side in ('source_kinds', 'target_kinds'):
            if not isinstance(r.get(side), list) or not r[side]:
                errors.append(f"{r['id']}: bad {side}")
            elif any(k != '*' and k not in kinds for k in r[side]):
                errors.append(f"{r['id']}: unknown endpoint kind")
        if r.get('semantics') not in SEMANTICS or not isinstance(r.get('label'), str):
            errors.append(f"{r['id']}: bad semantics or label")
    for n in doc['nodes']:
        if n.get('kind') not in kinds:
            errors.append(f"{n['id']}: unknown kind")
        for field in ('label', 'description', 'domain'):
            if not isinstance(n.get(field), str):
                errors.append(f"{n['id']}: {field} must be text")
        if n.get('scope') not in ('definition', 'example') or not isinstance(n.get('tags', []), list):
            errors.append(f"{n['id']}: bad scope or tags")
    if errors:
        return errors
    adjacency: dict[str, dict[str, list[str]]] = {r: {} for r in ('subtype_of', 'contains', 'precedes')}
    for e in doc['edges']:
        a, b, r = e.get('from'), e.get('to'), e.get('relation')
        if a not in nodes or b not in nodes or r not in rels:
            errors.append(f"{e['id']}: missing endpoint or relation")
            continue
        if not accepts(rels[r], nodes[a], nodes[b]):
            errors.append(f"{e['id']}: incompatible kinds for {a} --{r}--> {b}")
        if a == b:
            errors.append(f"{e['id']}: self link")
        expected = 'example' if 'example' in (nodes[a]['scope'], nodes[b]['scope']) else 'definition'
        if e.get('scope') != expected:
            errors.append(f"{e['id']}: wrong scope")
        q = e.get('qualifiers', {})
        if not isinstance(q, dict):
            errors.append(f"{e['id']}: qualifiers must be an object")
            continue
        if rels[r]['semantics'] == 'subjective' and 'holder' not in q:
            errors.append(f"{e['id']}: subjective relation needs holder")
        for ref in REFS:
            if ref in q and q[ref] not in nodes:
                errors.append(f"{e['id']}: unknown {ref} reference")
        allowed = {'holder': {'character', 'group'}, 'feeling': {'feeling'},
                   'relationship_type': {'relationship'}, 'claim': {'belief', 'rumor'}}
        for ref, allowed_kinds in allowed.items():
            if ref in q and q[ref] in nodes and nodes[q[ref]]['kind'] not in allowed_kinds:
                errors.append(f"{e['id']}: wrong kind for {ref}")
        if r == 'feels_toward' and ('feeling' not in q or q.get('holder') != a):
            errors.append(f"{e['id']}: feels_toward requires feeling and holder=source")
        if r == 'has_relationship' and 'relationship_type' not in q:
            errors.append(f"{e['id']}: relationship_type required")
        for fraction in ('confidence', 'strength'):
            if fraction in q and (type(q[fraction]) not in (float, int) or not 0 <= q[fraction] <= 1):
                errors.append(f"{e['id']}: bad {fraction}")
        for tick in ('start_tick', 'end_tick'):
            if tick in q and type(q[tick]) not in (int, float):
                errors.append(f"{e['id']}: numeric {tick} required")
        if all(type(q.get(t)) in (int, float) for t in ('start_tick', 'end_tick')) and q['end_tick'] < q['start_tick']:
            errors.append(f"{e['id']}: reversed numeric interval")
        if r in adjacency:
            adjacency[r].setdefault(a, []).append(b)
    for r, adj in adjacency.items():
        for start in adj:
            stack, seen = list(adj[start]), set()
            while stack:
                current = stack.pop()
                if current == start:
                    errors.append(f'Cycle in {r} at {start}')
                    break
                if current not in seen:
                    seen.add(current)
                    stack.extend(adj.get(current, []))
    for view in doc['views']:
        if not isinstance(view.get('label'), str) or not isinstance(view.get('domains'), list):
            errors.append(f"{view['id']}: bad view")
        if 'focus' in view and view['focus'] not in nodes:
            errors.append(f"{view['id']}: missing focus")
    layout = doc.get('layout', {})
    if not isinstance(layout, dict):
        errors.append('layout must be an object')
    else:
        for positions in layout.values():
            if not isinstance(positions, dict):
                errors.append('layout view must be an object')
                continue
            for xy in positions.values():
                if not isinstance(xy, list) or len(xy) != 2 or any(type(v) not in (int, float) for v in xy):
                    errors.append('layout position must be numeric [x, y]')
    return errors

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', nargs='?', type=Path, default=SEED)
    parser.add_argument('--export', type=Path, help='Write an expanded copy; refuses to overwrite any existing file.')
    args = parser.parse_args()
    try:
        raw = load_seed(args.source)
        doc = expand_seed(raw) if 'groups' in raw else raw
        errors = validate(doc)
        if errors:
            print('\n'.join(errors))
            return 1
        used = {e[k] for e in doc['edges'] for k in ('from', 'to')}
        isolated = [n['id'] for n in doc['nodes'] if n['id'] not in used]
        print(f"PASS: {len(doc['kinds'])} kinds, {len(doc['relations'])} relation types, "
              f"{len(doc['nodes'])} nodes, {len(doc['edges'])} edges, {len(doc['views'])} views.")
        print(f'Unlinked draft nodes: {len(isolated)}')
        if isolated:
            print(', '.join(isolated))
        if args.export:
            args.export.parent.mkdir(parents=True, exist_ok=True)
            with args.export.open('x', encoding='utf-8') as out:
                json.dump(doc, out, indent=2, ensure_ascii=False)
                out.write('\n')
            print(f'Exported {args.export}')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'ERROR: {exc}')
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
