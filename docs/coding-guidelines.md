# Coding Guidelines

## JavaScript / Node.js

- Use `const` and `let`; never `var`
- Use `async/await` over raw Promises or callbacks
- Export a configured `app` from `app.js`; keep `index.js` as the entrypoint only
- Error responses must include `{ error: string, message: string }` shape
- Use `express-validator` for input validation at API boundaries
- All route handlers should be `async` and wrapped in try/catch

## Terraform

- `required_version` and `required_providers` must be present in every module
- Variable names: `snake_case`, required variables before optional ones
- Every variable must have `description` and `type`
- Use `validation {}` blocks for variables with finite valid values (e.g., environment)
- Resource names: `snake_case`, prefixed with service name (e.g., `todo_service_ecs_task`)
- No `count` for single-instance resources; use `for_each` when iterating
- Outputs must have `description` fields
- Do not use `locals` for values that could be variables

## GitHub Actions

- Pin all actions to a full commit SHA, not a tag (e.g., `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`)
- Use `secrets` and `vars` context — never hardcode credentials
- Use `GITHUB_TOKEN` or OIDC for AWS authentication; never IAM user keys
- Job names must be human-readable (sentence case)
- Step names must clearly describe what the step does
- Use `continue-on-error: true` only for informational steps (not required checks)
- Always add `permissions:` at the job or workflow level

## CloudWatch / Container Insights

- Log groups are provisioned by the ECS module — do not create them manually
- Use structured JSON logging in application code so CloudWatch Logs Insights can query fields
- CloudWatch alarm names must be PascalCase (e.g., `HighErrorRate`)
- Alarm thresholds: critical `EvaluationPeriods >= 2`, warning `EvaluationPeriods >= 3`

## Naming Conventions

| Resource | Convention | Example |
|---|---|---|
| Terraform module | kebab-case | `todo-service` |
| Terraform resource | snake_case | `aws_ecs_cluster.todo_service` |
| GitHub Actions workflow | kebab-case | `golden-path-ci.yml` |
| CloudWatch dashboard | kebab-case | `todo-service-overview` |
| CloudWatch alarm | PascalCase | `HighErrorRate` |
