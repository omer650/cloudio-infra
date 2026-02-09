terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "omer-cloudio-tf-state"  
    key            = "cloudio/terraform.tfstate"
    region         = "us-east-1"              
    dynamodb_table = "terraform-state-lock"  
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1" 
}

# --- SSH Key Pair ---
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "cloudio-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "${path.module}/cloudio-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0400"
}

# --- Security Group ---
resource "aws_security_group" "web_sg" {
  name        = "cloudio-sg"
  description = "Allow SSH, HTTP, HTTPS and K8s NodePorts"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s NodePorts (General Range)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- התיקון עבור ה-Frontend ---
  # Explicitly allow Frontend NodePort
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 Instance ---
resource "aws_instance" "app_server" {
  ami                  = "ami-0694d931cee176e7d" 
  instance_type        = "t3.medium"             
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  key_name               = aws_key_pair.kp.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "Cloudio-Server"
  }
}

# --- IAM Role for EC2 ---
resource "aws_iam_role" "ec2_role" {
  name = "cloudio_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# --- Attach ECR ReadOnly Policy ---
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- Instance Profile ---
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "cloudio_ec2_profile"
  role = aws_iam_role.ec2_role.name
}

# --- S3 Bucket ---
resource "aws_s3_bucket" "cloudio_storage" {
  bucket_prefix = "cloudio-data-"
  force_destroy = true

  tags = {
    Name = "Cloudio Storage"
  }
}

# --- ECR Repositories ---
resource "aws_ecr_repository" "cloudio_backend" {
  name                 = "cloudio-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cloudio_frontend" {
  name                 = "cloudio-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- Outputs ---
output "server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ssh_command" {
  value = "ssh -i cloudio-key.pem ubuntu@${aws_instance.app_server.public_ip}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.cloudio_backend.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.cloudio_frontend.repository_url
}