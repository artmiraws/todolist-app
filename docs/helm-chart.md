# Helm chart (AWS dev)

The `charts/todolist` chart packages the application for the AWS `dev` environment. Local
development keeps using the plain manifests in `k8s/` through `make up`; the chart targets EKS and
does not depend on a local PostgreSQL.

## What it renders

| Resource | Purpose |
|---|---|
| Deployment | App pods (image by digest, ConfigMap env, secret files, probes, resources) |
| Service | ClusterIP on port 80 |
| Ingress | ALB through the AWS Load Balancer Controller (Helm-owned) |
| ConfigMap | Non-sensitive configuration (`APP_*`, `DB_HOST/PORT/NAME`) |
| ExternalSecret | Syncs DB and app credentials from Secrets Manager through the `aws-secrets-manager` ClusterSecretStore |
| ServiceAccount + Role/RoleBinding | Lets `/pods` and `/cleanup/status` query the Kubernetes API |
| HorizontalPodAutoscaler | CPU-based scaling (2-6 replicas) |
| PodDisruptionBudget | `minAvailable: 1` for safe node drains |
| CronJob | Calls the cleanup endpoint every 5 minutes |

## Values

See `values.yaml` and `values-dev.example.yaml`. The relevant AWS dev values are:

- `image.repository` / `image.digest`: ECR repository and immutable digest.
- `config.dbHost`: the Aurora writer endpoint (`tofu output -raw db_cluster_endpoint`).
- `externalSecret.dbSecretArn`: the RDS-managed secret ARN
  (`tofu output -raw db_master_user_secret_arn`).
- `externalSecret.appSecretArn`: optional application secret with `SESSION_KEY`, `ADMIN_USER`,
  `ADMIN_PASSWORD`, and `CLEANUP_TOKEN`.
- `ingress.host` and `ingress.annotations`: documented hostname and ALB/certificate settings.

No secret value is written to a values file; the chart references secret ARNs only.

## Local vs cloud differences

| Concern | Local (`k8s/`, k3d) | AWS dev (this chart) |
|---|---|---|
| Database | PostgreSQL Deployment in the cluster | Aurora PostgreSQL in private subnets |
| Credentials | Plain `Secret` (`k8s/secret.yaml`) | `ExternalSecret` from Secrets Manager through ESO |
| Ingress | Traefik, no hostname | ALB with the documented hostname and ACM |
| Image | `todolist-app:local` imported into k3d | ECR image referenced by digest |
| Secrets directory | `/var/run/secrets/todolist` | Same path, files written by ESO |

## Schema startup and rolling updates

The application calls `db.create_all()` at startup. With more than one replica, concurrent schema
creation can race on first boot. For this dev proof of concept the schema is created when the first
pod starts; production should use a migration tool or a single migration Job before the rollout. The
Deployment uses `maxUnavailable: 0` / `maxSurge: 1` and a PodDisruptionBudget with
`minAvailable: 1`, so rolling updates keep at least one pod serving.

## Ownership

This chart owns the application's Kubernetes objects, including the `ExternalSecret`. The
infrastructure repository owns the External Secrets Operator, its IRSA role, and the
`ClusterSecretStore` (ADR-001, ADR-010). The two never manage the same object.

## Deploy

```bash
helm upgrade --install todolist charts/todolist \
  --namespace todolist --create-namespace \
  -f charts/todolist/values-dev.yaml
```

CI generates `values-dev.yaml` from the Terraform outputs and the ECR image digest (EPIC-6).
