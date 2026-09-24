---
mode: agent
description: Prepare the Mini Golden Path for PR submission - consolidate branches, generate lockfiles, and gather evidence
---

You are preparing a Mini Golden Path implementation for PR submission. Follow these steps:

## Step 1: Consolidate branches (if needed)

Check if there are separate feature branches that need to be merged:

- `feat/pe-iac-module`
- `feat/pe-ci-pipeline`

> If they exist, create a consolidated branch and merge them. If working in a single branch, skip this step.

## Step 2: Generate required lockfiles

Generate lockfiles to prevent CI errors:

**npm lockfiles:**

- Run `npm install` from the workspace root
- Add `package-lock.json` and `packages/*/package-lock.json` to git

Commit these lockfiles with descriptive messages.

## Step 3: Gather evidence

Run validation commands and report results:

**Terraform plan output:**

- Change to `infra/stacks/dev`
- Run `terraform plan -var-file=terraform.tfvars`
- Show the last 20 lines of output

**Checkov security scan:**

- Run `checkov -d infra/modules/todo-service --framework terraform --compact`
- Report scan results

## Step 4: Create summary

Provide a summary of:

- Which lockfiles were generated/updated
- Validation results (pass/fail for each check)
- Any issues found that need to be addressed
- Confirmation that the PR is ready to be opened

> If any validations fail, provide specific guidance on how to fix the issues.

Execute all commands using the terminal and provide clear status updates for each step.
