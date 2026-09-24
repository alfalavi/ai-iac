# ============================================================
# Dev Stack — calls the Slalom PE Lab ECS App golden-path module
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — shared bucket, key is unique per student repo to avoid collisions.
  # The key is passed at runtime via -backend-config in CI (see golden-path-ci.yml).
  #
  # STEP 1-2 (local validation): keep this block commented out so `terraform init`
  # works without AWS credentials. Uncomment in Step 3 before running terraform apply.
  #
  # backend "s3" {
  #   bucket  = "pe-labs-terraform-state"
  #   region  = "us-east-2"
  #   encrypt = true
  #   # key is injected by CI: todo-service/<github-repo>/dev/terraform.tfstate
  # }
}

# ---------------------------------------------------------------
# Provider configuration
# ---------------------------------------------------------------
# MOCK MODE (Steps 1–2): The skip_* flags and placeholder credentials
# allow `terraform plan` to run without real AWS credentials.
# This is intentional for validating IaC structure in the bootcamp.
#
# REAL DEPLOY (Step 3): When running `terraform apply` via GitHub Actions
# with OIDC, remove the access_key, secret_key, and skip_* lines below.
# The AWS provider will pick up short-lived credentials automatically
# from the environment variables set by aws-actions/configure-aws-credentials.
# ---------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  #we are setting up OIDC as pre-requisite for this lab, so we can use mock credentials and skip validation when running terraform plan locally without real AWS creds. The real OIDC credentials will be automatically injected into the GitHub Actions runner environment, so no need to set them here in the provider config.
  # REMOVE these four lines in Step 3 when switching to real OIDC credentials:
  access_key                  = "mock-access-key"
  secret_key                  = "mock-secret-key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

# ---------------------------------------------------------------
# Todo Service — provisioned via the Slalom PE Lab golden-path module
# Using local module copy (mirrors github.com/Slalom/slalom-terraform-pe-lab-ecs-app v1.0.4) to avoid codespace remote repo access issues. The module creates an ECS cluster, ALB, ECR repos, and all necessary IAM roles/policies, networking, and CloudWatch log groups.
# ---------------------------------------------------------------
module "todo_service" {
  source = "../../modules/todo-service"

  environment = "dev"

  # Networking — the module creates its own VPC, subnets, and NAT gateway.
  # Set create_networking = false and supply vpc_id / subnet IDs if you want
  # to reuse an existing VPC.
  create_networking = true

  # CIDR that is allowed to reach the ALB on port 80.
  # For the lab, use the CIDR your instructor provides (never use 0.0.0.0/0).
  alb_ingress_cidr = var.alb_ingress_cidr

  # Container images — leave empty during Step 1 (ECR repos will be created
  # by the module; images are pushed in Step 3 by the build-and-push job).
  backend_image  = var.backend_image
  frontend_image = var.frontend_image

  desired_count         = 1
  cpu                   = 256
  memory                = 512
  log_retention_in_days = 7
  ecr_force_delete      = true # allow clean destroy in the lab
}

# ---------------------------------------------------------------
# Variables
# ---------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "alb_ingress_cidr" {
  description = "CIDR block allowed to reach the Application Load Balancer on port 80. Ask your instructor for the correct value."
  type        = string
}

variable "backend_image" {
  description = "Docker image URI for the backend container. Leave empty to use the ECR repo managed by this module."
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Docker image URI for the frontend nginx container. Leave empty to use the ECR repo managed by this module."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------
# Outputs — forwarded from the module for use in CI and downstream steps
# ---------------------------------------------------------------
output "service_url" {
  description = "Load Balancer URL for the deployed todo-service"
  value       = module.todo_service.service_url
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.todo_service.cluster_name
}

output "backend_ecr_repository_url" {
  description = "ECR URL for the backend image"
  value       = module.todo_service.backend_ecr_repository_url
}

output "frontend_ecr_repository_url" {
  description = "ECR URL for the frontend image"
  value       = module.todo_service.frontend_ecr_repository_url
}
