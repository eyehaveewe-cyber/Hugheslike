#!/usr/bin/env python3
"""Additive catalog loading and strict extended checks. No dependencies or AI execution."""
from __future__ import annotations
from copy import deepcopy
import argparse
import json
from pathlib import Path
from typing import Any
from atlas_data import load_seed as load_base, expand_seed as expand_base, validate as validate_base, SEED

PACK = SEED.with_name('seed_extension.json')
REFS = ('holder', 'context', 'object', 'feeling', 'relationship_type', 'claim')

def load_seed() -> dict:
    seed = load_base()
    pack = json.loads(PACK.read_text(encoding='utf-8'))
    for section in ('kinds', 'relations', 'groups', 'links', 'views'):
        additions = pack.get(section, [])
        if not isinstance(additions, list):
            raise ValueError(f'Extension {section} must be an array.')
        seed[section].extend(deepcopy(additions))
    seed['catalog_revision'] = '0.2'
    return seed

def expand_seed(seed: dict) -> dict:
    doc = expand_base(seed)
    doc['catalog_revision'] = str(seed.get('catalog_revision', '0.1'))
    return doc

def validate(doc: Any) -> list[str]:
    if not isinstance(doc, dict):
        return ['Document must be an object.']
    errors = []
    for section in ('kinds', 'relations', 'nodes', 'edges', 'views'):
        if not isinstance(doc.get(section), list):
            return [f'{section} must be an array.']
        for record in doc[section]:
            if not isinstance(record, dict):
                return [f'{section} records must be objects.']
            for field in ('id', 'kind', 'from', 'to', 'relation', 'focus'):
                if field in record and not isinstance(record[field], str):
                    errors.append(f'{section}: {field} must be a string.')
            if section == 'relations':
                for side in ('source_kinds', 'target_kinds', 'required_qualifiers'):
                    if side in record and (not isinstance(record[side], list) or any(not isinstance(k, str) for k in record[side])):
                        errors.append(f'{side} must be an array of strings.')
            if section == 'edges' and isinstance(record.get('qualifiers', {}), dict):
                q = record.get('qualifiers', {})
                for field in REFS:
                    if field in q and not isinstance(q[field], str):
                        errors.append(f'Qualifier {field} must be a node ID string.')
    if errors:
        return errors
    errors = validate_base(doc)
    if errors:
        return errors
    relations = {r['id']: r for r in doc['relations']}
    for edge in doc['edges']:
        relation, q = relations[edge['relation']], edge.get('qualifiers', {})
        for required in relation.get('required_qualifiers', []):
            if required not in q:
                errors.append(f"{edge['id']}: requires qualifier {required}")
        if relation['semantics'] == 'subjective' and relation['id'] != 'perceived_as' and q.get('holder') != edge['from']:
            errors.append(f"{edge['id']}: this subjective predicate belongs to the source person")
        if 'evidence_mode' in q and q['evidence_mode'] not in ('direct', 'reported', 'inferred', 'imagined'):
            errors.append(f"{edge['id']}: invalid evidence_mode")
    return errors

def merge_missing(existing: dict, incoming: dict) -> tuple[dict, dict]:
    errors = validate(existing) + validate(incoming)
    if errors:
        raise ValueError('\n'.join(errors))
    merged, counts, retained = deepcopy(existing), {}, 0
    for section in ('kinds', 'relations', 'nodes', 'edges', 'views'):
        known = {r['id']: r for r in merged[section]}
        counts[section] = 0
        for record in incoming[section]:
            if record['id'] not in known:
                merged[section].append(deepcopy(record))
                known[record['id']] = record
                counts[section] += 1
            elif known[record['id']] != record:
                retained += 1
    merged['catalog_revision'] = str(incoming.get('catalog_revision', '0.2'))
    errors = validate(merged)
    if errors:
        raise ValueError('Catalog merge conflicts with authored schema: ' + '\n'.join(errors))
    return merged, {'added': counts, 'retained_edits': retained}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', type=Path)
    args = parser.parse_args()
    try:
        doc = expand_seed(load_seed())
        errors = validate(doc)
        if errors:
            print('\n'.join(errors))
            return 1
        used = {e[k] for e in doc['edges'] for k in ('from', 'to')}
        isolated = [n['id'] for n in doc['nodes'] if n['id'] not in used]
        print('Expanded catalog PASS: ' + ', '.join(f'{len(doc[k])} {k}' for k in ('kinds','relations','nodes','edges','views')))
        print(f'Unlinked drafts: {len(isolated)}' + (': ' + ', '.join(isolated) if isolated else ''))
        if args.export:
            args.export.parent.mkdir(parents=True, exist_ok=True)
            with args.export.open('x', encoding='utf-8') as out:
                json.dump(doc, out, indent=2, ensure_ascii=False)
                out.write('\n')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print('ERROR:', exc)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
