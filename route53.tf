# קבלת ה-Hosted Zone הקיים
data "aws_route53_zone" "primary" {
  name         = "omerha1.shop."
  private_zone = false
}

# יצירת רשומת A שמצביעה ל-IP של הקלאסטר
# יצירת רשומת A עבור Wildcard (*.omerha1.shop)
resource "aws_route53_record" "k8s_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "*.omerha1.shop"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app_server.public_ip]
}

# יצירת רשומת A עבור Root Domain (omerha1.shop)
resource "aws_route53_record" "root_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "omerha1.shop"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app_server.public_ip]
}
