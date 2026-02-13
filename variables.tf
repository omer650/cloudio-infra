variable "cluster_ip" {
  description = "The public IP of the Kubernetes cluster (EC2 instance)"
  type        = string
  default     = "34.247.141.77"
}

variable "domain_name" {
  description = "The domain name for the application"
  type        = string
  default     = "k8s.omerha1.shop"
}

variable "zone_id" {
  description = "The Route53 Hosted Zone ID for omerha1.shop"
  type        = string
  default     = "" # המשתמש לא סיפק, ננסה למצוא אותו או נבקש אותו אם ה-data source לא יעבוד
}
