resource "kubernetes_namespace" "observability" {
  metadata {
    name = local.observability_namespace_name
  }
}

resource "kubernetes_secret" "thanos-storage-config" {
  metadata {
    name      = "thanos-storage-config"
    namespace = kubernetes_namespace.observability.id
  }

  data = {
    "thanos-storage-config.yaml" = templatefile("${path.module}/templates/thanos-storage-config.tpl.yaml", {
      bucket_id  = local.bucket_thanos["bucket_id"]
      aws_region = var.aws_region
    })
  }
}

// https://aws.amazon.com/blogs/opensource/improving-ha-and-long-term-storage-for-prometheus-using-thanos-on-eks-with-s3/
module "ingress_secret_prometheus" {
  source = "../../modules/htpasswd"

  name      = "ingress-prometheus"
  namespace = kubernetes_namespace.observability.id

  users = ["admin"]
}

resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "17.2.1"
  atomic     = true
  timeout    = 120

  namespace = kubernetes_namespace.observability.id

  values = [templatefile("${path.module}/templates/kube-prometheus-stack.tpl.yaml", {
    sa_role_arn = local.thanos_sa.role_arn
    sa_name     = local.thanos_sa.name
    zone_name   = local.zone_name
    secret_name = module.ingress_secret_prometheus.name
  })]

  depends_on = [kubernetes_secret.thanos-storage-config]
}

//// TODO: Update for EKS CloudWatch
//// TODO: Update to add dashboards with proper configuration
//// TODO: Investigate alermanager and grafana alerting
//// TODO: Investigate smtp credentials
module "ingress_secret_loki" {
  source = "../../modules/htpasswd"

  name      = "ingress-loki"
  namespace = kubernetes_namespace.observability.id

  users = [
    "production",
    "sandbox",
    "staging",
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "2.6.0"
  atomic     = true
  timeout    = 120

  namespace = kubernetes_namespace.observability.id

  values = [templatefile("${path.module}/templates/loki.tpl.yaml", {
    sa_role_arn = local.loki_sa.role_arn
    sa_name     = local.loki_sa.name
    bucket_id   = local.bucket_loki["bucket_id"]
    aws_region  = var.aws_region
    zone_name   = local.zone_name
    secret_name = module.ingress_secret_loki.name
  })]

  depends_on = [helm_release.kube-prometheus-stack]
}

// TODO: multi-tenant promtail and grafana datasource
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "3.7.0"
  atomic     = true
  timeout    = 120

  namespace = kubernetes_namespace.observability.id

  values = [templatefile("${path.module}/templates/promtail.tpl.yaml", {
    account_id = local.account_id
  })]

  depends_on = [helm_release.kube-prometheus-stack]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  atomic     = true
  timeout    = 120
  version    = "6.16.0"

  namespace        = kubernetes_namespace.observability.id
  create_namespace = true

  values = [templatefile("${path.module}/templates/grafana.tpl.yaml", {
    sa_role_arn   = local.grafana_sa.role_arn
    sa_name       = local.grafana_sa.name
    zone_name     = local.zone_name
    client_id     = local.gh_grafana_client_id
    client_secret = local.gh_grafana_client_secret
    aws_region    = var.aws_region
    account_ids = {
      Internal = local.account_id
    }
  })]

  depends_on = [helm_release.kube-prometheus-stack]
}
