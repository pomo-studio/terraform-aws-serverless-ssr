#!/usr/bin/env python3
"""Plan an exact reviewed VCS candidate against previous-tag state in TFC only."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

from check_upgrade_plan import check_plan

API = 'https://app.terraform.io/api/v2/'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(path, payload=None):
    url = API + path
    headers = {'Authorization': 'Bearer ' + os.environ['TFC_TOKEN'], 'Content-Type': 'application/vnd.api+json'}
    data = None if payload is None else json.dumps(payload).encode()
    opener = build_opener(NoRedirect)
    try:
        with opener.open(Request(url, data=data, headers=headers), timeout=60) as response:
            return json.load(response)
    except HTTPError as error:
        # Plan JSON redirects to a signed download. Never forward the API token.
        if error.code == 307 and path.endswith('/json-output'):
            location = error.headers['Location']
            if urlparse(location).scheme != 'https':
                raise ValueError('Refusing insecure plan redirect') from None
            with opener.open(Request(location), timeout=60) as response:
                return json.load(response)
        raise ValueError(f'TFC API returned HTTP {error.code}; no response body logged') from None


def relationship(item, name):
    return item['relationships'][name]['data']['id']


def run_upgrade(args, api=request, pause=time.sleep):
    if not re.fullmatch(r'[0-9a-f]{40}', args.candidate_sha) or not re.fullmatch(r'cv-[A-Za-z0-9]+', args.configuration_version):
        raise ValueError('Expected full candidate SHA and configuration version ID')
    workspace = api('organizations/Pitangaville/workspaces/' + args.workspace)['data']
    a = workspace['attributes']
    if a.get('execution-mode') != 'remote' or a.get('auto-apply') is not False:
        raise ValueError('Test workspace must use remote execution with auto-apply disabled')
    if a.get('vcs-repo', {}).get('identifier') != 'pomo-studio/terraform-aws-serverless-ssr' or a.get('working-directory') != args.example:
        raise ValueError('Workspace must point at this repository and the exact example')
    if 'module-test' not in a.get('tag-names', []) or 'production' in a.get('tag-names', []):
        raise ValueError('An explicitly tagged module-test, non-production workspace is required')
    ws_id = workspace['id']
    state_path = 'workspaces/' + ws_id + '/current-state-version'
    state = api(state_path)['data']
    baseline_run = api('runs/' + relationship(state, 'run'))['data']
    if baseline_run['attributes']['status'] != 'applied' or relationship(baseline_run, 'workspace') != ws_id:
        raise ValueError('Current state must come from an applied run in this workspace')
    baseline_cv = relationship(baseline_run, 'configuration-version')
    ingress = api('configuration-versions/' + baseline_cv + '/ingress-attributes')['data']['attributes']
    if ingress.get('commit-sha') != args.baseline_sha:
        raise ValueError('Established state is not from the specified previous stable tag')
    cv_path = 'configuration-versions/' + args.configuration_version
    candidate = api(cv_path)['data']
    if candidate['attributes'].get('status') != 'uploaded' or candidate['attributes'].get('speculative') is not True:
        raise ValueError('Candidate must be an uploaded speculative configuration version')
    # Membership is checked via the workspace collection, not an undocumented CV relationship.
    found = False
    page = 1
    while page:
        versions = api(f'workspaces/{ws_id}/configuration-versions?page%5Bsize%5D=100&page%5Bnumber%5D={page}')
        if any(item['id'] == args.configuration_version for item in versions['data']):
            found = True
            break
        page = versions.get('meta', {}).get('pagination', {}).get('next-page')
    if not found:
        raise ValueError('Candidate configuration does not belong to the test workspace')
    if api(cv_path + '/ingress-attributes')['data']['attributes'].get('commit-sha') != args.candidate_sha:
        raise ValueError('Candidate configuration does not match reviewed commit')
    if api(state_path)['data']['id'] != state['id']:
        raise ValueError('Baseline state changed during preflight')
    payload = {'data': {'type': 'runs', 'attributes': {
        'message': f'Upgrade safety: {args.baseline_tag} -> {args.candidate_sha}',
        'plan-only': True, 'auto-apply': False, 'is-destroy': False, 'refresh': True,
    }, 'relationships': {
        'workspace': {'data': {'type': 'workspaces', 'id': ws_id}},
        'configuration-version': {'data': {'type': 'configuration-versions', 'id': args.configuration_version}},
    }}}
    run_id = api('runs', payload)['data']['id']
    print(f'Plan-only run: https://app.terraform.io/app/Pitangaville/workspaces/{args.workspace}/runs/{run_id}')
    for _ in range(120):
        run = api('runs/' + run_id)['data']
        status = run['attributes']['status']
        if status == 'planned_and_finished':
            if relationship(run, 'configuration-version') != args.configuration_version or relationship(run, 'workspace') != ws_id:
                raise ValueError('Run identity mismatch')
            plan_id = relationship(run, 'plan')
            plan_meta = api('plans/' + plan_id)['data']['attributes']
            if plan_meta.get('status') != 'finished':
                raise ValueError('Plan did not finish')
            plan = api('plans/' + plan_id + '/json-output')
            count, approved = check_plan(plan, args.approvals, args.baseline_tag, args.candidate_sha)
            if api(state_path)['data']['id'] != state['id']:
                raise ValueError('State changed during plan; rerun against an established baseline')
            print(f'PASS: baseline {args.baseline_tag} ({args.baseline_sha}), candidate {args.candidate_sha}, state {state["id"]}, {count} changes, {approved} approved migrations. No apply performed.')
            return
        if status in ('errored', 'canceled', 'force_canceled', 'discarded', 'applied'):
            raise ValueError('Unexpected run status: ' + status)
        pause(15)
    raise ValueError('Timed out; inspect the linked plan-only run. No apply will occur.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', required=True)
    parser.add_argument('--example', choices=['examples/basic', 'examples/complete'], required=True)
    parser.add_argument('--configuration-version', required=True)
    parser.add_argument('--candidate-sha', required=True)
    parser.add_argument('--baseline-tag', required=True)
    parser.add_argument('--approvals', type=Path)
    args = parser.parse_args()
    try:
        if not os.environ.get('TFC_TOKEN'):
            raise ValueError('TFC_TOKEN is required; no credential discovery or privilege changes are performed')
        if not re.fullmatch(r'[A-Za-z0-9_-]+', args.workspace):
            raise ValueError('Invalid workspace name')
        if not re.fullmatch(r'v\d+\.\d+\.\d+', args.baseline_tag):
            raise ValueError('Baseline must be a stable semantic version tag')
        if not re.fullmatch(r'[0-9a-f]{40}', args.candidate_sha):
            raise ValueError('Candidate must be a full reviewed commit SHA')
        def git(*command):
            return subprocess.check_output(['git', *command], text=True).strip()
        args.baseline_sha = git('rev-parse', args.baseline_tag + '^{commit}')
        tags = git('tag', '--merged', args.candidate_sha).splitlines()
        stable = [tag for tag in tags if re.fullmatch(r'v\d+\.\d+\.\d+', tag) and git('rev-parse', tag + '^{commit}') != args.candidate_sha]
        if not stable or max(stable, key=lambda tag: tuple(map(int, tag[1:].split('.')))) != args.baseline_tag:
            raise ValueError('Baseline must be the most recent stable tag reachable before the candidate')
        args.approvals = json.loads(args.approvals.read_text()) if args.approvals else {'baseline_tag': args.baseline_tag, 'candidate_sha': args.candidate_sha, 'exceptions': []}
        run_upgrade(args)
    except (ValueError, KeyError, TypeError, AttributeError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'FAIL: {error}\n')


if __name__ == '__main__':
    main()
