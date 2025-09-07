# Project README

# Global Infrastructure

This Terraform stack provisions all the global/shared resources required for the deployment system.  
It is responsible for supply chain security, the CI/CD integration with GitHub Actions, and the global
observability and secrets foundations.

## What This Stack Creates

- **Terraform backend resources**
  - S3 bucket for remote Terraform state (`aws_s3_bucket.tf_state`)
  - DynamoDB table for state locking (`aws_dynamodb_table.tf_lock`)
- **Encryption**
  - KMS CMK used by ECR and Secrets Manager
- **Container Registry**
  - ECR repository (`podinfo`) with scan-on-push and KMS encryption
- **Deployment Storage**
  - S3 bucket for CodeDeploy application bundles
- **CI/CD Identity**
  - GitHub Actions OIDC provider
  - IAM Role for GitHub Actions OIDC, scoped to your org/repo/branch
  - IAM Policy attached with permissions for ECR, Lambda, CodeDeploy, CloudWatch, Logs, S3, DynamoDB, and Secrets Manager
- **Secrets**
  - AWS Secrets Manager secret `/dockyard/SUPER_SECRET_TOKEN`
- **Monitoring**
  - CloudWatch alarm skeleton (see `alarms.tf`)

## Bootstrapping the Backend

Terraform cannot create the backend (S3 + DynamoDB) before it has a backend to store state in.
This is a chicken-and-egg problem. The solution is:

1. **Step 1 — Local backend apply**  
   Temporarily configure `backend.tf` to use the local backend:
   ```hcl
   terraform {
     required_version = ">= 1.9.0"
     backend "local" {}
   }
````

Then run:

```bash
terraform init
terraform apply -var-file=terraform.tfvars
```

This creates the remote state bucket and DynamoDB table defined in `main.tf`.

2. **Step 2 — Switch to S3 backend and migrate**
   Update `backend.tf` to:

   ```hcl
   terraform {
     required_version = ">= 1.9.0"
     backend "s3" {}
   }
   ```

   Re-initialize and migrate your local state to S3:

   ```bash
   terraform init \
     -backend-config="bucket=<your-tf-state-bucket>" \
     -backend-config="key=global/terraform.tfstate" \
     -backend-config="region=eu-central-1" \
     -backend-config="dynamodb_table=dockyard-tf-lock" \
     -backend-config="encrypt=true" \
     -migrate-state
   ```

After migration, all future Terraform runs will use the remote S3 backend with DynamoDB locking.

## Outputs

* `oidc_role_arn` — IAM Role ARN for GitHub Actions OIDC
* `ecr_repo_url` — ECR repository URL for Podinfo
* `deploy_bucket` — S3 bucket name for CodeDeploy bundles
* `tf_state_bucket` — S3 bucket name for Terraform state
* `tf_lock_table` — DynamoDB table name for state locking

## Logs

For full reproducibility, see [terminal_output.yml](terminal_output.yml)  
It contains complete logs of `terraform init/apply`, GitHub Actions workflows,
smoke tests, and secret rotation.

** For visual confirmation of the resources and deployments, also see the screenshots in the main directory.


### Configure GitHub Actions → AWS OIDC

After running `terraform apply` in `infra/global`, collect the outputs:

```bash
terraform output
# Example:
# deploy_bucket   = "dockyard-dev-deploy"
# ecr_repo_url    = "580073665957.dkr.ecr.eu-central-1.amazonaws.com/podinfo"
# oidc_role_arn   = "arn:aws:iam::580073665957:role/dockyard-dev-gha-oidc"
Add these values to your GitHub repository settings:

Secrets

AWS_GHA_ROLE_ARN = value of oidc_role_arn

Variables

AWS_REGION = your AWS region (e.g. eu-central-1)

ECR_REGISTRY = registry part of ecr_repo_url (e.g. 580073665957.dkr.ecr.eu-central-1.amazonaws.com)

ECR_REPO = repository name (e.g. podinfo)

S3_DEPLOY_BUCKET = value of deploy_bucket

** See the screenshots in the main directory of this repo for an example of how the GitHub secrets and variables are configured.
