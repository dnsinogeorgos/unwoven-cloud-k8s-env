output "cluster_autoscaler" {
  value = module.cluster_autoscaler
}

output "aws_ebs_csi_driver" {
  value = module.aws_ebs_csi_driver
}

output "aws_efs_csi_driver" {
  value = module.aws_efs_csi_driver
}

output "cert_manager" {
  value = module.cert_manager
}

output "external_dns" {
  value = module.external_dns
}

output "loki" {
  value = module.loki
}

output "thanos" {
  value = module.thanos
}

output "grafana" {
  value = module.grafana
}
