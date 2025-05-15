# outputs.tf
output "alb_dns_name" {
  value = aws_lb.wordpress.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.wordpress.endpoint
}