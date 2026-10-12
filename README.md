# eks-cicd-platform

![ci](https://github.com/navkaransinghhunjan/eks-cicd-platform/actions/workflows/ci.yml/badge.svg)

> **Reference blueprint — not deployed.** This repo documents *how* I ship to EKS. Every file is real and lint/validate-checked in CI, but the AWS workflows (`infra`, `deploy`) are **manual-only and skip themselves** until AWS is wired up, so nothing runs up a bill. See [Going live](#going-live) to turn it on.

How I deploy to **Amazon EKS** with **GitHub Actions** — infrastructure in Terraform, no static AWS keys, scanned immutable images, Helm releases that roll themselves back, and an **append-only `install.log`** recording every deployment.

```
PR / main ─► ci: pytest · Trivy · helm lint · shellcheck · terraform validate   (runs always, free)

manual    ─► infra: terraform plan | apply (approval) | destroy               (skipped until AWS vars exist)
manual    ─► deploy: build ─► Trivy ─► push ECR ─► helm upgrade --atomic ─► smoke test ─► install.log
```

Full diagram and design decisions: [docs/architecture.md](docs/architecture.md) · Ops: [docs/runbook.md](docs/runbook.md)

## Stack

**AWS** VPC · EKS (AL2023 managed nodes, Spot) · ECR · S3 · IAM/OIDC  
**IaC** Terraform (`terraform-aws-modules` vpc + eks, S3 backend with native locking)  
**CI/CD** GitHub Actions · Trivy · Helm · ingress-nginx (NLB)  
**App** FastAPI with health/readiness probes, HPA, PDB, non-root read-only container

## install.log

Every deploy run — success **or** failure — appends one line (illustrative):

```
2026-10-13T10:42:05Z | env=prod | app=eks-demo | image=sha-3f9c2a1 | commit=3f9c2a1 | helm_rev=7 | actor=navkaransinghhunjan | run=11502233445 | status=SUCCESS | duration=94s
2026-10-13T11:05:47Z | env=prod | app=eks-demo | image=sha-9b1e004 | commit=9b1e004 | helm_rev=7 | actor=navkaransinghhunjan | run=11502987120 | status=FAILURE | duration=312s
```

(The second line: rollout failed, `--atomic` rolled back, so the Helm revision stayed at 7.)

- **Source of truth:** versioned, encrypted S3 bucket → every change is retained and recoverable.
- **Readable copy:** committed back to [`logs/install.log`](logs/install.log) with `[skip ci]`.
- Also written to the run's job summary. Logic lives in [`scripts/log-deploy.sh`](scripts/log-deploy.sh).

## Security choices

- **OIDC, three roles:** `tf-plan` (PRs, read-only), `tf-apply` (only from the reviewer-gated `infra` environment), `deploy` (only from `prod`; ECR push, `eks:DescribeCluster`, log bucket).
- **Explicit EKS access entries** — CI applies can't silently replace the human cluster admin.
- **Images:** immutable tags, scan-on-push, Trivy gate before push, non-root UID, read-only root FS, all capabilities dropped.

## Going live

1. Run the setup below (first `terraform apply` is local — the CI roles don't exist yet).
2. Optionally restore the automatic triggers noted at the top of `infra.yml` / `deploy.yml`.
3. Until the repo variables exist, `infra` and `deploy` are skipped, never failed.

## Setup

Prereqs: AWS CLI, Terraform ≥ 1.10, `gh` CLI, an IAM user/role with admin for the first apply.

```bash
# 1. State bucket (one time)
scripts/bootstrap-state.sh ap-south-1
#    → prints the commands to create backend.hcl + terraform.tfvars; then set admin_principal_arns

# 2. First apply locally (CI roles don't exist yet)
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform apply

# 3. Wire GitHub
scripts/set-github-vars.sh
gh api -X PUT repos/navkaransinghhunjan/eks-cicd-platform/environments/prod
gh api -X PUT repos/navkaransinghhunjan/eks-cicd-platform/environments/infra   # then add yourself as required reviewer in Settings → Environments

# 4. Deploy
git commit --allow-empty -m "deploy" && git push   # or Actions → deploy → Run workflow
```

## Cost

EKS control plane ≈ **$0.10/h (~$73/mo)** + one NAT gateway + NLB + 2× Spot t3.medium. Run it for demos, then destroy (Actions → **infra** → `destroy`). Stay on a Kubernetes version in standard support — extended support bills the control plane at 6×.

## Repo layout

```
app/              FastAPI service, tests, Dockerfile
helm/app/         Deployment, Service, Ingress, HPA, PDB
terraform/        VPC, EKS, ECR, log bucket, GitHub OIDC roles
.github/workflows ci.yml · infra.yml · deploy.yml
scripts/          log-deploy.sh · bootstrap-state.sh · set-github-vars.sh
logs/install.log  deployment record
docs/             architecture · runbook
AGENTS.md         context for AI assistants adapting this blueprint
```

## Roadmap

- [ ] Argo CD (GitOps) variant for comparison with push-based deploys
- [ ] External Secrets Operator + Pod Identity pulling from SSM Parameter Store
- [ ] kube-prometheus-stack + SLO burn-rate alerts
- [ ] Custom domain with cert-manager / ACM TLS
- [ ] Staging environment with promotion to prod

## License

MIT
