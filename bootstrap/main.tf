# Bootstrap stack — applied ONCE from an operator laptop with human credentials.
# Everything else in this repo is applied ONLY by CI (GitHub Actions OIDC).
#
# Creates the three things CI cannot create for itself:
#   1. the Terraform state bucket for the main stack
#   2. the GitHub OIDC identity provider
#   3. the acme-ci-deploy role GitHub Actions assumes (no long-lived keys anywhere)
#
# State for THIS stack stays local and gitignored (it holds nothing sensitive;
# re-import is trivial if lost).

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      project    = "acme-estate"
      env        = "dev"
      managed_by = "terraform-bootstrap"
      repo       = "QuietNode-Studio/acme-infra"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo       = "QuietNode-Studio/acme-infra"
  # This org issues immutable-ID subject claims (org@id/repo@id). Pinning the
  # ids is deliberate: the trust survives (and is immune to) renames. The
  # name-based patterns are kept for portability if the org ever reverts to
  # classic sub claims. Diagnosed 2026-07-21 via a temporary claims workflow.
  repo_with_ids = "QuietNode-Studio@263530096/acme-infra@1307155172"
}

# ── 1. Terraform state bucket (native S3 lockfile — no DynamoDB needed) ───────
resource "aws_s3_bucket" "tfstate" {
  bucket = "acme-tfstate-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── 2. GitHub OIDC provider ──────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ── 3. CI deploy role — the ONLY principal that applies the main stack ───────
resource "aws_iam_role" "ci_deploy" {
  name = "acme-ci-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubActionsOIDC"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # plan on PRs, apply on main — this repo only
          "token.actions.githubusercontent.com:sub" = [
            "repo:${local.repo}:ref:refs/heads/main",
            "repo:${local.repo}:pull_request",
            "repo:${local.repo_with_ids}:ref:refs/heads/main",
            "repo:${local.repo_with_ids}:pull_request",
          ]
        }
      }
    }]
  })
}

# Bounded deploy permissions: every mutable resource is name-prefixed acme-*.
# This is deliberately NOT AdministratorAccess — CI can manage the acme estate
# and nothing else in the account.
resource "aws_iam_role_policy" "ci_deploy" {
  name = "acme-estate-deploy"
  role = aws_iam_role.ci_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TfStateRW"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
      },
      {
        Sid      = "S3Estate"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = ["arn:aws:s3:::acme-*", "arn:aws:s3:::acme-*/*"]
      },
      {
        Sid      = "LambdaEstate"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = ["arn:aws:lambda:us-east-2:${local.account_id}:function:acme-*"]
      },
      {
        Sid    = "LogsEstate"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:us-east-2:${local.account_id}:log-group:/acme/*",
          "arn:aws:logs:us-east-2:${local.account_id}:log-group:/aws/lambda/acme-*",
        ]
      },
      {
        Sid      = "LogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid      = "EventsEstate"
        Effect   = "Allow"
        Action   = ["events:*"]
        Resource = ["arn:aws:events:us-east-2:${local.account_id}:rule/acme-*"]
      },
      {
        Sid    = "IamEstateRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole", "iam:ListRoleTags",
          "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:TagRole", "iam:UntagRole", "iam:PassRole",
        ]
        Resource = ["arn:aws:iam::${local.account_id}:role/acme-*"]
      },
      {
        Sid      = "SecretsEstate"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = ["arn:aws:secretsmanager:us-east-2:${local.account_id}:secret:acme/*"]
      },
      {
        Sid    = "Budgets"
        Effect = "Allow"
        Action = [
          "budgets:ViewBudget", "budgets:ModifyBudget",
          "budgets:TagResource", "budgets:UntagResource", "budgets:ListTagsForResource",
        ]
        Resource = ["arn:aws:budgets::${local.account_id}:budget/acme-*"]
      },
      {
        Sid      = "ReadOnlyContext"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity", "s3:ListAllMyBuckets"]
        Resource = "*"
      },
    ]
  })
}

output "ci_deploy_role_arn" {
  value = aws_iam_role.ci_deploy.arn
}

output "tfstate_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}
