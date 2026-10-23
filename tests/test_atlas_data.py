from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from atlas_data import SEED, load_seed, expand_seed, validate

class AtlasDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seed = load_seed()
        cls.base = expand_seed(cls.seed)

    def setUp(self):
        self.doc = deepcopy(self.base)

    def edge(self, relation):
        return next(e for e in self.doc['edges'] if e['relation'] == relation)

    def test_catalog_and_all_nodes_have_connections(self):
        self.assertEqual(validate(self.doc), [])
        self.assertEqual((len(self.doc['kinds']), len(self.doc['relations']), len(self.doc['nodes']), len(self.doc['edges'])), (39, 96, 483, 867))
        used = {e[k] for e in self.doc['edges'] for k in ('from', 'to')}
        self.assertEqual({n['id'] for n in self.doc['nodes']} - used, set())

    def test_seed_expansion_is_stable(self):
        self.assertEqual(expand_seed(deepcopy(self.seed)), self.doc)
        row = self.doc['edges'][0]
        key = '|'.join((row['from'], row['relation'], row['to'], ''))
        self.assertEqual(row['id'], 'e_' + hashlib.sha256(key.encode()).hexdigest()[:16])

    def test_json_roundtrip_preserves_qualifiers(self):
        self.assertEqual(json.loads(json.dumps(self.doc)), self.doc)

    def test_missing_endpoint_is_rejected(self):
        self.doc['edges'][0]['to'] = 'place.missing'
        self.assertTrue(validate(self.doc))

    def test_incompatible_kinds_are_rejected(self):
        self.edge('has_role')['to'] = 'mood.cheerful'
        self.assertTrue(validate(self.doc))

    def test_duplicate_ids_rejected(self):
        self.doc['nodes'].append(deepcopy(self.doc['nodes'][0]))
        self.assertTrue(validate(self.doc))

    def test_subjective_links_require_holder(self):
        self.edge('holds_belief')['qualifiers'].pop('holder')
        self.assertTrue(validate(self.doc))

    def test_holder_must_be_person_or_audience(self):
        self.edge('holds_belief')['qualifiers']['holder'] = 'place.school'
        self.assertTrue(validate(self.doc))

    def test_feeling_is_not_automatically_reciprocal(self):
        links = [e for e in self.doc['edges'] if e['relation'] == 'feels_toward' and {e['from'],e['to']} == {'character.avery','character.jules'}]
        self.assertEqual(len(links), 2)
        self.assertNotEqual(links[0]['qualifiers']['strength'], links[1]['qualifiers']['strength'])
        links[0]['qualifiers'].pop('feeling')
        self.assertTrue(validate(self.doc))

    def test_mismatched_scope_rejected(self):
        self.edge('has_role')['scope'] = 'definition'
        self.assertTrue(validate(self.doc))

    def test_confidence_bounds_rejected(self):
        self.edge('holds_belief')['qualifiers']['confidence'] = 1.2
        self.assertTrue(validate(self.doc))

    def test_numeric_interval_order_rejected(self):
        self.edge('formerly_held')['qualifiers'].update(start_tick=5, end_tick=2)
        self.assertTrue(validate(self.doc))

    def test_symbolic_intervals_are_preserved_not_guessed(self):
        self.assertEqual(validate(self.doc), [])
        self.assertEqual(self.edge('formerly_held')['qualifiers']['valid_until'], 'school_year_-25')

    def test_hierarchy_cycle_rejected_but_social_cycles_allowed(self):
        self.assertEqual(validate(self.doc), [])
        e = deepcopy(self.edge('contains'))
        e.update(id='test_cycle', **{'from': e['to'], 'to': e['from']})
        self.doc['edges'].append(e)
        self.assertTrue(any('Cycle' in err for err in validate(self.doc)))

    def test_subtype_is_not_arbitrary_cross_kind_link(self):
        self.edge('subtype_of')['to'] = 'mood.weary'
        self.assertTrue(validate(self.doc))

    def test_unknown_schema_is_not_silently_migrated(self):
        self.doc['schema_version'] = 99
        self.assertTrue(validate(self.doc))

    def test_bad_document_shape_does_not_pass(self):
        for value in ([], None, {'schema_version': 1}, {'schema_version': 1, 'nodes': {}}):
            self.assertTrue(validate(value))

    def test_bad_layout_and_focus_rejected(self):
        self.doc['layout'] = {'school': {'place.school': ['x',0]}}
        self.doc['views'][0]['focus'] = 'not.a.node'
        self.assertGreaterEqual(len(validate(self.doc)), 2)

    def test_false_belief_and_truth_can_coexist(self):
        edge_set = {(e['from'], e['relation'], e['to']) for e in self.doc['edges']}
        self.assertIn(('character.robin','holds_belief','belief.robin_theft_01'), edge_set)
        self.assertIn(('belief.robin_theft_01','contradicts','event.bike_loan_01'), edge_set)
        self.assertNotIn(('character.robin','knows_secret','secret.loan_permission'), edge_set)
        self.assertIn(('character.avery','carries','prop.bicycle'), edge_set)
        self.assertIn(('character.jules','owns','prop.bicycle'), edge_set)

    def test_graph_data_is_not_executable_behavior(self):
        relations = {r['id']: r for r in self.doc['relations']}
        for r in ('motivates', 'can_evoke', 'can_lead_to', 'can_reframe'):
            self.assertEqual(relations[r]['semantics'], 'possibility')
        self.assertEqual(relations['associated_with']['semantics'], 'design')
        self.assertNotIn('scripts', self.doc)

    def test_seed_contains_no_private_file_paths(self):
        text = json.dumps(self.seed)
        self.assertNotIn('/mnt/data/', text)
        self.assertNotIn('private_source', text)

if __name__ == '__main__':
    unittest.main()
