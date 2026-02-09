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
  ami                  = "ami-0694d931cee176e7d" 
  instance_type        = "t3.medium"             
  
  # שימוש ב-Subnet הציבורי מהמדול החדש
  subnet_id            = module.vpc.public_subnets[0]
  
  # שימוש ב-Security Group מהקובץ החדש
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  key_name             = "cloudio-key" # וודא שהמפתח קיים ב-AWS

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "Cloudio-Server"
  }
}

# --- ECR Repositories ---
resource "aws_ecr_repository" "cloudio_backend" {
  name                 = "cloudio-backend"
  force_delete         = true
}

resource "aws_ecr_repository" "cloudio_frontend" {
  name                 = "cloudio-frontend"
  force_delete         = true
}
