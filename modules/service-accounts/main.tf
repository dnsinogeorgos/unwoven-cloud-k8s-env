// https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/helm-chart-aws-ebs-csi-driver-2.1.0/docs/example-iam-policy.json
data "aws_iam_policy_document" "aws_ebs_csi_driver" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
    ]
  }

  statement {
    effect = "Allow"
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*",
    ]
    actions = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateVolume",
        "CreateSnapshot",
      ]
    }
  }

  statement {
    effect = "Allow"
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*",
    ]
    actions = ["ec2:DeleteTags"]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DeleteSnapshot"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DeleteSnapshot"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

module "aws_ebs_csi_driver" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.aws_ebs_csi_driver_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.aws_ebs_csi_driver.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.aws_ebs_csi_driver_sa_name
  service_account_namespace   = var.aws_ebs_csi_driver_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "aws_efs_csi_driver" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "elasticfilesystem:CreateAccessPoint",
    ]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }


  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "elasticfilesystem:DeleteAccessPoint",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

module "aws_efs_csi_driver" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.aws_efs_csi_driver_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.aws_efs_csi_driver.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.aws_efs_csi_driver_sa_name
  service_account_namespace   = var.aws_efs_csi_driver_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:route53:::change/*"]
    actions   = ["route53:GetChange"]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["route53:ListHostedZonesByName"]
  }
}

module "cert_manager" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.cert_manager_enabled && var.route53_zone_id != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.cert_manager.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.cert_manager_sa_name
  service_account_namespace   = var.cert_manager_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]
  }

  // TODO: restrict the following statement resources to ASG ARNs
  // TODO: restrict the last condition to clustername (known-after-apply issue)
  // https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler#aws---iam
  statement {
    effect    = "Allow"
    resources = ["arn:aws:autoscaling:*:${var.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/*"]
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_autoscaler_eks_cluster_name}"
      values   = ["owned"]
    }
  }
}

module "cluster_autoscaler" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.cluster_autoscaler_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.cluster_autoscaler.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.cluster_autoscaler_sa_name
  service_account_namespace   = var.cluster_autoscaler_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
  }
}

module "external_dns" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.external_dns_enabled && var.route53_zone_id != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.external_dns.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.external_dns_sa_name
  service_account_namespace   = var.external_dns_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "loki" {
  statement {
    effect    = "Allow"
    resources = [var.loki_bucket_arn]
    actions = [
      "s3:ListObjects",
      "s3:ListBucket",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["${var.loki_bucket_arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]
  }
}

module "loki" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.loki_enabled && var.loki_bucket_arn != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.loki.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.loki_sa_name
  service_account_namespace   = var.loki_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "thanos" {
  statement {
    effect    = "Allow"
    resources = [var.thanos_bucket_arn]
    actions = [
      "s3:ListObjects",
      "s3:ListBucket",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["${var.thanos_bucket_arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
  }
}

module "thanos" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.thanos_enabled && var.thanos_bucket_arn != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.thanos.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.thanos_sa_name
  service_account_namespace   = var.thanos_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "grafana" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["tag:GetResources"]
  }
}

module "grafana" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.grafana_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.grafana.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.grafana_sa_name
  service_account_namespace   = var.grafana_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}
