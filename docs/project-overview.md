# Project Overview — Todo Service

## What This Project Is

The **Todo Service** is a simple full-stack task management application used as the baseline service for the Platform Engineering golden path lab. It represents the kind of internal CRUD service that teams build frequently — stateless API, React frontend, persistent storage.

The goal of this lab is **not** to change the service itself, but to build the platform infrastructure around it: IaC, CI/CD, and observability, all as code.

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Browser                                                   │
│  React SPA (packages/frontend) — port 3000                 │
└───────────────────────┬────────────────────────────────────┘
                        │ HTTP/REST
┌───────────────────────▼────────────────────────────────────┐
│  Express API (packages/backend) — port 4000                │
│  Routes: GET/POST/PUT/DELETE /api/todos                    │
│  Services: todoService.js (in-memory store)                │
└────────────────────────────────────────────────────────────┘
```

In the golden path, this service would be containerised and deployed to **AWS ECS Fargate** behind an Application Load Balancer, with logs and metrics collected via CloudWatch and Container Insights.

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 |
| Backend | Node.js 20 + Express 4 |
| Testing | Jest |
| Package management | npm workspaces |
| Containerization | Docker (target) |
| IaC | Terraform >= 1.5, AWS provider ~> 5.0 |
| CI/CD | GitHub Actions |
| Observability | CloudWatch Logs + Container Insights |

## Repository Structure

```
packages/
  backend/             Express API
    src/
      app.js           Express app setup + Prometheus metrics middleware
      index.js         Server entrypoint
      services/
        todoService.js  Business logic (CRUD, in-memory)
    __tests__/         Jest tests
  frontend/            React SPA
    src/
      App.js           Root component
      components/      TodoList, TodoCard, TodoForm, etc.
      services/
        todoService.js  API client
infra/stacks/dev/      Dev stack calling the Slalom PE Lab golden-path module (configured in Step 1)
.github/workflows/     CI/CD (built in Step 2)
```

## Key Design Decisions

1. **In-memory storage** — the backend uses a simple in-memory array for todos. This is intentional for the lab; a real golden path would include a managed database module.
2. **CloudWatch observability** — the ECS module provisions CloudWatch log groups for both containers and enables Container Insights on the cluster for task-level metrics.
3. **npm workspaces** — frontend and backend share a single `package.json` root for unified dependency management.
