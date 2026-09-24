# Step 1 — IaC: Configure the Dev Stack

## What This Lab Teaches

Welcome to **Session PE: Ship a Mini Golden Path** — a hands-on lab where you use GitHub Copilot in Agent mode to build every layer of a production-ready paved road for a real service.

By the end of the four steps you will have shipped:

| Step                   | What you build                                                    | Key skill                                                                                                                                                                                                                             |
| ---------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1 — IaC Scaffold**   | Terraform dev stack calling the Slalom golden-path module         | [AI-assisted infrastructure authoring](https://docs.github.com/en/copilot/using-github-copilot/asking-github-copilot-questions-in-your-ide) + [policy checks with Checkov](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html) |
| **2 — CI/CD Pipeline** | Reusable `workflow_call` GitHub Actions template + service caller | [Reusable GitHub Actions workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows) with lint, test, security scan, and plan                                                                                |
| **3 — OIDC Apply**     | Terraform code cleaned up for real AWS + `terraform-apply` CI job | [Keyless cloud auth with OIDC federation](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)                                       |
| **4 — PR & Merge**     | Well-documented PR merged to `main` triggering a live deployment  | [AI-generated PR descriptions with Copilot](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-for-pull-requests/creating-a-pull-request-summary-with-github-copilot)                                       |

**Why a golden path?** When every team writes their own infrastructure and pipelines from scratch, you get inconsistent security postures, duplicated effort, and drift that's hard to audit. A golden path encodes your organisation's standards once — and every adopting team inherits them automatically. In this lab you are in the service team's seat: consuming a pre-built golden path to ship a production-ready service as fast as possible.

**Why Copilot Agent mode?** Rather than using AI to autocomplete one line at a time, Agent mode lets you delegate entire tasks — "scaffold this Terraform stack", "generate a reusable CI workflow", "write the PR description". The goal is to learn how to prompt and guide an AI agent effectively, not just to finish faster.

---

> [!NOTE]
> **Goal:** Use Copilot Agent mode to configure `infra/stacks/dev/main.tf` to call the Slalom PE Lab golden-path module, validate it with `terraform init`, `tflint`, and `checkov`, and open a PR.

---

## Before You Begin: Set Up Your Environment

This lab runs in **GitHub Codespaces** (recommended — zero local setup) or on your local machine.

### Option A — GitHub Codespaces (recommended)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/{{full_repo_name}}?quickstart=1)

1. Click the button above to open the **Create Codespace** page in a new tab. Use the default configuration.

1. Confirm the **Repository** field shows your copy of the exercise:
   - ✅ Your copy: **{{full_repo_name}}**
   - ❌ Original template — do not use this

1. Click the green **Create Codespace** button and wait for the environment to load. This may take a minute as GitHub provisions a fresh cloud environment with all tools pre-installed (Terraform, tflint, checkov, Node.js, GitHub CLI).

1. When ready, you'll see a VS Code interface in your browser with a terminal at the bottom. Wait for any post-start setup commands to finish.

### Option B — Local Machine

Follow the [Local Setup guide](https://github.com/{{full_repo_name}}/blob/main/LOCAL-SETUP.md) to install all required tools before starting.

---

## Add the AWS Role Secret

Before writing any code, add the IAM role ARN your instructor provided as a repository secret. You will need it in Step 3 to apply Terraform to AWS using OIDC authentication.

> [!CAUTION]
> **Do this now** — it only takes 60 seconds and you cannot complete Step 3 without it.

**Steps:**

1. In your repository, click the **Settings** tab (top navigation bar).
2. In the left sidebar, expand **Secrets and variables** → click **Actions**.
3. Click the green **New repository secret** button.
4. Fill in the form:
   - **Name:** `AWS_ROLE_ARN`
   - **Secret:** paste the ARN your instructor provided (format: `arn:aws:iam::<account-id>:role/<role-name>`)
5. Click **Add secret**.

You should now see `AWS_ROLE_ARN` listed under **Repository secrets**. The value is encrypted and will never be visible again — that's expected.

---

## Context

> [!NOTE]
> **New to Terraform or IaC?** [Infrastructure as Code](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/infrastructure-as-code) means defining your cloud resources in versioned configuration files instead of clicking through a console. [Terraform](https://developer.hashicorp.com/terraform/intro) is the most widely-used IaC tool — you describe the desired state and it figures out how to create or update resources to match. If you have never used it before, skim the [Get Started — AWS](https://developer.hashicorp.com/terraform/tutorials/aws-get-started) tutorial for a 5-minute overview before continuing.

The `packages/backend/` directory contains a running Express API (the Todo service). Your task is to configure the AWS infrastructure that will host this service using the **Slalom PE Lab ECS App module** — a pre-built, policy-compliant Terraform module maintained by the platform team.

> [!NOTE]
> **You do not build the Terraform module.** The module lives locally at `infra/modules/todo-service/`
> (a copy of the [Slalom PE Lab ECS App golden-path module](https://github.com/Slalom/slalom-terraform-pe-lab-ecs-app/tree/v1.0.4)) and is already production-ready. Your job in this step is to write the dev stack that _calls_ it
> — just like any service team adopting the golden path would do.
>
> **Why a vetted module?** When every team writes their own Terraform from scratch, you get inconsistent security postures, duplicated effort, and drift that's hard to audit. A centrally-maintained module encodes your organisation's standards once — encryption, least-privilege IAM, resource tagging, log retention — and every adopting team inherits them automatically. That's the core value of a golden path.

<!-- -->

> [!TIP]
> Not familiar with some of the resources below? Ask Copilot to walk you through the module before writing any code:
> _"Read `infra/modules/todo-service/` and explain what each resource does, why it's needed, and how the pieces connect."_

**What the module provisions for you:**

- [VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html), [public/private subnets](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html), [NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [ECS Fargate cluster](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html) with [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- Two [ECR repositories](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html) (backend + frontend) with [lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) + [target group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) + [security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [CloudWatch log groups](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html) and [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)

> [!NOTE]
> **[Remote state is ready.](https://developer.hashicorp.com/terraform/language/backend/s3)** An S3 bucket (`pe-labs-terraform-state`, `us-east-2`) has been pre-created for you — do not create your own. The S3 backend block in `infra/stacks/dev/main.tf` is **commented out** for Steps 1–2 so `terraform init` works locally without AWS credentials. You will uncomment it in Step 3 before applying.

## What You Will Build

```text
infra/
└── stacks/
    └── dev/
        └── main.tf   ← configure this to call the golden-path module
```

## Instructions

### 1. Create your working branch

You'll use **one branch for the entire lab named `feat/pe-golden-path`**. Create it now and keep all your work here — Steps 2 and 3 will add more commits to this same branch.

**Steps:**

1. Open Copilot Chat in **Agent** mode (sparkle icon in the chat input).
2. Run the prompt: _"Create a new branch called `feat/pe-golden-path` and switch to it."_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
git checkout -b feat/pe-golden-path
```

</details>

### 2. Populate your requirements context

Before generating anything, give the agent a clear picture of what to build.

**Steps:**

1. Open Copilot Chat in **Agent** mode (sparkle icon in the chat input).
2. Run:

```text
Read docs/project-overview.md and docs/functional-requirements.md, then fill in the <!-- Copilot: ... --> placeholder in context/iac-requirements.md with a concise summary of what the todo-service is and how it will be hosted.
```

3. Review `context/iac-requirements.md` before continuing.

> **Why this matters:** Populating the requirements file first means you can review and edit the context before generating any code. It also serves as a versioned record of what was built and why.

### 3. Configure the dev stack

**Requirements for the dev stack:**

- Call the golden-path module at `../../modules/todo-service`
- Enable networking (`create_networking = true`) — this is a fresh account with no shared VPC
- Accept `alb_ingress_cidr` as a variable (do not hardcode an IP)
- Leave `backend_image` and `frontend_image` defaulting to `""` — the module creates the ECR repos; images are pushed in a later step
- Include the S3 remote-state backend block, **commented out**, so it can be uncommented in Step 3 without regenerating the file
- Expose at minimum `service_url` and `cluster_name` as outputs

> [!TIP]
> Not sure what any of the requirements above mean? Ask Copilot before running the slash command:
> _"Read `infra/modules/todo-service/` and explain what inputs I need to provide and why."_

**Steps:**

1. Open Copilot Chat in **Agent** mode (sparkle icon in the chat input) and run:

```text
/iac-scaffold
```

2. Find your public IP — run this command in your **local machine's terminal** (not the Codespace terminal):

```bash
curl -s checkip.amazonaws.com
```

3. Update `infra/stacks/dev/terraform.tfvars` with your IP as a `/32` (e.g., `203.0.113.42/32`).

> [!WARNING]
> The `alb_ingress_cidr` variable controls who can reach your Application Load Balancer.
> By Slalom policy you can't use 0.0.0.0 (all the Internet)

> [!NOTE]
> **Use your local machine's IP, not the Codespace's IP.** The Codespace runs in a GitHub-managed cloud VM — its outbound IP is not yours. To find your real public IP, run the command above in your **local machine's terminal** (not the Codespace terminal), or open `https://whatismyip.com` in your browser. Use the result as `x.x.x.x/32` in `terraform.tfvars`.

> [!TIP]
> If you are not sure how to set the variable, ask Copilot:
> _"This my public ip `"your-ip"` then update `alb_ingress_cidr` in `infra/stacks/dev/terraform.tfvars` to that IP as a /32."_

**What's happening:**

`/iac-scaffold` loads `.github/prompts/iac-scaffold.prompt.md` as your agent instruction. The agent reads `context/iac-requirements.md` and `.github/copilot-instructions.md`, then updates `infra/stacks/dev/main.tf` to call the Slalom golden-path module with the correct inputs.

**Why this approach?**

Storing the prompt in a versioned file (`.github/prompts/`) and the requirements in a separate context file means the generation recipe is repeatable, reviewable, and auditable — any team member can re-run it and get the same result. It also mirrors how platform teams ship golden paths in practice: the prompt is the runbook, the context file is the ADR.

### 4. Review the generated configuration

Read through `infra/stacks/dev/main.tf` and check:

- [ ] Module source points to `../../modules/todo-service` (the local golden-path module copy)
- [ ] `create_networking = true`
- [ ] `alb_ingress_cidr` is set as a variable (not hardcoded)
- [ ] `backend_image` and `frontend_image` default to `""` (ECR repos will be created by the module)
- [ ] S3 backend block is present but **commented out** (will be uncommented in Step 3)
- [ ] Outputs include at minimum `service_url` and `cluster_name`

### 5. Run policy checks

> [!IMPORTANT]
> "OK errors" will be seen and can be ignored. The same would be seen through Copilot and it gives an explanation, e.g.
> ```plain
> ...
> This is expected with mock credentials. The data "aws_availability_zones" source makes a real EC2 API call during planning. The skip_* provider flags suppress credential validation but > don't suppress data source calls. This will succeed in Step 3 when real OIDC credentials are injected by CI.
> ...
> checkov — 61 passed, 17 failed, 2 skipped
> Important: every single failure is in ../../modules/todo-service/main.tf — the golden-path module. Your stack file (main.tf) has zero checkov findings. These are module-level issues > owned by the platform team, not your stack.
> ...
> ```

Instead of copy-pasting commands, ask Copilot to handle validation:

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Validate my Terraform stack — run terraform init -backend=false, tflint, checkov, and terraform plan. Report any findings."_

<details>
<summary>Or run manually if you prefer:</summary>

From the `project` root

```bash
# Initialize Terraform (S3 backend is commented out, so plain init works locally)
terraform --chdir=infra/stacks/dev init -backend=false

# Validate syntax and config
terraform --chdir=infra/stacks/dev validate

# Run tflint
tflint --chdir=infra/stacks/dev

# Run checkov security scan
checkov -d infra/stacks/dev --framework terraform --compact

# Preview the plan (uses mock provider — no real AWS needed)
terraform --chdir=infra/stacks/dev plan -var="alb_ingress_cidr=10.0.0.0/8" -var-file=terraform.tfvars
```

</details>

### 6. Commit, push, and open the PR

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Commit my changes, push to `feat/pe-golden-path`, and open a pull request into `main` with the title 'feat: todo-service golden path'."_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
git add .
git commit -m "feat(iac): configure dev stack to use slalom-terraform-pe-lab-ecs-app module"
git push origin feat/pe-golden-path

gh pr create --title "feat: todo-service golden path" --base main
```

</details>

Opening the PR triggers step detection. The automation will:

1. Open **Step 2 — CI/CD Pipeline**

> [!NOTE]
> You'll keep using this same branch and PR for Steps 2 and 3. Each time you push, the PR updates automatically and triggers the next detection check.

## Completion Criteria

**Your PR is detected when it adds or modifies files under `infra/` and `infra/stacks/dev/main.tf` references the `slalom-terraform-pe-lab-ecs-app` module via the local path `../../modules/todo-service`.**

## Hints

> [!TIP]
>
> - The module source uses a relative path to the local copy: `../../modules/todo-service`
> - `terraform init` works without any flags because the S3 backend block is commented out — no AWS credentials needed for Steps 1–2
> - If `terraform plan` fails on the mock provider, that's expected for some resource types — `terraform validate` is the real gate here
> - Ask Copilot: _"What does `create_networking = true` do in this module? When would you set it to false?"_

---

_Step 1 of 4 — [Next: CI/CD Pipeline]_
