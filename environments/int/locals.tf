locals {
  account                      = data.terraform_remote_state.aws-int.outputs.account
  vpc                          = data.terraform_remote_state.aws-int.outputs.vpc
  subnets                      = data.terraform_remote_state.aws-int.outputs.subnets
  efs                          = data.terraform_remote_state.aws-int.outputs.efs
  eks_cluster                  = data.terraform_remote_state.aws-int.outputs.eks_cluster
  eks_node_groups              = data.terraform_remote_state.aws-int.outputs.eks_node_groups
  service_accounts             = data.terraform_remote_state.aws-int.outputs.service_accounts
  grafana_application          = data.terraform_remote_state.aad-int.outputs.grafana_application
  grafana_application_password = data.terraform_remote_state.aad-int.outputs.grafana_application_password

  role_arn                          = local.account["role_arn"]
  zone_name                         = local.account["zone_name"]
  zone_id                           = local.account["zone_id"]
  efs_id                            = local.efs["id"]
  eks_cluster_id                    = local.eks_cluster["eks_cluster_id"]
  efs_csi_sa_name                   = local.service_accounts["efs_csi_driver_role"]["service_account_name"]
  efs_csi_sa_namespace              = local.service_accounts["efs_csi_driver_role"]["service_account_namespace"]
  efs_csi_sa_role_arn               = local.service_accounts["efs_csi_driver_role"]["service_account_role_arn"]
  cluster_autoscaler_sa_name        = local.service_accounts["cluster_autoscaler_role"]["service_account_name"]
  cluster_autoscaler_sa_namespace   = local.service_accounts["cluster_autoscaler_role"]["service_account_namespace"]
  cluster_autoscaler_sa_role_arn    = local.service_accounts["cluster_autoscaler_role"]["service_account_role_arn"]
  route53_external_dns_sa_name      = local.service_accounts["route53_external_dns_role"]["service_account_name"]
  route53_external_dns_sa_namespace = local.service_accounts["route53_external_dns_role"]["service_account_namespace"]
  route53_external_dns_sa_role_arn  = local.service_accounts["route53_external_dns_role"]["service_account_role_arn"]
  grafana_client_id                 = local.grafana_application["application_id"]
  grafana_client_secret             = local.grafana_application_password["value"]
}
