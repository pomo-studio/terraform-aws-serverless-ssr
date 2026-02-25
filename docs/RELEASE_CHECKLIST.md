# Release Checklist

Use this checklist before publishing a new module version.

## 1) Local quality gates

- `terraform fmt -check -recursive`
- `make validate`
- `make test`

## 2) Upgrade safety gate (required)

For any change that moves/renames resources internally:

- Add `moved` blocks for every address migration.
- Test upgrade plans from at least one real consumer baseline.
- Block release if plan contains unexpected destroys.

Minimum validation targets:

- Previous stable tag -> candidate tag
- At least one active consumer workspace config

## 3) Release notes quality gate

- State upgrade risk explicitly.
- Include upgrade path guidance (`upgrade directly to X`).
- Include rollback guidance if applicable.

## 4) Post-release checks

- Validate Terraform Registry version availability.
- Verify consumer CI runs after source pin bumps.
- Verify one production-like apply path before broad rollout.
