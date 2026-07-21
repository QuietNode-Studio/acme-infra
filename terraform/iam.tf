# ── Pumpkin's employment contract, in IAM ────────────────────────────────────
# Two roles, per the two-tier model in the agent repo's required-iam.md:
#
#   acme-pumpkin-runtime   — Pumpkin's OWN identity (RUNTIME_PRINCIPAL_ARN).
#                            Holds nothing but the right to assume the standing
#                            metadata role. Every temporary grant Pumpkin
#                            authors under grants/ must trust EXACTLY this ARN.
#   acme-pumpkin-metadata  — the STANDING role: metadata-only discovery.
#                            Describe*/List*/Get* on catalogs and job metadata.
#                            Zero s3:GetObject. Zero secretsmanager. Zero
#                            lambda:InvokeFunction — DELIBERATE: earning that
#                            one action through a grants/ PR is scenario S1.

resource "aws_iam_role" "pumpkin_runtime" {
  name        = "acme-pumpkin-runtime"
  description = "Pumpkin's runtime identity. Temporary grants trust this ARN and nothing else."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RuntimeHost"
      Effect = "Allow"
      Principal = {
        AWS = length(var.runtime_trusted_principal_arns) > 0 ? var.runtime_trusted_principal_arns : ["arn:aws:iam::${local.account_id}:root"]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# The runtime role itself may do exactly one thing: put on its standing badge.
resource "aws_iam_role_policy" "pumpkin_runtime" {
  name = "assume-standing-metadata-only"
  role = aws_iam_role.pumpkin_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeStandingRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.pumpkin_metadata.arn
    }]
  })
}

resource "aws_iam_role" "pumpkin_metadata" {
  name                 = "acme-pumpkin-metadata"
  description          = "Standing metadata-only discovery for Pumpkin. Anything more is earned via grants/ PRs."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PumpkinRuntimeOnly"
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.pumpkin_runtime.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "pumpkin_metadata" {
  name = "metadata-only-discovery"
  role = aws_iam_role.pumpkin_metadata.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MetadataOnlyDiscovery"
        Effect = "Allow"
        Action = [
          # object-store LAYOUT, never contents
          "s3:ListAllMyBuckets", "s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketTagging",
          # catalogs & jobs
          "glue:GetDatabases", "glue:GetTables", "glue:GetTable", "glue:GetPartitions",
          "glue:GetJobs", "glue:GetJob", "glue:GetJobRuns", "glue:GetJobRun", "glue:GetCrawlers",
          "athena:ListWorkGroups", "athena:GetWorkGroup", "athena:ListDataCatalogs",
          # pipeline-step metadata (configuration, not code, not invoke)
          "lambda:ListFunctions", "lambda:GetFunctionConfiguration", "lambda:ListEventSourceMappings",
          "lambda:GetPolicy", "lambda:ListTags",
          "states:ListStateMachines", "states:DescribeStateMachine", "states:ListExecutions",
          "states:DescribeExecution",
          "events:ListRules", "events:DescribeRule", "events:ListTargetsByRule",
          # run telemetry
          "cloudwatch:ListMetrics", "cloudwatch:GetMetricData",
          "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:FilterLogEvents",
          "rds:DescribeDBInstances", "rds:DescribeDBClusters",
          "sts:GetCallerIdentity",
        ]
        Resource = "*"
      },
      {
        # Belt AND suspenders: the allow list above never grants these, and this
        # deny makes the contract explicit and un-expandable by accident.
        Sid    = "HardDeny"
        Effect = "Deny"
        Action = [
          "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:DeleteBucket",
          "lambda:InvokeFunction", "lambda:GetFunction", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "secretsmanager:*", "ssm:GetParameter", "ssm:GetParameters", "kms:Decrypt",
          "iam:*",
          "glue:UpdateJob", "glue:StartJobRun", "glue:DeleteJob",
          "states:StartExecution", "events:PutRule", "events:PutTargets",
        ]
        Resource = "*"
      },
    ]
  })
}
