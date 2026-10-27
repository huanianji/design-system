import copy
import unittest
from compare_interactions import compare


class CompareInteractionsTest(unittest.TestCase):
    def setUp(self):
        self.contract = dict(scope='unseen-dialog', context={'scale':1}, context_keys=['scale','fixture'],
                             expect={'focus_returned':True}, equal_fields=['focus_returned'],
                             cases=[dict(id='close', actions=['key:Escape'], expect={})])
        self.record = dict(cases=[dict(id='close', actions=['key:Escape'], context={'scale':1,'fixture':'sample'},
                                      observed={'focus_returned':True}, screenshot='actual.png')])

    def run_pair(self, right=None):
        return compare(self.contract, {'a':self.record, 'b':right or copy.deepcopy(self.record)})

    def test_arbitrary_role_is_supported(self):
        self.assertTrue(self.run_pair()['passed'])

    def test_equal_but_wrong_fails(self):
        self.record['cases'][0]['observed']['focus_returned']=False
        result=self.run_pair()
        self.assertFalse(result['passed'])
        self.assertTrue(any(f['kind']=='contract' for f in result['findings']))

    def test_missing_checkpoint_is_unobserved(self):
        result=self.run_pair({'cases':[]})
        self.assertTrue(any(f['kind']=='unobserved' for f in result['findings']))

    def test_different_context_is_not_visual_bug(self):
        right=copy.deepcopy(self.record)
        right['cases'][0]['context']['scale']=1.25
        result=self.run_pair(right)
        self.assertTrue(any(f['kind']=='not-comparable' for f in result['findings']))
        self.assertFalse(any(f['kind']=='platform-difference' for f in result['findings']))

    def test_missing_observation_fails(self):
        right=copy.deepcopy(self.record)
        right['cases'][0]['observed']={}
        self.assertFalse(self.run_pair(right)['passed'])

    def test_state_setter_does_not_replace_input_path(self):
        right=copy.deepcopy(self.record)
        right['cases'][0]['actions']=['set_closed']
        self.assertTrue(any(f['kind']=='input-path' for f in self.run_pair(right)['findings']))

    def test_duplicate_checkpoint_is_rejected(self):
        right=copy.deepcopy(self.record)
        right['cases'].append(copy.deepcopy(right['cases'][0]))
        with self.assertRaises(ValueError):self.run_pair(right)


if __name__=='__main__':
    unittest.main()
