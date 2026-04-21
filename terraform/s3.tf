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

resource "aws_s3_bucket_public_access_block" "diagramas" {
  bucket = aws_s3_bucket.diagramas.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

