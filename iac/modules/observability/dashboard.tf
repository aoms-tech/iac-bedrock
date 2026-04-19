resource "aws_cloudwatch_dashboard" "bedrock" {
  dashboard_name = "${var.name_prefix}-bedrock"
  dashboard_body = templatefile("${path.module}/dashboard_body.tftpl", {
    project_name   = var.project_name
    environment    = var.environment
    aws_region     = var.aws_region
    log_group_name = var.log_group_name
    name_prefix    = var.name_prefix
  })
}
