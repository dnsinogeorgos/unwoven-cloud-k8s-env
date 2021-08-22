locals {
  account         = data.terraform_remote_state.aws-int.outputs.account
  github          = data.terraform_remote_state.aws-int.outputs.github
  vpc             = data.terraform_remote_state.aws-int.outputs.vpc
  subnets         = data.terraform_remote_state.aws-int.outputs.subnets
  efs             = data.terraform_remote_state.aws-int.outputs.efs
  eks_cluster     = data.terraform_remote_state.aws-int.outputs.eks_cluster
  eks_node_groups = data.terraform_remote_state.aws-int.outputs.eks_node_groups
  buckets_loki    = data.terraform_remote_state.aws-int.outputs.buckets_loki
  buckets_thanos  = data.terraform_remote_state.aws-int.outputs.buckets_thanos
  loki_tenant_ids = data.terraform_remote_state.aws-int.outputs.loki_tenant_ids

  account_id                  = local.account["account_id"]
  account_email               = local.account["email"]
  role_arn                    = local.account["role_arn"]
  zone_name                   = local.account["zone_name"]
  zone_id                     = local.account["zone_id"]
  efs_id                      = local.efs["id"]
  eks_cluster_id              = local.eks_cluster["eks_cluster_id"]
  eks_cluster_oidc_issuer_url = local.eks_cluster["eks_cluster_identity_oidc_issuer"]
  bucket_loki                 = local.buckets_loki["main"]
  bucket_thanos               = local.buckets_thanos["main"]

  gh_grafana_client_id     = local.github["grafana_client_id"]
  gh_grafana_client_secret = local.github["grafana_client_secret"]

  service_accounts = module.service_accounts
  aws_efs_csi_driver_sa = {
    name      = local.service_accounts["aws_efs_csi_driver"]["service_account_name"]
    namespace = local.service_accounts["aws_efs_csi_driver"]["service_account_namespace"]
    role_arn  = local.service_accounts["aws_efs_csi_driver"]["service_account_role_arn"]
  }
  cert_manager_sa = {
    name      = local.service_accounts["cert_manager"]["service_account_name"]
    namespace = local.service_accounts["cert_manager"]["service_account_namespace"]
    role_arn  = local.service_accounts["cert_manager"]["service_account_role_arn"]
  }
  cluster_autoscaler_sa = {
    name      = local.service_accounts["cluster_autoscaler"]["service_account_name"]
    namespace = local.service_accounts["cluster_autoscaler"]["service_account_namespace"]
    role_arn  = local.service_accounts["cluster_autoscaler"]["service_account_role_arn"]
  }
  external_dns_sa = {
    name      = local.service_accounts["external_dns"]["service_account_name"]
    namespace = local.service_accounts["external_dns"]["service_account_namespace"]
    role_arn  = local.service_accounts["external_dns"]["service_account_role_arn"]
  }
  loki_sa = {
    name      = local.service_accounts["loki"]["service_account_name"]
    namespace = local.service_accounts["loki"]["service_account_namespace"]
    role_arn  = local.service_accounts["loki"]["service_account_role_arn"]
  }
  thanos_sa = {
    name      = local.service_accounts["thanos"]["service_account_name"]
    namespace = local.service_accounts["thanos"]["service_account_namespace"]
    role_arn  = local.service_accounts["thanos"]["service_account_role_arn"]
  }
  grafana_sa = {
    name      = local.service_accounts["grafana"]["service_account_name"]
    namespace = local.service_accounts["grafana"]["service_account_namespace"]
    role_arn  = local.service_accounts["grafana"]["service_account_role_arn"]
  }
}
