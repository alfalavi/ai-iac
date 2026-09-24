# Testing Guidelines

## Coverage Targets

| Layer | Minimum Coverage |
|---|---|
| Backend (Express API) | 80% lines + branches |
| Frontend (React) | 70% lines |

## Backend Testing (Jest)

- Test files live in `packages/backend/__tests__/`
- Use `supertest` for API endpoint tests — test the HTTP layer, not the router directly
- Each route should have tests for: happy path, validation errors, edge cases
- `todoService.js` should have unit tests independent of Express

```js
// Good: test the HTTP response shape
const res = await request(app).get('/api/todos');
expect(res.status).toBe(200);
expect(res.body).toEqual(expect.arrayContaining([
  expect.objectContaining({ id: expect.any(String), title: expect.any(String) })
]));
```

## Frontend Testing (Jest + React Testing Library)

- Test files live next to components in `__tests__/` subdirectories
- Test user behaviour, not implementation details
- Avoid testing component internals (state, refs); test what the user sees

## IaC Validation (Not unit tests)

- `terraform validate` — syntax and type checking
- `tflint` — best practice linting
- `checkov` — security policy checks
- These run in CI via the `golden-path-ci.yml` reusable workflow

## CloudWatch Alarm Validation

- Verify CloudWatch alarm thresholds are reasonable before merging
- Verify `runbook_url` links are not 404 before merging
