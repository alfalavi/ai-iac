---
mode: agent
description: Generate a comprehensive description for the Mini Golden Path implementation and save it to /tmp/pr-body.md
---

Read `docs/functional-requirements.md` for the full acceptance criteria, then examine
the diff between `main` and the current branch (which merges `feat/pe-iac-module`
and `feat/pe-ci-pipeline`).

Write a GitHub Pull Request description with these sections:

## Summary

## What Changed

## Why This Matters

## How to Adopt This Golden Path

Three-step quickstart for a new team picking up this golden path for the first time.

## Evidence

- [ ] terraform plan output
- [ ] checkov scan — 0 HIGH findings
- [ ] CI workflow passing

## Checklist

- [ ] IaC module follows coding standards
- [ ] No hardcoded secrets or account IDs
- [ ] All resources tagged (`environment`, `service`, `managed_by`)
- [ ] Required CI checks defined
- [ ] Runbook has `runbook_url` referenced in each alert rule

Make it professional, concise, and focused on the value delivered to the next team.

When done, save the output to `/tmp/pr-body.md`.
