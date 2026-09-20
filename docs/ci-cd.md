# CI/CD

Two workflows deliver the app. Both run on self-hosted ARC runners inside the target VPC and use
**IRSA** for AWS access (no long-lived keys, no GitHub OIDC):

| Workflow | Trigger | Environment | Purpose |
|---|---|---|---|
| `deploy-dev.yml` | push to `main` (or manual) | `dev` | build → scan → push by digest → commit the digest |
| `promote-prod.yml` | published release (or manual) | `prod` (reviewer required) | promote the **same digest** to prod |

Argo CD (installed by the platform repo) is the only owner of the application release: CI never
runs `helm upgrade`. CI updates the desired image digest in Git and Argo CD reconciles it (ADR-012).

## Runner

The jobs run on **self-hosted ARC runners** inside the VPC, created by the platform repo:
`arc-runner-set` (dev cluster) and `arc-runner-set-prod` (prod cluster). They reach the private EKS
APIs and use **IRSA** for ECR push, `eks:DescribeCluster`, and SSM reads.

Prerequisite: the GitHub App credentials must exist in Secrets Manager as `todolist-dev/github-app`
(the app is repository-scoped and shared by both environments) so ARC can register the runners.

## Deploy dev (GitOps)

1. **Build** the image from the `Dockerfile`.
2. **Scan** with Trivy; **fail on CRITICAL** findings. The report is uploaded as an artifact
   (`trivy-report`).
3. **Push** to ECR and capture the immutable **digest**.
4. **Commit** the digest to `charts/todolist/gitops/dev.yaml` (only the digest; the rest of the wiring
   is injected by OpenTofu). A `GITHUB_TOKEN` push does not re-trigger workflows, and the workflow
   ignores `charts/todolist/gitops/**`.
5. **Wait** for the Argo CD `Application` `todolist-dev` to reach `Synced`/`Healthy`.
6. **Smoke test** `https://<hostname>/healthz`.

A `concurrency` group (`deploy-dev`, no cancel) serializes deployments.

## Promote prod

- **Trigger:** a published GitHub Release (`on: release: types: [published]`) or a manual
  `workflow_dispatch` (with an optional `digest` input for rollback).
- The `prod` GitHub Environment **requires a reviewer**, so promotion is an explicit approval.
- **Digest, never a rebuild:** unless an explicit digest is given, the workflow reads the digest dev
  currently runs (`charts/todolist/gitops/dev.yaml`) and commits it to
  `charts/todolist/gitops/prod.yaml`, then waits for `todolist-prod` to sync.
- **Rollback:** re-run with the previous `digest` input.

## Where the configuration lives

- The **image digest** is the only per-environment value committed (`charts/todolist/gitops/<env>.yaml`).
- All other wiring (ECR repository URL, database host, secret ARNs, hostname, certificate ARN) is
  injected inline by OpenTofu into the Argo CD `Application`, so no account IDs, ARNs, or hostnames
  are committed (ADR-012).
- Secrets stay in Secrets Manager and are synced into the cluster by the External Secrets Operator.

## Releases

`.github/workflows/release.yml` runs **release-please** on merges to `main`. It reads
**Conventional Commits** and opens/updates a release PR; merging that PR creates a tag (`vX.Y.Z`) and
a GitHub Release with a generated `CHANGELOG.md`.

- `fix:` -> patch, `feat:` -> minor, `feat!:` / `BREAKING CHANGE:` -> major.
- `docs:`, `chore:`, `ci:`, `refactor:`, `test:` -> no release.
- The version is release metadata; deployments stay pinned to the image **digest**.
- A published Release is what triggers the production promotion.
- The current version is tracked in `.release-please-manifest.json`; no manual version bumping.

## Ownership

- Argo CD owns the **application release** (from the chart in this repository).
- The platform repository owns the cluster, add-ons, Argo CD itself, ECR, and the CI runners
  (ADR-001, ADR-012).
- Neither pipeline runs `tofu`.

## Notes

- Helm charts for cluster add-ons are **vendored** in the platform repo (ADR-004); the app chart
  is in this repository.
- Dev and prod are torn down between demo windows; the state bucket and snapshots persist. See the
  infrastructure runbook for stale state-lock recovery.

## After a teardown

The shared ECR persists across teardown, but its images may not (for example after a force-delete).
The dev pipeline repopulates it: the next merge to `main` builds and pushes the image, and Argo CD
reconciles. If a deployment is stuck in `ImagePullBackOff`, run the dev pipeline (or push to `main`)
to publish a new image.
