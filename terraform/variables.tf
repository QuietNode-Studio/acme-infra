variable "region" {
  description = "Home region for the estate. Must match AWS_REGION in Pumpkin's .env."
  type        = string
  default     = "us-east-2"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget hard line for the whole account sandbox."
  type        = string
  default     = "50"
}

variable "budget_email" {
  description = "Where budget breach notifications go."
  type        = string
  default     = "prashanthsirusala2209@gmail.com"
}

variable "allowed_cidrs" {
  description = <<-EOT
    CIDRs permitted to reach anything network-exposed. The estate currently
    exposes NOTHING (Lambdas are not in a VPC, buckets are private, no NAT, no
    endpoints) — this variable exists as the house rule: any future
    network-exposed resource MUST gate its ingress on this list. Empty = closed.
  EOT
  type        = list(string)
  default     = []
}

variable "runtime_trusted_principal_arns" {
  description = "Principals allowed to assume acme-pumpkin-runtime (Pumpkin's runtime identity). Empty = the account root (local docker-compose deployments running on operator credentials)."
  type        = list(string)
  default     = []
}
