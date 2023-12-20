output "application_url" {
  value = "use URL - ${aws_lb.your_load_balancer.dns_name}:8080 to access the application"
}

