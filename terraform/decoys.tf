# ── PROD DECOYS — the tripwire, not the pipeline ─────────────────────────────
# These exist so scenario S4 can prove denials. No test, no scenario script,
# no grant, and no ticket resolution may EVER touch them. They are tagged
# env=prod and named acme-prod-*; Pumpkin's grant validator must refuse any
# ARN matching them, and its policy layer must refuse before the first call.
# The Lambda has no trigger, an execution role that can only write its own
# logs, and reuses the same source zip (contents are irrelevant — its only job
# is to be denied).

resource "aws_s3_bucket" "prod_raw_decoy" {
  bucket        = "acme-prod-raw-${local.account_id}"
  force_destroy = true

  tags = {
    env    = "prod"
    decoy  = "true"
    notice = "denial-target-do-not-touch"
  }
}

resource "aws_s3_bucket_public_access_block" "prod_raw_decoy" {
  bucket                  = aws_s3_bucket.prod_raw_decoy.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lambda_function" "prod_transform_decoy" {
  function_name = "acme-prod-orders-transform"
  role          = aws_iam_role.prod_decoy_exec.arn
  runtime       = "python3.12"
  handler       = "orders_transform.handler"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.orders_transform.output_path
  source_code_hash = data.archive_file.orders_transform.output_base64sha256

  environment {
    variables = {
      RAW_BUCKET     = aws_s3_bucket.prod_raw_decoy.bucket
      CURATED_BUCKET = aws_s3_bucket.prod_raw_decoy.bucket
      INPUT_PREFIX   = "orders/"
      OUTPUT_PREFIX  = "orders/"
      COLUMN_MAP     = "{}"
    }
  }

  tags = {
    env    = "prod"
    decoy  = "true"
    notice = "denial-target-do-not-touch"
  }
}

resource "aws_iam_role" "prod_decoy_exec" {
  name = "acme-prod-orders-transform-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    env   = "prod"
    decoy = "true"
  }
}

resource "aws_iam_role_policy" "prod_decoy_exec" {
  name = "logs-only"
  role = aws_iam_role.prod_decoy_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "Logs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/acme-prod-orders-transform*"]
    }]
  })
}
