terraform {
  backend "s3" {
    encrypt = true
  }
}

data "terraform_remote_state" "aws-int" {
  backend = "s3"
  config = {
    bucket = var.aws-int_bucket
    key    = var.aws-int_key
    region = var.aws-int_region
  }
}

data "terraform_remote_state" "aad-int" {
  backend = "s3"
  config = {
    bucket = var.aad-int_bucket
    key    = var.aad-int_key
    region = var.aad-int_region
  }
}

data "aws_eks_cluster" "cluster" {
  name = local.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.eks_cluster_id
}

module "kubeconfig" {
  source = "../../modules/kubeconfig"

  cluster_id                                   = local.eks_cluster_id
  kubeconfig_aws_authenticator_additional_args = ["-r", local.role_arn]
}
