locals {
  name = "dockyard-${var.environment}"
}

# KMS CMK
resource "aws_kms_key" "cmk" {
  description             = "${local.name} CMK"
  deletion_window_in_days = 7
}

# ECR
resource "aws_ecr_repository" "podinfo" {
  name = "podinfo"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.cmk.arn
  }
}

# S3 bucket for CodeDeploy bundles
resource "aws_s3_bucket" "deploy" {
  bucket        = "${local.name}-deploy"
  force_destroy = true
}

resource "aws_s3_bucket" "tf_state" {
  bucket        = var.tf_state_bucket_name
  force_destroy = false

  # İstersen aşağıyı açabilirsin:
  # versioning {
  #   enabled = true
  # }
  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  #   }
  # }

  lifecycle {
    prevent_destroy = true
  }
}

# DynamoDB for TF state lock (if not pre-created)
resource "aws_dynamodb_table" "tf_lock" {
  name         = "dockyard-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM role for GitHub Actions OIDC
resource "aws_iam_role" "gha_oidc" {
  name = "${local.name}-gha-oidc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
          ]
        }
      }
    }]
  })
}

# Policy for GitHub Actions
resource "aws_iam_policy" "gha_policy" {
  name   = "${local.name}-gha-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:*",
          "lambda:*",
          "codedeploy:*",
          "cloudwatch:*",
          "logs:*",
          "s3:*",
          "dynamodb:*",
          "secretsmanager:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.gha_oidc.name
  policy_arn = aws_iam_policy.gha_policy.arn
}

# Secrets Manager secret
resource "aws_secretsmanager_secret" "super_secret" {
  name       = "/dockyard/SUPER_SECRET_TOKEN"
  kms_key_id = aws_kms_key.cmk.arn
}

