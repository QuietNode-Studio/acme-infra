# ── Pumpkin's audit export sinks ─────────────────────────────────────────────
# Append-only by convention (Pumpkin's runtime never deletes audit events);
# versioning gives tamper-evidence on the bucket side.

resource "aws_s3_bucket" "pumpkin_audit" {
  bucket        = "acme-pumpkin-audit-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "pumpkin_audit" {
  bucket = aws_s3_bucket.pumpkin_audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "pumpkin_audit" {
  bucket                  = aws_s3_bucket.pumpkin_audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pumpkin_audit" {
  bucket = aws_s3_bucket.pumpkin_audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_log_group" "pumpkin_audit" {
  name              = "/acme/pumpkin/audit"
  retention_in_days = 30
}
