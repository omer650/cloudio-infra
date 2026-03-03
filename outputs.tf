output "server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "backend_fqdn" {
  value = aws_route53_record.root.fqdn
}