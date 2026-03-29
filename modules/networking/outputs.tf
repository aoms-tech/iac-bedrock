output "vpc_endpoint_ids" {
  value = { for k, e in aws_vpc_endpoint.bedrock : k => e.id }
}

output "bedrock_endpoint_security_group_id" {
  value = aws_security_group.bedrock_endpoints.id
}
