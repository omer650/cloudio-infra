output "backend_fqdn" {
  value       = aws_route53_record.k8s_record.fqdn
  description = "The FQDN of the backend service"
}
