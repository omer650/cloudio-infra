resource "aws_security_group" "web_sg" {
  name        = "cloudio-sg"
  description = "Allow SSH, HTTP, HTTPS and K8s NodePorts"
  vpc_id      = module.vpc.vpc_id # חיבור ל-VPC החדש שיצרנו

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
