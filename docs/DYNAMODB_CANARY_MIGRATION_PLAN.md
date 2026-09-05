# DynamoDB Canary Migration Plan

## Goal

Migrate `serverless-ssr` DynamoDB resources to the shared `dynamodb-global-table` module with zero unexpected destroys.

## Scope

Current resources in root module:

- `aws_dynamodb_table.visits_primary[0]`
- `aws_dynamodb_table_replica.visits_dr[0]`
- `aws_dynamodb_table_item.counter[0]`

Target resources:

- `module.dynamodb[0].aws_dynamodb_table.primary`
- `module.dynamodb[0].aws_dynamodb_table_replica.dr[0]`
- keep `aws_dynamodb_table_item.counter[0]` in root for first migration wave

## Proposed Code Change Sequence

1. Add new module call (name: `module "dynamodb"`) using existing table semantics:
   - table name: `${local.app_name}-visits`
   - billing mode: `PAY_PER_REQUEST`
   - keys: `PK`, `SK`
   - streams: enabled (`NEW_AND_OLD_IMAGES`)
   - DR replica conditional on `enable_dynamo && enable_dr`
2. Re-point references from old resources to module outputs/resources:
   - `lambda.tf`
   - `iam-cicd.tf`
   - `outputs.tf`
   - tests in `tests/unit.tftest.hcl`
3. Keep `aws_dynamodb_table_item.counter[0]` in root in this first wave.

## Required moved blocks

Add these to `moved.tf` in the same release:

```hcl
moved {
  from = aws_dynamodb_table.visits_primary[0]
  to   = module.dynamodb[0].aws_dynamodb_table.primary
}

moved {
  from = aws_dynamodb_table_replica.visits_dr[0]
  to   = module.dynamodb[0].aws_dynamodb_table_replica.dr[0]
}
```

## Fallback import mappings (only if state is already drifted)

Use only when moved blocks cannot reconcile a workspace due to prior failed/partial applies.

```bash
terraform import 'module.dynamodb[0].aws_dynamodb_table.primary' '<app-name>-visits'
terraform import 'module.dynamodb[0].aws_dynamodb_table_replica.dr[0]' '<app-name>-visits'
```

If replica import format differs in provider behavior, run import once and follow the provider error hint for exact ID format.

## Canary Execution Steps (Non-Destructive)

1. Create migration branch in `terraform-aws-serverless-ssr`.
2. Implement module call + reference rewires + moved blocks.
3. Validate locally:
   - `terraform fmt -check -recursive`
   - `make validate`
   - `make test`
4. Release candidate module version.
5. Canary consumer (`pomo-dev` recommended):
   - bump module source version
   - run plan
   - run no-destroy gate (`check-no-destroy.sh` on plan JSON)
6. Apply canary workspace.
7. Verify:
   - app health endpoint
   - counter read/write path
   - deploy path still resolves `dynamodb.table_name`
8. Roll out to `pomo-ssr`.

## Exit Criteria

- Canary and second consumer both apply with no unexpected destroys.
- No app regressions in visits counter behavior.
- No manual import needed in normal path.
