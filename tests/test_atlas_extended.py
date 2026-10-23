from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from atlas_data import load_seed as load_base, expand_seed as expand_base
from atlas_extended import load_seed, expand_seed, validate, merge_missing

class ExpandedAtlasTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = expand_base(load_base())
        cls.full = expand_seed(load_seed())

    def setUp(self):
        self.doc = deepcopy(self.full)

    def matching(self, source=None, relation=None, target=None):
        return [e for e in self.doc['edges'] if (source is None or e['from'] == source)
                and (relation is None or e['relation'] == relation)
                and (target is None or e['to'] == target)]

    def test_expansion_is_valid_and_connected(self):
        self.assertEqual(validate(self.doc), [])
        self.assertEqual(len(self.doc['kinds']), 53)
        self.assertEqual(len(self.doc['views']), 14)
        self.assertGreater(len(self.doc['nodes']), 680)
        self.assertGreater(len(self.doc['edges']), 1200)
        used = {e[k] for e in self.doc['edges'] for k in ('from', 'to')}
        self.assertEqual({n['id'] for n in self.doc['nodes']} - used, set())

    def test_original_records_are_unchanged(self):
        for section in ('kinds', 'relations', 'nodes', 'edges', 'views'):
            full = {r['id']: r for r in self.doc[section]}
            for record in self.base[section]:
                self.assertEqual(record, full[record['id']])

    def test_expanded_json_roundtrip(self):
        self.assertEqual(json.loads(json.dumps(self.doc)), self.doc)

    def test_repeated_seed_expansion_is_stable(self):
        self.assertEqual(expand_seed(load_seed()), self.doc)

    def test_conflicting_feelings_can_coexist(self):
        links = self.matching('character.tess', 'feels_toward', 'character.rowan')
        self.assertEqual(len(links), 2)
        self.assertEqual({e['qualifiers']['feeling'] for e in links}, {'feeling.affection', 'feeling.resentment'})
        self.assertEqual(len({e['id'] for e in links}), 2)

    def test_private_beliefs_do_not_become_world_facts(self):
        e = self.matching('character.tess', 'holds_belief', 'belief.tess_not_priority_02')[0]
        self.assertEqual(e['qualifiers']['holder'], 'character.tess')
        self.assertEqual(e['qualifiers']['evidence_mode'], 'inferred')
        self.assertFalse(self.matching('character.tess', 'witnessed', 'event.rota_change_02'))
        self.assertTrue(self.matching('belief.rowan_message_received_02', 'contradicts', 'event.message_late_02'))

    def test_public_credit_is_not_the_same_as_contribution(self):
        self.assertTrue(self.matching('character.tess', 'receives_credit_for', 'event.poster_credit_02'))
        self.assertTrue(self.matching('character.avery', 'participated_in', 'event.poster_credit_02'))
        self.assertTrue(self.matching('character.avery', 'bears_cost', 'consequence.unseen_effort'))

    def test_past_role_is_not_a_current_role(self):
        self.assertTrue(self.matching('character.mara', 'formerly_held', 'role.bus_driver'))
        self.assertFalse(self.matching('character.mara', 'has_role', 'role.bus_driver'))
        self.assertTrue(self.matching('character.mara', 'has_role', 'role.retired_neighbor'))

    def test_required_shared_interest_object(self):
        self.matching(relation='shared_interest_with')[0]['qualifiers'].pop('object')
        self.assertTrue(any('requires qualifier object' in e for e in validate(self.doc)))

    def test_subjective_holder_cannot_be_someone_else(self):
        self.matching('character.tess', 'expects')[0]['qualifiers']['holder'] = 'character.rowan'
        self.assertTrue(validate(self.doc))

    def test_perceived_as_has_an_observer_not_necessarily_the_subject(self):
        e = self.matching('character.ellis', 'perceived_as')[0]
        self.assertNotEqual(e['from'], e['qualifiers']['holder'])
        self.assertEqual(validate(self.doc), [])

    def test_evidence_mode_is_checked(self):
        self.matching('character.tess', 'holds_belief')[0]['qualifiers']['evidence_mode'] = 'omniscient_guess'
        self.assertTrue(validate(self.doc))

    def test_malformed_reference_returns_errors_not_exception(self):
        for value in ([], {}, 42, None):
            doc = deepcopy(self.full)
            next(e for e in doc['edges'] if e['relation'] == 'holds_belief')['qualifiers']['holder'] = value
            self.assertTrue(validate(doc))

    def test_merge_preserves_existing_authored_changes(self):
        edited = deepcopy(self.base)
        edited['title'] = 'My personal draft'
        edited['nodes'][0]['label'] = 'My principal label'
        edited['nodes'][0]['custom_note'] = 'Keep this'
        edited['layout'] = {'school:place.school': {'place.school': [170, 240]}}
        merged, report = merge_missing(edited, self.full)
        self.assertEqual(merged['title'], edited['title'])
        self.assertEqual(merged['layout'], edited['layout'])
        self.assertEqual(merged['nodes'][0], edited['nodes'][0])
        self.assertGreater(report['retained_edits'], 0)
        self.assertGreater(report['added']['nodes'], 0)
        self.assertEqual(len(merged['nodes']), len(self.full['nodes']))

    def test_merge_is_idempotent(self):
        once, _ = merge_missing(self.base, self.full)
        twice, report = merge_missing(once, self.full)
        self.assertEqual(once, twice)
        self.assertTrue(all(count == 0 for count in report['added'].values()))

    def test_merge_does_not_mutate_inputs(self):
        before_base, before_full = deepcopy(self.base), deepcopy(self.full)
        merge_missing(self.base, self.full)
        self.assertEqual(self.base, before_base)
        self.assertEqual(self.full, before_full)

    def test_invalid_merge_is_refused(self):
        edited = deepcopy(self.base)
        edited['edges'][0]['to'] = 'missing.endpoint'
        with self.assertRaises(ValueError):
            merge_missing(edited, self.full)

    def test_new_types_have_relevant_typed_predicates(self):
        expected = {'has_interest': 'interest', 'prefers': 'preference', 'has_habit': 'habit',
                    'uses_coping': 'coping_strategy', 'has_boundary': 'boundary',
                    'appraises': 'appraisal', 'expects': 'expectation', 'faces_constraint': 'constraint',
                    'identifies_as': 'self_image', 'undergoes_transition': 'transition'}
        relations = {r['id']: r for r in self.doc['relations']}
        for predicate, target_kind in expected.items():
            self.assertIn(target_kind, relations[predicate]['target_kinds'])
            self.assertTrue(self.matching(relation=predicate))

    def test_opportunities_are_not_executable_causation(self):
        relations = {r['id']: r for r in self.doc['relations']}
        for predicate in ('draws_toward', 'can_amplify', 'appraisal_of', 'can_disappoint', 'occasion_for'):
            self.assertEqual(relations[predicate]['semantics'], 'possibility')
        self.assertFalse('runtime_rules' in self.doc)

if __name__ == '__main__':
    unittest.main()
