# Documentation

Audience: engineers and AI agents working on this app. Start here.

| Document | Purpose |
|---|---|
| [`local-kubernetes.md`](local-kubernetes.md) | Run the app locally on k3d (beginner-friendly). |
| [`helm-chart.md`](helm-chart.md) | The Helm chart, values strategy, and local vs cloud differences. |
| [`aws-access.md`](aws-access.md) | How the `dev` app is reached (hostname, TLS, ALB). |
| [`ci-cd.md`](ci-cd.md) | The deploy pipeline and its required variables. |
| [`PLAN.md`](PLAN.md) | The delivery plan (mirror of the workspace plan). |

## Source of truth
- Delivery plan: the workspace `PLAN.md` (this repo keeps a synced copy).
- Task tracking: the workspace `TASKS.yaml`.
- Application objects: `charts/todolist/` — do not manage them with ad-hoc `kubectl apply`.

## Conventions
- English throughout.
- No environment-specific values (account IDs, ARNs, hostnames) in committed docs.
