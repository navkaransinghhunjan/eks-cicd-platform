# Versioned bucket = tamper-evident history of install.log
resource "aws_s3_bucket" "deploy_logs" {
  bucket        = "${var.project}-deploy-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "deploy_logs" {
  bucket = aws_s3_bucket.deploy_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deploy_logs" {
  bucket = aws_s3_bucket.deploy_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "deploy_logs" {
  bucket                  = aws_s3_bucket.deploy_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "deploy_logs" {
  bucket = aws_s3_bucket.deploy_logs.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
