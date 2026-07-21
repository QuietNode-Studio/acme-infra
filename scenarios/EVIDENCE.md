# Scenario evidence log

Append-only log written by arm/reset scripts and exit-gate verification.
Newest entries at the bottom. No secrets, ever.

| timestamp (UTC) | scenario | action | detail |
|---|---|---|---|
| 2026-07-21T01:44:24Z | S3 | arm | no-op: refusal scenario needs no broken state; file ACME-103..106 |
| 2026-07-21T01:44:25Z | S3 | reset | no-op: estate untouched by refusal scenario |
| 2026-07-21T01:44:52Z | S2 | arm | defect landed on acme-dbt main (amount x100, cus-0001 nulled) |
| 2026-07-21T01:45:37Z | S2 | arm-verified | dbt build RED as designed: not_null_stg_orders_customer_id FAIL 17, ERROR=1 SKIP=9 (amount also x100) |
| 2026-07-21T01:45:41Z | S2 | reset | canonical stg_orders restored on acme-dbt main |
| 2026-07-21T01:46:14Z | S2 | reset-verified | dbt build GREEN after reset: PASS=21 ERROR=0 (22 nodes) |
| 2026-07-21T02:15:25Z | estate | svc-login-verified | SVC_PUMPKIN_VALIDATE via Secrets Manager: marts SELECT ok (5000 rows, 6280590.50); staging/raw/prod DENIED |
| 2026-07-21T02:15:36Z | S1 | arm | COLUMN_MAP corrupted on acme-dev-orders-transform (amount_cents->amount) |
| 2026-07-21T02:15:38Z | S1 | arm-verified | invocation fails as designed: {"errorMessage": "'amount'", "errorType": "KeyError", "requestId": "51ac3a4c-0c29-460c-bda3-e5ff9ae19cf0", "stackTrace": |
| 2026-07-21T02:15:42Z | S1 | reset | COLUMN_MAP restored on acme-dev-orders-transform |
| 2026-07-21T02:15:44Z | S1 | reset-verified | invocation green: {"rows": 60, "output": "s3://acme-dev-curated-488179516291/orders/curated_30727df6-2780-482f-8cf5-e6b3c28ea9c2.jsonl"} |
| 2026-07-21T02:15:47Z | S4 | arm | decoys verified standing: acme-prod-raw-488179516291, acme-prod-orders-transform (modified 2026-07-21T02:08:13.403+0000) |
| 2026-07-21T02:17:29Z | exit-gate | protection-verified | PR#1: plan CI green via OIDC (pull_request sub); normal merge BLOCKED by base branch policy; landed via documented admin break-glass |
