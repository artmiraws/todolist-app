# Documentation

Audience: engineers and AI agents working on this app. Start here.

| Document | Purpose |
|---|---|
| [`local-kubernetes.md`](local-kubernetes.md) | Run the app locally on k3d (beginner-friendly). |
| [`helm-chart.md`](helm-chart.md) | The Helm chart, values strategy, and local vs cloud differences. |
| [`aws-access.md`](aws-access.md) | How the app is reached (hostname, TLS, ALB) in `dev` and `prod`. |
| [`ci-cd.md`](ci-cd.md) | GitOps delivery: build/scan/digest (dev), promotion (prod), and releases. |
| [`PLAN.md`](PLAN.md) | The delivery plan (mirror of the workspace plan). |

## Source of truth
- Delivery plan: the workspace `PLAN.md` (this repo keeps a synced copy).
- Task tracking: the workspace `TASKS.yaml`.
- Application objects: `charts/todolist/` — do not manage them with ad-hoc `kubectl apply`.
- Desired image per environment: `charts/todolist/gitops/<env>.yaml` — updated by CI, reconciled by Argo CD.

## Conventions
- English throughout.
- No environment-specific values (account IDs, ARNs, hostnames) in committed docs.
