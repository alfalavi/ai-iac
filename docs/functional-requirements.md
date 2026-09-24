# Functional Requirements — Todo Service Golden Path

## Golden Path Requirements

### FR-1: Infrastructure as Code

| ID     | Requirement                                                                                                                               |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| FR-1.1 | `infra/stacks/dev/main.tf` must call the Slalom PE Lab module at `github.com/Slalom/slalom-terraform-pe-lab-ecs-app//modules/todo-service?ref=v1.0.4` |
| FR-1.2 | The stack must set `environment = "dev"`, `create_networking = true`, and `alb_ingress_cidr`                                              |
| FR-1.3 | The stack must output `service_url`, `cluster_name`, `backend_ecr_repository_url`, `frontend_ecr_repository_url` from the module         |
| FR-1.4 | `terraform validate` and `tflint` must pass with no errors on `infra/stacks/dev/`                                                        |
| FR-1.5 | `checkov` must report 0 HIGH severity findings on `infra/stacks/dev/`                                                                    |
| FR-1.6 | `AWS_ROLE_ARN` secret must be configured in repository settings                                                                           |

### FR-2: CI/CD Pipeline

| ID     | Requirement                                                                                                                 |
| ------ | --------------------------------------------------------------------------------------------------------------------------- |
| FR-2.1 | A reusable workflow at `.github/workflows/golden-path-ci.yml` must use `on: workflow_call`                                  |
| FR-2.2 | The reusable workflow must include jobs: `lint`, `test`, `security-scan`, `terraform-plan`, `build-and-push`                |
| FR-2.3 | The `test` job must fail if Jest coverage falls below 80%                                                                   |
| FR-2.4 | A caller workflow at `.github/workflows/todo-service-ci.yml` must adopt the reusable workflow                               |
| FR-2.5 | All workflows must use `permissions:` blocks with least privilege                                                           |
| FR-2.6 | CI must run on `push` to `main` and on all pull requests                                                                    |
| FR-2.7 | The `build-and-push` job must build both `packages/backend/Dockerfile` and `packages/frontend/Dockerfile` and push to ECR  |
| FR-2.8 | `build-and-push` must authenticate to AWS via OIDC and only run on push to `main`                                          |

### FR-3: Terraform Apply with OIDC

| ID     | Requirement                                                                                                                              |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| FR-3.1 | `golden-path-ci.yml` must contain a `terraform-apply` job controlled by a `run_terraform_apply` boolean input (default: `false`)        |
| FR-3.2 | The job must declare `id-token: write` permission and use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`               |
| FR-3.3 | The role ARN must be passed as a secret input (`aws_role_arn`) — never hardcoded in the workflow file                                    |
| FR-3.4 | The job must run `terraform apply` against `infra/stacks/dev` and only execute on push to `main` (not on pull requests)                 |
| FR-3.5 | `todo-service-ci.yml` must pass `run_terraform_apply: true` and `secrets.AWS_ROLE_ARN` to the reusable workflow on push to `main`       |

### FR-4: Pull Request

| ID     | Requirement                                                                      |
| ------ | -------------------------------------------------------------------------------- |
| FR-4.1 | The PR description must include a "what changed / why" narrative                 |
| FR-4.2 | The PR description must include a "How to Adopt" quickstart for new teams        |
| FR-4.3 | The PR description must include evidence: terraform plan output, checkov summary |

## Todo Service API Requirements (Existing)

The backend already implements these endpoints. Do not modify them unless needed for the golden path.

| Method | Path           | Description                       |
| ------ | -------------- | --------------------------------- |
| GET    | /api/todos     | List all todos                    |
| POST   | /api/todos     | Create a new todo                 |
| PUT    | /api/todos/:id | Update a todo                     |
| DELETE | /api/todos/:id | Delete a todo                     |
| GET    | /health        | Health check for ALB target group |
