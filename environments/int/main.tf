terraform {
  backend "s3" {
    encrypt = true
  }
}

data "terraform_remote_state" "aws-int" {
  backend = "s3"
  config = {
    bucket = var.aws-int_bucket
    key    = var.aws-int_key
    region = var.aws-int_region
  }
}

locals {
  state           = data.terraform_remote_state.aws-int.outputs.state
  vpc             = data.terraform_remote_state.aws-int.outputs.vpc
  subnets         = data.terraform_remote_state.aws-int.outputs.subnets
  efs             = data.terraform_remote_state.aws-int.outputs.efs
  eks_cluster     = data.terraform_remote_state.aws-int.outputs.eks_cluster
  eks_node_groups = data.terraform_remote_state.aws-int.outputs.eks_node_groups
  eks_efs_role    = data.terraform_remote_state.aws-int.outputs.eks_efs_role
}

data "aws_eks_cluster" "cluster" {
  name = local.eks_cluster["eks_cluster_id"]
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.eks_cluster["eks_cluster_id"]
}

module "kubeconfig" {
  source = "../../modules/kubeconfig"

  cluster_id                                   = local.eks_cluster["eks_cluster_id"]
  kubeconfig_aws_authenticator_additional_args = ["-r", local.state["role_arn"]]
}

// https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
resource "helm_release" "aws-efs-csi-driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.1.4"

  namespace = "kube-system"

  values = [
    yamlencode(
      {
        image = {
          tag = "v1.3.2"
        }
        sidecars = {
          livenessProbe = {
            image = {
              tag = "v2.2.0-eks-1-21-2"
            }
          }
          nodeDriverRegistrar = {
            image = {
              tag = "v2.1.0-eks-1-21-2"
            }
          }
          csiProvisioner = {
            image = {
              tag = "v2.1.1-eks-1-21-2"
            }
          }
        }
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = local.eks_efs_role["service_account_role_arn"]
            }
          }
        }
        storageClasses = [
          {
            name = "efs-sc"
            parameters = {
              provisioningMode = "efs-ap"
              fileSystemId     = local.efs["id"]
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

resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "v9.10.3"
  timeout    = 120

  namespace = "kube-system"

  values = [
    yamlencode(
      {
        cloudProvider = "aws"
        autoDiscovery = {
          clusterName = local.eks_cluster["eks_cluster_id"]
        }
        awsRegion        = var.aws_region
        fullnameOverride = "cluster-autoscaler"
        extraArgs = {
          aws-use-static-instance-list = true
        }
        image = {
          tag = "v1.21.0"
        }
      }
    )
  ]
}

resource "helm_release" "kubernetes-dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  timeout    = 60

  namespace        = "kubernetes-dashboard"
  create_namespace = true

  values = [
    yamlencode(
      {
        fullnameOverride = "kubernetes-dashboard"
      }
    )
  ]
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "loki-stack" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"

  namespace        = "loki-stack"
  create_namespace = true

  values = [
    yamlencode(
      {
        grafana = {
          enabled = "true"
        }
        promtail = {
          enabled = "true"
        }
        prometheus = {
          enabled = "true"
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
        loki = {
          enabled = "true"
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
