// TODO: investigate best practices, metrics-server and prometheus (VPA)
// TODO: convert this to use service account instead of nodegroup role
resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "v9.10.3"

  namespace        = local.cluster_autoscaler_sa_namespace
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
              "eks.amazonaws.com/role-arn" = local.cluster_autoscaler_sa_role_arn
            }
            name = local.cluster_autoscaler_sa_name
          }
        }
      }
    )
  ]
}

resource "helm_release" "aws-efs-csi-driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.1.4"

  namespace        = local.efs_csi_sa_namespace
  create_namespace = true

  // https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/charts/aws-efs-csi-driver/values.yaml
  values = [
    yamlencode(
      {
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = local.efs_csi_sa_role_arn
            }
            name = local.efs_csi_sa_name
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

// triggered on ingress and services (loadbalancer) with the following
//  annotations:
//    external-dns.alpha.kubernetes.io/hostname: <subdomain>.	int.6cb06.xyz.
resource "helm_release" "external-dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "5.2.2"

  namespace        = local.route53_external_dns_sa_namespace
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
            "eks.amazonaws.com/role-arn" = local.route53_external_dns_sa_role_arn
          }
          name = local.route53_external_dns_sa_name
        }
        txtOwnerId    = local.eks_cluster_id
        zoneIdFilters = [local.zone_id]
      }
    )
  ]
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.4.2"

  namespace        = local.route53_cert_manager_sa_namespace
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
            "eks.amazonaws.com/role-arn" = local.route53_cert_manager_sa_role_arn
          }
          name = local.route53_cert_manager_sa_name
        }
        securityContext = {
          enabled = true
          fsGroup = 1001
        }
      }
    )
  ]
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "3.35.0"
  atomic     = true

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

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "10.1.1"
  atomic     = true

  namespace        = "traefik-ingress"
  create_namespace = true

  // https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
  values = [
    yamlencode(
      {
        deployment = {
          replicas = 3
        }
        globalArguments = [
          //            "--global.checknewversion",
          //            "--global.sendanonymoususage",
        ]
        ingressClass = {
          enabled        = "false"
          isDefaultClass = "false"
        }
        logs = {
          general = {
            level = "WARN"
          }
          access = {
            enabled = true
          }
        }
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

// TODO: Update for EKS CloudWatch
// TODO: Update to add dashboards with proper configuration
// TODO: Investigate alermanager and grafana alerting
// TODO: Investigate smtp credentials
resource "helm_release" "loki-stack" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  atomic     = true

  namespace        = "loki-stack"
  create_namespace = true

  // https://github.com/grafana/helm-charts/blob/main/charts/loki-stack/values.yaml
  // kubectl get secret --namespace loki-stack loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  values = [
    yamlencode(
      {
        // https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
        grafana = {
          dashboardProviders = {
            "dashboardproviders.yaml" = {
              apiVersion = 1
              providers = [
                {
                  name            = "default"
                  orgId           = 1
                  folder          = ""
                  type            = "file"
                  disableDeletion = false
                  editable        = true
                  options = {
                    path = "/var/lib/grafana/dashboards/default"
                  }
                }
              ]
            }
          }
          dashboards = {
            default = {
              prometheus-stats = {
                gnetId     = 2
                revision   = 2
                datasource = "Prometheus"
              }
              ingress-nginx = {
                gnetId     = 9614
                revision   = 1
                datasource = "Prometheus"
              }
              node-exporter = {
                gnetId     = 1860
                revision   = 23
                datasource = "Prometheus"
              }
            }
          }
          enabled = true
          "grafana.ini" = {
            server = {
              root_url = "https://grafana.${local.zone_name}"
              domain   = "grafana.${local.zone_name}"
            }
            "auth.github" = {
              enabled               = "true"
              allow_sign_up         = "true" // any github user can login
              client_id             = local.gh_grafana_client_id
              client_secret         = local.gh_grafana_client_secret
              scopes                = "user:email,read:org"
              auth_url              = "https://github.com/login/oauth/authorize"
              token_url             = "https://github.com/login/oauth/access_token"
              api_url               = "https://api.github.com/user"
              team_ids              = ""
              allowed_organizations = ""
            }
          }
          ingress = {
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            }
            enabled  = true
            hosts    = ["grafana.${local.zone_name}"]
            path     = "/"
            pathType = "Prefix"
            tls = [
              {
                secretName = "grafana-tls"
                hosts      = ["grafana.${local.zone_name}"]
              }
            ]
          }
        }
        // https://github.com/grafana/helm-charts/blob/main/charts/promtail/values.yaml
        promtail = {
          enabled = true
        }
        // https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/values.yaml
        prometheus = {
          enabled = true
          alertmanager = {
            persistentVolume = {
              enabled      = true
              size         = "200Gi"
              storageClass = "efs-sc"
            }
          }
          server = {
            persistentVolume = {
              enabled      = true
              size         = "200Gi"
              storageClass = "efs-sc"
            }
          }
        }
        // https://github.com/grafana/helm-charts/blob/main/charts/loki/values.yaml
        loki = {
          enabled = true
          persistence = {
            enabled          = true
            size             = "200Gi"
            storageClassName = "efs-sc"
          }
        }
      }
    )
  ]
}
