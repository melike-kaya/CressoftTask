variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "github_owner" {
  description = "GitHub org or user"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to deploy"
  type        = string
}

variable "tf_state_bucket_name" {
  type        = string
  description = "Terraform remote state S3 bucket (globally unique)"
}


# Variables
