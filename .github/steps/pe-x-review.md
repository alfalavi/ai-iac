# Review — Ship a Mini Golden Path

> Congratulations on completing the **Session PE: Ship a Mini Golden Path** lab!

## Step 1 — Verify Your App is Live

Before tearing anything down, confirm the todo-service is actually running in AWS.

### Find the Load Balancer URL

> [!IMPORTANT]
> **Wait for the workflow to finish before opening the URL.** After merging to `main`, go to the **Actions** tab and wait until both the `terraform-apply` and `build-and-push` jobs show a green checkmark. The Load Balancer exists only after `terraform-apply` completes, and the app is only running after `build-and-push` forces the ECS deployment. Opening the URL before both jobs finish will result in a connection error or a 503.

1. Open the **Actions** tab in your repository
2. Wait for the workflow run triggered by your merge to `main` to complete (both `terraform-apply` and `build-and-push` jobs green)
3. Click the **terraform-apply** job → expand the **Terraform** apply step and scroll to the bottom of the logs. You will find Outputs information.
4. Copy the "service_url" (format: `http://<alb-dns-name>.us-east-1.elb.amazonaws.com`)

> [!TIP]
> The URL also appears in the **Actions run summary** — click the workflow run and look at the top-level summary tab.

### Test the app

Open the URL in your browser. You should see the todo-service frontend. To verify the backend API is responding:

```bash
curl http://<your-alb-url>/api/health
# Expected: {"status":"ok"}

curl http://<your-alb-url>/api/todos
# Expected: [] or a list of todos
```

> [!NOTE]
> ECS tasks can take 1–2 minutes to become healthy after the `build-and-push` job triggers the deployment. If the URL isn't responding immediately, wait a moment and retry.

<!-- -->

> [!TIP]
> **Sharing the room with other participants?** The `alb_ingress_cidr` in your stack is set to your shared external IP — so everyone on the same network (office Wi-Fi, WeWork, etc.) can reach _each other's_ deployed apps. Grab a teammate's Load Balancer URL and open it in your browser. Each one is a fully independent stack, but all accessible from the same connection. Try adding a todo on someone else's app!

---

## Step 2 — Full Journey Checklist

Before wrapping up, verify every layer of the golden path was successfully delivered end-to-end:

### Docker Images

- [ ] Backend Docker image built from `packages/backend/Dockerfile` in the `build-and-push` job
- [ ] Frontend Docker image built from `packages/frontend/Dockerfile` in the `build-and-push` job
- [ ] Both images tagged with `${{ github.sha }}` and pushed to Amazon ECR

### Infrastructure

- [ ] `infra/modules/todo-service/` scaffolded with ECS Fargate, ALB, ECR repos, security groups
- [ ] All resources tagged with `environment`, `service`, and `managed_by`
- [ ] `terraform plan` ran clean in CI (no errors, 0 HIGH checkov findings)
- [ ] `terraform apply` ran successfully via OIDC — no static credentials used

### Deployment

- [ ] `build-and-push` job ran after `terraform-apply` (ECR repos existed before push)
- [ ] ECS `update-service --force-new-deployment` triggered in CI
- [ ] ECS tasks reached a healthy state (confirmed by ALB responding)
- [ ] Load Balancer URL captured and written to the Actions run summary

### CI/CD Pipeline

- [ ] `golden-path-ci.yml` uses `on: workflow_call` (reusable template)
- [ ] Jobs: `lint` → `test` → `security-scan` → `terraform-plan` → `terraform-apply` → `build-and-push`
- [ ] `id-token: write` permission declared for OIDC jobs
- [ ] No hardcoded ARNs, account IDs, or static credentials anywhere
- [ ] `todo-service-ci.yml` adopts the golden path with a single `uses:` line

### PR

- [ ] PR description explains "what changed / why"
- [ ] PR includes a "How to Adopt" quickstart for new teams
- [ ] Evidence section includes terraform plan output

---

## What You Built

| Layer          | Artifact                                | Description                                                     |
| -------------- | --------------------------------------- | --------------------------------------------------------------- |
| **IaC**        | `infra/modules/todo-service/`           | Terraform module with ECS, ALB, ECR, security groups            |
| **IaC**        | `infra/stacks/dev/`                     | Stack consuming the module with dev defaults                    |
| **CI/CD**      | `.github/workflows/golden-path-ci.yml`  | Reusable workflow: lint, test, security, plan, apply, deploy    |
| **CI/CD**      | `.github/workflows/todo-service-ci.yml` | Service caller adopting the golden path in one `uses:` line     |
| **OIDC Apply** | `terraform-apply` job                   | Provisions AWS infrastructure with short-lived OIDC credentials |
| **Docker**     | `build-and-push` job                    | Builds backend + frontend images, pushes to ECR, deploys to ECS |
| **PR**         | GitHub Pull Request                     | Clear description with "what changed / why" and adoption guide  |

---

## Reflection Questions

Think through these with your cohort or capture in a short written summary:

1. **Adoption friction:** What would a new service team need to do to adopt this golden path? How many lines of code?
2. **Policy as code:** How did checkov findings change your Terraform? What category of issue came up most?
3. **OIDC vs. static keys:** Why does OIDC matter for CI/CD security? What attack surface does it eliminate?
4. **Deployment pipeline:** The `build-and-push` job runs after `terraform-apply`. Why does order matter here?
5. **AI leverage:** Where did Copilot accelerate you the most? Where did you have to guide it most carefully?

---

## What a Real Golden Path Adds Next

This lab covered the MVP. A production golden path would also include:

- Remote Terraform state (S3 + DynamoDB lock table)
- Secrets management (AWS Secrets Manager / Vault references)
- Image signing and supply chain security (Sigstore/cosign)
- DORA metrics collection (deploy frequency, lead time, MTTR)
- Service catalog entry (Backstage or similar)
- Cost estimation (Infracost in the CI pipeline)
- Drift detection (scheduled `terraform plan` with alerting)

---

## Final Step — Tear Down the Infrastructure

> [!WARNING]
> **Only run the destroy workflow after you have confirmed your app is live and you are done with the lab.** This action is irreversible — it will delete the ECS cluster, ECR repositories (and all pushed images), the Application Load Balancer, and all supporting AWS resources in the dev environment.

### Run the Terraform Destroy workflow

1. In your repository, click the **Actions** tab
2. In the left sidebar, click **Terraform Destroy — Todo Service Dev**
3. Click the **Run workflow** button (top right of the workflow list)
4. Fill in the inputs:
   - **Confirm destroy:** type `DESTROY` (all caps, exactly)
5. Click the green **Run workflow** button

The workflow will authenticate to AWS via OIDC, run `terraform destroy -auto-approve`, and write a summary of what was removed to the Actions run summary.

> [!NOTE]
> The destroy workflow uses the same S3 backend key as the apply workflow, so it targets exactly your dev stack — not another student's environment.

---

## Share Your Work

Post your PR link in the session Slack channel with a one-sentence summary of the most interesting thing Copilot generated for you.

---

_Lab complete — thank you for participating in the AI Accelerated Engineering Bootcamp._
