# Session PE — Ship a Mini Golden Path: Tester Overview

This document is for testers validating the lab before wider release. It covers prerequisites, the full student flow, how each detection workflow triggers and what it checks, and known edge cases.

---

## Prerequisites

### Repository Setup

- This is a **GitHub template repository**. Each student creates their own copy via "Use this template".
- The first push to `main` triggers `0-pe-start-exercise.yml`, which bootstraps the exercise (creates Issue #1, enables only the first detection workflow, disables all others).

### Required Repository Secret

Students must add **`AWS_ROLE_ARN`** as a repository secret before starting Step 3. The IAM role must have an OIDC trust policy scoped to the student's repo (`owner/repo`). Without this, Step 3's `terraform-apply` job will fail and the detection check will not pass.

### Required Tooling (Codespace or local)

| Tool | Version | Purpose |
|---|---|---|
| Terraform | 1.5+ | IaC validation and apply |
| tflint | v0.50.3 (pinned) | Terraform linting |
| checkov | latest | Security policy checks |
| Node.js | 20 | Backend + frontend |
| GitHub CLI (`gh`) | latest | PR and workflow operations |
| Docker | latest | Image builds |

### AWS Infrastructure (pre-created by instructor)

- **S3 bucket:** `pe-labs-terraform-state` in `us-east-2` — used for remote Terraform state in Step 3
- **IAM role:** an OIDC-enabled role per student (or shared) — ARN is what goes into `AWS_ROLE_ARN`

---

## Repository Structure

```
.
├── .github/
│   ├── prompts/                  ← Copilot slash-command prompts
│   │   ├── iac-scaffold.prompt.md
│   │   ├── ci-pipeline.prompt.md
│   │   ├── ci-pipeline-docs.prompt.md
│   │   └── generate-description.prompt.md
│   ├── steps/                    ← Step instructions (posted to GitHub Issues)
│   │   ├── pe-1-iac-scaffold.md
│   │   ├── pe-2-ci-pipeline.md
│   │   ├── pe-3-terraform-apply.md
│   │   ├── pe-4-open-pr.md
│   │   └── pe-x-review.md
│   └── workflows/
│       ├── 0-pe-start-exercise.yml       ← Bootstrap (fires on first push to main)
│       ├── 1-pe-iac-scaffold.yml         ← Detects Step 1 complete
│       ├── 2-pe-ci-pipeline.yml          ← Detects Step 2 complete
│       ├── 3-pe-terraform-apply.yml      ← Detects Step 3 complete
│       ├── 4-pe-open-pr.yml              ← Detects Step 4 complete
│       ├── pe-terraform-destroy.yml      ← Manual destroy (enabled after Step 4)
│       └── scoreboard-post-completion.yml
├── context/
│   ├── iac-requirements.md       ← Student-populated in Step 1
│   └── ci-requirements.md        ← Student-populated in Step 2
├── docs/
│   ├── project-overview.md
│   ├── functional-requirements.md
│   ├── coding-guidelines.md
│   ├── testing-guidelines.md
│   └── ui-guidelines.md
├── infra/
│   ├── modules/todo-service/     ← Pre-built golden-path module (do not modify)
│   └── stacks/dev/               ← Student builds main.tf here in Step 1
└── packages/
    ├── backend/                  ← Express API (Node.js 20)
    └── frontend/                 ← React 18 SPA
```

---

## Full Lab Flow

### Workflow Enable/Disable Sequence

The lab uses a sequential enable/disable mechanism so only the relevant detection workflow is active at each step:

```
0-pe-start-exercise  →  enables 1-pe-iac-scaffold
                              ↓ (on success)
                         1-pe-iac-scaffold  →  enables 2-pe-ci-pipeline
                                                     ↓ (on success)
                                                2-pe-ci-pipeline  →  enables 3-pe-terraform-apply
                                                                            ↓ (on success)
                                                                       3-pe-terraform-apply  →  enables 4-pe-open-pr
                                                                                                      ↓ (on success)
                                                                                                 4-pe-open-pr  →  enables pe-terraform-destroy
```

Each detection workflow **disables itself** and **enables the next** only on success, keeping the lab linear.

---

## Step-by-Step Detection Logic

### Step 1 — IaC Scaffold (`1-pe-iac-scaffold.yml`)

**Trigger:** `pull_request` (opened, synchronize, reopened) with changes to `infra/**` · `workflow_dispatch`

**Checks (all must pass):**

| Check | What it looks for |
|---|---|
| File exists | `infra/stacks/dev/main.tf` present in PR |
| Module reference | File contains `slalom-terraform-pe-lab-ecs-app` |
| Terraform validate | `terraform init -backend=false && terraform validate` succeeds |
| tflint | `tflint --chdir=infra/stacks/dev` exits 0 |
| checkov | 0 HIGH severity findings |
| AWS_ROLE_ARN secret | Secret is configured in repo settings |

**Student deliverable:** `infra/stacks/dev/main.tf` calling the golden-path module, committed to `feat/pe-golden-path` and pushed.

---

### Step 2 — CI/CD Pipeline (`2-pe-ci-pipeline.yml`)

**Trigger:** `pull_request` (opened, synchronize, reopened) with changes to `.github/workflows/golden-path-ci.yml` or `.github/workflows/todo-service-ci.yml` · `workflow_dispatch`

**Checks (all must pass):**

| Check | What it looks for |
|---|---|
| Files present | Both `golden-path-ci.yml` and `todo-service-ci.yml` exist |
| YAML syntax | Valid YAML (Python yaml parser) |
| workflow_call trigger | `golden-path-ci.yml` contains `workflow_call` |
| uses: reference | `todo-service-ci.yml` calls reusable workflow via `uses:` |
| Workflow structure | Jobs section present; triggers present; `uses:` path references `golden-path-ci.yml` |

**Student deliverable:** Two workflow files committed to `feat/pe-golden-path`. Note: workflow run failures (e.g. terraform-plan failing on mock credentials) are expected and do not block Step 2 detection.

---

### Step 3 — Terraform Apply with OIDC (`3-pe-terraform-apply.yml`)

**Trigger:** Completion of `"Todo Service CI"` workflow (any conclusion) · `workflow_dispatch`

> The workflow checks out the PR head SHA (`github.event.workflow_run.head_sha`) so validation runs against the student's branch, not `main`.

**Checks (all 15 must pass):**

| Check | What it looks for |
|---|---|
| File exists | `golden-path-ci.yml` present |
| YAML valid | Valid YAML |
| terraform-apply job | Job named `terraform-apply` in `golden-path-ci.yml` |
| OIDC permission | `id-token: write` declared |
| OIDC action | `aws-actions/configure-aws-credentials` used |
| No hardcoded ARN | `aws_role_arn` referenced via inputs; no `arn:aws:iam::` literal |
| terraform apply command | `terraform apply` present; targets `infra/stacks/dev` |
| Caller inputs (apply) | `todo-service-ci.yml` passes `run_terraform_apply` and `AWS_ROLE_ARN` |
| service_url captured | `terraform output` present; `GITHUB_STEP_SUMMARY` written |
| build-and-push job | Job named `build-and-push` exists |
| ECR login | `amazon-ecr-login` action used |
| Docker commands | `docker build` and `docker push` present |
| ECS deploy | `aws ecs update-service --force-new-deployment` present |
| Caller inputs (build) | `todo-service-ci.yml` passes `build_and_push` input |
| CI run conclusion | `todo-service-ci.yml` run on this PR's head SHA concluded `success` |

**Student deliverable:** Updated `main.tf` (mock creds removed, S3 backend uncommented), updated `golden-path-ci.yml` (apply + build-and-push jobs), updated `todo-service-ci.yml` (inputs and secrets passed). `Todo Service CI` must have completed successfully.

---

### Step 4 — Open PR (`4-pe-open-pr.yml`)

**Trigger:** Completion of `"Todo Service CI"` workflow (any conclusion) · `workflow_dispatch`

> Also checks out PR head SHA from `github.event.workflow_run.head_sha`.

**Checks:**

| Check | What it looks for |
|---|---|
| build-and-push succeeded | Queries `/actions/runs/{run_id}/jobs` API; finds job matching `build-and-push` with conclusion `success` |

**On success:** Posts a review checklist comment to the PR, advances to the Review issue, disables this workflow, enables `pe-terraform-destroy.yml`.

**Student deliverable:** PR with a well-described body merged to `main`, triggering the full pipeline including real AWS deployment.

---

## Known Edge Cases and Gotchas

### Steps 3 and 4 both fire on "Todo Service CI" completion

Both `3-pe-terraform-apply.yml` and `4-pe-open-pr.yml` listen for the same `workflow_run` event. This means:
- Step 3 runs every time `Todo Service CI` completes, even before the student has done step 3 work — it will fail until checks pass.
- Step 4 runs too, and will fail on the `build-and-push` check until that job actually passes.
- This is by design: both workflows are idempotent and fail gracefully. The enable/disable mechanism ensures only the appropriate workflow is active at each stage.

### workflow_run checkout defaults to main

When triggered by `workflow_run`, `actions/checkout` defaults to the default branch (`main`), not the triggering PR's branch. Both step 3 and step 4 work around this with:
```yaml
ref: ${{ github.event.workflow_run.head_sha || github.sha }}
```

### PR number resolution in workflow_run context

`github.event.pull_request.number` is not available in `workflow_run` context. PR number is resolved via:
```bash
echo '${{ toJSON(github.event.workflow_run.pull_requests) }}' | jq -r '.[0].number // empty'
```
This only works when the triggering run was associated with a PR. Runs triggered by a direct push to a branch (not a PR) will result in an empty PR number and those checks will be skipped.

### Step 1 runs tflint and checkov against the PR branch

Uses the same `ref: ${{ github.event.pull_request.head.sha }}` pattern (implicit in `pull_request` trigger) — no special handling needed here.

### Destroy workflow is manual-only

`pe-terraform-destroy.yml` requires a `workflow_dispatch` with `confirm_destroy` set to exactly `"DESTROY"`. It is only enabled after Step 4 completes. It also patches out mock provider config before running `terraform destroy`.

---

## Manually Triggering Detection Workflows

All detection workflows support `workflow_dispatch`. To re-run a check without the student pushing:

1. Go to **Actions** tab → select the detection workflow by name
2. Click **Run workflow**
3. Select the correct branch (usually `main` for the detection workflows)

> **Note:** `workflow_dispatch` runs on `main` — file checks will validate what's currently on `main`, not a PR branch. Use this only to verify the workflow logic itself, not student work.

---

## What a Successful Run Looks Like

After a student completes all four steps:

1. **GitHub Issues:** One issue closed per step, final Review issue open
2. **PR on `feat/pe-golden-path`:** Merged to `main`; description has summary, adoption guide, evidence section
3. **GitHub Actions runs:**
   - `Todo Service CI` — green, all jobs passed (lint, test, security-scan, terraform-plan, terraform-apply, build-and-push)
   - `3-pe-terraform-apply.yml` — green
   - `4-pe-open-pr.yml` — green
4. **AWS resources:** ECS cluster, ECR repos, ALB, VPC provisioned in `us-east-2`
5. **App live:** ALB URL responds with todo frontend; `/api/health` returns `{"status":"ok"}` — **verify this from your local machine, not a Codespace** (the ALB security group only allows the `alb_ingress_cidr` IP, which is your local machine's public IP)
6. **Cleanup:** Student runs `pe-terraform-destroy.yml` to tear down AWS resources

---

## Feedback and Issues

If detection workflows fire incorrectly, check:
- Workflow enable/disable state: **Actions → Manage workflows** (sidebar)
- Whether `AWS_ROLE_ARN` is set: **Settings → Secrets and variables → Actions**
- Whether `Todo Service CI` ran on the correct head SHA (not a stale run)
- The PR number resolution in `workflow_run` logs (look for `PR head SHA:` log line)
