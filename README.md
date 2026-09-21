# TodoList

A web task-list application.

![App main screen](assets/todolist.png)

> How this app is delivered — the platform it runs on, the contract it consumes, and its pipeline —
> is documented in the platform handbook's
> [worked example](https://docs.nexusauto.com.br/onboarding/worked-example/).

## Documentation

| Document | What it covers |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | The delivery plan and the delivered architecture. |
| [`docs/local-kubernetes.md`](docs/local-kubernetes.md) | Running the app locally on k3d/k3s. |
| [`docs/helm-chart.md`](docs/helm-chart.md) | The Helm chart and local vs cloud differences. |
| [Platform handbook](https://docs.nexusauto.com.br/) | How the platform is built, operated, and extended. |

## Stack

- Python 3.11
- Flask
- SQLAlchemy
- PostgreSQL
- gunicorn

## Environment variables

### Application

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `TodoList` | Title shown in the UI |
| `APP_PORT` | `5000` | Server port |
| `APP_COLOR` | *(gray)* | UI theme color. Accepted values below |
| `SESSION_KEY` | `dev-only-insecure-key` | Signs session cookies via HMAC |
| `ADMIN_USER` | `admin` | Login user |
| `ADMIN_PASSWORD` | `admin` | Login password |
| `CLEANUP_TOKEN` | *(empty)* | Token required in the `X-Cleanup-Token` header by `POST /cleanup` |

### Database

| Variable | Default | Description |
|---|---|---|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `todolist` | Database name |
| `DB_USER` | `todolist` | Database user |
| `DB_PASSWORD` | *(empty)* | Database user password |

The schema is created by the app on startup. The database must exist and be reachable before the app
starts.

## File-based credentials

Credentials can come from a file instead of an environment variable. The app looks for a file named
after the variable inside `SECRETS_DIR`, and uses the environment variable only when the file does
not exist.

| Variable | Default | Description |
|---|---|---|
| `SECRETS_DIR` | `/var/run/secrets/todolist` | Directory where the app looks for file-based credentials |

Values that accept a file: `DB_USER`, `DB_PASSWORD`, `SESSION_KEY`, `ADMIN_USER`, `ADMIN_PASSWORD`,
and `CLEANUP_TOKEN`.

Example: with the default `SECRETS_DIR`, a file at `/var/run/secrets/todolist/DB_PASSWORD` is read
instead of the `DB_PASSWORD` variable. Leading/trailing whitespace and newlines are stripped.

## Accepted `APP_COLOR` values

`purple`, `green`, `blue`, `cyan`, `pink`, `red`, `orange`, `brown`, `yellow`.

A missing or invalid value falls back to the gray theme.

## Endpoints

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/` | GET | Session | Task list |
| `/login` | GET, POST | — | Login form |
| `/logout` | GET | Session | Ends the session |
| `/add` | POST | Session | Creates a task |
| `/toggle/<id>` | POST | Session | Toggles a task between done and pending |
| `/delete/<id>` | POST | Session | Deletes a task |
| `/healthz` | GET | — | Checks the database connection and returns `ok` |
| `/cleanup` | POST | `X-Cleanup-Token` header | Removes all completed tasks and returns the count removed |
| `/pods` | GET | Session | Lists the namespace pods |
| `/cleanup/status` | GET, POST | Session | Cleanup run history. POST pauses or resumes the schedule |

## Cleaning up completed tasks

The app does not remove completed tasks by itself. Cleanup must be triggered externally by calling
the endpoint periodically with the token in the `X-Cleanup-Token` header:

```bash
curl -X POST -H "X-Cleanup-Token: $CLEANUP_TOKEN" http://<host>/cleanup
```

The response is the number of tasks removed, as `deleted N`. Without the correct token the endpoint
returns `401`.

The `/cleanup/status` page shows the results of recent runs and lets you pause and resume the
schedule.

## Running locally

Requirements: Python 3.11 and a reachable PostgreSQL.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=todolist
export DB_USER=todolist
export DB_PASSWORD=your-password

export SESSION_KEY=local-key
export ADMIN_USER=admin
export ADMIN_PASSWORD=admin
export CLEANUP_TOKEN=local-token

gunicorn --bind 0.0.0.0:5000 app:app
```

The app is available at `http://localhost:5000`.

## Notes

The app was written to run on Kubernetes. Outside a cluster, some features don't work fully.

## Environment strategy

The delivery plan and the platform decisions live in the platform handbook (the `platform-docs`
repository).

- **Local (k3s in k3d):** developer validation cluster, no AWS cost; not a pipeline stage.
- **Dev (AWS EKS):** the initial cloud scope — a single small, cost-conscious EKS cluster. There is no
  local-to-dev promotion: GitHub Actions builds from source and deploys to dev with Helm.
- **Prod (separate EKS):** an isolated, optional environment, only if time remains after the
  requirements; dev → prod promotion reuses the same tested image digest, with explicit approval.
- **Staging:** future work — a production-like environment for performance and other validation.

## Running on local Kubernetes (k3d)

The recommended way to run the app is inside a local Kubernetes cluster (k3d/k3s) — no cloud
dependency, but the experience mirrors a real deploy.

If you've never used Kubernetes, follow the full guide at
[`docs/local-kubernetes.md`](docs/local-kubernetes.md). It explains each tool, how to install it, and
what each command does.

### Quick start (`make up`)

Prerequisites: [Docker](https://www.docker.com/), [k3d](https://k3d.io/), `kubectl`, and `make`
installed (instructions in [`docs/local-kubernetes.md`](docs/local-kubernetes.md)).

```bash
make up
```

This creates the cluster, builds the image, deploys, and waits for the pods to become ready. The app
is at **http://localhost:8080** (user: `admin` / password: `admin`).

Other useful commands:

| Command | What it does |
|---|---|
| `make status` | Show pod and ingress status |
| `make logs` | Follow the app logs |
| `make health` | Test the app health check (fails on a non-2xx response) |
| `make restart` | Restart the Deployment (to pick up a rebuilt image) |
| `make down` | Remove the app from the cluster (keeps the cluster) |
| `make destroy` | Destroy the cluster |
| `make clean` | Remove the app and destroy the cluster |

### Chart contents (`charts/todolist/`)

The deploy (local and cloud) uses a single Helm chart. Local values live in
`charts/todolist/values-local.yaml`; cloud values are generated by the pipeline.

| Resource | What it does |
|---|---|
| Deployment | The app (probes, resources, image by digest) |
| Service | The app's ClusterIP |
| Ingress | Traefik locally; ALB on AWS |
| ConfigMap | Public variables (APP_NAME, DB_HOST, etc.) |
| Secret | Local credentials (when `secrets.create` is on) |
| ExternalSecret | Cloud credentials via the External Secrets Operator |
| PostgreSQL | Deployment + Service + PVC, local only (`postgresql.enabled`) |
| RBAC | ServiceAccount + Role + RoleBinding (Kubernetes API access) |
| HPA / PDB | Autoscaling (2–6 replicas) and node-drain protection |
| CronJob | Cleanup of completed tasks every 5 minutes |

### Notes

- The `postgres:16-alpine` image is pulled from Docker Hub on the first local deploy.
- The credentials in `values-local.yaml` are for local use **only** — do not use them in production.
  On AWS, the same chart uses the External Secrets Operator and AWS Secrets Manager.
- The HPA depends on `metrics-server` (included in k3s). On a local cluster with little load the CPU
  metric may not appear immediately; the HPA waits for the first reading before scaling.
- The `/pods` and `/cleanup/status` pages require the chart's RBAC permissions. Without them, the app
  returns a friendly message.

## Helm

The chart in [`charts/todolist`](charts/todolist) is the single source of truth for the app's
Kubernetes objects, used both locally (`make up`, with `values-local.yaml`) and on the platform (with
values injected by OpenTofu). Details and local/cloud differences are in
[`docs/helm-chart.md`](docs/helm-chart.md). AWS access (hostname, TLS, ALB), the delivery pipeline,
and the promotion flow live in the platform handbook (the `platform-docs` repository).
