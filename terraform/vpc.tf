locals {
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster_name = var.project
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = var.project
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost: one NAT for the demo; use one per AZ in prod
  enable_dns_hostnames = true

  # Subnet discovery for AWS load balancers
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
