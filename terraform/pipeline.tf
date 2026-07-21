# ── The dev batch pipeline Pumpkin is employed to keep healthy ───────────────
# s3://acme-dev-raw-*/orders/ ── acme-dev-orders-transform ──> s3://acme-dev-curated-*/orders/
# EventBridge hourly schedule exists but ships DISABLED — scenario runs invoke
# deliberately; nothing burns money in the background.

resource "aws_s3_bucket" "dev_raw" {
  bucket        = "acme-dev-raw-${local.account_id}"
  force_destroy = true # sandbox: terraform destroy must be clean
}

resource "aws_s3_bucket" "dev_curated" {
  bucket        = "acme-dev-curated-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "dev_raw" {
  bucket                  = aws_s3_bucket.dev_raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "dev_curated" {
  bucket                  = aws_s3_bucket.dev_curated.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deterministic input the transform consumes (also the S1 scenario fixture).
resource "aws_s3_object" "sample_orders" {
  bucket       = aws_s3_bucket.dev_raw.id
  key          = "orders/orders_2026-07.csv"
  source       = "${path.module}/sample_data/orders_2026-07.csv"
  source_hash  = filemd5("${path.module}/sample_data/orders_2026-07.csv")
  content_type = "text/csv"
}

data "archive_file" "orders_transform" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/orders_transform.py"
  output_path = "${path.module}/.build/orders_transform.zip"
}

resource "aws_lambda_function" "dev_orders_transform" {
  function_name = "acme-dev-orders-transform"
  role          = aws_iam_role.dev_transform_exec.arn
  runtime       = "python3.12"
  handler       = "orders_transform.handler"
  timeout       = 120
  memory_size   = 256

  filename = data.archive_file.orders_transform.output_path
  # Hash the SOURCE, not the zip: archive_file zips embed OS file modes, so
  # zip hashes differ between CI (linux) and operator machines (windows) even
  # for identical sources. With eol=lf pinned in .gitattributes this hash is
  # machine-independent and plans stay clean everywhere.
  source_code_hash = filebase64sha256("${path.module}/lambda_src/orders_transform.py")

  environment {
    variables = {
      RAW_BUCKET     = aws_s3_bucket.dev_raw.bucket
      CURATED_BUCKET = aws_s3_bucket.dev_curated.bucket
      INPUT_PREFIX   = "orders/"
      OUTPUT_PREFIX  = "orders/"
      # Logical field -> CSV header. Scenario S1 arms by corrupting this map
      # out-of-band (console-style config drift); terraform apply restores it,
      # which is exactly what "reset to green" means.
      COLUMN_MAP = jsonencode({
        order_id     = "order_id"
        customer_id  = "customer_id"
        order_date   = "order_date"
        status       = "status"
        amount_cents = "amount_cents"
        currency     = "currency"
      })
    }
  }

  lifecycle {
    # S1 arms by mutating env out-of-band; plan must stay clean while armed so
    # CI does not silently disarm a live scenario. reset.py re-applies config.
    ignore_changes = [environment]
  }
}

resource "aws_cloudwatch_log_group" "dev_orders_transform" {
  name              = "/aws/lambda/${aws_lambda_function.dev_orders_transform.function_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "dev_transform_exec" {
  name = "acme-dev-orders-transform-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dev_transform_exec" {
  name = "pipeline-runtime"
  role = aws_iam_role.dev_transform_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadRawOrders"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.dev_raw.arn}/orders/*"]
      },
      {
        Sid      = "ListRaw"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.dev_raw.arn]
      },
      {
        Sid      = "WriteCurated"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.dev_curated.arn}/orders/*"]
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/acme-dev-orders-transform*"]
      },
    ]
  })
}

# Hourly schedule — DISABLED by default, forever, unless a human flips it.
resource "aws_cloudwatch_event_rule" "dev_orders_hourly" {
  name                = "acme-dev-orders-hourly"
  description         = "Hourly batch trigger for the dev orders transform (ships disabled)"
  schedule_expression = "rate(1 hour)"
  state               = "DISABLED"
}

resource "aws_cloudwatch_event_target" "dev_orders_hourly" {
  rule = aws_cloudwatch_event_rule.dev_orders_hourly.name
  arn  = aws_lambda_function.dev_orders_transform.arn
}

resource "aws_lambda_permission" "dev_orders_hourly" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dev_orders_transform.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dev_orders_hourly.arn
}
