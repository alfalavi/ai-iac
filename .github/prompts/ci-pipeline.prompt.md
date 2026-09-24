---
description: Create the golden-path reusable CI/CD workflow and service caller
---

Read the requirements from #file:../../context/ci-requirements.md and the coding standards from #file:../copilot-instructions.md before writing any files.

Create a reusable GitHub Actions workflow at `.github/workflows/golden-path-ci.yml` and a caller workflow at `.github/workflows/todo-service-ci.yml` that match those requirements exactly.

**Use the following as the reference implementation for `golden-path-ci.yml`:**

```yaml
name: Golden Path CI

on:
  workflow_call:
    inputs:
      node_version:
        description: Node.js version for lint/test jobs
        required: false
        type: string
        default: "20"
      terraform_version:
        description: Terraform version for IaC validation
        required: false
        type: string
        default: "1.7.0"
      run_terraform_plan:
        description: Run security scan and terraform plan jobs
        required: false
        type: boolean
        default: false
      run_terraform_apply:
        description: Run terraform apply in dev stack
        required: false
        type: boolean
        default: false
      build_and_push:
        description: Build and push Docker images to ECR
        required: false
        type: boolean
        default: false
    secrets:
      aws_role_arn:
        description: AWS IAM role ARN for OIDC federation
        required: false

permissions:
  contents: read
  pull-requests: write

jobs:
  lint:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node_version }}

      - name: Install dependencies
        run: npm install

      - name: Lint backend
        run: npm run lint --workspace=packages/backend

      - name: Lint frontend
        run: npm run lint --workspace=packages/frontend

  test:
    name: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node_version }}

      - name: Install dependencies
        run: npm install

      - name: Run backend tests with coverage
        run: npm run test --workspace=packages/backend -- --coverage --coverageReporters=json-summary --coverageReporters=text-summary

      - name: Append coverage summary
        run: |
          node -e 'const fs=require("fs");const p="packages/backend/coverage/coverage-summary.json";const c=JSON.parse(fs.readFileSync(p,"utf8")).total;const msg=`## Test Coverage\n- Lines: ${c.lines.pct}%\n- Branches: ${c.branches.pct}%\n- Functions: ${c.functions.pct}%\n- Statements: ${c.statements.pct}%`;fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,msg+"\n");'

  security-scan:
    name: security-scan
    runs-on: ubuntu-latest
    if: ${{ inputs.run_terraform_plan }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        run: |
          python3 -m pip install --upgrade pip
          python3 -m pip install checkov

      - name: Run Checkov on infra
        run: checkov -d infra --hard-fail-on HIGH

  terraform-plan:
    name: terraform-plan
    runs-on: ubuntu-latest
    if: ${{ inputs.run_terraform_plan }}
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          aws-region: us-east-1

      - name: Install Terraform
        run: |
          set -euo pipefail
          TF_VERSION="${{ inputs.terraform_version }}"
          curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" -o terraform.zip
          unzip -o terraform.zip
          sudo install terraform /usr/local/bin/terraform
          terraform version

      - name: Terraform init and plan
        working-directory: infra/stacks/dev
        run: |
          set -euo pipefail
          terraform init -reconfigure -backend-config="key=todo-service/${{ github.repository_owner }}/dev/terraform.tfstate"

          if [[ "${{ inputs.run_terraform_apply }}" != "true" ]]; then
            printf '%s\n' \
              'vpc_id = "vpc-mock"' \
              'private_subnet_ids = ["subnet-mock"]' \
              'public_subnet_ids = ["subnet-mock"]' \
              > ci-plan.auto.tfvars
          fi

          terraform plan -out=tfplan

      - name: Terraform plan summary
        working-directory: infra/stacks/dev
        run: |
          {
            echo "## Terraform Plan"
            echo
            terraform show -no-color tfplan | sed -n '1,120p'
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Upload Terraform plan artifact
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan
          path: infra/stacks/dev/tfplan

  docker-build:
    name: docker-build
    runs-on: ubuntu-latest
    needs: [lint, test]
    if: ${{ github.event_name == 'pull_request' }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build backend Docker image
        run: docker build -f packages/backend/Dockerfile packages/backend/

      - name: Build frontend Docker image
        run: docker build --build-arg REACT_APP_USERNAME=${{ github.actor }} -f packages/frontend/Dockerfile packages/frontend/

  terraform-apply:
    name: terraform-apply
    runs-on: ubuntu-latest
    if: ${{ inputs.run_terraform_apply }}
    needs: [terraform-plan]
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          aws-region: us-east-1

      - name: Install Terraform
        run: |
          set -euo pipefail
          TF_VERSION="${{ inputs.terraform_version }}"
          curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" -o terraform.zip
          unzip -o terraform.zip
          sudo install terraform /usr/local/bin/terraform
          terraform version

      - name: Update provider for OIDC
        working-directory: infra/stacks/dev
        run: |
          sed -i '/skip_credentials_validation\|skip_metadata_api_check\|skip_region_validation\|skip_requesting_account_id/d' main.tf

      - name: Terraform init with S3 backend
        working-directory: infra/stacks/dev
        run: |
          terraform init -backend-config="key=todo-service/${{ github.repository_owner }}/dev/terraform.tfstate"

      - name: Download Terraform plan artifact
        uses: actions/download-artifact@v4
        with:
          name: terraform-plan
          path: infra/stacks/dev

      - name: Terraform apply
        working-directory: infra/stacks/dev
        run: terraform apply tfplan

      - name: Show deployment URL
        id: deployment
        working-directory: infra/stacks/dev
        run: |
          SERVICE_URL=$(terraform output -raw service_url)
          echo "service_url=$SERVICE_URL" >> $GITHUB_OUTPUT
          echo "## ✅ Deployment complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Output | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Load Balancer URL | $SERVICE_URL |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "→ Open: $SERVICE_URL" >> $GITHUB_STEP_SUMMARY

  build-and-push:
    name: build-and-push
    runs-on: ubuntu-latest
    if: ${{ inputs.build_and_push }}
    needs: [terraform-apply]
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          aws-region: us-east-1

      - name: Install Terraform
        run: |
          set -euo pipefail
          TF_VERSION="${{ inputs.terraform_version }}"
          curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" -o terraform.zip
          unzip -o terraform.zip
          sudo install terraform /usr/local/bin/terraform
          terraform version

      - name: Resolve ECR repository URLs
        id: ecr-repos
        working-directory: infra/stacks/dev
        run: |
          set -euo pipefail
          terraform init -reconfigure -backend-config="key=todo-service/${{ github.repository_owner }}/dev/terraform.tfstate"
          BACKEND_REPO=$(terraform output -raw backend_ecr_repository_url)
          FRONTEND_REPO=$(terraform output -raw frontend_ecr_repository_url)
          echo "backend_repo=$BACKEND_REPO" >> "$GITHUB_OUTPUT"
          echo "frontend_repo=$FRONTEND_REPO" >> "$GITHUB_OUTPUT"

      - name: Login to Amazon ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push backend image
        run: |
          docker build -t ${{ steps.ecr-repos.outputs.backend_repo }}:${{ github.sha }} -t ${{ steps.ecr-repos.outputs.backend_repo }}:latest -f packages/backend/Dockerfile packages/backend/
          docker push ${{ steps.ecr-repos.outputs.backend_repo }}:${{ github.sha }}
          docker push ${{ steps.ecr-repos.outputs.backend_repo }}:latest

      - name: Build and push frontend image
        run: |
          docker build --build-arg REACT_APP_USERNAME=${{ github.actor }} -t ${{ steps.ecr-repos.outputs.frontend_repo }}:${{ github.sha }} -t ${{ steps.ecr-repos.outputs.frontend_repo }}:latest -f packages/frontend/Dockerfile packages/frontend/
          docker push ${{ steps.ecr-repos.outputs.frontend_repo }}:${{ github.sha }}
          docker push ${{ steps.ecr-repos.outputs.frontend_repo }}:latest

      - name: Deploy to ECS
        run: |
          CLUSTER=$(aws ecs list-clusters --query 'clusterArns[0]' --output text | xargs -I{} aws ecs describe-clusters --clusters {} --query 'clusters[0].clusterName' --output text)
          SERVICE=$(aws ecs list-services --cluster "$CLUSTER" --query 'serviceArns[0]' --output text | xargs -I{} aws ecs describe-services --cluster "$CLUSTER" --services {} --query 'services[0].serviceName' --output text)
          aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment
          echo "## 🚀 ECS deployment triggered" >> $GITHUB_STEP_SUMMARY
          echo "Cluster: \`$CLUSTER\`  Service: \`$SERVICE\`" >> $GITHUB_STEP_SUMMARY
          echo "Backend image: \`${{ steps.ecr-repos.outputs.backend_repo }}:latest\`" >> $GITHUB_STEP_SUMMARY
          echo "Frontend image: \`${{ steps.ecr-repos.outputs.frontend_repo }}:latest\`" >> $GITHUB_STEP_SUMMARY
          echo "Also pushed immutable tags: \`${{ github.sha }}\`." >> $GITHUB_STEP_SUMMARY
```

**Use the following as the reference implementation for `todo-service-ci.yml`:**

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

**Critical constraints — violating these will break CI:**
1. Do NOT use commit SHA hashes for action versions (e.g. `actions/checkout@abc1234...`). Always use version tags (e.g. `actions/checkout@v4`).
2. Do NOT set `cache: 'npm'` on `actions/setup-node` — this repo has no lock files and the job will fail with a "lock file not found" error.
3. Never reference `secrets.AWS_ROLE_ARN` directly inside `golden-path-ci.yml` — always use `secrets.aws_role_arn` (the workflow_call secret input).
4. `id-token: write` **must be declared at the top-level `permissions` block of `todo-service-ci.yml`** (the caller). Declaring it only inside `golden-path-ci.yml` is not sufficient — GitHub only grants the OIDC token to workflows that explicitly request it at the caller level.
