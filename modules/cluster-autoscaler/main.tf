data "aws_iam_policy_document" "eks_node_groups" {
  statement {
    sid       = "eksWorkerAutoscalingAll"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions"
    ]
  }

  statement {
    sid       = "eksWorkerAutoscalingOwn"
    effect    = "Allow"
    resources = [for k, v in var.node_groups : v["arn"]]

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup"
    ]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_id}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_policy" "eks_node_groups" {
  count = signum(length(var.node_groups))

  name   = "eks_node_groups"
  policy = data.aws_iam_policy_document.eks_node_groups.0.json
}

resource "aws_iam_role_policy_attachment" "eks_node_groups" {
  for_each = length(var.node_groups) != 0 ? var.node_groups : {}

  policy_arn = aws_iam_policy.eks_node_groups.0.arn
  role       = each.value["role_arn"]
}

resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler-chart"
  timeout    = 120

  namespace = "kube-system"

  values = [
    yamlencode(
      {
        autoDiscovery = {
          clusterName = var.cluster_id
        }
        awsRegion        = var.aws_region
        fullnameOverride = "cluster-autoscaler"
        extraArgs = {
          aws-use-static-instance-list = true
        }
      }
    )
  ]
}
