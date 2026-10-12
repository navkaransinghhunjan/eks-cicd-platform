# GitHub Actions -> AWS via OIDC. No long-lived access keys anywhere.
# Three roles, each trusted only for one workflow context:
#   tf-plan  : pull_request          -> read-only + state
#   tf-apply : environment "infra"   -> admin (protected by required reviewers)
#   deploy   : environment "prod"    -> ECR push, EKS describe, log bucket

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  github_subjects = {
    tf_plan  = "repo:${var.github_repo}:pull_request"
    tf_apply = "repo:${var.github_repo}:environment:infra"
    deploy   = "repo:${var.github_repo}:environment:prod"
  }
}

data "aws_iam_policy_document" "github_trust" {
  for_each = local.github_subjects

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

# ---------- deploy ----------
resource "aws_iam_role" "github_deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust["deploy"].json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
      "ecr:DescribeImages", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
  statement {
    sid       = "EksKubeconfig"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
  statement {
    sid       = "DeployLogList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.deploy_logs.arn]
  }
  statement {
    sid       = "DeployLogRw"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.deploy_logs.arn}/*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# ---------- terraform plan (PRs) ----------
resource "aws_iam_role" "tf_plan" {
  name               = "${var.project}-github-tf-plan"
  assume_role_policy = data.aws_iam_policy_document.github_trust["tf_plan"].json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "tf_state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }
  statement {
    # Get/Put the state + the .tflock file used by use_lockfile
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "tf_plan_state" {
  name   = "tf-state"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.tf_state.json
}

# ---------- terraform apply (main, gated by "infra" environment) ----------
resource "aws_iam_role" "tf_apply" {
  name               = "${var.project}-github-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.github_trust["tf_apply"].json
}

# Creating VPC/EKS/IAM needs broad rights; the guardrail is the trust policy
# (only the reviewer-protected "infra" environment can assume this role).
resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
