# Snowflake estate (idempotent SQL + scripts)

Terraform's snowflake provider is deliberately not used (see header of
`estate.sql`). Everything here is idempotent and operator-run with admin env
vars — never CI, never Pumpkin.

| Step | Command | Needs |
|---|---|---|
| 1. Estate DDL | `python snowflake/run_sql.py snowflake/estate.sql` | Snowflake admin env |
| 2. Seed dev data | `python snowflake/seed_dev.py` | Snowflake admin env |
| 3. Credentials | `python snowflake/materialize_credentials.py --gh-secrets` | + AWS creds, gh CLI |

Admin env vars (never in files): `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`,
`SNOWFLAKE_PASSWORD` (+ optional `SNOWFLAKE_ROLE`, default ACCOUNTADMIN).

## What exists afterwards

- **ACME_DEV** (RAW / STAGING / MARTS) — seeded, dbt-built, validated.
- **ACME_PROD** — EMPTY. A denial target. No role here ever gets a grant.
- **ACME_WH_XS** — XS, auto-suspend 60 s, hard-capped at 5 credits/mo by
  resource monitor **ACME_RM** (suspend-immediate at 100%).
- Roles `PUMPKIN_VALIDATE` (SELECT on MARTS only) and `DBT_RUNNER_DEV`
  (read RAW, usage+create on STAGING/MARTS), with service users
  `SVC_PUMPKIN_VALIDATE` / `SVC_DBT_RUNNER_DEV`.
- Credentials live ONLY in AWS Secrets Manager:
  `acme/snowflake/pumpkin-validate`, `acme/snowflake/dbt-runner-dev`.

## Teardown

`DROP DATABASE ACME_DEV; DROP DATABASE ACME_PROD; DROP WAREHOUSE ACME_WH_XS;
DROP RESOURCE MONITOR ACME_RM; DROP ROLE PUMPKIN_VALIDATE; DROP ROLE
DBT_RUNNER_DEV; DROP USER SVC_PUMPKIN_VALIDATE; DROP USER SVC_DBT_RUNNER_DEV;`
then delete the two Secrets Manager secrets.
