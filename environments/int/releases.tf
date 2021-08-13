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

  namespace        = local.loki_sa.namespace
  create_namespace = true

  // https://github.com/grafana/helm-charts/blob/main/charts/loki-stack/values.yaml
  // kubectl get secret --namespace loki-stack loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  values = [
    yamlencode(
      {
        // TODO: Add cloudwatch/cloudwatch logs service account, data source and dashboards
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
              redis = {
                gnetId     = 763
                revision   = 3
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
          //          config = {
          //            snippets = {
          //              extraScrapeConfigs = [
          //                {
          //                  job_name = "journal"
          //                  journal = {
          //                    path    = "/var/log/journal"
          //                    max_age = "12h"
          //                    labels = {
          //                      job = "systemd-journal"
          //                    }
          //                  }
          //                  relabel_configs = [
          //                    {
          //                      source_labels = ["__journal__systemd_unit"]
          //                      target_label  = "unit"
          //                    },
          //                    {
          //                      source_labels = ["__journal__hostname"]
          //                      target_label  = "hostname"
          //                    }
          //                  ]
          //                }
          //              ]
          //            }
          //          }
          //          extraVolumes = [
          //            {
          //              name = "journal"
          //              hostPath = {
          //                path = "/var/log/journal"
          //              }
          //            }
          //          ]
          //          extraVolumeMounts = [
          //            {
          //              name      = "journal"
          //              mountPath = "/var/log/journal"
          //              readOnly  = true
          //            }
          //          ]
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
        }
      }
    )
  ]

  depends_on = [
    helm_release.aws-efs-csi-driver,
    helm_release.cluster-issuers,
  ]
}
