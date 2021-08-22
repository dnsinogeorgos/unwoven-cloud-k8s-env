// using a local to circumvent "known after apply" issue with modules
locals {
  observability_namespace_name = "observability"
}

module "service_accounts" {
  source = "../../modules/service-accounts"

  aws_account_id              = local.account_id
  eks_cluster_oidc_issuer_url = local.eks_cluster_oidc_issuer_url
  route53_zone_id             = local.zone_id

  aws_efs_csi_driver_enabled = true
  cert_manager_enabled       = true
  cluster_autoscaler_enabled = true
  external_dns_enabled       = true
  loki_enabled               = true
  thanos_enabled             = true
  grafana_enabled            = true

  cluster_autoscaler_eks_cluster_name = local.eks_cluster_id
  loki_bucket_arn                     = local.bucket_loki["bucket_arn"]
  loki_sa_namespace                   = local.observability_namespace_name
  thanos_bucket_arn                   = local.bucket_thanos["bucket_arn"]
  thanos_sa_namespace                 = local.observability_namespace_name
  grafana_sa_namespace                = local.observability_namespace_name

  context = module.this.context
}

resource "helm_release" "aws-efs-csi-driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.1.5"
  atomic     = true
  timeout    = 60

  namespace        = local.aws_efs_csi_driver_sa.namespace
  create_namespace = true

  values = [templatefile("${path.module}/templates/aws-efs-csi-driver.tpl.yaml", {
    sa_role_arn = local.aws_efs_csi_driver_sa.role_arn
    sa_name     = local.aws_efs_csi_driver_sa.name
    efs_id      = local.efs_id
  })]

  // users of efs-sc need time to shutdown before driver id destroyed
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 60"
  }
}

// TODO: decide on strategy for issuers, cluster or namespaced
resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.4.2"
  atomic     = true
  wait       = true
  timeout    = 60

  namespace        = local.cert_manager_sa.namespace
  create_namespace = true

  values = [templatefile("${path.module}/templates/cert-manager.tpl.yaml", {
    sa_role_arn = local.cert_manager_sa.role_arn
    sa_name     = local.cert_manager_sa.name
  })]

  depends_on = [helm_release.kube-prometheus-stack]

  // CRDs cannot be used until cert-manager is initialized
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

// TODO: investigate best practices, metrics-server and prometheus (VPA)
resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "v9.10.3"
  atomic     = true
  timeout    = 60

  namespace        = local.cluster_autoscaler_sa.namespace
  create_namespace = true

  values = [templatefile("${path.module}/templates/cluster-autoscaler.tpl.yaml", {
    sa_role_arn    = local.cluster_autoscaler_sa.role_arn
    sa_name        = local.cluster_autoscaler_sa.name
    eks_cluster_id = local.eks_cluster_id
    aws_region     = var.aws_region
  })]

  depends_on = [helm_release.kube-prometheus-stack]
}

// TODO: use repository directly instead of github release
resource "helm_release" "external-dns" {
  name    = "external-dns"
  chart   = "https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-1.2.0/external-dns-1.2.0.tgz"
  atomic  = true
  timeout = 60

  namespace        = local.external_dns_sa.namespace
  create_namespace = true

  values = [templatefile("${path.module}/templates/external-dns.tpl.yaml", {
    sa_role_arn    = local.external_dns_sa.role_arn
    sa_name        = local.external_dns_sa.name
    eks_cluster_id = local.eks_cluster_id
    zone_names     = [local.zone_name]
  })]

  depends_on = [helm_release.kube-prometheus-stack]
}

resource "helm_release" "cluster-issuers" {
  name  = "cluster-issuers"
  chart = "../../charts/cluster-issuers"

  values = [templatefile("${path.module}/templates/cluster-issuers.tpl.yaml", {
    account_email = local.account_email
    aws_region    = var.aws_region
    zone_names    = [local.zone_name]
  })]

  depends_on = [helm_release.cert-manager]
}

// TODO: build pipeline for arm64 and host repository
resource "helm_release" "eventrouter" {
  name       = "eventrouter"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "eventrouter"
  version    = "0.3.6"
  atomic     = true
  timeout    = 30

  namespace = "kube-system"

  values = [templatefile("${path.module}/templates/eventrouter.tpl.yaml", {})]
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "3.35.0"
  atomic     = true
  timeout    = 60

  namespace        = "nginx-ingress"
  create_namespace = true

  values = [templatefile("${path.module}/templates/ingress-nginx.tpl.yaml", {})]

  depends_on = [helm_release.kube-prometheus-stack]
}
