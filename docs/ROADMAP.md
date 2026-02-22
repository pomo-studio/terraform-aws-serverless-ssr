# Roadmap Notes

## Module Boundaries

- `terraform-aws-serverless-ssr` owns SSR web delivery and CloudFront plus Lambda integration.
- API POST workflows are out of scope for this module.
- API workflows should be implemented via dedicated API modules (for example AppSync/API Gateway).

## Backlog

- TxWatch refactor: move auth and other `/api/*` POST flows from SSR-routed endpoints to an AppSync-owned API boundary.
- Tracking issue: https://github.com/pomo-studio/terraform-aws-serverless-ssr/issues/2
