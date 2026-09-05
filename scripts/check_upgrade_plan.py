#!/usr/bin/env python3
"""Fail closed on destructive upgrade plans. Never print resource values."""
import argparse
import json
from pathlib import Path


def check_plan(plan, approvals, baseline_tag, candidate_sha):
    if not isinstance(plan, dict) or not str(plan.get('format_version', '')).startswith('1.'):
        raise ValueError('Unsupported or missing plan format')
    if plan.get('errored') is not False or plan.get('complete') is not True:
        raise ValueError('Plan must be complete and error-free (Terraform 1.8+)')
    if not isinstance(plan.get('planned_values', {}).get('root_module'), dict):
        raise ValueError('Missing planned root module')
    modules = [plan.get('prior_state', {}).get('values', {}).get('root_module', {})]
    established = False
    while modules:
        module = modules.pop()
        established |= any(
            r.get('mode') == 'managed' and r.get('address', '').startswith('module.ssr.')
            for r in module.get('resources', [])
        )
        modules.extend(module.get('child_modules', []))
    if not established:
        raise ValueError('No established module.ssr managed state; fresh plans are not upgrades')
    if not isinstance(approvals, dict) or set(approvals) != {'baseline_tag', 'candidate_sha', 'exceptions'}:
        raise ValueError('Approval file must bind baseline_tag, candidate_sha, and exceptions')
    if approvals['baseline_tag'] != baseline_tag or approvals['candidate_sha'] != candidate_sha:
        raise ValueError('Migration approvals do not match this upgrade')
    allowed = {}
    if not isinstance(approvals['exceptions'], list):
        raise ValueError('Exceptions must be a list')
    for entry in approvals['exceptions']:
        if not isinstance(entry, dict) or set(entry) != {'address', 'actions', 'reason', 'approval_url'}:
            raise ValueError('Every exception needs an exact address/actions, reason, and approval_url')
        address = entry['address']
        if not isinstance(address, str) or not address or any(c in address for c in '*?\n') or address in allowed:
            raise ValueError('Duplicate, empty, or wildcard migration address')
        if not isinstance(entry['actions'], list) or not any(a in entry['actions'] for a in ('delete', 'forget')):
            raise ValueError('Only destructive/state-removal actions need exceptions')
        if not isinstance(entry['reason'], str) or not entry['reason'].strip():
            raise ValueError('Migration reason is required')
        if not isinstance(entry['approval_url'], str) or not entry['approval_url'].startswith('https://github.com/pomo-studio/'):
            raise ValueError('Migration needs a maintainer-reviewed organization PR/issue URL')
        allowed[address] = entry['actions']
    changes = plan.get('resource_changes', [])
    if not isinstance(changes, list):
        raise ValueError('Malformed resource_changes')
    valid = [('no-op',), ('read',), ('create',), ('update',), ('delete',), ('forget',), ('create', 'delete'), ('delete', 'create'), ('create', 'forget')]
    used, seen = set(), set()
    for change in changes:
        address = change.get('address')
        actions = change.get('change', {}).get('actions')
        if not isinstance(address, str) or not address or address in seen or not isinstance(actions, list) or tuple(actions) not in valid:
            raise ValueError('Malformed, duplicate, or unsupported resource change')
        seen.add(address)
        if 'delete' in actions or 'forget' in actions:
            if allowed.get(address) != actions:
                raise ValueError('Unexpected destroy, replacement, or state removal: ' + address)
            used.add(address)
    if used != set(allowed):
        raise ValueError('Unused migration exceptions; remove stale approvals')
    return len(changes), len(used)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--approvals', required=True, type=Path)
    parser.add_argument('--baseline-tag', required=True)
    parser.add_argument('--candidate-sha', required=True)
    args = parser.parse_args()
    try:
        count, approved = check_plan(json.loads(args.plan.read_text()), json.loads(args.approvals.read_text()), args.baseline_tag, args.candidate_sha)
    except (ValueError, KeyError, TypeError, AttributeError, OSError) as error:
        parser.exit(1, f'FAIL: {error}\n')
    print(f'PASS: {count} resource changes, {approved} explicitly approved migrations')
