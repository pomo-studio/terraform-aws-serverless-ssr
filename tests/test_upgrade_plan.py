import copy
import contextlib
import io
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from check_upgrade_plan import check_plan
from tfc_upgrade_plan import run_upgrade

SHA = 'a' * 40
ADDRESS = 'module.ssr.module.lambda.aws_lambda_function.primary'
PLAN = {'format_version': '1.2', 'complete': True, 'errored': False,
        'planned_values': {'root_module': {}},
        'prior_state': {'values': {'root_module': {'child_modules': [
            {'resources': [{'address': ADDRESS, 'mode': 'managed'}]}]}}}}
APPROVALS = {'baseline_tag': 'v2.5.2', 'candidate_sha': SHA, 'exceptions': []}


class CheckerTests(unittest.TestCase):
    def check(self, actions=None, approvals=None, plan=None):
        plan = copy.deepcopy(PLAN if plan is None else plan)
        if actions is not None:
            plan['resource_changes'] = [{'address': ADDRESS, 'change': {'actions': actions}}]
        return check_plan(plan, APPROVALS if approvals is None else approvals, 'v2.5.2', SHA)

    def test_safe_actions_and_noop_without_changes(self):
        self.check()
        for action in ('no-op', 'create', 'update', 'read'):
            with self.subTest(action=action):
                self.check([action])

    def test_destroys_replacements_and_forget_fail(self):
        for actions in (['delete'], ['create', 'delete'], ['delete', 'create'], ['forget'], ['create', 'forget']):
            with self.subTest(actions=actions), self.assertRaises(ValueError):
                self.check(actions)

    def test_exact_authorized_migration(self):
        approval = copy.deepcopy(APPROVALS)
        approval['exceptions'] = [{'address': ADDRESS, 'actions': ['delete', 'create'], 'reason': 'Reviewed immutable field migration', 'approval_url': 'https://github.com/pomo-studio/terraform-aws-serverless-ssr/pull/4'}]
        self.assertEqual(self.check(['delete', 'create'], approval), (1, 1))
        for actions in (['delete'], ['create', 'delete'], ['no-op']):
            with self.subTest(actions=actions), self.assertRaises(ValueError):
                self.check(actions, approval)
        approval['exceptions'][0]['address'] = 'module.ssr.*'
        with self.assertRaises(ValueError):
            self.check(['delete', 'create'], approval)

    def test_fail_closed(self):
        for key, value in (('complete', False), ('errored', True), ('format_version', '2.0'), ('prior_state', {}), ('planned_values', {}), ('resource_changes', {})):
            plan = copy.deepcopy(PLAN)
            plan[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check(plan=plan)
        with self.assertRaises(ValueError):
            self.check(['unknown'])
        with self.assertRaises(ValueError):
            self.check(approvals={**APPROVALS, 'candidate_sha': 'b' * 40})
        with self.assertRaises(ValueError):
            self.check(plan={})

    def test_moved_address_is_safe(self):
        plan = copy.deepcopy(PLAN)
        plan['resource_changes'] = [{'address': ADDRESS, 'previous_address': 'module.ssr.aws_lambda_function.primary', 'change': {'actions': ['no-op']}}]
        self.check(plan=plan)


def rel(**values):
    return {key: {'data': {'id': value}} for key, value in values.items()}


class TfcTests(unittest.TestCase):
    def setUp(self):
        # Fixture run IDs are not live evidence; keep them out of test output.
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)
        self.calls = []
        self.args = SimpleNamespace(workspace='ssr-test', example='examples/basic', baseline_tag='v2.5.2', baseline_sha='b' * 40, candidate_sha=SHA, configuration_version='cv-candidate', approvals=APPROVALS)
        self.responses = {
            'organizations/Pitangaville/workspaces/ssr-test': {'id': 'ws-test', 'attributes': {'execution-mode': 'remote', 'auto-apply': False, 'vcs-repo': {'identifier': 'pomo-studio/terraform-aws-serverless-ssr'}, 'working-directory': 'examples/basic', 'tag-names': ['module-test']}},
            'workspaces/ws-test/current-state-version': {'id': 'sv-baseline', 'relationships': rel(run='run-baseline')},
            'runs/run-baseline': {'attributes': {'status': 'applied'}, 'relationships': rel(workspace='ws-test', **{'configuration-version': 'cv-baseline'})},
            'configuration-versions/cv-baseline/ingress-attributes': {'attributes': {'commit-sha': 'b' * 40}},
            'configuration-versions/cv-candidate': {'attributes': {'status': 'uploaded', 'speculative': True}},
            'configuration-versions/cv-candidate/ingress-attributes': {'attributes': {'commit-sha': SHA}},
            'workspaces/ws-test/configuration-versions?page%5Bsize%5D=100&page%5Bnumber%5D=1': [{'id': 'cv-candidate'}],
            'runs': {'id': 'run-candidate'},
            'runs/run-candidate': {'attributes': {'status': 'planned_and_finished'}, 'relationships': rel(workspace='ws-test', plan='plan-test', **{'configuration-version': 'cv-candidate'})},
            'plans/plan-test': {'attributes': {'status': 'finished'}},
        }

    def api(self, path, payload=None):
        self.calls.append((path, payload))
        if path == 'plans/plan-test/json-output':
            return copy.deepcopy(PLAN)
        return {'data': copy.deepcopy(self.responses[path])}

    def test_only_plan_write_and_exact_identity(self):
        run_upgrade(self.args, self.api, lambda _: None)
        writes = [(path, data) for path, data in self.calls if data is not None]
        self.assertEqual(len(writes), 1)
        self.assertEqual(writes[0][0], 'runs')
        attributes = writes[0][1]['data']['attributes']
        self.assertTrue(attributes['plan-only'])
        self.assertFalse(attributes['auto-apply'])
        self.assertFalse(attributes['is-destroy'])

    def test_preflight_rejections_never_queue(self):
        cases = [
            ('organizations/Pitangaville/workspaces/ssr-test', 'auto-apply', True),
            ('organizations/Pitangaville/workspaces/ssr-test', 'tag-names', ['production']),
            ('organizations/Pitangaville/workspaces/ssr-test', 'working-directory', 'infra'),
            ('configuration-versions/cv-baseline/ingress-attributes', 'commit-sha', SHA),
            ('configuration-versions/cv-candidate/ingress-attributes', 'commit-sha', 'c' * 40),
            ('configuration-versions/cv-candidate', 'speculative', False),
            ('runs/run-baseline', 'status', 'planned_and_finished'),
        ]
        for path, key, value in cases:
            with self.subTest(path=path, key=key):
                self.setUp()
                self.responses[path]['attributes'][key] = value
                with self.assertRaises(ValueError):
                    run_upgrade(self.args, self.api, lambda _: None)
                self.assertFalse(any(payload for _, payload in self.calls))

    def test_changed_state_fails(self):
        def changed(path, payload=None):
            response = self.api(path, payload)
            if path.endswith('/current-state-version') and sum(p == path for p, _ in self.calls) > 1:
                response['data']['id'] = 'sv-other'
            return response
        with self.assertRaises(ValueError):
            run_upgrade(self.args, changed, lambda _: None)
        self.assertFalse(any(payload for _, payload in self.calls))

    def test_failed_run_and_timeout_fail(self):
        for status in ('errored', 'applied', 'pending'):
            with self.subTest(status=status), self.assertRaises(ValueError):
                self.responses['runs/run-candidate']['attributes']['status'] = status
                run_upgrade(self.args, self.api, lambda _: None)


if __name__ == '__main__':
    unittest.main()
