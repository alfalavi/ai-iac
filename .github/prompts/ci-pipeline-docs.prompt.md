---
mode: agent
description: Generate docs/ci-pipeline.md explaining the golden-path reusable workflow
---

Read `.github/workflows/golden-path-ci.yml` and `.github/workflows/todo-service-ci.yml`,
then generate `docs/ci-pipeline.md` that explains:

- What `golden-path-ci.yml` does and why each job exists
- How a new service team adopts it (show the minimum `todo-service-ci.yml` caller)
- What each required check validates and why it is required
- How to configure secrets (OIDC role ARN) for the `terraform-plan` job
