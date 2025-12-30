# S3 bucket for audio files
resource "aws_s3_bucket" "audio" {
  bucket = var.service_name
}

resource "aws_s3_bucket_public_access_block" "audio" {
  bucket = aws_s3_bucket.audio.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
