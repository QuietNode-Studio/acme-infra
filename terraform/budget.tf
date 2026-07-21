# ── Cost guard: $50/mo hard line with early warning ──────────────────────────
# Estate design keeps standing cost near zero anyway: no NAT gateways, no VPCs,
# Lambdas idle, schedules disabled, buckets holding kilobytes. Snowflake-side
# the ACME_RM resource monitor is the equivalent guard.

resource "aws_budgets_budget" "monthly" {
  name         = "acme-estate-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
