resource "aws_security_group" "web_sg" {
  name        = "cloudio-sg"
  description = "Allow SSH, HTTP, HTTPS and K8s NodePorts"
  vpc_id      = module.vpc.vpc_id # חיבור ל-VPC החדש שיצרנו





  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
