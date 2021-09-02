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

data "aws_eks_cluster" "cluster" {
  name = local.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.eks_cluster_id
}

module "kubeconfig" {
  source = "../../modules/kubeconfig"

  cluster_id                                   = local.eks_cluster_id
  kubeconfig_aws_authenticator_additional_args = ["-r", local.role_arn]
}

resource "null_resource" "patch_kube-proxy_cm" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${module.kubeconfig.kubeconfig_filename} -n kube-system get cm kube-proxy-config -o yaml | sed 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | kubectl --kubeconfig ${module.kubeconfig.kubeconfig_filename} apply -f -"
  }
}

resource "null_resource" "patch_kube-proxy_ds" {
  provisioner "local-exec" {
    command = <<-EOF
                JSON="{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"updateTime\":\"$(date +"%s")\"}}}}}"
                kubectl --kubeconfig ${module.kubeconfig.kubeconfig_filename} -n kube-system patch ds kube-proxy -p "$JSON"
              EOF
  }

  depends_on = [null_resource.patch_kube-proxy_cm]
}
