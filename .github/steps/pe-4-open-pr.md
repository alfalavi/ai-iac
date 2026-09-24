# Step 4 — Document and Merge the Golden Path PR

> [!NOTE]
> **Goal:** Craft a PR description that tells the complete "what changed / why" story for your golden path, then merge it to `main` to trigger the real deployment.

## Context

Your `feat/pe-golden-path` PR is already open with all the work from Steps 1–3. Before merging, you need to do the one thing CI can't do for you: explain _why_ these changes exist and how the next team adopts them.

The PR description is a first-class deliverable — not a formality. It is the artifact that a platform engineer, security reviewer, or new service team will read when they need to understand and adopt your golden path.

---

## Instructions

### 1. Generate the PR description with Copilot

> [!TIP]
> Not sure what makes a good PR description for a golden path? Ask Copilot first:
> _"What should a PR description include when introducing a new golden path to a platform team? What does a reviewer or new adopter most need to know?"_

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:

```text
/generate-description
```

> **What's happening:** `/generate-description` loads `.github/prompts/generate-description.prompt.md`. The agent reads `docs/functional-requirements.md` and the diff of your branch against `main` to understand what changed and why, then writes a structured PR description to `/tmp/pr-body.md`.

### 2. Update the PR description

With the generated description ready, ask Copilot to apply it to the existing PR:

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Update the open PR on `feat/pe-golden-path` with the description you generated in `/tmp/pr-body.md`"_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
# Find your open PR number
gh pr list --head feat/pe-golden-path

# Update the description
gh pr edit <PR-NUMBER> --body-file /tmp/pr-body.md
```

</details>

### 3. Self-review before merging

Read the updated PR as if you were a new team adopting this golden path for the first time. Verify each item before merging:

**PR description:**

- [ ] "What changed / why" narrative is clear — not just a list of files
- [ ] "How to Adopt" section tells a new service team exactly what to do
- [ ] Evidence section references terraform plan, checkov, and CI results

**Code:**

- [ ] `infra/stacks/dev/main.tf` has no mock credentials and S3 backend is uncommented
- [ ] `golden-path-ci.yml` has `id-token: write` permission and `terraform-apply` job
- [ ] No hardcoded ARNs, account IDs, or static credentials anywhere in the workflows

If something needs fixing, ask Copilot to help and push the fix to `feat/pe-golden-path`.

### 4. Merge to `main`

Once the checklist is complete, merge the PR:

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Merge the open PR on `feat/pe-golden-path` into `main`"_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
gh pr merge feat/pe-golden-path --squash --subject "feat: ship mini golden path for todo-service (IaC + CI/CD + OIDC apply)"
```

</details>

> [!NOTE]
> Merging triggers the `terraform-apply` and `build-and-push` jobs in `todo-service-ci.yml`. Watch the **Actions** tab — when both jobs complete, your todo-service will be live behind a real AWS Load Balancer.
>
> **To find the Load Balancer URL after merging:**
>
> 1. Open the **Actions** tab and click the **Todo Service CI** run triggered by the merge
> 2. Open the **terraform-apply** job → **Show deployment URL** step to copy your Load Balancer URL
> 3. Confirm the **build-and-push** job summary shows that ECS deployment was triggered
>
> **Test the ALB URL from your local machine, not from a Codespace.** The `alb_ingress_cidr` setting restricts which IP addresses can reach the load balancer. Codespaces run on GitHub-managed infrastructure with an outbound IP outside that allowed range, so the connection will be blocked by the security group.

---

## Completion Criteria

Once the **build-and-push** job in your **Todo Service CI** pipeline completes successfully, the step-detection workflow triggers automatically and will:

1. Open the **Review** issue with your final deliverable checklist

## Deliverables Summary

| Artifact             | Location                                | Verified                    |
| -------------------- | --------------------------------------- | --------------------------- |
| Terraform module     | `infra/modules/todo-service/`           | terraform plan passes       |
| Stack config         | `infra/stacks/dev/`                     | tflint + checkov clean      |
| Reusable CI workflow | `.github/workflows/golden-path-ci.yml`  | YAML valid, apply job wired |
| Service CI caller    | `.github/workflows/todo-service-ci.yml` | workflow_call + OIDC secret |
| PR description       | GitHub PR                               | "what changed / why" clear  |

---

_Step 4 of 4 — [Previous: Terraform Apply] · [Next: Review]_
