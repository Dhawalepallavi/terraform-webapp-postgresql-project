# Output DNS name of the web application
output "web_app_dns" {
  value = aws_instance.webapp_instance.public_dns
}



