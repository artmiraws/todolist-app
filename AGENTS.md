# AGENTS.md

Guidance for AI coding agents working in this repository. Keep it short and accurate.

## What this is
A Flask + SQLAlchemy + PostgreSQL TODO app, packaged with Helm, running on a local k3d cluster or the
AWS EKS `dev`/`prod` environments (Argo CD reconciles the app; CI only updates the image digest).

## Commands
- Run locally: `make up` (k3d + Helm using `charts/todolist/values-local.yaml`), `make down`, `make clean`
- Image only: `make build`
- Chart checks: `helm lint charts/todolist` and `helm template todolist charts/todolist -f charts/todolist/values-local.yaml`
- There are no automated app tests yet; add them before changing behavior.

## Layout
- `app.py` — Flask app: routes, config loading, health, and the RBAC-backed `/pods` and `/cleanup/status`.
- `charts/todolist/` — the only source of truth for the app's Kubernetes objects.
- `docs/` — documentation; start at `docs/README.md`.
- `.github/workflows/deploy-dev.yml` — CI: build, scan, ECR push, then commit the image digest (Argo CD deploys).
- `.github/workflows/promote-prod.yml` — promotes the dev-validated digest to prod on a published release.
- `.github/workflows/release.yml` + `release-please-config.json` — Conventional Commits to version, changelog, and GitHub Release.
- `charts/todolist/gitops/` — per-environment desired image digest (the only committed per-env value).
- `Dockerfile`, `.dockerignore`, `requirements.txt`, `Makefile`.

## Conventions
- One Helm chart for local and cloud; differences live only in values files.
- `values-local.yaml` is committed; `values-dev.yaml` is gitignored and injected by CI.
- Secrets are never committed — they come from Secrets Manager via the External Secrets Operator.
- No account IDs, ARNs, or hostnames in committed files.
- Deployments are pinned to an image digest. Argo CD owns the app release; CI only commits the digest.
- Use Conventional Commits; releases (version + changelog) are automated by release-please — never bump versions by hand.
