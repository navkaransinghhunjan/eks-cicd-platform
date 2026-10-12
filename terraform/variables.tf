variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "eks-cicd-platform"
}

variable "app_name" {
  description = "Application / ECR repository name"
  type        = string
  default     = "eks-demo"
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI roles via OIDC"
  type        = string
  default     = "navkaransinghhunjan/eks-cicd-platform"
}

variable "create_github_oidc_provider" {
  description = "Set false if the GitHub OIDC provider already exists in this account"
  type        = bool
  default     = true
}

variable "tf_state_bucket" {
  description = "S3 bucket holding Terraform state (created by scripts/bootstrap-state.sh)"
  type        = string
}

variable "admin_principal_arns" {
  description = "IAM users/roles given cluster-admin (e.g. your own IAM user). Explicit so CI applies don't swap the creator."
  type        = list(string)
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "cluster_version" {
  description = "EKS Kubernetes version. Stay on a version in *standard* support — extended support costs 6x."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "Multiple types improve Spot availability"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "node_capacity_type" {
  description = "SPOT (cheap, demo) or ON_DEMAND"
  type        = string
  default     = "SPOT"
}

variable "node_desired_size" {
  type    = number
  default = 2
}
