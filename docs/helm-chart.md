# Helm chart

The `charts/todolist` chart is the single source of truth for the application's Kubernetes objects,
used by both local development and AWS dev. Local and cloud differences are expressed only in values
files, never in duplicated manifests.

## Why values are split this way

Values files hold structure and non-sensitive environment configuration. They never hold secret
values, and real cloud identifiers are injected at deploy time instead of being committed:

- `values.yaml` — defaults and structure, shared by every environment.
- `values-local.yaml` — **committed**. Local-only, non-sensitive values (`image.tag: local`,
  in-cluster PostgreSQL, Traefik ingress, a dev-only Secret). Safe to share.
- `values-dev.yaml` — **not committed**. Account ID, ECR repository, secret ARNs, Aurora endpoint,
  hostname, and ACM ARN. CI generates it from the SSM wiring published by the infrastructure
  (`/todolist/dev`), so the repository never contains the account ID and the values cannot drift from
  the infrastructure.
- `values-dev.example.yaml` — committed template with placeholders.
- Secret values (DB password, `SESSION_KEY`, admin password, cleanup token) are never in a values
  file. Locally they come from a chart-managed dev-only Secret; in the cloud they are synced by the
  External Secrets Operator from Secrets Manager.

Rationale: committing real environment values would leak the account ID and would drift every time
dev is torn down and recreated. Deriving them at deploy time from the single source of truth (the
infrastructure's SSM outputs) keeps the repository public-safe and consistent.

## Toggles

| Concern | `values-local.yaml` (committed) | dev (CI / `values-dev.yaml`) |
|---|---|---|
| `postgresql.enabled` | `true` (in-cluster) | `false` (Aurora) |
| `externalSecret.enabled` | `false` | `true` |
| `secrets.create` | `true` (dev-only credentials) | `false` |
| `ingress.className` | `traefik` | `alb` + host + ACM annotations |
| `image` | tag `local` | repository + digest |

`secrets.create` and `externalSecret.enabled` are mutually exclusive; the chart fails to render if
both are set.

## What it renders

| Resource | Purpose |
|---|---|
| Deployment | App pods (image by digest, ConfigMap env, secret files, probes, resources) |
| Service | ClusterIP on port 80 |
| Ingress | ALB through the AWS Load Balancer Controller (Helm-owned) |
| ConfigMap | Non-sensitive configuration (`APP_*`, `DB_HOST/PORT/NAME`) |
| Secret | Local-only credentials when `secrets.create` is true |
| ExternalSecret | Cloud credentials synced from Secrets Manager through the `aws-secrets-manager` store |
| PostgreSQL Deployment/Service/PVC | Local-only database when `postgresql.enabled` is true |
| ServiceAccount + Role/RoleBinding | Lets `/pods` and `/cleanup/status` query the Kubernetes API |
| HorizontalPodAutoscaler | CPU-based scaling (2-6 replicas) |
| PodDisruptionBudget | `minAvailable: 1` for safe node drains |
| CronJob | Calls the cleanup endpoint every 5 minutes |

## Local vs cloud differences

| Concern | Local (k3d) | AWS dev |
|---|---|---|
| Database | PostgreSQL Deployment in the cluster | Aurora PostgreSQL in private subnets |
| Credentials | Chart-managed dev-only `Secret` | `ExternalSecret` from Secrets Manager through ESO |
| Ingress | Traefik, no hostname | ALB with the documented hostname and ACM |
| Image | `todolist-app:local` imported into k3d | ECR image referenced by digest |
| Secrets directory | `/var/run/secrets/todolist` | Same path, files written by ESO |

See [`aws-access.md`](aws-access.md) for the dev hostname, TLS, and the ALB-vs-Service-LoadBalancer
choice.

## Schema startup and rolling updates

The application calls `db.create_all()` at startup. With more than one replica, concurrent schema
creation can race on first boot. For this dev proof of concept the schema is created when the first
pod starts; production should use a migration tool or a single migration Job before the rollout. The
Deployment uses `maxUnavailable: 0` / `maxSurge: 1` and a PodDisruptionBudget with
`minAvailable: 1`, so rolling updates keep at least one pod serving.

## Ownership

This chart owns the application's Kubernetes objects, including the `ExternalSecret`. The
platform repository owns the External Secrets Operator, its IRSA role, and the
`ClusterSecretStore` (ADR-001, ADR-010). The two never manage the same object.

## Deploy

Local (via `make up`):

```bash
helm upgrade --install todolist charts/todolist \
  --namespace todolist --create-namespace \
  -f charts/todolist/values-local.yaml
```

Cloud (CI, EPIC-6): the same command with a generated `values-dev.yaml`.
