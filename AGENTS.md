# AGENTS.md — context for AI assistants

This repo is a **reference blueprint** for deploying a containerised service to Amazon EKS with GitHub Actions. It is not deployed. Use it as the pattern when asked to build or adapt a similar pipeline.

## Invariants (keep these when adapting)
- **No static cloud keys.** GitHub OIDC → IAM roles; each role's trust policy pins one `sub` (PR/main → plan, `environment:infra` → apply, `environment:prod` → deploy).
- **Admin rights only behind approval.** `tf-apply` is assumable only from the reviewer-protected `infra` environment.
- **Explicit EKS access entries** (`enable_cluster_creator_admin_permissions = false`) so CI applies don't replace the human admin.
- **Immutable image tags** `sha-<7>`; **Trivy gate before push**; ECR scan-on-push.
- **`helm upgrade --atomic --wait`** + a smoke test that checks the *served version* equals the new tag.
- **install.log:** every deploy run (success or failure) appends one line via `scripts/log-deploy.sh`; S3 (versioned) is the source of truth, the repo copy is committed with `[skip ci]`; deploys are serialised with a `concurrency` group.
- **Cost guard:** AWS workflows are `workflow_dispatch` only and skip when `vars.AWS_REGION` is empty.

## Map
| Concern | File |
|---|---|
| Network | `terraform/vpc.tf` (2 AZs, single NAT) |
| Cluster | `terraform/eks.tf` (module v20, AL2023, Spot) |
| Registry | `terraform/ecr.tf` |
| Deploy log bucket | `terraform/logs.tf` |
| CI identity | `terraform/iam-github.tf` |
| Checks (no AWS) | `.github/workflows/ci.yml` |
| Infra pipeline | `.github/workflows/infra.yml` |
| App pipeline | `.github/workflows/deploy.yml` |
| Release manifest | `helm/app/` |
| Ops | `docs/runbook.md` |

## Common adaptations
- **Different app:** replace `app/`, keep port 8000 and `/healthz` `/readyz` or update probes in `helm/app/templates/deployment.yaml`.
- **GitLab CI instead of Actions:** GitLab also issues OIDC ID tokens (`id_tokens:`); trust `gitlab.com` (or self-hosted URL) with `sub` = `project_path:<group>/<project>:ref_type:branch:ref:main`. Map jobs 1:1 (ci → MR pipelines, deploy → protected `main` with a manual/protected environment).
- **Another cloud:** GKE + Workload Identity Federation, Artifact Registry, GCS bucket for install.log — same pipeline shape.
- **GitOps:** replace the `helm upgrade` step with a commit to a manifests repo watched by Argo CD; keep install.log by logging in the CI step that bumps the image tag.

## Don't
- Don't add long-lived `AWS_ACCESS_KEY_ID` secrets.
- Don't use mutable tags like `latest` for deploys.
- Don't make `deploy` / `infra` auto-trigger unless the user explicitly wants a live environment.
