# CI/CD (dev)

`.github/workflows/deploy-dev.yml` builds the image from source, scans it, publishes it to ECR by
digest, deploys it to the `dev` EKS environment with Helm, and runs a smoke test.

## Runner

The job runs on a **self-hosted ARC runner** (`runs-on: arc-runner-set`) inside the VPC, created by
the infrastructure repo. It reaches the private EKS API and uses **IRSA** for AWS access (ECR push,
`eks:DescribeCluster`, Helm deploy) — there are **no long-lived AWS keys** and no GitHub OIDC.

Prerequisite: the GitHub App credentials must exist in Secrets Manager as `todolist-dev/github-app`
so ARC can register the runner.

## Pipeline steps

1. **Build** the image from the `Dockerfile`.
2. **Scan** with Trivy; **fail on CRITICAL** findings. The report is uploaded as an artifact
   (`trivy-report`).
3. **Push** to ECR and capture the immutable **digest**.
4. **Deploy** with `helm upgrade --install`, referencing the image by **digest** (not a tag).
5. **Smoke test** `https://<hostname>/healthz`.

A `concurrency` group (`deploy-dev`, no cancel) serializes deployments.

## Releases

`.github/workflows/release.yml` runs **release-please** on merges to `main`. It reads
**Conventional Commits** and opens/updates a release PR; merging that PR creates a tag (`vX.Y.Z`) and
a GitHub Release with a generated `CHANGELOG.md`.

- `fix:` -> patch, `feat:` -> minor, `feat!:` / `BREAKING CHANGE:` -> major.
- `docs:`, `chore:`, `ci:`, `refactor:`, `test:` -> no release.
- The version is release metadata; deployments stay pinned to the image **digest**.
- The current version is tracked in `.release-please-manifest.json`; no manual version bumping.

## Triggers

- **Dev deploy** and **release-please** run on `push` to `main` (a merged PR is a push) — continuous
  delivery for dev.
- **Prod** (future) deploys on a **published release** (`on: release: types: [published]`) or an
  approval-gated `workflow_dispatch`, so production only ever sees tagged, dev-validated digests.

## Required GitHub repository variables

Set once from the infrastructure outputs (in the app repo):

```bash
gh variable set APP_HOSTNAME   --body "$(tofu -chdir=../infra/environments/dev output -raw app_hostname)"
gh variable set DB_HOST        --body "$(tofu -chdir=../infra/environments/dev output -raw db_cluster_endpoint)"
gh variable set DB_SECRET_ARN  --body "$(tofu -chdir=../infra/environments/dev output -raw db_master_user_secret_arn)"
gh variable set APP_SECRET_ARN --body "$(tofu -chdir=../infra/environments/dev output -raw app_secret_arn)"
gh variable set INGRESS_CERT_ARN --body "$(tofu -chdir=../infra/environments/dev output -raw ingress_certificate_arn)"
```

No secret values are stored in GitHub; only non-sensitive wiring (hostnames, endpoints, ARNs). The
actual credentials live in Secrets Manager and are synced by the External Secrets Operator.

## Ownership

- This workflow owns the **application Helm release** only.
- The infrastructure repository owns the cluster, add-ons, ECR, and the CI runner (ADR-001).
- The pipeline never runs `tofu`.

## Notes

- Helm charts are **vendored** in the infrastructure repo (ADR-004); the app chart is in this repo.
  Mirroring charts to ECR as OCI artifacts is an optional future step.
- Dev is torn down between demo windows; the state bucket and snapshots persist. See the
  infrastructure runbook for stale state-lock recovery.
