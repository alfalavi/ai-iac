# IaC Requirements — Todo Service Dev Stack

> **How to use this file:** This is your working context for Step 1. Review the skeleton below,
> then ask Copilot to fill in the <!-- Copilot: ... --> placeholder based on `docs/project-overview.md`
> before running `/iac-scaffold`.

---

## Service Context

<!-- Copilot: summarize what the todo-service is and how it will be hosted (from docs/project-overview.md) -->

---

## Golden-Path Module

The todo-service is provisioned using the **Slalom PE Lab ECS App module** — a pre-built, policy-compliant Terraform module maintained by the platform team. You do **not** build this module; you configure the dev stack to call it.

| Detail | Value |
|--------|-------|
| **Module source** | `github.com/Slalom/slalom-terraform-pe-lab-ecs-app//modules/todo-service` |
| **Version** | `v1.0.4` |
| **Docs** | https://github.com/Slalom/slalom-terraform-pe-lab-ecs-app/tree/v1.0.4 |

**What the module provisions:**

- VPC, public/private subnets, Internet Gateway, NAT Gateway (when `create_networking = true`)
- Two ECR repositories (`todo-service-backend`, `todo-service-frontend`) with lifecycle policies
- ECS Fargate cluster with Container Insights enabled
- ECS task definition with two containers (frontend nginx on port 80 + backend API on port 4000)
- Application Load Balancer (HTTP, port 80) with target group and health checks
- Security groups for ALB and ECS tasks
- CloudWatch log groups for both containers
- IAM task execution role and application task role

---

## Dev Stack Configuration

Your task is to write `infra/stacks/dev/main.tf` that calls the module with these values:

```hcl
module "todo_service" {
  source = "github.com/Slalom/slalom-terraform-pe-lab-ecs-app//modules/todo-service?ref=v1.0.4"

  environment       = "dev"
  create_networking = true
  alb_ingress_cidr  = var.alb_ingress_cidr  # your own public IP as a /32 CIDR

  backend_image  = var.backend_image   # defaults to "" → module creates ECR repo
  frontend_image = var.frontend_image  # defaults to "" → module creates ECR repo

  desired_count         = 1
  cpu                   = 256
  memory                = 512
  log_retention_in_days = 7
  ecr_force_delete      = true
}
```

### Module inputs reference

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `environment` | string | Yes | Must be `dev`, `staging`, or `prod` |
| `create_networking` | bool | No (default: true) | Create VPC and subnets — set `true` for lab |
| `alb_ingress_cidr` | string | Yes | CIDR allowed to reach the ALB. **Set this to your own local machine's public IP (e.g. `1.2.3.4/32`), not a Codespace IP** — the ALB security group will only allow traffic from this CIDR, so you must test the deployed load balancer from your local machine, not from a Codespace. |
| `backend_image` | string | No (default: "") | Backend ECR image URI; empty = use module-managed ECR |
| `frontend_image` | string | No (default: "") | Frontend ECR image URI; empty = use module-managed ECR |
| `desired_count` | number | No (default: 1) | Number of ECS task replicas |
| `cpu` | number | No (default: 256) | Fargate CPU units |
| `memory` | number | No (default: 512) | Fargate memory in MiB |
| `log_retention_in_days` | number | No (default: 30) | CloudWatch log retention |
| `ecr_force_delete` | bool | No (default: false) | Allow `terraform destroy` to delete ECR repos |

### Module outputs to expose

| Output | Source |
|--------|--------|
| `service_url` | `module.todo_service.service_url` |
| `cluster_name` | `module.todo_service.cluster_name` |
| `backend_ecr_repository_url` | `module.todo_service.backend_ecr_repository_url` |
| `frontend_ecr_repository_url` | `module.todo_service.frontend_ecr_repository_url` |

---

## Remote State Backend

The S3 bucket for Terraform state has been pre-created by the lab instructors — **do not create it yourself**. The `infra/stacks/dev/main.tf` terraform block is already configured with:

```hcl
backend "s3" {
  bucket  = "pe-labs-terraform-state"
  region  = "us-east-2"
  encrypt = true
  # key is injected by CI: todo-service/<github-repo>/dev/terraform.tfstate
}
```

The `key` is intentionally omitted — it is passed at `terraform init` time by CI to prevent state collisions between students:

```bash
terraform init -backend-config="key=todo-service/${{ github.repository }}/dev/terraform.tfstate"
```

For local validation (Steps 1–2), use `terraform init -backend=false` to skip the S3 backend.

---

## Acceptance Criteria

| ID | Requirement |
|----|-------------|
| FR-1.1 | `infra/stacks/dev/main.tf` calls the `slalom-terraform-pe-lab-ecs-app` module at `v1.0.4` |
| FR-1.2 | Stack sets `environment`, `create_networking`, and `alb_ingress_cidr` |
| FR-1.3 | `terraform validate` and `tflint` pass with no errors |
| FR-1.4 | `checkov` reports 0 HIGH severity findings on the stack |
| FR-1.5 | Stack outputs `service_url` and `cluster_name` from the module |
| FR-1.6 | `AWS_ROLE_ARN` secret is configured in repo settings |
