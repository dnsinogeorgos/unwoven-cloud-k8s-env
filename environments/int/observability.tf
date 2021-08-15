resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "17.2.1"
  atomic     = true
  timeout    = 120

  namespace        = "observability"
  create_namespace = true

  // https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  values = [
    yamlencode(
      {
        // https://github.com/prometheus-community/helm-charts/blob/main/charts/alertmanager/values.yaml
        alertmanager = {
          alertmanagerSpec = {
            retention = "168h"
            storage = {
              volumeClaimTemplate = {
                spec = {
                  storageClassName = "efs-sc"
                  accessModes      = ["ReadWriteOnce"]
                  resources = {
                    requests = {
                      storage = "200Gi"
                    }
                  }
                }
              }
            }
          }
          ingress = {
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            }
            enabled  = true
            hosts    = ["alertmanager.${local.zone_name}"]
            path     = "/"
            pathType = "Prefix"
            tls = [
              {
                secretName = "alertmanager-tls"
                hosts      = ["alertmanager.${local.zone_name}"]
              }
            ]
          }
        }
        grafana = {
          enabled                  = false
          forceDeployDatasources   = true
          forceDeployDashboards    = true
          defaultDashboardsEnabled = true
        }
        // https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/values.yaml
        prometheus = {
          ingress = {
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            }
            enabled  = true
            hosts    = ["prometheus.${local.zone_name}"]
            path     = "/"
            pathType = "Prefix"
            tls = [
              {
                secretName = "prometheus-tls"
                hosts      = ["prometheus.${local.zone_name}"]
              }
            ]
          }
          prometheusSpec = {
            retention = "30d"
            storageSpec = {
              volumeClaimTemplate = {
                spec = {
                  storageClassName = "efs-sc"
                  accessModes      = ["ReadWriteOnce"]
                  resources = {
                    requests = {
                      storage = "200Gi"
                    }
                  }
                }
              }
            }
          }
        }
      }
    )
  ]
}

//// TODO: Update for EKS CloudWatch
//// TODO: Update to add dashboards with proper configuration
//// TODO: Investigate alermanager and grafana alerting
//// TODO: Investigate smtp credentials
resource "helm_release" "loki-stack" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  atomic     = true
  timeout    = 120

  namespace        = "observability"
  create_namespace = true

  values = [
    yamlencode(
      {
        grafana = {
          sidecar = {
            datasources = {
              enabled = true
            }
          }
        }
        // by default loki and promtail are enabled, as well as grafana datasource for loki
        // https://github.com/grafana/helm-charts/blob/main/charts/loki/values.yaml
        loki = {
          config = {
            schema_config = {
              configs = [
                {
                  from         = "2021-08-11"
                  store        = "boltdb-shipper"
                  object_store = "aws"
                  schema       = "v11"
                  index = {
                    period = "24h"
                  }
                  chunks = {
                    period = "24h"
                  }
                }
              ]
            }
            storage_config = {
              aws = {
                bucketnames    = local.loki_bucket["bucket_id"]
                s3             = "s3://eu-central-1"
                region         = "eu-central-1"
                sse_encryption = true
              }
              boltdb_shipper = {
                cache_ttl            = "168h"
                query_ready_num_days = 7
                shared_store         = "s3"
              }
            }
          }
          persistence = {
            enabled          = true
            size             = "200Gi"
            storageClassName = "efs-sc"
          }
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = local.loki_sa.role_arn
            }
            name = local.loki_sa.name
          }
          serviceMonitor = {
            enabled = true
            additionalLabels = {
              release = "kube-prometheus-stack"
            }
          }
        }
      }
    )
  ]

  depends_on = [helm_release.kube-prometheus-stack]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  atomic     = true
  timeout    = 120

  namespace        = "observability"
  create_namespace = true

  // https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
  // kubectl get secret --namespace observability grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  values = [
    yamlencode(
      {
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
        dashboards = {
          default = {
            ingress-nginx = {
              gnetId     = 9614
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }
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
        serviceMonitor = {
          enabled = true
        }
        sidecar = {
          dashboards = {
            enabled = true
          }
          datasources = {
            enabled = true
          }
        }
      }
    )
  ]

  depends_on = [helm_release.kube-prometheus-stack]
}
