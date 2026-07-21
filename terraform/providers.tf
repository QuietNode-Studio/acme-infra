provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "acme-estate"
      env        = "dev" # decoys override to env=prod at the resource level
      managed_by = "terraform"
      repo       = "QuietNode-Studio/acme-infra"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
