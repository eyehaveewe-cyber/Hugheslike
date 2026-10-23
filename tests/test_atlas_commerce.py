from copy import deepcopy
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from atlas_commerce import load_seed, expand_seed, validate, append_packs, merge_missing, report, MANIFEST
from atlas_extended import load_seed as load_v02, expand_seed as expand_v02

class CommerceAtlasTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seed = load_seed()
        cls.doc = expand_seed(cls.seed)
        cls.nodes = {n['id']: n for n in cls.doc['nodes']}
        cls.triples = {(e['from'],e['relation'],e['to']) for e in cls.doc['edges']}

    def edge(self, a, relation, b):
        return next(e for e in self.doc['edges'] if (e['from'],e['relation'],e['to']) == (a,relation,b))

    def test_full_catalog_validates(self):
        self.assertEqual(validate(self.doc), [])
        self.assertEqual(len(self.doc['kinds']), 61)
        self.assertEqual(len(self.doc['views']), 23)
        self.assertEqual(self.doc['catalog_revision'], '0.3')

    def test_five_packs_have_distinct_ids(self):
        self.assertEqual(len(self.doc['catalog_packs']), 5)
        self.assertEqual(len(set(self.doc['catalog_packs'])), 5)

    def test_old_records_are_preserved(self):
        old = expand_v02(load_v02())
        for section in ('kinds','relations','nodes','edges','views'):
            combined = {r['id']: r for r in self.doc[section]}
            for record in old[section]:
                self.assertEqual(combined[record['id']], record)

    def test_all_entries_are_connected(self):
        self.assertEqual(report(self.doc)['unlinked'], [])

    def test_new_people_use_biblical_names_without_rewriting_old_cast(self):
        expected = {'Joseph','Ruth','Samuel','Naomi','Deborah','Nathan','Esther','Ezra','Hannah','Caleb','Isaac','Lydia'}
        new = [n for n in self.doc['nodes'] if n['kind']=='character' and n['domain']=='commerce_examples']
        self.assertEqual({n['label'].split(',')[0] for n in new}, expected)
        self.assertTrue(all(n['scope']=='example' for n in new))
        self.assertIn('character.tess', self.nodes)

    def test_all_three_stores_have_native_views(self):
        views = {v['id']:v for v in self.doc['views']}
        for store in ('grocery','bank','video_store'):
            self.assertEqual(views[store]['focus'], 'place.'+store)
            self.assertIn(('institution.'+store,'located_in','place.'+store), self.triples)
            self.assertIn(('place.'+store,'connects_to','place.street'), self.triples)

    def test_store_situations_have_location_and_choices(self):
        for node in self.doc['nodes']:
            if node['kind']=='situation' and node['domain'] in ('grocery','bank','video_store'):
                links = [e for e in self.doc['edges'] if e['from']==node['id']]
                self.assertTrue(any(e['relation']=='happens_at' for e in links), node['id'])
                self.assertTrue(any(e['relation']=='respond_with' for e in links), node['id'])

    def test_shared_errand_visits_three_businesses(self):
        for place in ('grocery','bank','video_store'):
            self.assertIn(('routine.three_stop_errand','commerce_schedule_includes','place.'+place), self.triples)

    def test_product_is_not_a_physical_copy(self):
        self.assertEqual(self.nodes['catalog_item.film_lake']['kind'], 'catalog_item')
        for copy in ('a','b'):
            self.assertIn(('prop.video_sample_copy_'+copy,'commerce_copy_of','catalog_item.film_lake'), self.triples)
        self.assertIn(('prop.video_sample_copy_a','commerce_inventory_state','inventory_state.reserved_copy'), self.triples)
        self.assertIn(('prop.video_sample_copy_b','commerce_inventory_state','inventory_state.checked_out'), self.triples)
        self.assertFalse(any(e['from']=='catalog_item.film_lake' and e['relation']=='commerce_inventory_state' for e in self.doc['edges']))

    def test_return_and_processing_are_distinct_transactions(self):
        self.assertIn(('transaction.hannah_return_03','commerce_transaction_state','transaction_state.completed'),self.triples)
        self.assertIn(('transaction.ezra_processing_03','commerce_transaction_state','transaction_state.pending'),self.triples)
        self.assertIn(('event.hannah_return_event_03','precedes','event.ezra_processing_event_03'),self.triples)
        self.assertIn(('belief.ezra_late_guess_03','contradicts','event.hannah_return_event_03'),self.triples)

    def test_custody_period_precedes_returned_state(self):
        custody=self.edge('character.hannah','carries','prop.captain_copy_03')['qualifiers']
        inventory=self.edge('prop.captain_copy_03','commerce_inventory_state','inventory_state.returned_unprocessed')['qualifiers']
        self.assertEqual(custody['end_tick'], inventory['start_tick'])

    def test_membership_and_return_permission_are_not_ownership(self):
        self.assertIn(('account.naomi_video_03','commerce_account_holder','character.naomi'),self.triples)
        self.assertNotIn(('account.naomi_video_03','commerce_account_holder','character.hannah'),self.triples)
        self.assertIn(('institution.video_store','owns','prop.captain_copy_03'),self.triples)
        self.assertNotIn(('character.hannah','owns','prop.captain_copy_03'),self.triples)
        q=self.edge('character.hannah','commerce_authorized_on','account.naomi_video_03')['qualifiers']
        self.assertIn('not permission to rent',q['notes'])

    def test_bank_availability_does_not_prove_job_loss(self):
        self.assertIn(('account.ruth_bank_03','commerce_account_state','account_state.availability_pending'),self.triples)
        self.assertIn(('character.ruth','has_role','role.grocery_cashier'),self.triples)
        guess=self.edge('character.esther','holds_belief','belief.esther_job_guess_03')
        self.assertEqual(guess['qualifiers']['evidence_mode'],'inferred')
        self.assertNotIn(('character.ruth','has_background','background.lost_job'),self.triples)

    def test_partial_witness_does_not_receive_private_account_record(self):
        self.assertNotIn(('character.esther','commerce_record_seen','record.ruth_availability_03'),self.triples)
        self.assertNotIn(('character.samuel','commerce_record_seen','record.ruth_availability_03'),self.triples)
        self.assertNotIn(('character.esther','knows_secret','secret.ruth_private_bank_03'),self.triples)
        for holder in ('ruth','deborah'):
            q=self.edge('character.'+holder,'commerce_record_seen','record.ruth_availability_03')['qualifiers']
            self.assertEqual(q['holder'],'character.'+holder)

    def test_business_messenger_does_not_own_deposit(self):
        self.assertIn(('character.samuel','commerce_entrusted_with','prop.samuel_envelope_03'),self.triples)
        self.assertIn(('institution.grocery','owns','prop.samuel_envelope_03'),self.triples)
        self.assertNotIn(('character.samuel','owns','prop.samuel_envelope_03'),self.triples)
        self.assertNotIn(('account.joseph_business_03','commerce_account_holder','character.samuel'),self.triples)

    def test_conflicting_records_are_retained(self):
        self.assertIn(('record.hannah_return_account_03','commerce_records_conflict','record.naomi_fee_notice_03'),self.triples)
        self.assertIn(('record.naomi_fee_notice_03','commerce_supports_claim','belief.ezra_late_guess_03'),self.triples)

    def test_opposing_feelings_survive(self):
        feelings=[e['qualifiers']['feeling'] for e in self.doc['edges'] if (e['from'],e['relation'],e['to'])==('character.hannah','feels_toward','character.caleb')]
        self.assertEqual(set(feelings),{'feeling.affection','feeling.resentment'})

    def test_graph_merge_preserves_names_notes_and_layout(self):
        prior=expand_v02(load_v02())
        prior['nodes'][0]['label']='My authored principal'
        prior['nodes'][0]['custom_note']='Keep this'
        prior['layout']={'custom':{'place.school':[1,2]}}
        merged, stats=merge_missing(prior,self.doc)
        self.assertEqual(merged['nodes'][0],prior['nodes'][0])
        self.assertEqual(merged['layout'],prior['layout'])
        self.assertEqual(merged['catalog_packs'],self.doc['catalog_packs'])
        self.assertGreater(stats['added']['nodes'],0)

    def test_graph_merge_is_idempotent_and_does_not_mutate_inputs(self):
        old=expand_v02(load_v02()); old_copy=deepcopy(old); incoming_copy=deepcopy(self.doc)
        merged,_=merge_missing(old,self.doc)
        again,_=merge_missing(merged,self.doc)
        self.assertEqual(again,merged)
        self.assertEqual(old,old_copy)
        self.assertEqual(self.doc,incoming_copy)

    def test_repeatable_expansion_and_json_roundtrip(self):
        self.assertEqual(expand_seed(load_seed()),self.doc)
        self.assertEqual(json.loads(json.dumps(self.doc)),self.doc)

    def test_manifest_rejects_path_traversal_and_duplicates(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            manifest=root/'manifest.json'
            for files in (['../outside.json'],['a\\b.json'],['same.json','same.json']):
                (root/'same.json').write_text(json.dumps({'pack_id':'test_pack'}),encoding='utf-8')
                manifest.write_text(json.dumps({'pack_format':1,'files':files}),encoding='utf-8')
                with self.assertRaises(ValueError):
                    append_packs(load_v02(),manifest)

    def test_manifest_rejects_duplicate_pack_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for filename in ('one.json','two.json'):
                (root/filename).write_text(json.dumps({'pack_id':'same_id'}),encoding='utf-8')
            path=root/'manifest.json'
            path.write_text(json.dumps({'pack_format':1,'files':['one.json','two.json']}),encoding='utf-8')
            with self.assertRaises(ValueError):
                append_packs(load_v02(),path)

    def test_all_quiet_outcomes_are_retained(self):
        for scenario in ('grocery_ordinary_purchase','bank_ordinary_service','video_no_rental','ordinary_transactions'):
            self.assertIn(('situation.'+scenario,'respond_with','action.leave_scene'),self.triples)

    def test_no_external_program_or_financial_service_is_executed(self):
        for key in ('scripts','endpoints','credentials','real_accounts'):
            self.assertNotIn(key,self.doc)
        self.assertNotIn('account_number',json.dumps(self.seed))

if __name__=='__main__':
    unittest.main()
