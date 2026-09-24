---
description: Configure the Terraform dev stack to deploy the todo-service using the Slalom PE Lab golden-path module
---

Read the requirements from #file:../../context/iac-requirements.md and the coding standards from #file:../copilot-instructions.md before writing any files.

Your task is to update `infra/stacks/dev/main.tf` so it calls the pre-built Slalom golden-path module to provision the todo-service infrastructure.

**Module source:**
```hcl
source = "../../modules/todo-service"
```

**Required inputs for the dev environment:**
- `environment = "dev"`
- `create_networking = true` (the module manages its own VPC and subnets)
- `alb_ingress_cidr = var.alb_ingress_cidr` (student supplies this value — use your own machine's public IP as a `/32` CIDR)
- `backend_image` and `frontend_image` should default to `""` so the module creates the ECR repos (images are pushed in Step 3)
- `desired_count = 1`, `cpu = 256`, `memory = 512`
- `log_retention_in_days = 7`
- `ecr_force_delete = true` (clean destroy at end of lab)

**Outputs to expose from the stack:**
- `service_url` → `module.todo_service.service_url`
- `cluster_name` → `module.todo_service.cluster_name`
- `backend_ecr_repository_url` → `module.todo_service.backend_ecr_repository_url`
- `frontend_ecr_repository_url` → `module.todo_service.frontend_ecr_repository_url`

**Keep the S3 backend block commented out** — it is intentionally disabled for Steps 1–2 so `terraform init` works locally without AWS credentials. It will be uncommented in Step 3. Keep the mock provider block for local validation (Steps 1–2). Do not modify `infra/modules/todo-service/` — that is the golden-path module, only the stack that calls it should be updated.
