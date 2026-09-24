# CI/CD Requirements — Golden Path Reusable Workflow

> **How to use this file:** This is your working context for Step 2. Review the skeleton below,
> then ask Copilot to fill in any gaps based on `docs/project-overview.md` and
> `docs/functional-requirements.md` before running `/ci-pipeline`.

---

## Service Context

<!-- Copilot: summarize the tech stack (Node.js version, test framework, IaC tool) that CI must validate (from docs/project-overview.md) -->

## Reusable Workflow (`golden-path-ci.yml`)

**Trigger:** `on: workflow_call` with inputs:

- `node_version` (string, default `"20"`)
- `terraform_version` (string, default `"1.7.0"`)
- `run_terraform_plan` (boolean, default `false`)

**Jobs:**

1. `lint` — ESLint on `packages/backend` and `packages/frontend`
2. `test` — Jest with coverage; fail if < 80%
3. `security-scan` (if `run_terraform_plan`) — checkov against `infra/`
4. `terraform-plan` (if `run_terraform_plan`) — validate and plan against `infra/stacks/dev`:
   - **REQUIRED**: Run `terraform init -backend=false` (NOT plain `terraform init`). This skips the S3 backend and avoids needing AWS credentials on PRs. Using plain `terraform init` will fail with a backend error.
   - Then run `terraform plan -var="vpc_id=vpc-mock" -var='private_subnet_ids=["subnet-mock"]' -var='public_subnet_ids=["subnet-mock"]'`
5. `docker-build` — build both Docker images on every PR to validate the Dockerfiles:
   - No push, no AWS credentials required
   - `docker build -f packages/backend/Dockerfile packages/backend/`
   - `docker build -f packages/frontend/Dockerfile packages/frontend/`
   - Use `needs: [lint, test]`

**Standards:**

- `permissions: contents: read, pull-requests: write` at workflow level
- Pin all actions to SHA (use v4 equivalents)
- Add `$GITHUB_STEP_SUMMARY` output for test coverage and plan results
- **REQUIRED**: Do NOT set `cache: 'npm'` on `actions/setup-node` — this repo has no lock files and the job will fail with a "lock file not found" error.

## Caller Workflow (`todo-service-ci.yml`)

- Triggers: `push` to `main`, `pull_request`
- Calls `golden-path-ci.yml` with `run_terraform_plan: true` and `node_version: "20"`

## Acceptance Criteria (from docs/functional-requirements.md)

| ID | Requirement |
|---|---|
| FR-2.1 | Reusable workflow at `.github/workflows/golden-path-ci.yml` uses `on: workflow_call` |
| FR-2.2 | Reusable workflow includes jobs: `lint`, `test`, `security-scan`, `terraform-plan` |
| FR-2.3 | `test` job fails if Jest coverage falls below 80% |
| FR-2.4 | Caller workflow at `.github/workflows/todo-service-ci.yml` adopts the reusable workflow |
| FR-2.5 | All workflows use `permissions:` blocks with least privilege |
| FR-2.6 | CI runs on `push` to `main` and on all pull requests |
