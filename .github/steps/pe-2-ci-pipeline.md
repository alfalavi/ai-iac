# Step 2 — CI/CD: Reusable Pipeline Template

> [!IMPORTANT]
> **Before starting:** Make sure you're on `feat/pe-golden-path` (`git checkout feat/pe-golden-path`). All your work goes on this same branch — no new branch needed.

> [!NOTE]
> **Goal:** Create a reusable GitHub Actions workflow that encodes all required checks for the golden path, then wire the todo-service to use it.

## Context

A golden path only works if the CI pipeline is as easy to adopt as the IaC module. Your task is to create a reusable `workflow_call` template that runs lint, test, security scan, and terraform plan — then create a caller workflow for the todo-service that adopts it with a single `uses:` line.

## What You Will Build

```text
.github/workflows/
├── golden-path-ci.yml        ← Reusable workflow (workflow_call)
└── todo-service-ci.yml       ← Caller workflow for this service
```

## Instructions

### 1. Populate your requirements context

Before generating any workflows, give the agent a clear picture of what to build.

**Steps:**

1. Open Copilot Chat in **Agent** mode (sparkle icon in the chat input).
2. Run:

```text
Read docs/project-overview.md and docs/functional-requirements.md, then fill in the <!-- Copilot: ... --> placeholder in context/ci-requirements.md with a concise summary of the tech stack that CI must validate (Node.js version, test framework, IaC tool).
```

3. Review `context/ci-requirements.md` before continuing.

> **Why this matters:** Keeping requirements in a versioned file — not in chat — means you can re-run the workflow generator at any time with the same context. It also makes requirements reviewable in PRs alongside the code they describe.

> [!TIP]
> Not sure what belongs in the requirements file? Ask Copilot first:
> _"Read `context/ci-requirements.md` and explain what I need to fill in and why each field matters for CI."_

### 2. Generate the reusable workflow

> [!TIP]
> Not sure how `workflow_call` or reusable workflows work? Ask Copilot before running the slash command:
> _"Explain the difference between `workflow_call` and `workflow_dispatch` in GitHub Actions, and show me a minimal reusable workflow example."_

**Steps:**

1. Open Copilot Chat in **Agent** mode (sparkle icon in the chat input) and run:

```text
/ci-pipeline
```

> **What's happening:** `/ci-pipeline` loads `.github/prompts/ci-pipeline.prompt.md` as your agent instruction. That prompt reads `context/ci-requirements.md` (the file you just populated) and `.github/copilot-instructions.md`, then writes both workflow files to `.github/workflows/`. Requirements and prompt are kept separate so the recipe is reusable.

### 3. Review the generated workflows

Check each file:

- [ ] `golden-path-ci.yml` uses `on: workflow_call:` (not `on: push`)
- [ ] `todo-service-ci.yml` uses `jobs.<job>.uses:` pointing to `golden-path-ci.yml`
- [ ] `permissions:` blocks present on both files
- [ ] Action versions are pinned (e.g., `actions/checkout@v4` not `@main`)
- [ ] Jobs have meaningful `name:` fields
- [ ] At least one job uses `if:` to conditionally run terraform steps

### 4. Add documentation

> [!TIP]
> Not sure what the docs should cover? Ask Copilot first:
> _"Read `.github/workflows/golden-path-ci.yml` and describe what each job does and why it exists — as if explaining to a new team adopting this pipeline."_

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:

```text
/ci-pipeline-docs
```

2. Review `docs/ci-pipeline.md` before continuing.

> This runs `.github/prompts/ci-pipeline-docs.prompt.md`, which reads the generated workflows and produces `docs/ci-pipeline.md`.
>
> **Why this matters:** Generated workflows can be hard to onboard into without written context. Documentation captures the intent behind each job — what it checks and why — so future adopters can extend or debug the pipeline without reverse-engineering the YAML.

### 5. Validate and commit workflows

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Validate my workflow YAML files, then commit them with the documentation to `feat/pe-golden-path` and push. Use conventional commit messages."_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
# Quick local validation (no actual run needed)
npx js-yaml .github/workflows/golden-path-ci.yml
npx js-yaml .github/workflows/todo-service-ci.yml

# Commit and push to the existing branch
git add .github/workflows/golden-path-ci.yml .github/workflows/todo-service-ci.yml docs/ci-pipeline.md
git commit -m "feat(ci): add golden-path reusable workflow and todo-service caller"
git push origin feat/pe-golden-path
```

</details>

## Completion Criteria

Push `golden-path-ci.yml` and `todo-service-ci.yml` to `feat/pe-golden-path`. The step-detection workflow triggers automatically when those files are present in the PR and will:

1. Open **Step 3 — Terraform Apply**

Detection checks that `golden-path-ci.yml` uses `workflow_call` and that `todo-service-ci.yml` calls it via `uses:`.

### _Workflow run errors at this stage are expected._

> [!WARNING]
> **Workflow run errors at this stage are expected.**
>
> The `terraform-plan` and any AWS-facing jobs will fail because `infra/stacks/dev/main.tf` still uses mock credentials — that is intentional. The mock credentials allow local validation in Step 1 but are not valid for a real AWS account. You will remove them and enable the S3 backend in Step 3. For now, a passing `lint`, `test`, and `security-scan` job is all that is required to advance.

## Hints

> [!TIP]
>
> - If you're unsure about `workflow_call` syntax, ask: _"Show me a minimal reusable GitHub Actions workflow with a boolean input"_
> - The `checkov` job can use `bridgecrew/checkov-action@v12` — ask Copilot to find the correct pinned SHA
> - Coverage thresholds go in `packages/backend/jest.config.js` under `coverageThreshold`

> [!WARNING]
> **"Dependencies lock file is not found" error?**
> Do not set `cache: 'npm'` on `actions/setup-node` — this repo has no lock files and the job will fail immediately. Remove the `cache:` line entirely from your `setup-node` step.

---

_Step 2 of 5 — [Previous: IaC Scaffold] · [Next: Adjust Terraform Code]_
