terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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

provider "kubernetes" {
  config_path = "~/.kube/config"
  insecure    = true
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    insecure    = true
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  version    = "5.46.7" # Stable version
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "monitoring"
  create_namespace = true
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  namespace  = "logging"
  create_namespace = true
  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name  = "minimumMasterNodes"
    value = "1"
  }
}


# --- EC2 Instance ---
resource "aws_instance" "app_server" {
  ami           = "ami-0694d931cee176e7d"
  instance_type = "t3.medium"
  subnet_id     = module.vpc.public_subnets[0]
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = "cloudio-key"

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | sh -
    sleep 45
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    kubectl create namespace cloudio --dry-run=client -o yaml | kubectl apply -f -
    TOKEN=$(aws ecr get-login-password --region eu-west-1)
    kubectl create secret docker-registry ecr-registry-helper \
      --docker-server=102586998566.dkr.ecr.eu-west-1.amazonaws.com \
      --docker-username=AWS \
      --docker-password="$TOKEN" \
      --namespace=cloudio --dry-run=client -o yaml | kubectl apply -f -
  EOF

  tags = { Name = "Cloudio-Server" }
}

# --- Security Group Rules (מקובעים למניעת מחיקה) ---

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "allow_k3s_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["77.137.77.12/32"] 
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "allow_frontend_nodeport" {
  type              = "ingress"
  from_port         = 30081
  to_port           = 30081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "allow_backend_nodeport" {
  type              = "ingress"
  from_port         = 30091
  to_port           = 30091
  protocol          = "tcp"
  cidr_blocks       = ["77.137.77.12/32"]
  security_group_id = aws_security_group.web_sg.id
}

# --- Kubernetes Resources ---

resource "kubernetes_secret" "db_secret" {
  metadata {
    name      = "db-secret"
    namespace = "cloudio"
  }
  data = {
    username = "postgres"
    password = "password123"
    database = "cloudio_db"
  }
  type = "Opaque"
}

resource "kubernetes_service" "cloudio_backend_svc" {
  metadata {
    name      = "cloudio-backend-service"
    namespace = "cloudio"
  }
  spec {
    selector = { app = "cloudio-backend" }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "cloudio_ingress" {
  metadata {
    name      = "cloudio-ingress"
    namespace = "cloudio"
    annotations = { "kubernetes.io/ingress.class" = "traefik" }
  }
  spec {
    rule {
      host = "k8s.omerha1.shop"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.cloudio_backend_svc.metadata[0].name
              port { number = 8080 }
            }
          }
        }
      }
    }
    rule {
      host = "prometheus.omerha1.shop"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-server"
              port { number = 80 }
            }
          }
        }
      }
    }
    rule {
      host = "argo.omerha1.shop"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}

# --- ECR Repositories ---
resource "aws_ecr_repository" "cloudio_backend" {
  name = "cloudio-backend"
  force_delete = true
}

resource "aws_ecr_repository" "cloudio_frontend" {
  name = "cloudio-frontend"
  force_delete = true
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}
