-- acme Snowflake estate — idempotent; run as ACCOUNTADMIN via run_sql.py.
-- Terraform's snowflake provider was considered and skipped deliberately: the
-- account is operator-owned (not CI-owned), credentials for a provider would
-- have to live in CI, and this estate is a handful of objects. Idempotent SQL
-- + a tiny runner is the smaller attack surface. Revisit if the estate grows.

-- ── Databases: dev is real, prod is an EMPTY denial target ──────────────────
CREATE DATABASE IF NOT EXISTS ACME_DEV;
CREATE DATABASE IF NOT EXISTS ACME_PROD
  COMMENT = 'DENIAL TARGET — deliberately empty. No role below may ever receive a grant here.';

CREATE SCHEMA IF NOT EXISTS ACME_DEV.RAW;
CREATE SCHEMA IF NOT EXISTS ACME_DEV.STAGING;
CREATE SCHEMA IF NOT EXISTS ACME_DEV.MARTS;

-- ── Warehouse: XS, aggressive suspend, hard-capped by a resource monitor ────
CREATE WAREHOUSE IF NOT EXISTS ACME_WH_XS
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'acme estate compute. Capped by ACME_RM.';

CREATE RESOURCE MONITOR IF NOT EXISTS ACME_RM
  WITH CREDIT_QUOTA = 5
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE ACME_WH_XS SET RESOURCE_MONITOR = ACME_RM;

-- ── Roles (least privilege, no login of their own) ──────────────────────────
-- PUMPKIN_VALIDATE: read-only validation SELECTs on ACME_DEV marts. Nothing
-- else — no staging, no raw, no prod, no DDL.
CREATE ROLE IF NOT EXISTS PUMPKIN_VALIDATE
  COMMENT = 'Pumpkin validation: SELECT on ACME_DEV.MARTS only.';

-- DBT_RUNNER_DEV: what `dbt build --target dev` needs — read raw sources,
-- create/refresh objects in staging+marts. No prod, no admin verbs.
CREATE ROLE IF NOT EXISTS DBT_RUNNER_DEV
  COMMENT = 'dbt dev target: usage+create on ACME_DEV staging/marts, read on raw.';

GRANT USAGE ON WAREHOUSE ACME_WH_XS TO ROLE PUMPKIN_VALIDATE;
GRANT USAGE ON WAREHOUSE ACME_WH_XS TO ROLE DBT_RUNNER_DEV;

GRANT USAGE ON DATABASE ACME_DEV TO ROLE PUMPKIN_VALIDATE;
GRANT USAGE ON DATABASE ACME_DEV TO ROLE DBT_RUNNER_DEV;

-- PUMPKIN_VALIDATE: marts only
GRANT USAGE ON SCHEMA ACME_DEV.MARTS TO ROLE PUMPKIN_VALIDATE;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME_DEV.MARTS TO ROLE PUMPKIN_VALIDATE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME_DEV.MARTS TO ROLE PUMPKIN_VALIDATE;
GRANT SELECT ON ALL VIEWS IN SCHEMA ACME_DEV.MARTS TO ROLE PUMPKIN_VALIDATE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ACME_DEV.MARTS TO ROLE PUMPKIN_VALIDATE;

-- DBT_RUNNER_DEV: read raw (model inputs), build staging+marts
GRANT USAGE ON SCHEMA ACME_DEV.RAW TO ROLE DBT_RUNNER_DEV;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME_DEV.RAW TO ROLE DBT_RUNNER_DEV;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME_DEV.RAW TO ROLE DBT_RUNNER_DEV;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA ACME_DEV.STAGING TO ROLE DBT_RUNNER_DEV;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA ACME_DEV.MARTS TO ROLE DBT_RUNNER_DEV;

-- ── Service users (one per role; passwords set ONLY by materialize step) ────
-- Created disabled-by-password: LOGIN happens only after
-- materialize_credentials.py sets a generated password and stores it in AWS
-- Secrets Manager. Values never touch git, chat, or logs.
CREATE USER IF NOT EXISTS SVC_PUMPKIN_VALIDATE
  DEFAULT_ROLE = PUMPKIN_VALIDATE
  DEFAULT_WAREHOUSE = ACME_WH_XS
  DEFAULT_NAMESPACE = ACME_DEV.MARTS
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Service login for Pumpkin validation SELECTs.';

CREATE USER IF NOT EXISTS SVC_DBT_RUNNER_DEV
  DEFAULT_ROLE = DBT_RUNNER_DEV
  DEFAULT_WAREHOUSE = ACME_WH_XS
  DEFAULT_NAMESPACE = ACME_DEV.STAGING
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Service login for the dbt dev target (CI + governed runner).';

GRANT ROLE PUMPKIN_VALIDATE TO USER SVC_PUMPKIN_VALIDATE;
GRANT ROLE DBT_RUNNER_DEV TO USER SVC_DBT_RUNNER_DEV;

-- Snowflake defaults users to SECONDARY ROLES ('ALL'), which activates EVERY
-- granted role for authorization — that would quietly widen a service login
-- beyond its one role. Pin secondaries OFF (idempotent, covers pre-existing
-- users too, since CREATE IF NOT EXISTS won't touch them).
ALTER USER SVC_PUMPKIN_VALIDATE SET DEFAULT_SECONDARY_ROLES = ();
ALTER USER SVC_DBT_RUNNER_DEV SET DEFAULT_SECONDARY_ROLES = ();

-- Operator convenience: lets the admin user verify the exact privilege set of
-- each role (e.g. `dbt build` AS ROLE DBT_RUNNER_DEV) without service creds.
GRANT ROLE PUMPKIN_VALIDATE TO USER QUIETNODE;
GRANT ROLE DBT_RUNNER_DEV TO USER QUIETNODE;
