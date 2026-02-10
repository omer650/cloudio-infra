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

# --- EC2 Instance ---
resource "aws_instance" "app_server" {
  ami           = "ami-0694d931cee176e7d"
  instance_type = "t3.medium"

  # שייוך ל-Subnet ירוק/צהוב
  subnet_id = module.vpc.public_subnets[0]

  # שייוך ל-Security Group
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  key_name             = "cloudio-key" # AWS בא-מייק חתפמהש אדוו

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
              #!/bin/bash
              # 1. הגדרת הרשאות ל-kubectl
              sudo chmod 644 /etc/rancher/k3s/k3s.yaml
              export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

              # 2. המתנה קלה לעליית ה-K3s
              sleep 45

              # 3. חידוש טוקן ECR ויצירת הסוד ב-Kubernetes
              TOKEN=$(aws ecr get-login-password --region eu-west-1)
              kubectl delete secret ecr-registry-helper -n cloudio --ignore-not-found
              kubectl create secret docker-registry ecr-registry-helper \
                --docker-server=102586998566.dkr.ecr.eu-west-1.amazonaws.com \
                --docker-username=AWS \
                --docker-password="$TOKEN" \
                --namespace=cloudio

              # 4. רענון הפודים כדי שישתמשו בטוקן החדש
              kubectl rollout restart deployment -n cloudio
              EOF

  tags = {
    Name = "Cloudio-Server"
  }
}

# --- ECR Repositories ---
resource "aws_ecr_repository" "cloudio_backend" {
  name         = "cloudio-backend"
  force_delete = true
}

resource "aws_ecr_repository" "cloudio_frontend" {
  name         = "cloudio-frontend"
  force_delete = true
}
