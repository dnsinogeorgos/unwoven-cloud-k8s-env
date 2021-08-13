data "aws_iam_policy_document" "aws_efs_csi_driver_role" {
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

module "aws_efs_csi_driver_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.aws_efs_csi_driver_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.aws_efs_csi_driver_role.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.aws_efs_csi_driver_sa_name
  service_account_namespace   = var.aws_efs_csi_driver_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "cert_manager_role" {
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

module "cert_manager_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.cert_manager_enabled && var.route53_zone_id != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.cert_manager_role.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.cert_manager_sa_name
  service_account_namespace   = var.cert_manager_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "cluster_autoscaler_role" {
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

module "cluster_autoscaler_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.cluster_autoscaler_enabled
  aws_iam_policy_document     = data.aws_iam_policy_document.cluster_autoscaler_role.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.cluster_autoscaler_sa_name
  service_account_namespace   = var.cluster_autoscaler_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "external_dns_role" {
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

module "external_dns_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.external_dns_enabled && var.route53_zone_id != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.external_dns_role.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.external_dns_sa_name
  service_account_namespace   = var.external_dns_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}

data "aws_iam_policy_document" "loki_role" {
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

module "loki_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "0.10.0"

  enabled                     = var.loki_enabled && var.loki_bucket_arn != ""
  aws_iam_policy_document     = data.aws_iam_policy_document.loki_role.json
  aws_account_number          = var.aws_account_id
  service_account_name        = var.loki_sa_name
  service_account_namespace   = var.loki_sa_namespace
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url

  context = module.this.context
}
