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
