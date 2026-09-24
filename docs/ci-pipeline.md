# CI Pipeline Overview

This repository uses a two-layer GitHub Actions model:

- a reusable workflow at `.github/workflows/golden-path-ci.yml` that defines the standard validation and deployment checks
- a service-specific caller workflow at `.github/workflows/todo-service-ci.yml` that triggers the reusable workflow for this service

This keeps the platform guardrails centralized while allowing each service to opt in with a small caller file.

---

## What the reusable workflow does

The file `.github/workflows/golden-path-ci.yml` is the shared CI contract for the Todo Service golden path. It is triggered with `on: workflow_call`, which means it is designed to be invoked by another workflow rather than run manually.

The workflow accepts inputs such as:

- `node_version` with a default of `20`
- `terraform_version` with a default of `1.7.0`
- `run_terraform_plan` with a default of `false`
- `run_terraform_apply` with a default of `false`
- `build_and_push` with a default of `false`

It also accepts a `aws_role_arn` secret for AWS OIDC authentication.

### Why this pattern exists

The reusable workflow defines the standard checks every service should pass before it is merged or deployed. The caller workflow then decides when to run those checks and which values to pass in.

This keeps validation consistent across teams while still allowing service-specific triggers and environment variables.

---

## Jobs in the reusable workflow

### 1. `lint`

Purpose:

- install dependencies
- run ESLint on both the backend and frontend

Why it is required:

- catches syntax errors, unused variables, invalid imports, and common code issues before tests or deploy steps run
- ensures both application layers follow the repo’s code quality rules

Implementation:

- runs `npm install`
- runs `npm run lint --workspace=packages/backend`
- runs `npm run lint --workspace=packages/frontend`

---

### 2. `test`

Purpose:

- run the backend test suite with coverage enabled
- publish the coverage summary to the workflow summary

Why it is required:

- this service is built with Jest
- the requirements state that Jest coverage must fail below 80%
- a low coverage threshold means regressions can slip through without detection

Implementation:

- installs dependencies with Node
- runs `npm run test --workspace=packages/backend -- --coverage --coverageReporters=json-summary --coverageReporters=text-summary`
- reads the generated summary and writes the results to `$GITHUB_STEP_SUMMARY`

---

### 3. `security-scan`

Purpose:

- run Checkov against the `infra/` directory

Why it is required:

- validates the Terraform configuration for common security and policy issues
- catches risky IaC patterns before they reach AWS
- aligns with the requirement to scan infrastructure as code

Implementation:

- installs Checkov with Python
- runs `checkov -d infra --hard-fail-on HIGH`
- only runs when `run_terraform_plan` is true

---

### 4. `terraform-plan`

Purpose:

- validate the Terraform configuration for the dev stack
- generate a plan for the stack without requiring a full backend setup on pull requests

Why it is required:

- ensures infrastructure changes are syntactically valid and logically reviewable before merge
- allows a pull request to verify Terraform changes without needing a real AWS backend on PR runs
- catches config drift, invalid values, and broken references early

Implementation details:

- authenticates to AWS with OIDC via `aws-actions/configure-aws-credentials@v4`
- installs the configured Terraform version
- runs `terraform init -reconfigure -backend-config="key=todo-service/${{ github.repository_owner }}/dev/terraform.tfstate"`
- writes mock VPC and subnet values for PR validation when `run_terraform_apply` is not true
- runs `terraform plan -out=tfplan`
- writes the plan summary to `$GITHUB_STEP_SUMMARY`
- uploads the plan artifact for later use

Important note:

- the workflow intentionally uses `terraform init` with `-backend=false` in the earlier guidance for local validation, but the CI plan job in this repo configures the backend key for the actual dev stack plan.
- the key point is that Terraform must be validated in CI and must not silently assume a local-only state file.

---

### 5. `docker-build`

Purpose:

- build the backend and frontend containers on pull requests

Why it is required:

- validates that both Dockerfiles still build
- catches broken build context, missing files, or bad Docker arguments before deployment
- ensures the app remains containerizable without pushing images anywhere

Implementation:

- runs `docker build -f packages/backend/Dockerfile packages/backend/`
- runs `docker build --build-arg REACT_APP_USERNAME=${{ github.actor }} -f packages/frontend/Dockerfile packages/frontend/`
- runs only for pull requests and after lint + test pass

---

### 6. `terraform-apply`

Purpose:

- apply the dev stack when a push to `main` is approved by the workflow input configuration

Why it is required:

- enables the infrastructure to be deployed to AWS through OIDC
- gates production-like deployment behind a controlled flag and a main-branch push

Implementation:

- requires `run_terraform_apply` to be true
- uses OIDC credentials and the `aws_role_arn` secret
- downloads the Terraform plan artifact
- runs `terraform apply tfplan`
- writes the deployment URL to the workflow summary

---

### 7. `build-and-push`

Purpose:

- authenticate to Amazon ECR
- build the backend and frontend images
- push them to ECR
- trigger an ECS service update

Why it is required:

- ensures the built containers are actually shipped to the registry for deployment
- aligns with the golden path pattern for containerized deployment
- keeps a versioned image and a latest tag for the app

Implementation:

- requires `build_and_push` to be true
- resolves the ECR repository URLs from Terraform outputs
- logs in to Amazon ECR
- builds and pushes both images
- triggers an ECS deployment

---

## How a new service team adopts it

A new service only needs to create a small caller workflow that points to the reusable pipeline.

Minimum example:

```yaml
name: Todo Service CI

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  call-golden-path:
    uses: ./.github/workflows/golden-path-ci.yml
    with:
      node_version: "20"
      run_terraform_plan: true
      run_terraform_apply: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
      build_and_push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

This is the exact adoption pattern already used in `.github/workflows/todo-service-ci.yml`.

What the caller is doing:

- defines the repo trigger policy
- chooses the Node.js version
- enables Terraform planning for PRs
- enables apply and image push only on `main`
- passes the AWS role ARN required for OIDC

---

## What each required check validates

### Lint

Validates:

- JS/JSX correctness
- static quality issues
- broken code patterns before runtime

Why required:

- low-cost feedback loop
- avoids failing later in the pipeline or in deployment

### Test

Validates:

- behavior of the backend code
- code coverage level for regressions

Why required:

- this is the main behavior gate for the app
- enforces the 80% threshold from the requirements

### Security scan

Validates:

- Terraform security posture
- risky infrastructure definitions

Why required:

- infrastructure must be reviewed for security issues before deployment
- prevents unsafe defaults from being promoted into AWS

### Terraform plan

Validates:

- Terraform syntax and module compatibility
- state and provider configuration
- resource changes that would be applied

Why required:

- confirms infrastructure changes are reviewable before apply
- prevents accidental AWS modifications from an unreviewed config

### Docker build

Validates:

- container buildability
- packaging correctness for each service component

Why required:

- ensures the app remains deployable in containers
- catches build failures before the release path is attempted

---

## How to configure the OIDC role secret

The Terraform jobs use OIDC instead of long-lived AWS credentials. The required secret is:

- `AWS_ROLE_ARN`

### Required setup

1. Create or use an AWS IAM role that trusts GitHub Actions OIDC.
2. Add the repository as the GitHub identity provider.
3. Allow the role to be assumed from this repository and branch.
4. Add the role ARN to the GitHub repository secrets.
5. Reference it in the caller workflow as:

```yaml
secrets:
  aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

### Why this matters

The `terraform-plan` and other AWS-authenticated jobs need a secure identity to assume AWS permissions. OIDC avoids storing static AWS access keys in GitHub and keeps permission scoping aligned with the role policy.

The repo requirement is explicit: the secret must be configured in GitHub repository settings and passed as a `workflow_call` secret named `aws_role_arn` into the reusable workflow.

---

## Summary

The golden path workflow is the standard platform gate for application quality, infrastructure safety, and deployment readiness. It enforces the repo’s required checks in a consistent way, while the caller workflow is the simple service-specific entry point that decides when those checks run.

For this service, the workflow is intentionally designed to:

- validate app code on every PR
- validate Terraform changes before merge
- approve actual AWS deployment only from `main`
- build and push images only in the deployment path

This is the core pattern for a reusable CI/CD golden path.
