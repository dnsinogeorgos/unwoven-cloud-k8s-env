output "cluster_autoscaler_role" {
  value = module.cluster_autoscaler_role
}

output "aws_efs_csi_driver_role" {
  value = module.aws_efs_csi_driver_role
}

output "cert_manager_role" {
  value = module.cert_manager_role
}

output "external_dns_role" {
  value = module.external_dns_role
}

output "loki_role" {
  value = module.loki_role
}
