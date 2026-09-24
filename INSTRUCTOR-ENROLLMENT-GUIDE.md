# Instructor Enrollment Guide

This guide explains what an instructor needs to do to onboard new students into the PE Bootcamp lab — including how each student gets their own isolated VPC and Terraform state file, and why the OIDC + per-cohort IAM role approach requires the least possible setup.

---

## Table of Contents

1. [What You Need Before Students Begin](#1-what-you-need-before-students-begin)
2. [Enrolling Students](#2-enrolling-students)
3. [How Each Student Gets Their Own VPC](#3-how-each-student-gets-their-own-vpc)
4. [How Each Student Gets Their Own Terraform State File](#4-how-each-student-gets-their-own-terraform-state-file)
5. [Why OIDC + a Per-Cohort Role Is the Right Approach](#5-why-oidc--a-per-cohort-role-is-the-right-approach)
6. [Why a Single Shared AWS Account Works Well Here](#6-why-a-single-shared-aws-account-works-well-here)
7. [Instructor Checklist](#7-instructor-checklist)
8. [Troubleshooting Common Issues](#8-troubleshooting-common-issues)

---

## 1. What You Need Before Students Begin

The following items are **one-time setup items** that already exist in the `aws-innovationlabs-guadalajara` account. Nothing in this section needs to be repeated for each new student. Items marked as **per-cohort** must be done once before each new cohort begins.

| Prerequisite | Details |
| --- | --- |
| AWS account | `aws-innovationlabs-guadalajara` — single shared account, primary region `us-east-1` |
| VPC capacity | Account is pre-approved for **50 concurrent student VPCs** in `us-east-1` |
| GitHub OIDC provider | `token.actions.githubusercontent.com` registered once in the AWS account |
| S3 state bucket | `pe-labs-terraform-state` in `us-east-2`, encryption and versioning enabled |
| IAM role **(per cohort)** | A new IAM role is created for each cohort. Contact Mario Tristan to get your cohort's IAM role ARN before the session. |
| Template repository | This repo configured as a GitHub template so students can create their own private copy |

Because the OIDC provider and S3 bucket are already in place, and each cohort gets a fresh IAM role, **enrolling a new student within a cohort requires no AWS changes beyond updating the trust policy**. The instructor only needs to add the student's username and share the cohort role ARN.

---

## 2. Enrolling Students

Students can be enrolled **before the session starts**. The only information the instructor needs is each student's GitHub username. There is no need to wait for students to create their repositories — enrollment is done entirely on the AWS side in advance.

### Step 1 — Collect GitHub usernames

Before the session, collect the GitHub username of each participant. Verify each username is a member of the Slalom GitHub org — that org membership is your confirmation they are a registered participant. No other information is needed.

### Step 2 — Add all usernames to the cohort role trust policy in one update

Each cohort has its own IAM role (e.g., `innovation-labs-pipelines-cohort-3`). Open that role in IAM and update the `StringLike` condition array with all student usernames at once:

If you need detailed IAM role update instructions, follow the role management guide here: https://github.com/Slalom/innovation-labs-latam/blob/main/docs/iam-role-management.md

```json
"token.actions.githubusercontent.com:sub": [
  "repo:existing-student/*",
  "repo:new-student-github-username/*"
]
```

Each entry follows the pattern `repo:<github-username>/*`, which allows that student's GitHub Actions workflows to assume the role from any repo under their account. Do this for the entire cohort in a single trust policy update before the session — no per-student AWS changes are needed on the day.

A full trust policy with multiple students enrolled looks like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:jdoe/*",
            "repo:asmith/*",
            "repo:mlopez/*"
          ]
        }
      }
    }
  ]
}
```

> **Why enumerate usernames instead of allowing all GitHub accounts?**
> Keeping the list explicit ensures only known Slalom participants can use the role. An open trust policy (`repo:*`) would allow any GitHub Actions workflow worldwide to attempt role assumption. Listing usernames takes 30 seconds per student and limits the blast radius if the role's permission policy ever gets misconfigured.

#### Tightening the scope further — repo-level restrictions

If participants share their repo names before the session (e.g., via a sign-up form), the trust policy can be scoped to specific repositories instead of all repos under a username. Replace the `/*` wildcard with the exact repo name and an optional branch pattern:

```json
"token.actions.githubusercontent.com:sub": [
  "repo:jdoe/copilot-bootcamp-pe:ref:refs/heads/*",
  "repo:asmith/copilot-bootcamp-pe:ref:refs/heads/*"
]
```

This means the role can only be assumed from that exact repository, on any branch. Even if a student's GitHub account were compromised, no other repo under their account could use the role. The tradeoff is that the instructor must know repo names in advance and update the policy if a student renames their repo.

### Step 3 — Instructor shares the cohort role ARN with the student

A new IAM role is provisioned for each cohort, so the ARN is unique per cohort. Contact Mario Tristan before the session to obtain it. It will follow the pattern:

```text
arn:aws:iam::<ACCOUNT_ID>:role/innovation-labs-pipelines-<cohort-id>
```

The student adds it to their repository:

- Go to **Settings → Secrets and variables → Actions**
- Create a secret named `AWS_ROLE_ARN`
- Paste in the role ARN above

That is all the student ever needs to do. No access keys, no AWS Console login, no account of their own.

### Step 3 — Students discover the `alb_ingress_cidr` themselves

Finding the correct `alb_ingress_cidr` is part of the learning exercise. Students will determine their own IP/CIDR as a step within the lab — no instructor input is required.

---

## 3. How Each Student Gets Their Own VPC

Every student who runs a `terraform apply` gets a fresh, isolated VPC automatically. This is handled by the Terraform module at [infra/modules/todo-service/](infra/modules/todo-service/). The `aws-innovationlabs-guadalajara` account in `us-east-1` is provisioned to support **up to 50 concurrent student VPCs**, enough for large cohorts without any quota increase requests.

When `create_networking = true` (always the case in the dev stack), the module provisions:

| Resource | Details |
| --- | --- |
| VPC | 10.42.0.0/16 CIDR (configurable via `vpc_cidr`) |
| Public subnets | 2x /24, across two availability zones |
| Private subnets | 2x /24, across two availability zones |
| Internet Gateway | Attached to the VPC |
| NAT Gateway | 1x in a public subnet with an Elastic IP, routes private outbound traffic |
| Route tables | Public (IGW route) + private (NAT route) |
| Security groups | ALB SG (ingress from `alb_ingress_cidr`) + ECS task SG (ingress from ALB only) |

**Resource naming** includes a random suffix (e.g., `dev-todo-service-alb-abc123`) to prevent name collisions when multiple students deploy to the same account simultaneously.

**ALB ingress restriction** — `alb_ingress_cidr` is required and cannot be `0.0.0.0/0`. This is enforced by a Checkov policy in the CI pipeline. Students determine their own CIDR as part of the lab exercise, so load balancers are scoped to their IP rather than exposed to the public internet.

**No manual networking setup** is ever needed by the student. The module is self-contained and creates everything from scratch on first apply.

---

## 4. How Each Student Gets Their Own Terraform State File

All students share a single S3 bucket (`pe-labs-terraform-state` in `us-east-2`), but each student's state is stored under a unique key path derived from their GitHub username:

```text
s3://pe-labs-terraform-state/
  todo-service/
    jdoe/
      dev/
        terraform.tfstate
    asmith/
      dev/
        terraform.tfstate
```

The key is injected by CI at runtime during `terraform init`:

```bash
terraform init -reconfigure \
  -backend-config="key=todo-service/${{ github.repository_owner }}/dev/terraform.tfstate"
```

Because `github.repository_owner` is the student's GitHub username, the key is unique per student with no manual configuration required. The instructor never needs to pre-create folders or state files — S3 creates the object on first `terraform apply`.

**Why not Terraform workspaces?** Workspaces share the same backend configuration and require coordinated naming. The key-path approach is simpler: each student's state is fully independent, and `terraform destroy` in one repo has zero impact on any other student's state.

**Backend config in the repo** — The backend block in `infra/stacks/dev/main.tf` is intentionally commented out when students first clone the repo. This allows Steps 1 and 2 (local validation, `terraform init -backend=false`) to work without any AWS credentials. The CI pipeline uncomments and configures the backend during `terraform apply` in Step 3.

---

## 5. Why OIDC + a Per-Cohort Role Is the Right Approach

### How it works

GitHub Actions has built-in support for OIDC. When a workflow job runs, GitHub can issue a short-lived JWT token signed by GitHub's OIDC provider. The job presents that token to AWS STS, which validates it against the registered OIDC provider and issues temporary credentials scoped to the assumed role. No secrets change hands — the token is generated fresh for every run and expires when the job ends.

```text
GitHub Actions job
  → requests OIDC token from GitHub (JWT, expires in minutes)
  → calls sts:AssumeRoleWithWebIdentity with that token
  → AWS validates token signature against token.actions.githubusercontent.com
  → issues short-lived STS credentials for innovation-labs-pipelines
  → job uses credentials; they expire automatically when job ends
```

### The trust policy on the cohort role

Each cohort gets its own IAM role (e.g., `innovation-labs-pipelines-cohort-3`). The role's trust policy uses a `StringLike` condition to enumerate the GitHub usernames of enrolled students. Only workflows running under a listed username can assume the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:jdoe/*",
            "repo:asmith/*"
          ]
        }
      }
    }
  ]
}
```

Adding a new student means adding one line (`"repo:<username>/*"`) to the array. Removing a student after the lab is equally simple. The instructor needs only the student's GitHub username — verified by checking that they are a member of the Slalom GitHub org.

> **Security note:** The permission policy attached to the role should be scoped to the resources the lab needs: ECS, ECR, VPC in `us-east-1`, and the `pe-labs-terraform-state` S3 bucket in `us-east-2`. The role should not have `AdministratorAccess`. The combination of an explicit username list in the trust policy and a tight permission policy keeps the shared role safe.

### Why one role per cohort is simpler than per-student roles

| Approach | IAM changes per new student | Role ARN to distribute | Cleanup after lab |
| --- | --- | --- | --- |
| One role per student repo | Create role + attach policy | Different ARN per student | Delete N roles |
| One role per GitHub username | Create role + attach policy | Different ARN per student | Delete N roles |
| **One role per cohort (this approach)** | **Add one line to trust policy** | **Same ARN for all students in the cohort** | **Delete one role per cohort** |

With a single cohort role, enrollment is: **add one username to the trust policy, share one ARN and a CIDR**. No per-student roles, no new policies, no extra secrets to manage in AWS. After the lab, the entire cohort role can be deleted in one action.

### No long-lived credentials

With static access keys (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`), credentials must be:

- Generated manually in the AWS Console per student
- Stored as secrets in each repo
- Rotated regularly
- Revoked when a student finishes the lab

With OIDC, **there are no credentials to manage**. There is nothing to rotate, nothing to revoke, and nothing that can be leaked from a student's repo. A student finishing the lab just stops pushing to their repo — the role cannot be accessed from outside of GitHub Actions.

### No workflow changes needed per student

Once the student adds the `AWS_ROLE_ARN` secret, the single configure step in the workflow handles everything:

```yaml
- name: Configure AWS credentials via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

Students never interact with credentials directly. This also teaches the correct real-world pattern — OIDC is the recommended approach for CI/CD authenticating to AWS, and students leave the lab having used it in a real pipeline.

### Required workflow permission

The caller workflow must declare `id-token: write` so GitHub issues the OIDC token:

```yaml
permissions:
  contents: read
  id-token: write
```

This is an explicit opt-in. Without it, GitHub does not issue the token and the OIDC exchange fails with a clear error — easy to diagnose.

---

## 6. Why a Single Shared AWS Account Works Well Here

Rather than provisioning a separate AWS account per student (or per cohort), all student infrastructure lives in `aws-innovationlabs-guadalajara`. This is an intentional design decision.

### Instructor control over resources

The platform team owns the account. Students never log into the AWS Console — they only interact with AWS through GitHub Actions and the outputs shown in CI run summaries. This means:

- Students cannot accidentally leave expensive resources running in an account they control
- The instructor can audit all deployed resources from one place using the `pe-lab` resource tag
- The instructor can forcibly destroy any student's stack by running the destroy workflow manually

### Simplified cost management

With a single account, billing is centralized:

- One budget alert covers the entire cohort
- All student resources are tagged `pe-lab = true` and can be filtered in Cost Explorer
- After the lab, a simple tag-based query confirms all resources were destroyed

### No account provisioning overhead

Creating AWS accounts under Organizations involves account creation, SCP configuration, permission boundary setup, budget alerts, and cross-account IAM for any shared tooling. For a bootcamp that runs for a few hours and tears everything down, this overhead is not justified.

One account with isolated VPCs per student achieves the same isolation at a fraction of the operational cost. The pre-approved 50 VPC limit in `us-east-1` means the account can support a full cohort without any quota changes.

### Mirrors a real platform engineering pattern

In production, platform teams often use a single "workloads" account and provision isolated resources — separate VPCs, namespaces, or clusters — for each service team. Students experience this pattern directly: they are the service team, the instructor is the platform team, and `aws-innovationlabs-guadalajara` is the landing zone.

### Isolation between students

Even with a shared account and a shared role, students are fully isolated:

| Layer | Mechanism |
| --- | --- |
| Network | Separate VPC per student; non-overlapping CIDRs |
| State | Separate S3 key path per student (`todo-service/<github-username>/dev/terraform.tfstate`) |
| Naming | Random suffix on all resources prevents collisions |
| Identity | All students use the same role, but resources are namespaced by GitHub username via state key |

A student's `terraform destroy` only affects the resources in their own state file. Naming collisions are prevented by the random suffix on every resource the module creates.

---

## 7. Instructor Checklist

### One-time setup (already done in `aws-innovationlabs-guadalajara`)

- [x] GitHub OIDC provider registered (`token.actions.githubusercontent.com`)
- [x] S3 bucket `pe-labs-terraform-state` created in `us-east-2` with versioning and encryption
- [x] VPC limit in `us-east-1` raised to support 50 concurrent student VPCs

### Per cohort — before the session (instructor)

- [ ] Contact Mario Tristan to provision a new IAM role for this cohort (e.g., `innovation-labs-pipelines-cohort-<N>`) with OIDC trust policy and lab permission policy
- [ ] Collect GitHub usernames from all participants; verify each is a Slalom org member
- [ ] Add all usernames to the cohort role trust policy in one update (`"repo:<username>/*"` per student)
- [ ] Share with all students: cohort role ARN `arn:aws:iam::<ACCOUNT_ID>:role/innovation-labs-pipelines-<cohort-id>`

### On the day (student, no AWS action required)

- [ ] Student creates their private repo from the template
- [ ] Student adds `AWS_ROLE_ARN` secret with the shared role ARN
- [ ] Student determines their `alb_ingress_cidr` as part of the lab exercise

### After the lab

- [ ] Confirm each student has run `pe-terraform-destroy.yml` (manual workflow dispatch in their repo)
- [ ] Verify no tagged `pe-lab` resources remain in the account (tag-based resource search)
- [ ] Delete the cohort IAM role (removes access for all students in one action)

---

## 8. Troubleshooting Common Issues

### `Error: No credentials found` during terraform-apply

- Student has not added `AWS_ROLE_ARN` as a repository secret
- The workflow is missing `id-token: write` in permissions
- The caller workflow is not passing `run_terraform_apply: true`

### `Error: Not authorized to perform AssumeRoleWithWebIdentity`

- The role ARN in the secret has a typo
- The OIDC provider is not registered in the account (check IAM → Identity providers)
- The `aud` condition in the trust policy does not match `sts.amazonaws.com`

### Terraform state conflict / `state lock` error

- Two workflow runs tried to apply simultaneously (e.g., two rapid pushes to main)
- Wait for the first run to complete; the lock releases automatically

### `alb_ingress_cidr` rejected by Checkov

- Student used `0.0.0.0/0` — provide them the correct CIDR to use
- This check is intentional and cannot be skipped

### Destroy workflow fails

- The student did not reach Step 3; there is no real backend configured yet
- Resources can be cleaned up manually in the AWS Console filtered by the `pe-lab` tag
