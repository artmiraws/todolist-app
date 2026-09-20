# Running the app on local Kubernetes

A complete guide to running the TodoList app on a local Kubernetes cluster, from scratch — no prior
Kubernetes experience needed.

---

## 1. What you need

| Tool | What it is | Why you need it |
|---|---|---|
| **Git** | Version control | Clone this repository |
| **Docker** | Container platform | The k8s cluster and the app run as containers |
| **k3d** | Lightweight Kubernetes in Docker | Creates a local k8s cluster without installing anything on the host |
| **kubectl** | CLI to talk to the k8s cluster | Manages resources (deployments, pods, services) |
| **make** | Automation tool | Runs the `Makefile` commands (`make up`, `make down`, etc.) |

> Instructions were validated on Linux (Fedora). macOS and Windows steps are included for reference
> but were not tested.

---

## 2. Installing the tools

Install Git, Docker, k3d, kubectl, and make. Use each project's official instructions for your
distribution — the links below are enough; no need to copy long command blocks.

| Tool | Install |
|---|---|
| Git | [git-scm.com/downloads](https://git-scm.com/downloads) |
| Docker | [Docker Engine](https://docs.docker.com/engine/install/) (free on Linux) |
| k3d | [k3d.io](https://k3d.io/#installation) |
| kubectl | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) — k3d does **not** install it |
| make | your package manager: `sudo dnf install make` (Fedora) / `sudo apt install make` (Ubuntu) |

`k3d` runs a full Kubernetes cluster (k3s) inside a Docker container, so it works with any
Docker-compatible runtime.

> **Docker licensing:** Docker Engine (Linux) is free and open source. **Docker Desktop** is free for
> personal use and small businesses, but requires a paid subscription for larger companies (more
> than 250 employees, or more than US$10M in annual revenue). On macOS/Windows, if that applies, use
> an open-source alternative such as **Colima** or **Rancher Desktop**.

**Verify:**
```bash
git --version
docker --version
k3d version
kubectl version --client
make --version
```

---

## 3. Running the app

### 3.1. All at once (Makefile)

The repository includes a `Makefile` that automates the whole process. Run a **single command** to
create the cluster, build the image, and deploy:

```bash
make up
```

That command will:
1. Create a local k3d cluster (if it doesn't exist)
2. Build the app's Docker image
3. Import the image into the cluster
4. Deploy the Helm chart (app, local database, RBAC, etc.)
5. Wait for the pods to become ready

Then open: **http://localhost:8080** (user: `admin` / password: `admin`)

The deploy uses the chart in `charts/todolist` with the values in
`charts/todolist/values-local.yaml` (PostgreSQL in the cluster and a local Secret). On AWS, the same
chart uses Aurora and the External Secrets Operator; see [`helm-chart.md`](helm-chart.md).

---

### 3.2. Manual step by step

If you prefer to understand each step:

```bash
# 1. Create the k3s cluster inside Docker
#    --agents 1 = 1 extra worker node (besides the server)
#    --port 8080:80 = map Traefik's port 80 (ingress) to 8080 on your machine
k3d cluster create todolist --agents 1 --port "8080:80@loadbalancer"

# 2. Build the app's Docker image (multi-stage Dockerfile)
docker build -t todolist-app:local .

# 3. Import the image into the cluster
#    (without this, the k3d nodes can't pull the image)
k3d image import todolist-app:local -c todolist

# 4. Deploy the Helm chart (uses charts/todolist/values-local.yaml)
helm upgrade --install todolist charts/todolist \
  --namespace todolist --create-namespace \
  -f charts/todolist/values-local.yaml

# 5. Wait for PostgreSQL to be ready
kubectl -n todolist rollout status deploy/todolist-postgres

# 6. Wait for the app to be ready
kubectl -n todolist rollout status deploy/todolist

# 7. Open in the browser
#    http://localhost:8080
```

---

## 4. Useful Makefile commands

| Command | What it does |
|---|---|
| `make up` | Create cluster + build + import + deploy (all at once) |
| `make down` | Remove the Helm release and namespace (keeps the cluster) |
| `make destroy` | Destroy the cluster completely |
| `make clean` | Remove resources + destroy the cluster (clean environment) |
| `make build` | Build the Docker image only |
| `make import` | Import the image into the cluster only |
| `make status` | Show pod and deployment status |
| `make logs` | Stream the app logs |
| `make health` | Test the app health endpoint (fails on a non-2xx response) |
| `make pf` | Port-forward as an alternative to the ingress (`localhost:5000`) |
| `make restart` | Restart the app Deployment (to pick up a rebuilt image) |

Commands that use `kubectl` check that the current context is `k3d-todolist`
(`k3d-<cluster-name>`) before running, so they don't touch another cluster by mistake. To switch
manually: `kubectl config use-context k3d-todolist`.

Because the local image uses the fixed tag `todolist-app:local`, rebuilding the image and running
`make up` again does not restart the pods (the tag didn't change). After
`make build && make import`, run `make restart` so the Deployment picks up the new image.

---

## 5. About the app

### Login

- **User:** `admin`
- **Password:** `admin`
- Values are defined in the local Secret generated by the chart
  (`charts/todolist/values-local.yaml`). They are not safe for production.

### Features

| Route | What it does |
|---|---|
| `/` | Task list (requires login) |
| `/add` | Add a task |
| `/toggle/<id>` | Mark/unmark a task as done |
| `/delete/<id>` | Delete a task |
| `/pods` | List the namespace pods (requires RBAC — already configured) |
| `/cleanup` | Remove completed tasks (requires the `X-Cleanup-Token` header) |
| `/cleanup/status` | Cleanup run history + pause/resume the CronJob |
| `/healthz` | Health check (returns `ok` when the database is reachable) |

### Environment variables

The app reads configuration from two places, in this order:
1. **Files** under `/var/run/secrets/todolist/` (mounted from a Kubernetes Secret)
2. **Environment variables** (fallback)

So in the cluster, credentials live in the Kubernetes Secret object, not exposed in pod environment
variables.

### Sessions

The app uses **Flask sessions**, stored in a client-side cookie signed with HMAC — not in pod
memory. The key that signs the cookie (`SESSION_KEY`) is defined in the chart's local Secret
(`charts/todolist/values-local.yaml`). Because the cookie is client-side, login survives pod
restarts as long as `SESSION_KEY` doesn't change; changing the key invalidates existing sessions.

### Database

- PostgreSQL 16 (Alpine) running as a Deployment in the `todolist` namespace
- Data persisted on a PersistentVolumeClaim (`todolist-postgres-data`, 500Mi)
- The schema is created automatically by the app on startup (`db.create_all()`)

### Cleanup CronJob

A CronJob (`cleanup`) runs every 5 minutes and calls `POST /cleanup` to remove completed tasks. The
history is visible at `/cleanup/status`, where you can pause and resume the schedule.

---

## 6. Troubleshooting

### The app pod never becomes ready (CrashLoopBackOff)

**Most common cause:** PostgreSQL isn't ready yet.
```bash
# Check PostgreSQL status
kubectl -n todolist get pods
kubectl -n todolist logs deploy/todolist-postgres

# Check the app logs
kubectl -n todolist logs -l app.kubernetes.io/component=app --tail=20
```

Wait until the PostgreSQL pod shows `1/1 Running` before investigating the app.

### I can't reach http://localhost:8080

```bash
# Check the ingress
kubectl -n todolist get ingress

# Check that Traefik is running
kubectl -n kube-system get pods | grep traefik

# Test with curl (the ingress does not restrict the hostname, so no Host header is needed)
curl -fsS http://localhost:8080/healthz
```

If the ingress is OK but the browser can't connect, try:
- Opening `http://localhost:8080/login` directly
- Checking that nothing else is using port 8080

### The /pods page shows "Unable to query the Kubernetes API"

The ServiceAccount lacks permissions. Check:
```bash
kubectl -n todolist get rolebinding todolist -o yaml
kubectl -n todolist get sa todolist -o yaml
```

### HPA doesn't work (FailedComputeMetricsReplicas)

`metrics-server` needs time to collect metrics. On a local cluster with little load this can take a
few minutes. Check:
```bash
kubectl top nodes
kubectl -n todolist get hpa
```

---

## 7. File structure

```
todolist-app/
├── Dockerfile          # Multi-stage build (builder + runtime)
├── .dockerignore       # Files excluded from the build
├── app.py              # Flask app code
├── requirements.txt    # Python dependencies
├── Makefile            # Automation commands
├── README.md           # General documentation
├── charts/
│   └── todolist/
│       ├── Chart.yaml
│       ├── values.yaml             # Defaults and structure (all environments)
│       ├── values-local.yaml       # Local values (in-cluster PostgreSQL, local Secret)
│       ├── values-dev.example.yaml # Example for AWS dev
│       └── templates/              # Deployment, Service, Ingress, ExternalSecret, etc.
└── docs/
    ├── local-kubernetes.md   # This guide
    ├── helm-chart.md         # Chart, values, and local/cloud differences
    └── PLAN.md               # DevOps challenge plan
```
