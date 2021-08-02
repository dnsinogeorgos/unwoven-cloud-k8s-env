provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = local.account["role_arn"]
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  config_path            = module.kubeconfig.kubeconfig_filename
}

provider "helm" {
  kubernetes {
    config_path = module.kubeconfig.kubeconfig_filename
  }
}
