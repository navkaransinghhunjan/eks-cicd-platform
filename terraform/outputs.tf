output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "logs_bucket" {
  value = aws_s3_bucket.deploy_logs.bucket
}

output "deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "tf_plan_role_arn" {
  value = aws_iam_role.tf_plan.arn
}

output "tf_apply_role_arn" {
  value = aws_iam_role.tf_apply.arn
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "admin_principal_arns_json" {
  description = "Fed back to CI as TF_VAR_admin_principal_arns"
  value       = jsonencode(var.admin_principal_arns)
}
