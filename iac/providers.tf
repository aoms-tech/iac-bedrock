provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.tags,
    )
  }

  # Let humans use arbitrary tag keys (e.g. access key ids as keys) without Terraform fighting them.
  dynamic "ignore_tags" {
    for_each = length(var.ignore_tag_key_prefixes) > 0 ? [1] : []
    content {
      key_prefixes = var.ignore_tag_key_prefixes
    }
  }
}
