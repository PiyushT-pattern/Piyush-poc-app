output "load_balancer_url" {
  value = aws_lb.app_lb.dns_name
}
