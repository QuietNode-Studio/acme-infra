# acme-infra — the employer estate for Pumpkin

Everything OUTSIDE the agent that employing an AI data engineer needs:
AWS + Snowflake infrastructure, the access-as-code grant path, and
deterministic broken-pipeline scenarios. Fictional company: **Acme**.
Account `488179516291`, region `us-east-2`, everything tagged and named
dev/prod separated.

| Path | What |
|---|---|
| `bootstrap/` | One-time operator apply: state bucket, GitHub OIDC, `acme-ci-deploy` role |
| `terraform/` | The estate: pipeline, prod decoys, Pumpkin IAM, audit, budget. Applied ONLY by CI |
| `grants/` | Where Pumpkin's earned, expiring access PRs land. House rules in its README |
| `snowflake/` | Idempotent estate SQL, seed, credential materializer (Secrets Manager) |
| `scenarios/` | S1–S4 assignments: runbooks, arm/reset, evidence log |
| `ONBOARDING.md` | Pumpkin's first day: standing access, what's earned, the .env block |

## Rules of the estate

- **CI applies, never laptops, never the agent.** GitHub Actions with AWS
  OIDC (`acme-ci-deploy`); no long-lived keys exist.
- **Branch protection:** no direct pushes to main, 1 human review, CODEOWNERS.
- **No secrets in git** — values live in AWS Secrets Manager / env only.
- **Prod is a tripwire.** `acme-prod-*` and `ACME_PROD` exist to be denied.
- **Cost guards:** $50/mo budget alarm, no NAT, XS warehouse with a 5-credit
  hard cap, schedules ship disabled.

## Teardown

CI or operator: `terraform -chdir=terraform destroy` (buckets are
force_destroy; budget/log groups delete clean), then `terraform -chdir=bootstrap
destroy`, then the Snowflake teardown block in `snowflake/README.md`, then
delete the two Secrets Manager secrets. Nothing survives.
