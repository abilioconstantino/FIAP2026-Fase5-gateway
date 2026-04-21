# ============================================================================
# S3
# Armazenamento dos diagramas enviados para analise
# ============================================================================

resource "aws_s3_bucket" "diagramas" {
  bucket = local.bucket_diagramas_name

  tags = merge(local.common_tags, {
    Name = local.bucket_diagramas_name
  })
}

resource "aws_s3_bucket_ownership_controls" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  rule {
    id     = "abortar-multipart-incompleto"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "diagramas_ssl_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.diagramas.arn,
      "${aws_s3_bucket.diagramas.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "diagramas_ssl_only" {
  bucket = aws_s3_bucket.diagramas.id
  policy = data.aws_iam_policy_document.diagramas_ssl_only.json
}
