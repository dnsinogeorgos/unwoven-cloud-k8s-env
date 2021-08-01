data "aws_eks_cluster" "cluster" { name = var.cluster_id }
data "aws_eks_cluster_auth" "cluster" { name = var.cluster_id }

locals {
  cluster_name    = data.aws_eks_cluster.cluster.name
  kubeconfig_name = var.kubeconfig_name == "" ? "eks_${local.cluster_name}" : var.kubeconfig_name
  kubeconfig = templatefile("${path.module}/templates/kubeconfig.tpl", {
    kubeconfig_name                   = local.kubeconfig_name
    endpoint                          = data.aws_eks_cluster.cluster.endpoint
    cluster_auth_base64               = data.aws_eks_cluster.cluster.certificate_authority[0].data
    aws_authenticator_command         = var.kubeconfig_aws_authenticator_command
    aws_authenticator_command_args    = length(var.kubeconfig_aws_authenticator_command_args) > 0 ? var.kubeconfig_aws_authenticator_command_args : ["token", "-i", local.cluster_name]
    aws_authenticator_additional_args = var.kubeconfig_aws_authenticator_additional_args
    aws_authenticator_env_variables   = var.kubeconfig_aws_authenticator_env_variables
  })
}

resource "local_file" "kubeconfig" {
  content = local.kubeconfig

  filename             = substr(var.kubeconfig_output_path, -1, 1) == "/" ? "${var.kubeconfig_output_path}kubeconfig_${local.cluster_name}" : var.kubeconfig_output_path
  file_permission      = var.kubeconfig_file_permission
  directory_permission = "0755"
}
