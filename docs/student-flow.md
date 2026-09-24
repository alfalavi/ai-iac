# Student Flow — PE: Ship a Mini Golden Path

This document describes the end-to-end flow a student experiences when using this template repository, from creation through lab completion.

---

## Overview

```
Template repo created
        ↓
0-pe-start-exercise.yml  →  PE-1 instructions posted
        ↓
PE-1: IaC Scaffold        →  1-pe-iac-scaffold.yml
        ↓
PE-2: CI Pipeline         →  2-pe-ci-pipeline.yml
        ↓
PE-3: Terraform Apply     →  4-pe-terraform-apply.yml
        ↓
PE-4: Open PR             →  5-pe-open-pr.yml
        ↓
PE-x: Review + Teardown   →  scoreboard-post-completion.yml
```

Each detection workflow validates the student's work, posts results as issue comments, and enables the next workflow before disabling itself.

---

## Step-by-Step Flow

### Start — Template Created

**Trigger:** First push to `main` on repo creation (not template itself)

**Workflow:** `0-pe-start-exercise.yml`

- Creates the exercise issue
- Posts PE-1 instructions with `{{login}}` and `{{full_repo_name}}` resolved
- Disables ALL other workflows
- Enables `1-pe-iac-scaffold.yml`

---

### PE-1 — IaC Scaffold

**Student actions:**
1. Adds `AWS_ROLE_ARN` to repo Settings → Secrets → Actions _(required before proceeding)_
2. Opens Codespace or local environment
3. Creates `feat/pe-golden-path` branch _(used for all steps)_
4. Runs `/iac-scaffold` in Copilot Agent mode to configure `infra/stacks/dev/main.tf` to call the [Slalom PE Lab ECS App module](https://github.com/Slalom/slalom-terraform-pe-lab-ecs-app/tree/v1.0.4)
5. Validates: `terraform init -backend=false`, `tflint`, `checkov`
6. Opens PR from `feat/pe-golden-path` → `main`

**Workflow:** `1-pe-iac-scaffold.yml`
Triggers on PR paths: `infra/**`

Checks:
- ✅ `infra/stacks/dev/main.tf` present
- ✅ Dev stack references `slalom-terraform-pe-lab-ecs-app` module
- ✅ `terraform init` + `terraform validate` passes
- ✅ `AWS_ROLE_ARN` secret is configured _(blocks early if missing — needed in PE-3)_

On pass: posts PE-2 instructions → enables `2-pe-ci-pipeline.yml`

---

### PE-2 — CI Pipeline

**Student actions:**
1. Stays on `feat/pe-golden-path` branch
2. Runs `/ci-pipeline` in Copilot Agent mode to generate reusable workflow
3. Commits and pushes to `feat/pe-golden-path` — existing PR updates automatically

**Workflow:** `2-pe-ci-pipeline.yml`
Triggers on PR paths: `.github/workflows/golden-path-ci.yml`, `.github/workflows/todo-service-ci.yml`

Checks:
- ✅ `golden-path-ci.yml` + `todo-service-ci.yml` present
- ✅ YAML syntax valid for both files
- ✅ `golden-path-ci.yml` uses `workflow_call` trigger
- ✅ `todo-service-ci.yml` calls the reusable workflow via `uses:`

On pass: posts PE-3 instructions → enables `4-pe-terraform-apply.yml`

---

### PE-3 — Terraform Apply + Build & Push

**Student actions:**
1. Stays on `feat/pe-golden-path` branch
2. Runs `/terraform-apply` in Copilot Agent mode to extend the CI workflow
   - Adds `terraform-apply` job (OIDC auth → provisions ECR, ECS, ALB)
   - Adds `build-and-push` job (Docker build → ECR push → ECS deploy)
   - Updates `todo-service-ci.yml` with `run_terraform_apply`, `build_and_push`, `aws_role_arn` inputs
3. Validates YAML, commits, pushes to `feat/pe-golden-path` — existing PR updates automatically

**Workflow:** `4-pe-terraform-apply.yml`
Triggers on PR paths: `.github/workflows/golden-path-ci.yml`

Checks:
- ✅ `golden-path-ci.yml` present + YAML valid
- ✅ `terraform-apply` job present
- ✅ `id-token: write` permission declared (OIDC)
- ✅ `aws-actions/configure-aws-credentials` used
- ✅ Role ARN passed via secret input (not hardcoded)
- ✅ `terraform apply` targets `infra/stacks/dev`
- ✅ `todo-service-ci.yml` passes `run_terraform_apply` + `AWS_ROLE_ARN`
- ✅ `service_url` captured and written to `GITHUB_STEP_SUMMARY`
- ✅ `build-and-push` job present
- ✅ `amazon-ecr-login` action used
- ✅ `docker build` + `docker push` commands present
- ✅ `aws ecs update-service --force-new-deployment` present
- ✅ `todo-service-ci.yml` passes `build_and_push`

On pass: posts PE-4 instructions → enables `5-pe-open-pr.yml`

---

### PE-4 — Open the Golden Path PR

**Student actions:** _(already on `feat/pe-golden-path` from PE-3)_
1. Runs `/prepare-pr` → generates lockfiles, runs validation, pushes commit
2. Runs `/generate-description` → writes structured PR body to `/tmp/pr-body.md`
3. Opens or updates PR with the generated description

**Workflow:** `5-pe-open-pr.yml`
Triggers on PR events: `opened`, `synchronize`, `reopened`
_(synchronize catches the `/prepare-pr` push, which fires after the workflow is enabled)_

Actions:
- Posts review checklist comment directly on the PR
- Posts `pe-x-review.md` to the exercise issue
- Disables `5-pe-open-pr.yml`

**Scoreboard:** `scoreboard-post-completion.yml`
Triggers on `5-pe-open-pr.yml` completion → posts "Lab Complete!" with timestamp and participant tag

---

### PE-x — Review

**Student actions:**
1. Merges PR → CI pipeline runs `terraform-apply` then `build-and-push` automatically
2. Finds Load Balancer URL in Actions run summary
3. Tests the live app:
   ```bash
   curl http://<alb-url>/api/health   # → {"status":"ok"}
   curl http://<alb-url>/api/todos    # → [] or list of todos
   ```
4. Completes the full journey checklist (Docker images, infrastructure, deployment, CI/CD, PR)
5. Runs `pe-terraform-destroy.yml` workflow to tear down all AWS resources
6. Posts PR link in the session Slack channel

---

## Workflow Enable/Disable Chain

| Workflow file             | Enabled by       | Disables itself after |
|---------------------------|------------------|-----------------------|
| `0-pe-start-exercise.yml` | Always on        | Never (runs once on template create) |
| `1-pe-iac-scaffold.yml`   | `0-pe-start-exercise.yml` | After posting PE-2 |
| `2-pe-ci-pipeline.yml`    | `1-pe-iac-scaffold.yml`   | After posting PE-3 |
| `4-pe-terraform-apply.yml`| `2-pe-ci-pipeline.yml`    | After posting PE-4 |
| `5-pe-open-pr.yml`        | `4-pe-terraform-apply.yml`| After posting PE-x |
| `scoreboard-post-completion.yml` | `5-pe-open-pr.yml` completion | Never |
| `pe-terraform-destroy.yml`| Manual (`workflow_dispatch`) | N/A |
