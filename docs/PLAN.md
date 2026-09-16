# DevOps Challenge: TODO List App on Kubernetes

- **Status:** Plan
- **Goal:** Deliver a reproducible local Kubernetes setup and one cost-conscious AWS EKS environment named `dev`, with automated application deployment.
- **Timebox:** One week. R0–R5 take priority over additional environments and tooling.

## 1. Scope & Assumptions

- The existing application uses Python, Flask, SQLAlchemy, PostgreSQL, and gunicorn. Infrastructure and delivery are the focus; application changes require a demonstrated need.
- The initial cloud deliverable is **one EKS cluster: dev**, not a production environment. Small nodes and reduced redundancy are explicit budget decisions, not production sizing recommendations.
- Local k3s and AWS EKS exercise the same application but differ in networking, storage, identity, and managed services. Local validation does not replace testing on EKS.
- Kubernetes can host a single application; multiple applications are not a prerequisite. Managed orchestration is used here to satisfy the challenge and demonstrate operational practices.
- OpenTofu remains the selected IaC tool. It uses Terraform-compatible HCL; mentioning Terraform does not imply maintaining both tools or switching state ownership.

## 2. Architecture & Delivery

```text
Developer → local build/import → k3s in k3d → local PostgreSQL

GitHub → GitHub Actions → build → image scan → ECR
                                             │
                                             ▼
                                       Helm deploy to dev
                                             │
Browser → public ALB → Service → app pods on private EKS nodes
                                             │
                                             ▼
                                  Aurora PostgreSQL, private

Secrets Manager → External Secrets Operator → Kubernetes Secret → app
```

There is **no local → dev promotion pipeline**. Developers validate locally; CI builds from repository source and deploys to AWS dev. Local Docker images, credentials, and kubeconfig are not promoted.

The EKS control plane is AWS-managed, not a workload deployed in the application's private subnets. Worker nodes and database instances use private subnets. Secrets Manager is a regional AWS service accessed through controlled network connectivity and IAM.

## 3. Environments

| Environment | Initial scope | Purpose and footprint |
|---|---|---|
| **local / k3s in k3d** | Required | Developer-owned cluster in Docker; local PostgreSQL; no AWS dependency. Not a deployment pipeline stage. |
| **dev / EKS** | Required | One cloud cluster and one small managed node group. Smallest instance size/count that can fit application requests, system pods, controllers, and rollout headroom. |
| **prod / separate EKS** | Optional, if time remains | A second isolated cloud environment, after dev acceptance criteria pass. Separate state, credentials, database, secrets, and capacity settings. |
| **staging** | Future | Optional production-like environment for performance, load, migration, resilience, and release validation before production. |

### Optional dev → prod promotion

- Add this only after R0–R5 work reliably in dev; it is not required for the initial delivery.
- Promote the **same tested image digest** from ECR rather than rebuilding for production.
- Require successful dev smoke tests and scans, then an explicit production approval with environment-scoped IAM permissions.
- Use separate Helm values, IaC state, database, and secrets for each cloud environment.
- Verify health after promotion and support application rollback to a known-good digest. Database migrations require compatible changes and their own recovery procedure.
- Production acceptance must include appropriate redundancy, TLS, backups/restoration, operational visibility, and capacity validation; renaming dev does not make it production.

## 4. Decisions

| Decision | Initial choice | Rationale |
|---|---|---|
| Local Kubernetes | k3s via k3d | Reproducible development without AWS charges. |
| Cloud Kubernetes | One EKS dev cluster | Demonstrates managed Kubernetes while limiting cost and delivery scope. |
| Infrastructure | OpenTofu | Declarative AWS provisioning with reviewable plans and protected remote state. |
| Application delivery | GitHub Actions + Helm | Build, scan, publish, deploy, verify. GitOps is optional future work. |
| Registry | ECR | IAM-controlled image storage; deploy by immutable digest. |
| External access | AWS Load Balancer Controller + ALB | ALB through an Ingress with a ClusterIP backend. A literal Service type LoadBalancer would instead normally use an NLB; document this distinction. |
| Pod/node scaling | HPA + Cluster Autoscaler | Separate application scaling from node provisioning; bound both to control costs. Karpenter is future work. |
| Database | Aurora PostgreSQL Serverless v2 | Managed PostgreSQL with configurable capacity. Cost must be measured, not assumed lower than provisioned RDS. |
| Secrets | Secrets Manager + External Secrets Operator | No plaintext cloud credentials in Git; least-privilege controller and workload access. |
| Infrastructure boundary | AWS foundation separate from app releases | Infrastructure state and lifecycle must not be owned by the application's deploy job, regardless of repository layout. |

ArgoCD provides GitOps reconciliation; progressive canary delivery requires additional tooling such as Argo Rollouts. Neither ArgoCD sync failure nor reverting an image guarantees database rollback.

## 5. Infrastructure Layout & Lifecycle

Planned layout, not implemented infrastructure:

```text
infra/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   ├── secrets/
│   └── iam/
└── environments/
    └── dev/

todolist-app/
├── Dockerfile
├── k8s/
├── charts/todolist/
└── .github/workflows/
```

`infra/` describes the logical AWS foundation boundary; final repository placement can be decided independently. Add prod/staging environment roots only when implementing those environments, not as mandatory empty scaffolding.

Use a protected, encrypted remote state backend with locking and a separate bootstrap lifecycle. Keep state out of Git and retain it across dev teardown/recreation. Kubernetes bootstrap/add-ons must have explicit ownership; do not let OpenTofu and Helm/CI manage the same application objects.

### Cost-conscious dev operation

- Estimate costs in the selected AWS region for EKS, EC2, EBS, NAT, public IPv4, ALB, Aurora capacity/storage/I/O, ECR, logs, and data transfer. Tag resources and configure budget alerts; alerts are not spending caps.
- Use private/public subnet groups spanning the AZs required by EKS, ALB, and Aurora. A single small node group or database writer does not eliminate these subnet requirements.
- Start with small nodes and bounded autoscaling. Include kube-system/add-on overhead and update surge capacity; increase capacity if pods remain Pending or are OOM-killed.
- A single NAT gateway is an acceptable documented dev compromise. It is a failure point and can incur cross-AZ traffic charges.
- Dev Aurora may use one writer without a cross-AZ reader. Aurora storage is distributed across AZs, but a single compute instance is not equivalent to redundant database compute/failover capacity.
- Aurora Serverless v2 is not automatically free when idle. Minimum capacity and auto-pause depend on engine/version support and configuration; storage and other charges remain.
- Create dev only for validation/demo windows and tear it down when not needed. Scaling nodes to zero does not stop EKS control-plane or other AWS charges.

### Safe teardown and recreation

1. Pause application deployment jobs so CI does not race with teardown. Confirm AWS account, region, environment, and state before reviewing a destroy plan.
2. Decide whether database contents are disposable; take and verify a recoverable snapshot when retention is required. Preserve state/backend access outside the disposable stack.
3. Delete controller-owned Ingress/LoadBalancer resources while the cluster and controllers are still running, and wait for AWS load balancers to be removed.
4. Review and approve the OpenTofu destroy plan, then remove the dev stack. Never disable production deletion safeguards merely to reuse the dev procedure.
5. Check for retained snapshots, disks, ECR images, logs, public IPs, and other billable resources. Destroy does not guarantee zero cost.
6. Recreate the stack, bootstrap add-ons, restore or initialize the database, deploy a known image digest, and repeat smoke tests. Measure this recovery time before relying on it for the presentation.

Exact apply/destroy commands and backend settings belong in the infrastructure runbook once the modules exist; this plan does not claim provisioning has been validated.

## 6. Requirements & Acceptance

| Requirement | Initial delivery and evidence |
|---|---|
| **R0 — Run locally** | Multi-stage image, k3d/k3s, local PostgreSQL, browser access, and reproducible setup instructions. |
| **R1 — Cluster by code** | One EKS dev environment, networking, database, IAM, and dependencies through OpenTofu. Demonstrate reviewed create/destroy/recreate with retained state. |
| **R2 — Automated deployment** | GitHub Actions builds, scans, publishes, deploys to dev via Helm, and verifies health. No promotion from local is needed. |
| **R3 — Browser access** | Validate the actual documented hostname through the AWS load balancer, not only a custom Host header. |
| **R4 — Scalability/resilience** | Probes, requests/limits, replicas, rolling updates, HPA and bounded node scaling; demonstrate pod recovery and scaling. Explicitly distinguish these from node/AZ/database high availability. |
| **R5 — Documentation** | Setup, deploy, troubleshoot, costs, teardown/recreation, limitations, and approximately five substantive ADRs. |

For initial HTTP dev demonstrations use only disposable synthetic data and non-reused credentials. TLS is required before real users or sensitive data and for the optional production environment.

## 7. Epics & Commit Organization

### Required: local and one AWS dev environment

1. **EPIC-1 / R0 — Container and local setup:** multi-stage Dockerfile, k3d manifests, Makefile and instructions; validate login, health, and basic task operations.
2. **EPIC-2 / R1 — State and networking:** bootstrap protected state, VPC/subnets, dev NAT choice, resource tags, budget estimate and alerts.
3. **EPIC-3 / R1 — EKS dev foundation:** one cluster, small managed node group, IAM/OIDC, add-on bootstrap. Plan CI access to the Kubernetes API; AWS OIDC alone does not provide network reachability. Use a runner with a supported access path, never an unrestricted API endpoint as a shortcut.
4. **EPIC-4 / R1 — Database:** Aurora dev capacity bounds, private connectivity, backup/retention settings, documented single-writer trade-off.
5. **EPIC-5 / R1 — Secrets:** Secrets Manager and External Secrets Operator. Prefer service-managed credential generation where supported; protect any sensitive IaC state and avoid secret output in logs.
6. **EPIC-6 / R2 — CI/CD to dev:** validation → build → simple image scan → ECR push → Helm deployment → smoke tests. Fail the scan on CRITICAL findings; retain the report. Use OIDC, least privilege, immutable digests, and deployment concurrency control. No prod or local-promotion stage.
7. **EPIC-7 / R0/R4 — Application packaging:** Helm chart for AWS dev; explicit local/cloud configuration differences, probes, resources, secrets, replicas, HPA, and a PDB compatible with the small node pool.
8. **EPIC-8 / R3 — Browser access:** AWS load balancer controller, Helm-owned Ingress, correct DNS/access instructions and documented dev HTTP limitation.
9. **EPIC-9 / R4 — Validation and recovery:** smoke tests, pod replacement, rollout behavior, measured HPA/node scaling, and database recovery checks. Record what small capacity cannot demonstrate; rehearsed dev teardown/recreation.
10. **EPIC-11 / R5 — Runbook and ADRs:** document alongside implementation, not after optional features. Include an architecture diagram, environment strategy, cost rationale, evidence, and remaining limitations.

### Optional: only after dev meets R0–R5

- **EPIC-12 — Second cloud environment and promotion:** provision separate prod with appropriate safeguards; add approved dev → prod image-digest promotion and rollback validation. Staging remains a documented future extension.
- **EPIC-10 — GitOps:** introduce ArgoCD with clear resource ownership. Canary/automated analysis is a separate enhancement, not a prerequisite for basic promotion.

## 8. One-Week Priorities

| Window | Focus |
|---|---|
| Days 1–2 | Local reproducibility, cost assumptions, state/networking/EKS dev foundation. |
| Days 3–4 | Database/secrets, app packaging, CI/CD and browser access on dev. |
| Day 5 | Scaling/recovery evidence, cleanup/recreation rehearsal, documentation and presentation. |
| Remaining buffer | Fix defects and rehearse the demo first. Add prod/promotion only if all required checks pass and time/budget allow. |

One well-validated dev environment is the required deliverable. Two partially working cloud environments are not a better outcome.

## 9. Assumptions to Validate

- AWS account permissions, quotas, region, and spending budget are available.
- Choose an EKS version in standard support at implementation time and compatible add-ons; do not hard-code an outdated version as “latest.”
- Confirm Aurora engine/version capacity bounds, auto-pause support, and costs in the selected region.
- Confirm domain availability and the pipeline's EKS API access path.
- Recreating infrastructure takes time, may change endpoints, and does not automatically restore data. The demo must account for that.

## 10. Future Work

- Separate prod cluster and approved dev → prod promotion, if not delivered within the timebox.
- Optional production-like staging for load/performance, migration, failure/recovery, and release testing.
- ArgoCD GitOps; Argo Rollouts for progressive delivery and metric-based analysis.
- Karpenter and Spot strategies after workload availability and cost measurements justify them.
- Production node/AZ/database redundancy, TLS, observability/alerting, restore drills, and defined recovery objectives.
- Broader quality gates: application tests and coverage policy, SAST, dependency/IaC scanning, SBOM, image signing, and admission policies. The initial image scan is a demonstration, not a complete security program.
- WAF, External DNS, and additional network/security hardening based on actual requirements.
