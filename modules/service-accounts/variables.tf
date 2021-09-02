variable "aws_account_id" {
  type = string
}

variable "eks_cluster_oidc_issuer_url" {
  type = string
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

# aws-ebs-csi-driver
variable "aws_ebs_csi_driver_enabled" {
  type    = bool
  default = false
}

variable "aws_ebs_csi_driver_sa_name" {
  type    = string
  default = "aws-ebs-csi-driver-sa"
}

variable "aws_ebs_csi_driver_sa_namespace" {
  type    = string
  default = "aws-ebs-csi-driver"
}

# aws-efs-csi-driver
variable "aws_efs_csi_driver_enabled" {
  type    = bool
  default = false
}

variable "aws_efs_csi_driver_sa_name" {
  type    = string
  default = "aws-efs-csi-driver-sa"
}

variable "aws_efs_csi_driver_sa_namespace" {
  type    = string
  default = "aws-efs-csi-driver"
}

# cert-manager
variable "cert_manager_enabled" {
  type    = bool
  default = false
}

variable "cert_manager_sa_name" {
  type    = string
  default = "cert-manager-sa"
}

variable "cert_manager_sa_namespace" {
  type    = string
  default = "cert-manager"
}

# cluster-autoscaler
variable "cluster_autoscaler_enabled" {
  type    = bool
  default = false
}

variable "cluster_autoscaler_eks_cluster_name" {
  type    = string
  default = ""
}

variable "cluster_autoscaler_sa_name" {
  type    = string
  default = "cluster-autoscaler-sa"
}

variable "cluster_autoscaler_namespace" {
  type    = string
  default = "cluster-autoscaler"
}

# external-dns
variable "external_dns_enabled" {
  type    = bool
  default = false
}

variable "external_dns_sa_name" {
  type    = string
  default = "external-dns-sa"
}

variable "external_dns_sa_namespace" {
  type    = string
  default = "external-dns"
}

# loki
variable "loki_enabled" {
  type    = bool
  default = false
}

variable "loki_bucket_arn" {
  type    = string
  default = ""
}

variable "loki_sa_name" {
  type    = string
  default = "loki-sa"
}

variable "loki_sa_namespace" {
  type    = string
  default = "loki-stack"
}

# thanos
variable "thanos_enabled" {
  type    = bool
  default = false
}

variable "thanos_bucket_arn" {
  type    = string
  default = ""
}

variable "thanos_sa_name" {
  type    = string
  default = "thanos-sa"
}

variable "thanos_sa_namespace" {
  type    = string
  default = "monitoring"
}

# grafana
variable "grafana_enabled" {
  type    = bool
  default = false
}

variable "grafana_sa_name" {
  type    = string
  default = "grafana-sa"
}

variable "grafana_sa_namespace" {
  type    = string
  default = "monitoring"
}
