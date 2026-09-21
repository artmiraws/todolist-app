# DevOps Challenge: TODO List App on Kubernetes

- **Status:** Delivered (R0–R5), plus optional prod/promotion, GitOps, and a platform handbook.
- **Goal:** Deliver a reproducible local Kubernetes setup and cost-conscious AWS EKS environments
  (`dev` and `prod`), with automated application delivery and promotion.
- **Timebox:** One week. R0–R5 took priority over additional environments and tooling.
- **Where things are:** the platform handbook (`platform-docs`, served at
  <https://docs.nexusauto.com.br/>) owns the detail; [`TASKS.yaml`](TASKS.yaml) is the task tracker.

## 1. Scope & Assumptions

- The application is Python/Flask/SQLAlchemy/PostgreSQL/gunicorn. Infrastructure and delivery are the
  focus; the app code is unchanged apart from packaging.
- The cloud deliverable is **one required `dev` environment**; a second `prod` environment is an
  optional increment that was delivered to demonstrate promotion (small footprint, not production
  sizing).
- Local k3s and AWS EKS exercise the same application but differ in networking, storage, identity,
  and managed services. Local validation does not replace testing on EKS.
- OpenTofu is the IaC tool (Terraform-compatible HCL). No second IaC tool is maintained.

## 2. Delivered architecture

```text
Developer → k3d/k3s (Helm chart) → local PostgreSQL          # R0

GitHub → Actions (self-hosted ARC runner, IRSA)
        → build → Trivy scan → ECR (by digest)
        → commit the digest to Git → Argo CD reconciles       # R2 / GitOps

Browser → Route53 → ALB (ACM TLS) → Ingress → Service → pods
                                                   │
                                                   ▼
                        Secrets Manager → External Secrets Operator → Secret
                                                   │
                                                   ▼
                                     Aurora PostgreSQL Serverless v2   # R1/R3

Release published → promote job (approval) → same digest to prod    # promotion
```

- **No local → dev promotion:** developers validate locally; CI builds from source and deploys to
  AWS. Local images and credentials are never promoted.
- **GitOps:** Argo CD owns the application release; CI only commits the desired digest (ADR-012).
- **Platform vs application:** platform modules never name an application; each app's database,
  secret, hostname certificate, and Argo CD `Application` live in an `app-<name>` module (ADR-013).

## 3. Environments

| Environment | Scope | Purpose and footprint |
|---|---|---|
| **local / k3s in k3d** | Required | Developer-owned cluster in Docker; local PostgreSQL; no AWS. Not a pipeline stage. |
| **dev / EKS** | Required | Continuous delivery from `main`; smallest practical node pool; `t3.small`, bounded autoscaling. |
| **prod / EKS** | Delivered (optional increment) | Same small footprint with prod safeguards (deletion protection, final snapshot, 14-day backups, control-plane logs); deploys the dev-validated digest. |
| **staging** | Future | Production-like environment for performance, migration, and resilience testing (see the roadmap). |

## 4. Decisions (summary)

Full records live in the handbook's [decisions](https://docs.nexusauto.com.br/decisions/) (ADR-001…018).

| Decision | Choice |
|---|---|
| Local Kubernetes | k3s via k3d |
| Cloud Kubernetes | EKS (dev + prod), one small managed node group each |
| Infrastructure | OpenTofu, remote S3 state, one key per environment |
| Application delivery | GitHub Actions (self-hosted ARC runners, IRSA) + Argo CD (GitOps) |
| Registry | ECR, deploy by immutable digest |
| External access | AWS Load Balancer Controller + ALB (Ingress) with ACM TLS and ExternalDNS |
| Scaling | HPA + Cluster Autoscaler (Karpenter is future work) |
| Database | Aurora PostgreSQL Serverless v2 |
| Secrets | Secrets Manager + External Secrets Operator |
| Release/versioning | release-please (Conventional Commits) + digest promotion |
| Docs | `platform-docs`: a static MkDocs site on S3 + CloudFront |

Open questions and future work are tracked in the handbook's
[roadmap](https://docs.nexusauto.com.br/roadmap/) and
[open discussion](https://docs.nexusauto.com.br/decisions/open-discussion/) (for example, whether an
application should own its infrastructure).

## 5. Repository layout

```text
platform/                         # AWS foundation (OpenTofu)
├── bootstrap/                    # S3 remote-state bucket + /platform/* config
├── modules/                      # platform modules + app modules (app-todolist)
└── environments/{dev,prod}/      # environment roots (separate state keys)

todolist-app/                     # the application
├── app.py  Dockerfile  Makefile
├── charts/todolist/              # one Helm chart (values per environment)
├── deploy/applicationset.yaml
├── docs/                         # app docs + the plan and task tracker copies
└── .github/workflows/            # deploy-dev, promote-prod, release

platform-docs/                    # the handbook (static site)
├── docs/                         # Markdown content
├── infra/                        # S3 + CloudFront + ACM + Route53 (own state)
└── .github/workflows/            # build, sync to S3, invalidate CloudFront
```

## 6. Requirements & evidence

| Requirement | Delivered |
|---|---|
| **R0 — Run locally** | Multi-stage image, k3d/k3s, local PostgreSQL, browser access, `make up`, and a beginner guide. |
| **R1 — Cluster by code** | `dev` (and `prod`) provisioned with OpenTofu: VPC, EKS, Aurora, ECR, IAM, add-ons, and budget; reviewed create/destroy/recreate with retained state. |
| **R2 — Automated deployment** | GitHub Actions builds, scans (Trivy, fails on CRITICAL), pushes by digest, commits the digest, and Argo CD reconciles; health is smoke-tested. |
| **R3 — Browser access** | The documented hostname is served through the ALB with ACM TLS (dev and prod). |
| **R4 — Scalability/resilience** | Probes, requests/limits, rolling updates, HPA, bounded node scaling; pod recovery and scaling measured. Node/AZ/DB HA is explicitly distinguished and documented as out of scope. |
| **R5 — Documentation** | The platform handbook (concepts, architecture, runbook, costs, hardening backlog, ADRs, roadmap) and app-specific docs. |

## 7. Delivery and promotion

- **Dev:** merge to `main` → build, scan, push by digest, commit the digest to
  `charts/todolist/gitops/dev.yaml` → Argo CD reconciles → smoke test.
- **Prod:** publish a release → the chained `Promote prod` job (behind the `prod` environment
  approval) copies the dev-validated digest to `charts/todolist/gitops/prod.yaml` — no rebuild.
- **Rollback:** promote a previous digest; a schema change is handled separately.

## 8. Cost and teardown

- A US$50/month budget with alerts; dev/prod are ephemeral. See the handbook
  [cost model](https://docs.nexusauto.com.br/costs/).
- `platform/scripts/cost.sh status|sleep|wake` pauses Aurora and the nodes for short breaks; the EKS
  control plane and NAT only stop on `tofu destroy`.
- Teardown/recreation procedure: the handbook
  [runbook](https://docs.nexusauto.com.br/operations/runbook/).
- The handbook is a **static site** (S3 + CloudFront), so it stays online after the EKS environments
  are destroyed.

## 9. Future work

Tracked in the handbook [roadmap](https://docs.nexusauto.com.br/roadmap/): single Argo CD
(`GITOPS-HUB`), observability, progressive delivery, policy/admission, add-ons via Argo CD,
Karpenter/Spot, staging, and broader security gates (the
[hardening backlog](https://docs.nexusauto.com.br/operations/hardening/)).

## 10. Assumptions to validate

- AWS permissions, quotas, region, and budget are available.
- EKS and add-on versions remain in standard support; versions are pinned in variables.
- Aurora capacity bounds and costs are confirmed for the selected region.
- Recreating infrastructure takes time and may change endpoints; data is not restored automatically.
