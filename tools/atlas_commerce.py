#!/usr/bin/env python3
"""Compose the grocery/bank/video atlas packs. Data only; no network or NPC execution."""
from __future__ import annotations
from copy import deepcopy
import argparse
import json
from pathlib import Path
from typing import Any
from atlas_data import SEED, ID
from atlas_extended import load_seed as load_v02, expand_seed as expand_v02, validate, merge_missing as merge_v02

MANIFEST = SEED.parent / 'packs' / 'commerce_manifest.json'
SECTIONS = ('kinds', 'relations', 'groups', 'links', 'views')


def append_packs(original: dict, manifest_path: Path = MANIFEST) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    if not isinstance(manifest, dict) or manifest.get('pack_format') != 1 or not isinstance(manifest.get('files'), list):
        raise ValueError('Commerce manifest requires pack_format=1 and a files array.')
    seed = deepcopy(original)
    seen_files, seen_ids, sources = set(), set(), []
    for filename in manifest['files']:
        if (not isinstance(filename, str) or not filename or '/' in filename or '\\' in filename
                or filename.startswith('.') or Path(filename).suffix != '.json'):
            raise ValueError('Catalog pack filenames must be local JSON basenames.')
        if filename in seen_files:
            raise ValueError('Duplicate catalog pack filename: ' + filename)
        seen_files.add(filename)
        pack = json.loads((manifest_path.parent / filename).read_text(encoding='utf-8'))
        pack_id = pack.get('pack_id') if isinstance(pack, dict) else None
        if not isinstance(pack_id, str) or not ID.fullmatch(pack_id) or pack_id in seen_ids:
            raise ValueError('Catalog packs require distinct stable pack_id values.')
        seen_ids.add(pack_id)
        for section in SECTIONS:
            additions = pack.get(section, [])
            if not isinstance(additions, list) or not isinstance(seed.get(section), list):
                raise ValueError(f'{filename}: {section} must be an array.')
            seed[section].extend(deepcopy(additions))
        sources.append(pack_id)
    seed['catalog_revision'] = str(manifest.get('catalog_revision', '0.3'))
    seed['catalog_packs'] = sources
    return seed


def load_seed() -> dict:
    return append_packs(load_v02())


def expand_seed(seed: dict) -> dict:
    doc = expand_v02(seed)
    if 'catalog_packs' in seed:
        doc['catalog_packs'] = deepcopy(seed['catalog_packs'])
    return doc


def merge_missing(existing: dict, incoming: dict) -> tuple[dict, dict]:
    merged, report = merge_v02(existing, incoming)
    if 'catalog_packs' in incoming:
        merged['catalog_packs'] = deepcopy(incoming['catalog_packs'])
    return merged, report


def report(doc: dict) -> dict[str, Any]:
    old = expand_v02(load_v02())
    connected = {e[k] for e in doc['edges'] for k in ('from', 'to')}
    domains = {}
    for name in ('grocery', 'bank', 'video_store', 'commerce', 'commerce_examples'):
        rows = [n for n in doc['nodes'] if n['domain'] == name]
        ids = {n['id'] for n in rows}
        domains[name] = {'nodes': len(rows), 'incident_edges': sum(e['from'] in ids or e['to'] in ids for e in doc['edges'])}
    return {
        'catalog_revision': doc['catalog_revision'],
        'totals': {k: len(doc[k]) for k in ('kinds', 'relations', 'nodes', 'edges', 'views')},
        'added': {k: len(doc[k]) - len(old[k]) for k in ('kinds', 'relations', 'nodes', 'edges', 'views')},
        'domains': domains,
        'unlinked': [n['id'] for n in doc['nodes'] if n['id'] not in connected],
        'new_cast': [n['label'] for n in doc['nodes'] if n['kind'] == 'character' and n['domain'] == 'commerce_examples'],
        'not_implemented': ['runtime transactions', 'account arithmetic', 'NPC scheduling', 'external program adapter']
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', type=Path, help='Create a new expanded JSON; never overwrite an existing file.')
    parser.add_argument('--report', type=Path, help='Create a new report JSON; never overwrite an existing file.')
    args = parser.parse_args()
    try:
        doc = expand_seed(load_seed())
        errors = validate(doc)
        if errors:
            print('\n'.join(errors))
            return 1
        summary = report(doc)
        print('Commerce catalog PASS: ' + ', '.join(f'{len(doc[k])} {k}' for k in ('kinds','relations','nodes','edges','views')))
        print('Added: ' + ', '.join(f'{v} {k}' for k, v in summary['added'].items()))
        print('Unlinked drafts:', len(summary['unlinked']))
        print('New cast:', '; '.join(summary['new_cast']))
        for name, counts in summary['domains'].items():
            print(name + ': ' + json.dumps(counts, sort_keys=True))
        if summary['unlinked']:
            print(', '.join(summary['unlinked']))
            return 1
        for destination, payload in ((args.export, doc), (args.report, summary)):
            if destination:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with destination.open('x', encoding='utf-8') as out:
                    json.dump(payload, out, indent=2, ensure_ascii=False, allow_nan=False)
                    out.write('\n')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print('ERROR:', exc)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
