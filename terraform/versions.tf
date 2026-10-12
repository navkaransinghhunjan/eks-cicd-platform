terraform {
  required_version = ">= 1.10.0" # needed for S3 native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Partial config: values come from backend.hcl (local) or -backend-config flags (CI)
  backend "s3" {}
}
