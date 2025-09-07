output "oidc_role_arn" {
  description = "IAM Role ARN for GitHub OIDC"
  value       = aws_iam_role.gha_oidc.arn
}

output "ecr_repo_url" {
  description = "ECR repository URL for Podinfo"
  value       = aws_ecr_repository.podinfo.repository_url
}

output "deploy_bucket" {
  description = "S3 bucket for CodeDeploy bundles"
  value       = aws_s3_bucket.deploy.bucket
}
# Outputs
