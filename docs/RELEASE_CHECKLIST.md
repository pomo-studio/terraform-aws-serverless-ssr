# Release Checklist

Use this checklist before publishing a new module version.

## 1) Local quality gates

- `terraform fmt -check -recursive`
- CI example validation (backend disabled, no cloud credentials); do not run local init/validate.
- `make test` for existing mock-provider tests when dependencies are available.
- `python3 -m unittest discover -s tests -p 'test_upgrade*.py' -v`

## 2) Upgrade safety gate (required)

For any change that moves/renames resources internally:

- Add `moved` blocks for every address migration.
- Test upgrade plans from at least one real consumer baseline.
- Block release if plan contains unexpected destroys.

Minimum validation targets:

- Previous stable tag -> candidate tag
- At least one active consumer workspace config

### Executable Terraform Cloud Gate

Use `scripts/tfc_upgrade_plan.py` from a trusted checkout with all remote tags fetched. The script never initializes Terraform locally, uploads configuration, applies, destroys, creates infrastructure, or modifies state. It queues only an explicitly plan-only run against an existing speculative VCS configuration version.

Prerequisites:

- An existing, approved non-production workspace in `Pitangaville`, tagged `module-test`, with remote execution and auto-apply disabled.
- Its VCS repository is `pomo-studio/terraform-aws-serverless-ssr` and working directory is exactly `examples/basic` or `examples/complete`.
- Its current state came from an **applied** VCS run of the previous stable tag. The gate verifies the tag's commit against the state-producing run's ingress attributes. It does not bootstrap that state; a baseline apply needs separate authorization.
- A maintainer-reviewed candidate commit and its uploaded **speculative** VCS configuration version in the same workspace. Planning can execute code: do not submit untrusted PR configurations, even for speculative runs.
- `TFC_TOKEN` with existing access to read the workspace/run/state metadata and plan JSON and queue plans. Do not add privileges to bypass a failed preflight.

Example invocation (replace placeholders with reviewed, real identifiers):

```sh
python3 scripts/tfc_upgrade_plan.py \
  --workspace APPROVED_TEST_WORKSPACE \
  --example examples/basic \
  --baseline-tag v2.5.2 \
  --candidate-sha FULL_REVIEWED_COMMIT_SHA \
  --configuration-version cv-CANDIDATE
```

The gate requires the most recent stable tag reachable before the candidate. It verifies exact candidate ingress identity, current-state stability before/after the plan, and established `module.ssr` managed resources. It rejects incomplete/errored plans, every destroy/replacement/state removal, and malformed or unsupported plan data. A no-op move is permitted; a fresh-state create plan is not an upgrade.

### Authorized Migrations

The default exception set is empty. Only pass `--approvals PATH` after a maintainer has explicitly reviewed that file for this exact candidate and baseline. This file is an authorization record, not a way for PR code to self-approve. Never read approvals from untrusted candidate code in a credentialed workflow.

```json
{
  "baseline_tag": "v2.5.2",
  "candidate_sha": "FULL_REVIEWED_COMMIT_SHA",
  "exceptions": [
    {
      "address": "module.ssr.EXACT_RESOURCE_ADDRESS",
      "actions": ["delete", "create"],
      "reason": "Explain why this replacement is necessary and safe",
      "approval_url": "https://github.com/pomo-studio/terraform-aws-serverless-ssr/pull/REVIEW"
    }
  ]
}
```

Wildcards, action-order mismatches, duplicate exceptions, and unused approvals fail. `forget` also requires explicit authorization, even though it is not an AWS destroy. Document corresponding `moved`/`removed` blocks and consumer implications separately.

For an already retrieved sensitive plan, run `scripts/check_upgrade_plan.py PLAN.json --baseline-tag TAG --candidate-sha SHA --approvals APPROVALS.json`. This checks plan contents only; it does **not** prove TFC provenance. Never publish raw plans/state or upload them as CI artifacts. The TFC runner checks provenance and keeps plan values in memory, printing only IDs and counts.

### Evidence Status

Maintenance verification on 2026-09-05: credential-free checker/API-fixture tests pass. Live TFC discovery returned **HTTP 401 Unauthorized** with the available credential. No live example plan, established previous-tag baseline, or candidate upgrade has been verified by this maintenance work. The existing endpoint smoke variable points to `https://pomo.dev`; that is production availability, not candidate-specific integration evidence. Do not tag a release based on these fixture tests alone.

Record real workspace/run URL, example, baseline tag/SHA/state ID, candidate SHA/configuration version, result, and approved migration count when access and an approved baseline are available. Applies remain separately authorized through TFC. Do not use a production consumer as the test workspace.

## 3) Release notes quality gate

- State upgrade risk explicitly.
- Include upgrade path guidance (`upgrade directly to X`).
- Include rollback guidance if applicable.

## 4) Post-release checks

- Validate Terraform Registry version availability.
- Verify consumer CI runs after source pin bumps.
- Verify one production-like apply path before broad rollout.
