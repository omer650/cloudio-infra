# קבלת ה-Hosted Zone הקיים
data "aws_route53_zone" "primary" {
  name         = "omerha1.shop."
  private_zone = false
}

# יצירת רשומת A שמצביעה ל-IP של הקלאסטר
resource "aws_route53_record" "k8s_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app_server.public_ip]
}
