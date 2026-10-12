module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  # Explicit admins instead of "whoever ran apply" — avoids losing access
  # when CI (a different principal) runs the next apply.
  enable_cluster_creator_admin_permissions = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = 1
      max_size     = 3
      desired_size = var.node_desired_size
    }
  }

  access_entries = merge(
    {
      for i, arn in var.admin_principal_arns : "admin-${i}" => {
        principal_arn = arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    {
      # Deploy role installs ingress-nginx (cluster-scoped RBAC) + the app.
      # Tighten to a namespace scope once ingress is managed elsewhere.
      github-deploy = {
        principal_arn = aws_iam_role.github_deploy.arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    }
  )
}
