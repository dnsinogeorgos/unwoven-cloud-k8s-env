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

  cluster_autoscaler_eks_cluster_name = local.eks_cluster_id
  loki_bucket_arn                     = local.loki_s3_bucket_arn

  context = module.this.context
}

resource "helm_release" "aws-efs-csi-driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.1.4"
  timeout    = 60

  namespace        = local.aws_efs_csi_driver_sa.namespace
  create_namespace = true

  // https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/charts/aws-efs-csi-driver/values.yaml
  values = [
    yamlencode(
      {
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = local.aws_efs_csi_driver_sa.role_arn
            }
            name = local.aws_efs_csi_driver_sa.name
          }
        }
        storageClasses = [
          {
            name = "efs-sc"
            parameters = {
              provisioningMode = "efs-ap"
              fileSystemId     = local.efs_id
              directoryPerms   = "700"
              gidRangeStart    = "1000"
              gidRangeEnd      = "2000"
              basePath         = "/dynamic_provisioning"
            }
            reclaimPolicy     = "Delete"
            volumeBindingMode = "Immediate"
          }
        ]
      }
    )
  ]
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.4.2"
  timeout    = 60

  namespace        = local.cert_manager_sa.namespace
  create_namespace = true

  // https://github.com/jetstack/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
  values = [
    yamlencode(
      {
        extraArgs = [
          "--dns01-recursive-nameservers-only",
          "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
        ]
        installCRDs = "true"
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = local.cert_manager_sa.role_arn
          }
          name = local.cert_manager_sa.name
        }
        securityContext = {
          enabled = true
          fsGroup = 1001
        }
      }
    )
  ]
}

// TODO: investigate best practices, metrics-server and prometheus (VPA)
// TODO: convert this to use service account instead of nodegroup role
resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "v9.10.3"
  timeout    = 60

  namespace        = local.cluster_autoscaler_sa.namespace
  create_namespace = true

  // https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml
  values = [
    yamlencode(
      {
        autoDiscovery = {
          clusterName = local.eks_cluster_id
        }
        awsRegion     = var.aws_region
        cloudProvider = "aws"
        extraArgs = {
          aws-use-static-instance-list = true
        }
        fullnameOverride = "cluster-autoscaler"
        rbac = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = local.cluster_autoscaler_sa.role_arn
            }
            name = local.cluster_autoscaler_sa.name
          }
        }
      }
    )
  ]
}

// triggered on ingress and services (loadbalancer) with the following
//  annotations:
//    external-dns.alpha.kubernetes.io/hostname: <subdomain>.	int.6cb06.xyz.
resource "helm_release" "external-dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "5.2.2"
  timeout    = 60

  namespace        = local.external_dns_sa.namespace
  create_namespace = true

  // https://github.com/bitnami/charts/blob/master/bitnami/external-dns/values.yaml
  values = [
    yamlencode(
      {
        interval = "5s"
        policy   = "sync"
        provider = "aws"
        region   = var.aws_region
        registry = "txt"
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = local.external_dns_sa.role_arn
          }
          name = local.external_dns_sa.name
        }
        txtOwnerId    = local.eks_cluster_id
        txtPrefix     = "_external-dns."
        zoneIdFilters = [local.zone_id]
      }
    )
  ]
}

resource "helm_release" "cluster-issuers" {
  name  = "cluster-issuers"
  chart = "../../charts/cluster-issuers"

  wait = true

  values = [
    yamlencode(
      {
        email    = local.account["email"]
        region   = var.aws_region
        dnsZones = [local.account["zone_name"]]
      }
    )
  ]

  depends_on = [helm_release.cert-manager]
}

// *BEWARE* OF MULTIPLE NGINX-INGRESS DISTRIBUTIONS
// THIS IS A NIGHTMARE OF CONFUSING DOCUMENTATION, EXAMPLES AND TUTORIALS
//
// This is the kubernetes project ingress, NOT the official nginxinc
// https://docs.nginx.com/nginx-ingress-controller/intro/nginx-ingress-controllers
//
resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "3.35.0"
  atomic     = true
  timeout    = 60

  namespace        = "nginx-ingress"
  create_namespace = true

  // https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
  values = [
    yamlencode(
      {
        controller = {
          config = {
            use-proxy-protocol = "true"
          }
          metrics = {
            enabled = true
            port    = 10254
            service = {
              annotations = {
                "prometheus.io/scrape" = "true"
                "prometheus.io/port"   = "10254"
              }
            }
          }
          ingressClassResource = {
            enabled = true
            default = true
          }
          replicaCount = 3
          service = {
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-connection-draining-enable"        = "true"
              "service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout"       = "60"
              "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout"           = "60"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout"               = "2"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval"              = "5"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold"     = "2"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold"   = "2"
              "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"                    = "*"
            }
          }
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/instance" = "ingress-nginx"
                }
              }
            }
          ]
        }
      }
    )
  ]
}

resource "helm_release" "haproxy" {
  name       = "kubernetes-ingress"
  repository = "https://haproxytech.github.io/helm-charts"
  chart      = "kubernetes-ingress"
  version    = "1.16.2"
  atomic     = true

  namespace        = "haproxy-ingress"
  create_namespace = true

  // https://github.com/haproxytech/helm-charts/blob/main/kubernetes-ingress/values.yaml
  values = [
    yamlencode(
      {
        controller = {
          config = {
            forwarded-for  = "true"
            proxy-protocol = "0.0.0.0/0"
            ssl-redirect   = "true"
          }
          ingressClassResource = {
            enabled = true
            default = false
          }
          logging = {
            traffic = {
              address  = "stdout"
              format   = "raw"
              facility = "daemon"
            }
          }
          replicaCount = "3"
          service = {
            annotations = {
              "prometheus.io/port"   = "1024"
              "prometheus.io/scrape" = "true"

              "service.beta.kubernetes.io/aws-load-balancer-connection-draining-enable"        = "true"
              "service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout"       = "60"
              "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout"           = "60"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout"               = "2"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval"              = "5"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold"     = "2"
              "service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold"   = "2"
              "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"                    = "*"
            }
            enablePorts = {
              stat = false
            }
            type = "LoadBalancer"
          }
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name"     = "kubernetes-ingress"
                  "app.kubernetes.io/instance" = "kubernetes-ingress"
                }
              }
            }
          ]
        }
      }
    )
  ]
}
